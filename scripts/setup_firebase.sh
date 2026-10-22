#!/usr/bin/env bash
# One-time Firebase setup and deploy for Bill Samjho.
#
#   scripts/setup_firebase.sh <firebase-project-id> [--require-app-check]
#
# Needs: the project on the Blaze plan, `firebase login`, and
# functions/.secret.local containing GEMINI_API_KEY=... (never committed).
#
# App Check: sideloaded APKs cannot pass Play Integrity, so enforcement is
# OFF unless --require-app-check is given. Turn it on once the app is
# distributed through Google Play. Rate limits apply either way.
set -euo pipefail

PROJECT="${1:?usage: scripts/setup_firebase.sh <project-id> [--require-app-check]}"
REQUIRE_APP_CHECK=false
[[ "${2:-}" == "--require-app-check" ]] && REQUIRE_APP_CHECK=true
PACKAGE=pk.billsamjho.bill_samjho
REGION=asia-south1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ -f functions/.secret.local ]] || { echo "functions/.secret.local with GEMINI_API_KEY is missing"; exit 1; }

echo "== Project $PROJECT"
firebase use "$PROJECT"

echo "== Android app"
APP_ID=$(firebase apps:list ANDROID --project "$PROJECT" 2>/dev/null | grep -oE '1:[0-9]+:android:[0-9a-f]+' | head -1 || true)
if [[ -z "$APP_ID" ]]; then
  firebase apps:create ANDROID "Bill Samjho" --package-name "$PACKAGE" --project "$PROJECT"
  APP_ID=$(firebase apps:list ANDROID --project "$PROJECT" | grep -oE '1:[0-9]+:android:[0-9a-f]+' | head -1)
fi
firebase apps:sdkconfig ANDROID "$APP_ID" --project "$PROJECT" -o app/android/app/google-services.json

echo "== Firestore (rate-limit counters only)"
if ! OUT=$(firebase firestore:databases:create "(default)" --location "$REGION" --project "$PROJECT" 2>&1); then
  if grep -qi "already exists" <<<"$OUT"; then
    echo "(database already exists)"
  else
    echo "$OUT"
    echo "Create the Firestore database in the console (Firestore Database → Create database, $REGION), then re-run."
    exit 1
  fi
fi

echo "== Secrets"
grep '^GEMINI_API_KEY=' functions/.secret.local | cut -d= -f2- | tr -d '\n' \
  | firebase functions:secrets:set GEMINI_API_KEY --data-file - --project "$PROJECT" --force
grep '^RATE_LIMIT_SECRET=' functions/.secret.local | cut -d= -f2- | tr -d '\n' \
  | firebase functions:secrets:set RATE_LIMIT_SECRET --data-file - --project "$PROJECT" --force

echo "== Function settings"
{
  grep '^GEMINI_MODEL=' functions/.env.example
  echo "REQUIRE_APP_CHECK=$REQUIRE_APP_CHECK"
} > functions/.env

echo "== Remote Config (tariffs from app/assets/tariff_config_default.json)"
python3 - <<'PY'
import json
tariff = json.load(open('app/assets/tariff_config_default.json'))
template = {"parameters": {"tariff_config": {
    "defaultValue": {"value": json.dumps(tariff, ensure_ascii=False)},
    "valueType": "JSON",
    "description": "NEPRA domestic tariff used by the rules engine",
}}}
json.dump(template, open('remoteconfig.template.json', 'w'), ensure_ascii=False, indent=1)
PY

echo "== Deploy"
(cd functions && npm ci && npm run build)
firebase deploy --only functions,firestore,remoteconfig --project "$PROJECT"

URL="https://$REGION-$PROJECT.cloudfunctions.net/extractBill"
echo "== Build APK against $URL"
(cd app && flutter build apk --release --split-per-abi --dart-define=EXTRACT_URL="$URL")
mkdir -p "$HOME/Desktop/BillSamjho"
cp app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$HOME/Desktop/BillSamjho/BillSamjho-arm64.apk"
cp app/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$HOME/Desktop/BillSamjho/BillSamjho-older-phones.apk"
echo "Done. APKs in ~/Desktop/BillSamjho. Next: Firestore TTL policy on rateLimits.expiresAt (console)."
