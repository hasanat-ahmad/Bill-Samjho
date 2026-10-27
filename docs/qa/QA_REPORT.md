# QA Report — Bill Samjho

Audit date: 27 October 2026 · Commit audited: `3c66ce2` (main) · Auditor: QA review with Claude Code

Related: [TEST_PLAN.md](TEST_PLAN.md) · [SECURITY_REPORT.md](SECURITY_REPORT.md) · [BUGS_AND_FIXES.md](BUGS_AND_FIXES.md) · [QA_LEARNING_NOTES.md](QA_LEARNING_NOTES.md)

## 1. Verdict

The app's core logic is in good shape. It came into the audit with 134 passing tests, a clean analyzer, careful input validation and good privacy defaults. The audit found **no P0 issues**.

It found **one P2 functional defect, now fixed**. A bill date written as `2026-10-5` instead of `2026-10-05` passed validation. It then made the reminders for every meter, the chat screen and the estimate button fail. It also found **two P3 defects, now fixed**, and **one vulnerable dependency, now patched**.

Two **P1 items block a public release** and cannot be fixed in code. Both need the owner to act in the Firebase/Google Cloud console and on the build machine:

1. Gemini through Firebase AI Logic is callable without App Check enforcement (S-01).
2. Release builds are signed with the debug key (S-04).

**Release-readiness:** fine for private sideloaded testing. **Not ready for a public (Play Store) release** until S-01 and S-04 are done and the open items in §7 are checked.

## 2. What the project is (verified from the code)

```
Android phone (Flutter app, app/)                         Google / PITC
┌──────────────────────────────────────────────┐
│ UI (go_router screens, flutter_bloc cubits)  │
│   Home → Scan / Lookup → Confirm → Result     │
│   Result → Estimate · Chat · Appliances      │
│                                              │
│ domain/ (pure Dart, no AI)                   │
│   RulesEngine  verdict + findings R1–R7      │──────────────┐
│   Forecaster   next-bill estimate            │              │
│   ReminderPlanner, Appliances, ChatPrompt    │              │
│                                              │              │
│ data/                                        │              │
│   ExtractedBill.fromUntrusted  ◄── trust boundary for all bill data
│   FirebaseAiApiService ───────── HTTPS ────────► Gemini via Firebase AI Logic (default)
│   HttpApiService ─────────────── HTTPS ────────► Cloud Function extractBill (optional, Blaze)
│   PitcBillParser ◄── WebView, bill.pitc.com.pk only ──► PITC duplicate-bill site
│   LocalStore: Hive AES-256, key in Keystore  │
│ services/ TTS (offline), dictation, reminders│
└──────────────────────────────────────────────┘
functions/  TypeScript: extractBill, extractBillText, validateExtraction, Firestore rate limits
```

| Area | Implementation (verified) |
|---|---|
| Frontend | Flutter 3.41.4 / Dart 3.11.1, Android only (minSdk 26), English + Urdu (RTL) |
| Backend | Optional Firebase Cloud Functions v2 (Node 22): `POST extractBill` (multipart JPEG), `POST extractBillText` (JSON). **Not deployed** (project is on the free Spark plan). |
| AI | Gemini via Firebase AI Logic from the phone (default path); same prompt and schema as the function |
| Database | No server database of user data. Firestore holds only rate-limit counters (rules: deny all clients). On the phone: encrypted Hive boxes `connections`, `bills`, `settings`. |
| Auth | No user accounts. Requests are attested by App Check (optional; off by default). |
| Integrations | PITC website (WebView), Remote Config (tariffs), Crashlytics, local notifications, Android TTS/speech |
| CI | **None before this audit**; added `.github/workflows/ci.yml` |

**Main user journeys:**

1. Add a meter.
2. Get a bill by photo (AI) or by reference number (PITC page, parsed on the phone).
3. Confirm units and total.
4. See the verdict and findings, with voice.
5. Estimate the next bill, optionally from today's meter reading.
6. Ask the chat helper.
7. Use the appliance calculator.
8. Get reminders for the due date and the next bill.
9. Browse history.
10. Change settings or delete data.

