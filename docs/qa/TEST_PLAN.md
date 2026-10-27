# Test Plan — Bill Samjho

## 1. Strategy

**Risk-based.** Effort goes where a wrong answer hurts users most:

1. Bill data crossing a trust boundary: AI output, the PITC page, the backend.
2. Money and unit calculations: the rules engine, the forecaster, the appliance calculator.
3. Things that run unattended: reminders.
4. Privacy and security controls.

UI polish is lowest.

| Level | Tool | Where |
|---|---|---|
| Unit | `flutter_test` | `app/test/*_test.dart` (rules, forecaster, parsers, validation, speech) |
| Widget / end-to-end (in-process) | `flutter_test` with `BillSamjhoApp`, in-memory Hive, fake scanner, fake chat | `app/test/app_flow_test.dart` |
| Backend unit | `node --test` | `functions/src/validate.test.ts` |
| API (HTTP) | curl script against the Firebase emulator | `scripts/api_negative_tests.sh` |
| Static | `flutter analyze` (flutter_lints), `tsc` | CI |
| Dependency | `npm audit` | CI |
| Manual smoke / exploratory | Real phone | Section 4 |

**Entry criteria:** the code builds, and `flutter analyze` is clean.

**Exit criteria:**

- All automated tests pass.
- No open P0/P1 *defects* in code.
- P1 *release* items (S-01, S-04) are signed off by the owner.

Status values: **Pass**, **Fail**, **Blocked** (could not run), **Not run**.

## 2. Requirements traced

From the SRS ([bill-samjho-srs-sda.md](../../bill-samjho-srs-sda.md)), README and code: FR-04 (photo compression), FR-07 (confirm and edit numbers), FR-10 (voice), NFR-07 (encrypted storage), NFR-09 (untrusted backend data), rules R1–R7, the 200-unit protected limit, reminders, the estimate and the appliance calculator.

## 3. Automated test cases

Actual result for every row below: **Pass** in the final run on 27 Oct 2026, with two exceptions:

- API-17 **failed**: emulator only, see S-03.
- AUTH-01 is **Blocked**.

The evidence for each row is the test named in the last column.

### 3.1 Smoke (the app starts and the main path works)

| ID | Objective | Steps / data | Expected | Test |
|---|---|---|---|---|
| SM-A1 | First launch shows intro in English, left-to-right | Fresh store | "Understand your electricity bill", LTR | `app_flow_test` UC-1 |
| SM-A2 | Scan → confirm → result → complaint | Mock API sample bill | Confirm shows 186 / 7233; result verdict; complaint sheet | `app_flow_test` UC-1 |
| SM-A3 | Urdu, right-to-left | Switch language to Urdu | RTL; Urdu strings | `app_flow_test` *switching to Urdu flips the app right-to-left* |
| SM-A4 | Backend validator builds and runs | `npm test` | 15 pass | `validate.test.ts` |

### 3.2 Functional: business rules

| ID | Objective | Expected | Test |
|---|---|---|---|
| FN-01 | R1 energy charge matches either tariff within 3% | No R1 when within tolerance; R1 "wrong" otherwise | `rules_engine_test` R1 group |
| FN-02 | R2 big jump vs 6-month average (×1.4 check, ×2 wrong) | Severity by ratio | R2 group |
| FN-03 | R4 protected status lost, and the month it returns | Fires above 200; "after {month}" = last over + 6 | R4 group |
| FN-04 | Credit bill (negative total) | No "pay" reminder; "credit of Rs 297" | `rules_engine_test`, `reminders_test`, `pitc_parser_test` |
| FN-05 | Rescan of the same month replaces the old bill | One bill per month | `bill_repository_test` |
| FN-06 | Next-bill estimate: same month last year, then recent months, then this bill | Correct basis chosen | `forecaster_test` |
| FN-07 | Estimate from today's meter reading | 120 units in 20 days → about 180 units | `forecaster_test`, `app_flow_test` |
| FN-08 | Appliance calculator | 1.5-ton AC 6 h = 270 units; cost jumps past 200 | `appliances_test`, `app_flow_test` |
| FN-09 | Reminders | 3 days before due at 10:00; new-bill reminder at due + 20 | `reminders_test` |
| FN-10 | Speech text | "Rs 7,233" → "7,233 rupees"; Urdu numbers in words | `speech_test`, `urdu_numbers_test` |
| FN-11 | Chat prompt grounded in bill numbers | Includes reading date, today's date, what-if amounts | `chat_test` |
| FN-12 | Dictation: speech fills the box, the user sends, a late result does not refill it | Box stays empty after send | `dictation_test` *a late result after sending does not refill the box* |

