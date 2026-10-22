# Bill Samjho — بل سمجھو

Android app that reads a photo of a Pakistani electricity bill (WAPDA DISCOs and K-Electric) and explains it in simple words, by text and voice, in **English (default) or Urdu**. It says whether the bill looks normal and warns about the 200-unit protected limit.

Full requirements and design: [bill-samjho-srs-sda.md](bill-samjho-srs-sda.md). Security design: [SECURITY.md](SECURITY.md).

```
app/         Flutter app (Android only)
functions/   Firebase Cloud Function `extractBill` (TypeScript, Gemini)
firebase.json, firestore.rules
```

**Key principle:** AI only reads the image. The rules engine on the phone makes every judgement and fills every number into fixed templates.

## Changes from the SRS

| SRS | Now | Why |
|---|---|---|
| NFR-02: UI in Urdu | English by default; English/اردو switch on the first screen and in Settings. Urdu is fully right-to-left with Noto Nastaliq. | Product owner decision. |
| §8 `Finding.urduText` | `Finding.params` (raw values); text is built when shown | A saved bill is explained in whichever language is chosen later. |
| §10.3 `urdu_strings.json` | `assets/i18n/en.json` and `ur.json` (UI labels, templates, errors, glossary) | Two languages; a test checks both files have the same keys and placeholders. |

## Run the app

Debug builds without a backend URL run in **demo mode**: a sample LESCO bill, with a banner saying so.

```sh
cd app
flutter pub get
flutter run                                   # demo mode (debug only)
flutter test                                  # rules engine, security, i18n and UI flow tests
```

With the real backend:

```sh
flutter run --dart-define=EXTRACT_URL=https://asia-south1-<project-id>.cloudfunctions.net/extractBill
```

Release builds (obfuscated, debug symbols kept out of the APK):

```sh
# Play Store: the bundle delivers one CPU architecture per phone
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=EXTRACT_URL=https://...
# Sideloading: one APK per architecture (most phones need app-arm64-v8a-release.apk, ~20 MB)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols \
  --dart-define=EXTRACT_URL=https://...
```

A release build never falls back to demo data: without a valid `https://` `EXTRACT_URL` scanning shows "not available" (unless `--dart-define=USE_MOCK_API=true` is passed explicitly, which shows the demo banner). A plain `flutter build apk` makes a universal APK (~54 MB); the per-architecture APKs stay under the 25 MB limit (NFR-06).

## Test with real bills locally (no cloud project needed)

Runs the real backend and Gemini on this Mac, using the Firebase emulator with an offline `demo-` project.

```sh
# 1. Local secrets (both files are git-ignored)
printf 'GEMINI_API_KEY=<your key>\nRATE_LIMIT_SECRET=%s\n' "$(openssl rand -hex 32)" > functions/.secret.local
printf 'GEMINI_MODEL=gemini-3.5-flash,gemini-3.5-flash-lite,gemini-flash-latest\nREQUIRE_APP_CHECK=false\n' > functions/.env.local

# 2. Backend
cd functions && npm install && npm run build && cd ..
firebase emulators:start --only functions,firestore --project demo-bill-samjho

# 3. App on the Android emulator (debug builds may use plain HTTP to 10.0.2.2 only)
cd app && flutter run --dart-define=EXTRACT_URL=http://10.0.2.2:5001/demo-bill-samjho/asia-south1/extractBill
```

Gemini models are tried in order: if one is overloaded (503) or slow, the next is used within an 18-second budget. On 2026-10-22, `gemini-2.5-flash` was no longer available to new keys and `gemini-3.5-flash` / `gemini-3.5-flash-lite` read test bills correctly in 4–11 s.

## Firebase setup

The app works without Firebase: it uses the bundled tariff config, no crash reporting and no App Check. To connect it:

1. Create a Firebase project and **upgrade it to the Blaze plan** (required for Cloud Functions and Secret Manager).
2. Link the Android app. This creates `app/android/app/google-services.json`; Gradle then turns on the Firebase and Crashlytics plugins automatically.
   ```sh
   dart pub global activate flutterfire_cli
   cd app && flutterfire configure --platforms=android
   ```
3. **App Check:** in the Firebase console, register the app with the **Play Integrity** provider (add the release SHA-256 signing fingerprint). For debug builds, add the debug token printed in logcat.
4. Deploy the backend:
   ```sh
   firebase use <project-id>
   cp functions/.env.example functions/.env           # set GEMINI_MODEL
   firebase functions:secrets:set GEMINI_API_KEY      # stays on the server only
   firebase functions:secrets:set RATE_LIMIT_SECRET   # any long random string, e.g. `openssl rand -hex 32`
   firebase deploy --only functions,firestore
   ```
5. In the Firestore console, add a **TTL policy** on collection `rateLimits`, field `expiresAt`, so old rate-limit counters are deleted.
6. In **Remote Config**, add parameter `tariff_config` (type JSON) with the contents of `app/assets/tariff_config_default.json`. Tariff changes then reach users without an app release. Out-of-range values are rejected by the app.
7. In Google Cloud console, set a **daily quota** on the Gemini API key as a cost ceiling.

## Backend

`POST /extractBill`, multipart: `image` (JPEG ≤ 500 KB) and `deviceId` (UUID), header `X-Firebase-AppCheck`.

| Status | Body | Meaning |
|---|---|---|
| 200 | ExtractedBill JSON (snake_case) | Read successfully |
| 400 | `{"error":"not_a_bill"}` / `{"error":"unreadable"}` | Wrong photo, unclear, or not a JPEG |
| 401 | `{"error":"unauthorized"}` | Missing or invalid App Check token |
| 413 | `{"error":"too_large"}` | Image over 500 KB |
| 429 | `{"error":"rate_limited"}` | 30 per device / 300 per IP per day |
| 503 | `{"error":"ai_busy"}` | Gemini unavailable or timed out |

The image is parsed in memory and never stored or logged. Firestore holds only daily counters keyed by device ID and a keyed hash of the IP.

```sh
cd functions && npm install && npm test && npm audit
```

## Before release: VERIFY / TODO

- [x] Tariff rates checked against NEPRA decision TRF-100 / S.R.O. 279(I)/2026 (12 Feb 2026). **Re-check after every new NEPRA notification** and update Remote Config. The energy check accepts both the official and the older non-protected method, and is skipped for bills older than `effective_from`.
- [ ] **Gemini model name** in `functions/.env` (`GEMINI_MODEL`).
- [ ] **Urdu text review** by a native speaker: `app/assets/i18n/ur.json`.
- [ ] Release signing config in `app/android/app/build.gradle.kts` (currently debug keys).
- [ ] Test with 20 real bills from at least 3 DISCOs (acceptance target: ≥ 18 read correctly).
- [ ] Usability test with 5 non-technical users in both languages (acceptance criterion).