## 3. Scope and environment

| Item | Value |
|---|---|
| Machine | macOS (Darwin 25.6, arm64) |
| Flutter / Dart | 3.41.4 / 3.11.1 |
| Node / npm | 24.11.1 locally (`engines` says 22; CI uses 22) |
| Firebase tools | 15.17.0, functions emulator, offline project `demo-bill-samjho` |
| Real services | **Not called.** No request reached Gemini (verified in the emulator log), PITC was not contacted, and no production Firebase resource was touched. |
| Devices | No real-device or Android-emulator run in this audit (see §6). |

In scope: all Dart and TypeScript source, tests, Android manifest and build config, dependencies, git history (secrets).

Out of scope: penetration testing of Google/PITC services, load testing, the Firebase console configuration (cannot be inspected from the repo).

## 4. Test execution summary

| Check | Baseline (before changes) | Final (after fixes) |
|---|---|---|
| `flutter analyze` | No issues | No issues |
| `flutter test` | **134 passed**, 0 failed | **142 passed**, 0 failed (134 + 8 new) |
| `npm test` (functions) | 15 passed | 15 passed |
| `npm audit` (functions) | **1 high** (body-parser) | 0 vulnerabilities |
| API negative tests (emulator, new) | n/a | 16 passed, **1 failed** (API-17, emulator-only; see S-03) |
| Secret scan, full git history | 0 keys, 0 secret files | unchanged |
| CI workflow | none | added; **not yet run on GitHub** (YAML parsed; backend steps re-run from a clean `npm ci` copy) |

The 8 new Flutter tests, by file:

| File | New tests | Type |
|---|---|---|
| `security_test.dart` | 2 | Regression (D-01, D-02) |
| `firebase_ai_parse_test.dart` | 1 | Regression (D-02) |
| `reminders_test.dart` | 1 | Regression (D-01) |
| `forecaster_test.dart` | 1 | Boundary values (meter days, readings) |
| `format_test.dart` (new file) | 3 | Boundary values (dates, months) |