### 3.3 Positive and negative: untrusted bill data (NFR-09)

Equivalence classes for each number:

1. A valid number.
2. A number written as text.
3. Out of range.
4. Non-finite (NaN, Infinity).
5. Wrong type.
6. Missing.

| ID | Input | Class | Expected | Test |
|---|---|---|---|---|
| NG-01 | `units: null / -1 / 5001` | missing, below, above range | `FormatException` (rejected) | `security_test` |
| NG-02 | `total_due: NaN / ±1e12` | non-finite, out of range | rejected | `security_test` |
| NG-03 | `bill_month: "September" / "2026-13"` | invalid format | rejected | `security_test` |
| NG-04 | `units: "Infinity"`, `total_due: "NaN"` (text) | non-finite as text | rejected with `FormatException` (**was `UnsupportedError`**, D-02) | `security_test` (new) |
| NG-05 | `confidence: "NaN"` | non-finite | 0, not 1.0 (**D-02**) | `security_test` (new) |
| NG-06 | `confidence: "0.9"` on the AI path | number as text | read as 0.9 (**was "AI busy"**, D-02) | `firebase_ai_parse_test` (new) |
| NG-07 | `due_date: "2026-10-5"` | valid but short | stored `2026-10-05` (**D-01**) | `security_test` (new) |
| NG-08 | `reading_date: "2026-02-31"` | impossible date | dropped (**D-01**) | `security_test` (new) |
| NG-09 | `bill_month: "2026-9"`, history `"2026-8"` | valid but short | stored `2026-09` / `2026-08` (**D-01**) | `security_test` (new) |
| NG-10 | Reference number with bidi override and NUL, 200+ characters | malicious text | stripped, capped at 40 | `security_test` |
| NG-11 | 40 history rows | oversized list | capped at 24 | `security_test` |
| NG-12 | `history: "oops"` | wrong type | ignored | `security_test` |
| NG-13 | Model says not a bill / garbage JSON / low confidence | invalid | `notABill` / `unreadable` | `firebase_ai_parse_test` |
| NG-14 | Remote tariff with limit 0, rate 0, rate 99999, empty slabs | out of range | rejected, previous config kept | `security_test` |
| NG-15 | Backend URL `http://` in release | insecure | service unavailable | `security_test` |
| NG-16 | PITC page with no bill, or broken JSON | invalid page | parse returns null | `pitc_parser_test` |

### 3.4 Boundary value analysis

| ID | Boundary | Values tested | Expected | Test |
|---|---|---|---|---|
| BV-01 | Protected limit, 200 units (R4) | 200, 201 | 200: no R4; 201: R4 | `rules_engine_test` |
| BV-02 | Near-limit warning, 180–200 (R5) | 179, 180, 200, 201 | fires only for 180–200 | `rules_engine_test` |
| BV-03 | Protected energy | 180, 200, 201 | 201 → null (not protected) | `rules_engine_test` |
| BV-04 | Units allowed | -1, 0, 5000, 5001 | -1 and 5001 rejected | `security_test`, confirm form |
| BV-05 | Days since meter reading (1–60 allowed) | 0, 1, 60, 61 | tooSoon, ok, ok, tooOld | `forecaster_test` (new) |
| BV-06 | Today's reading vs bill reading | 354, 355 (bill = 355) | belowBill, ok with 0 units and no amount | `forecaster_test` (new) |
| BV-07 | Calendar dates | 02-28, 02-29 (2026 vs 2028), 04-30/31, month 00/13, day 00/32, 01-01, 12-31 | only real dates | `format_test` (new) |
| BV-08 | Questions per chat (real limit 20) | Limit logic, with a fake chat whose limit is 2 | Question after the limit is not sent; limit shown | `chat_test` *limit on questions per chat*; the real 20 is **not** tested at 19/20/21 (gap) |
| BV-09 | API page text 50–20,000 characters | 30; 20,001 | 400 | API-12, API-14 |
| BV-10 | API image ≤ 500 KB | 600 KB | 413 | API-08 |

### 3.5 API tests: `scripts/api_negative_tests.sh` (Firebase emulator)

