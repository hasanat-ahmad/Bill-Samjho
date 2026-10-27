#!/usr/bin/env bash
# Negative API tests for the extractBill / extractBillText Cloud Functions,
# run against the local Firebase emulator. Every request here must be
# rejected BEFORE the rate limiter and Gemini, so no AI quota is used.
#
#   cd functions && npm run build && cd ..
#   firebase emulators:start --only functions --project demo-bill-samjho
#   scripts/api_negative_tests.sh            # in another terminal
#
# BASE can point elsewhere: BASE=http://127.0.0.1:5001/<project>/asia-south1
set -uo pipefail
BASE="${BASE:-http://127.0.0.1:5001/demo-bill-samjho/asia-south1}"
UUID="123e4567-e89b-42d3-a456-426614174000"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

# check <id> <description> <expected status> <expected error code or -> -- <curl args...>
check() {
  local id="$1" what="$2" want_status="$3" want_error="$4"
  shift 5
  local status
  status="$(curl -s -o "$tmp/body" -D "$tmp/headers" -w '%{http_code}' "$@")"
  local body; body="$(cat "$tmp/body")"
  local ok=1
  [[ "$status" == "$want_status" ]] || ok=0
  if [[ "$want_error" != "-" ]]; then
    [[ "$body" == "{\"error\":\"$want_error\"}" ]] || ok=0
    # Error responses must not be cached and must not be content-sniffed.
    grep -qi '^cache-control: no-store' "$tmp/headers" || ok=0
    grep -qi '^x-content-type-options: nosniff' "$tmp/headers" || ok=0
  fi
  # No stack traces or file paths in any response.
  grep -qiE 'at [A-Za-z_.]+ \(|/functions/|node_modules' "$tmp/body" && ok=0
  if (( ok )); then
    pass=$((pass + 1)); printf 'PASS %-6s %s → %s %s\n' "$id" "$what" "$status" "$body"
  else
    fail=$((fail + 1)); printf 'FAIL %-6s %s → got %s %s (wanted %s %s)\n' "$id" "$what" "$status" "$body" "$want_status" "$want_error"
  fi
}

printf '\xff\xd8\xff\xe0fakejpeg' > "$tmp/small.jpg"
printf '\x89PNG\r\n\x1a\nnotjpeg' > "$tmp/image.png"
head -c 600000 /dev/zero | tr '\0' 'a' > "$tmp/big.jpg"
python3 -c "import json; print(json.dumps({'deviceId': '$UUID', 'text': 'x' * 30}))" > "$tmp/short.json"
python3 -c "import json; print(json.dumps({'deviceId': 'not-a-uuid', 'text': 'PAYABLE WITHIN DUE DATE ' * 5}))" > "$tmp/baddevice.json"
python3 -c "import json; print(json.dumps({'deviceId': '$UUID', 'text': 'x' * 20001}))" > "$tmp/long.json"
python3 -c "import json; print(json.dumps({'deviceId': '$UUID', 'text': 'x' * 90000}))" > "$tmp/huge.json"

echo "== extractBill (photo)"
check API-01 "GET is not allowed"            405 method_not_allowed -- "$BASE/extractBill"
check API-02 "PUT is not allowed"            405 method_not_allowed -- -X PUT "$BASE/extractBill"
check API-03 "JSON instead of multipart"     400 unreadable -- -X POST -H 'Content-Type: application/json' -d '{}' "$BASE/extractBill"
check API-04 "no deviceId"                   400 unreadable -- -F "image=@$tmp/small.jpg;type=image/jpeg" "$BASE/extractBill"
check API-05 "deviceId not a UUID"           400 unreadable -- -F deviceId=abc -F "image=@$tmp/small.jpg;type=image/jpeg" "$BASE/extractBill"
check API-06 "no image"                      400 unreadable -- -F deviceId=$UUID "$BASE/extractBill"
check API-07 "PNG named .jpg (not a JPEG)"   400 unreadable -- -F deviceId=$UUID -F "image=@$tmp/image.png;type=image/jpeg" "$BASE/extractBill"
check API-08 "image over 500 KB"             413 too_large  -- -F deviceId=$UUID -F "image=@$tmp/big.jpg;type=image/jpeg" "$BASE/extractBill"
check API-09 "malformed multipart body"      400 unreadable -- -X POST -H 'Content-Type: multipart/form-data; boundary=zz' --data-binary $'--zz\r\nbroken' "$BASE/extractBill"

echo "== extractBillText (PITC page text)"
check API-10 "GET is not allowed"            405 method_not_allowed -- "$BASE/extractBillText"
check API-11 "text/plain instead of JSON"    400 unreadable -- -X POST -H 'Content-Type: text/plain' -d 'hello' "$BASE/extractBillText"
check API-12 "text under 50 characters"      400 unreadable -- -X POST -H 'Content-Type: application/json' --data-binary "@$tmp/short.json" "$BASE/extractBillText"
check API-13 "deviceId not a UUID"           400 unreadable -- -X POST -H 'Content-Type: application/json' --data-binary "@$tmp/baddevice.json" "$BASE/extractBillText"
check API-14 "text 20,001 chars (limit+1)"   400 unreadable -- -X POST -H 'Content-Type: application/json' --data-binary "@$tmp/long.json" "$BASE/extractBillText"
check API-15 "body over 81 KB"               413 too_large  -- -X POST -H 'Content-Type: application/json' --data-binary "@$tmp/huge.json" "$BASE/extractBillText"
check API-16 "text is a number, not a string" 400 unreadable -- -X POST -H 'Content-Type: application/json' -d "{\"deviceId\":\"$UUID\",\"text\":12345}" "$BASE/extractBillText"
check API-17 "malformed JSON"                400 -          -- -X POST -H 'Content-Type: application/json' -d '{"deviceId":' "$BASE/extractBillText"

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