Commands are in [TEST_PLAN.md §5](TEST_PLAN.md#5-how-to-run-everything).

## 5. Findings

Severity is the impact on users or data. Priority is how soon it should be fixed. Full write-ups are in [BUGS_AND_FIXES.md](BUGS_AND_FIXES.md) and [SECURITY_REPORT.md](SECURITY_REPORT.md).

| ID | Title | Severity | Priority | Status |
|---|---|---|---|---|
| **S-01** | Gemini (AI Logic) usable by anyone with the public Firebase config while App Check is not enforced; chat limits are client-side only | High | **P1** | **Open**: owner action in console |
| **S-04** | Release build signed with the debug key | High (release) | **P1** | **Open**: needs owner's keystore |
| **D-01** | Dates like `2026-10-5` pass validation, then crash date parsing: reminders for all meters lost, chat screen fails to open, estimate fails; `2026-9` months sort and de-duplicate wrongly; `31 February` accepted | Major | **P2** | **Fixed**, regression tests |
| **S-02** | `body-parser` 2.3.0 DoS advisory GHSA-27r3-jxmh-p828 (high) via firebase-functions → express | Medium (backend not deployed) | P2 | **Fixed** (lockfile → 2.4.0) |
| **D-02** | Non-finite numbers: `"NaN"` confidence became 1.0; `"Infinity"` units threw the wrong error type; numbers sent as text made the AI path report "AI busy" and call every model | Minor | P3 | **Fixed**, regression tests |
| **D-03** | In-app PITC browser could call `setState` after the screen closed; malformed URL could throw | Minor | P3 | **Fixed**, no automated test (blocked) |
| **S-03** | Malformed JSON returns an HTML stack trace with file paths (emulator) | Low | P3 | **Needs verification** after deploy |
| **S-05** | Per-device rate limit keyed on a client-chosen UUID | Low | P3 | Open (by design, relies on App Check) |
| **S-06** | Server date check also accepts `31 February` | Low | P3 | Open (app re-validates, so no user impact) |
| **O-01** | Meter-reading box takes 8 digits; bill parser accepts readings up to 9 digits | Trivial | P4 | Open (observation) |
| **O-02** | Reminder re-planning is not serialised (possible race on rapid deletes) | Minor | P3 | Open (potential, not reproduced) |

**Investigated and found correct (not defects):**

- R4's "protected again after {month}" is correct. The template says *after*, so month + 6 is right; a test exists.
- Credit bills on the confirm screen are correct: edited as a positive amount, saved as negative.
- The rules-engine 200-unit boundaries are correct and already tested at 179/180/200/201.
- WebView JavaScript injection is safe: only digits are interpolated, and navigation is restricted to `https://bill.pitc.com.pk`.

## 6. What was not tested (blocked or out of scope)

| Area | Why | What to do |
|---|---|---|
| Real phone / emulator smoke test of this build | Not run in this session | Install `app-arm64-v8a-release.apk` and run smoke tests SM-01 to SM-08 from the test plan |
| App Check 401 path on the API | Local `.env.local` sets `REQUIRE_APP_CHECK=false` | Covered by code review; re-test after deploy |
| Rate limit 429 path | Would need 30 accepted requests, i.e. 30 real Gemini calls | Test against the emulator with a dummy Gemini key, or after deploy |
| Happy path of the API with a real bill | Needs Gemini quota and a real bill photo | Manual, with a synthetic bill |
| Chat/scan against real Gemini | External, paid/free-tier quota | Manual |
| WebView behaviour (D-03) | No WebView platform in unit tests | Manual: open lookup, press back while the page loads |
| Performance under load | No deployed backend; mobile app is single-user | See §7 and the test plan |
| Accessibility (TalkBack, contrast) | Not requested as a standard | Manual TalkBack pass recommended |
| Postman collection | Postman connector not authenticated here | `scripts/api_negative_tests.sh` gives the same checks with curl |

## 7. Remaining risks and release prerequisites

1. **S-01:** enforce App Check for AI Logic (Play build), restrict the Firebase API key to the Android app, and set Gemini quotas or per-user limits.
2. **S-04:** create an upload keystore and a release signing config; never commit it.
3. **Urdu review** and the **20-real-bills accuracy test**: open TODOs in README; they are acceptance criteria.
4. **Gemini model names** change over time (README already tracks this). The fallback chain handles outages, not removals.
5. **Tariffs** must be re-checked after every NEPRA notification. Remote Config range checks exist, but values are not verified against NEPRA automatically.
6. **Backend (if deployed later):** verify S-03 and the 401/429 paths, and add the Firestore TTL policy (README step 5).
7. Push the branch and confirm the new **CI workflow actually passes on GitHub** (the font download step needs network access to Fontshare).

## 8. Final verification log

| When | Command | Result |
|---|---|---|
| Baseline | `flutter analyze` | No issues found |
| Baseline | `flutter test` | +134: All tests passed |
| Baseline | `npm test` / `npm audit` | 15 pass / 1 high |
| Red phase | 4 new regression tests | 4 failed as expected: `'2026-9'` ≠ `'2026-09'`, `UnsupportedError`, `FormatException: Invalid date format`, `type 'String' is not a subtype of type 'num?'` |
| After fixes | targeted 3 files | +26: All tests passed |
| After fixes | `npm audit fix`, `npm test`, `npm audit` | body-parser 2.3.0 → 2.4.0 only; 15 pass; 0 vulnerabilities |
| After fixes | `scripts/api_negative_tests.sh` (emulator) | 16 passed, 1 failed (API-17) |
| Final | `flutter analyze` | No issues found |
| Final | `flutter test` | +142: All tests passed |