Each test asserts the status code, the **exact error body**, `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, and **no stack trace or path** in the body. None of these requests reaches the rate limiter or Gemini.

| ID | Endpoint | Request | Expected | Actual |
|---|---|---|---|---|
| API-01/02 | extractBill | GET, PUT | 405 `method_not_allowed` | Pass |
| API-03 | extractBill | JSON content type | 400 `unreadable` | Pass |
| API-04/05/06 | extractBill | no deviceId / `abc` / no image | 400 | Pass |
| API-07 | extractBill | PNG bytes named `.jpg` | 400 (magic-byte check) | Pass |
| API-08 | extractBill | 600 KB file | 413 `too_large` | Pass |
| API-09 | extractBill | broken multipart | 400 | Pass |
| API-10/11 | extractBillText | GET / text/plain | 405 / 400 | Pass |
| API-12/13/14 | extractBillText | short text / bad UUID / 20,001 characters | 400 | Pass |
| API-15 | extractBillText | 90 KB body | 413 | Pass |
| API-16 | extractBillText | `text` is a number | 400 | Pass |
| API-17 | extractBillText | malformed JSON | 400, no stack trace | **Fail**: stack trace (emulator, S-03) |
| AUTH-01 | both | no App Check token, enforcement on | 401 `unauthorized` | **Blocked** (local env disables it) |
| RL-01 | both | 31st request from a device in one day | 429 `rate_limited` | **Blocked** (would spend Gemini quota) |

### 3.6 Regression tests for fixed defects

| Defect | Tests |
|---|---|
| D-01 | `security_test` *dates and months are normalised…*; `reminders_test` *a bill with an unreadable due date…*; `format_test` (3) |
| D-02 | `security_test` *non-finite numbers…*; `firebase_ai_parse_test` *numbers written as text…* |
| D-03 | Manual only (MT-05) |

## 4. Manual tests (real phone)

Run on a real Android phone with the release APK. Use a **test meter with synthetic data**, not your own bills, when screen-recording.

| ID | Type | Steps | Expected |
|---|---|---|---|
| SM-01 | Smoke | Install APK, open | Intro, no crash |
| SM-02 | Smoke | Add meter, look up a bill by reference number on PITC, Explain this bill | Confirm screen with numbers |
| SM-03 | Smoke | Scan a bill photo | Confirm screen within 20 s, or a clear error |
| SM-04 | Smoke | Result → Listen (English and Urdu), airplane mode on | Speaks offline |
| SM-05 | Smoke | Estimate next bill with a reading | Estimate card |
| SM-06 | Smoke | Ask about this bill | Answer streams |
| SM-07 | Smoke | Appliance calculator | Extra units and cost |
| SM-08 | Smoke | Settings → delete all data | Home empty; reminders gone |
| MT-01 | Negative | Scan with airplane mode on | "You are offline", retry offered |
| MT-02 | Negative | Photo of a non-bill | "Not a bill" |
| MT-03 | Interrupted | Kill the app during upload, reopen | No half-saved bill |
| MT-04 | Interrupted | Rotate / background during chat answer | Answer kept or retry shown |
| MT-05 | Retest D-03 | Lookup → tap Search → press Back at once (×5); `adb logcat` | No "setState() called after dispose" |
| MT-06 | Reminders | Save a bill due in 4 days; change phone date to 1 day later at 10:01 | Due notification; tap opens the bill |
| MT-07 | Accessibility | TalkBack on: result screen | Every button announced |
| MT-08 | Sanity after tariff change | Change Remote Config value out of range | App keeps the old tariff |

## 5. How to run everything

```sh
scripts/fetch_fonts.sh                  # once: UI font (not in git, licence)
cd app && flutter pub get
flutter analyze
flutter test                            # all app tests
flutter test test/security_test.dart    # one file
cd ../functions && npm ci && npm test && npm audit --omit=dev --audit-level=high

# API tests (needs firebase-tools; uses no Gemini quota)
npm run build && cd ..
firebase emulators:start --only functions --project demo-bill-samjho   # terminal 1
scripts/api_negative_tests.sh                                         # terminal 2
```

CI (`.github/workflows/ci.yml`) runs analyze, test, the backend build/test, and `npm audit` on every push and pull request.

## 6. Performance (proposed targets, for your approval)

No performance requirements exist apart from the 20-second request timeout (SDA §12) and the APK under 25 MB (NFR-06). Measured so far:

- APK sizes from the last build: 21.1 MB arm64, 18.9 MB older phones. Under 25 MB.
- Full test suite: about 10 s.

**Proposed (not yet measured on a device):**

| Metric | Target |
|---|---|
| Cold start to home | < 2 s on a mid-range phone |
| Result screen open | < 300 ms |
| Rules engine plus forecaster for 24 months of history | < 5 ms |

To measure: `flutter run --profile`, then DevTools timeline.

There is no load test: the backend is not deployed, and the phone serves one user. If the function is deployed, a controlled test of 10 requests per second for 1 minute against the emulator is enough to check `maxInstances` and timeouts.
