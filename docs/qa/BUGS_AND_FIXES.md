# Bugs and Fixes

Each defect has been through the same loop:

1. Reproduce the defect.
2. Write a test that fails (red).
3. Make the smallest fix.
4. Retest (green).
5. Run related tests (sanity).
6. Run the full suite (regression).

Security items are in [SECURITY_REPORT.md](SECURITY_REPORT.md).

Severity scale: Critical / Major / Minor / Trivial. Priority scale: P0 (now) to P4 (whenever).

---

## D-01: Bill dates in a short form break reminders, chat and the estimate

| | |
|---|---|
| Severity / Priority | **Major / P2** |
| Component | `ExtractedBill.fromUntrusted`, `isIsoDate` ([format.dart](../../app/lib/domain/format.dart)) |
| Status | **Fixed and retested** |
| Found by | Code review of the trust boundary, then a probe of `DateTime.parse` with edge-case input |

**Bug report**

**Title:** A due date read as "2026-10-5" passes validation, then crashes date parsing.

**Environment:** any phone; photo read through Firebase AI Logic (the default path). This is the only path where AI output reaches the phone without the server's stricter regex.

**Steps to reproduce:**

1. The model returns `"due_date": "2026-10-5"` (one-digit day) for a bill. The prompt asks for `YYYY-MM-DD`, but nothing guarantees it.
2. The user confirms and saves the bill.
3. Then:
   - **3a.** Any later change triggers reminder re-planning.
   - **3b.** The user opens "Ask about this bill".
   - **3c.** The user taps "Estimate next bill" and enters a reading.

**Expected:** the date is understood as 5 October 2026, or ignored. Everything else keeps working.

**Actual:**

- `isIsoDate("2026-10-5")` returned **true**, so the text was saved as is.
- `DateTime.parse("2026-10-5")` throws `FormatException: Invalid date format`. That causes:
  - **3a:** `ReminderPlanner.plan` throws, and `ReminderService.sync` catches it after `cancelAll()`. **Every meter loses its reminders**, silently.
  - **3b:** `buildChatPrompt` → `Forecaster.readingDateOf` throws inside the route builder, so the chat screen fails to open.
  - **3c:** `meterProblem` throws inside the button handler, so nothing happens.
- Related problems with the same cause:
  - `"2026-02-31"` was accepted and silently became **3 March**.
  - A bill month `"2026-9"` was stored as is. Bills are sorted by this text, and `"2026-9" > "2026-10"`, so the September bill counted as *newer* than October. Re-scanning the same month as `"2026-09"` did not replace it, leaving two bills for one month.

**Evidence (red phase):**

```
security_test: Expected: '2026-09'  Actual: '2026-9'
reminders_test: FormatException: Invalid date format
```

**Root cause.** Two pieces of code disagreed about what a valid date is. The validator used `^(\d{4})-(\d{1,2})-(\d{1,2})$` and only checked `day ≤ 31`. The parser (`DateTime.parse`) needs exactly two digits and a real day. Validated data was also stored in whatever form it arrived in, instead of one canonical form.

**Fix (smallest safe change).**

- New `isoDate(String) → String?` in `format.dart`. It accepts one or two digits, checks a real calendar date by round-tripping through `DateTime.utc`, and returns the padded form `2026-10-05`, or null.
- `isIsoDate(s)` is now `isoDate(s) == s`: true only for the exact form `DateTime.parse` reads. Code that reads *already stored* bills (reminders, forecaster) now skips a bad date instead of crashing.
- `fromUntrusted` stores `billMonth`, history months, `dueDate` and `readingDate` in canonical form (`monthKey(monthIndex(..))`, `isoDate(..)`).

**Regression tests**

- `security_test.dart`: *dates and months are normalised; impossible dates are dropped*
- `reminders_test.dart`: *a bill with an unreadable due date is skipped, others still planned*
- `format_test.dart`: 3 boundary-value tests (month and year edges, leap day, day 0/32, month 0/13)

**Retest:** all of the above pass. **Sanity:** `forecaster_test`, `chat_test`, `pitc_parser_test`, `firebase_ai_parse_test` pass. **Regression:** full suite, +142, all passed.

**Remaining:** bills saved *before* this fix with a short date keep that text. They no longer crash anything; they are simply treated as having no due date.

---

## D-02: "NaN", "Infinity" and numbers-as-text from the AI

| | |
|---|---|
| Severity / Priority | **Minor / P3** |
| Component | `ExtractedBill` (`_double`), `FirebaseAiApiService.parseModelOutput` |
| Status | **Fixed and retested** |
| Found by | Equivalence partitioning of number inputs (finite / non-finite / text / wrong type), then probing Dart's behaviour |

**What happened:**

| Input | Before | Why it matters |
|---|---|---|
| `"confidence": "NaN"` | Became **1.0**: in Dart, `NaN.clamp(0, 1)` returns 1.0 | An unreadable result looked *fully* confident and skipped the "check these numbers" warning |
| `"units": "Infinity"` | Threw `UnsupportedError`, not the documented `FormatException` | Shown as "unknown error" instead of "unreadable photo" |
| History `amount: Infinity` or `1e15` | Kept (no range check) | The server rejects these; the phone did not, so the two disagreed |
| `"confidence": "0.9"` (text) on the AI path | `as num?` threw a `TypeError`, caught as **"AI busy"**, and **every model was tried** | Wrong message, and 3× the free-tier quota for one photo |

**Root cause.** The code comment says the phone applies "the same rules as functions/src/validate.ts". The server's `toNumber` uses `Number.isFinite` and accepts numeric text; the phone did neither.

**Fix.**

- `_double` returns null for non-finite values.
- History amounts are range-checked like the server's.
- `parseModelOutput` reads numbers with a `_number` helper that mirrors the server's `toNumber`.

**Regression tests**

- `security_test.dart`: *non-finite numbers are rejected, never trusted*
- `firebase_ai_parse_test.dart`: *numbers written as text: read like the server; NaN is unreadable*

**Retest:** pass. **Regression:** full suite passes.

---

## D-03: PITC browser updates a closed screen

| | |
|---|---|
| Severity / Priority | **Minor / P3** |
| Component | [lookup_screen.dart](../../app/lib/features/lookup/lookup_screen.dart) navigation delegate |
| Status | **Fixed**; verified by analyzer and review; **no automated test (blocked)** |
| Found by | Consistency review: `_afterPageLoad` checks `mounted`, but the other web-view callbacks did not |

**Scenario.** The user opens the PITC page and presses Back while it is still loading. The native web view can still report `onPageStarted` or `onWebResourceError`. These called `setState` on a disposed `State`: an assertion in debug, and a null-check error in release that goes to Crashlytics as a fatal error. `Uri.parse(request.url)` could also throw on a malformed URL inside the navigation callback.

**Fix.** Added `mounted` checks to those two callbacks. Use `Uri.tryParse`; a URL that cannot be parsed is blocked, which matches the allow-list rule.

**Why no automated test.** Unit and widget tests have no WebView platform. A fake `WebViewPlatform` would be more code than the fix. **Manual retest:** open lookup, tap Search, then press Back immediately. Repeat 5 times; check that `adb logcat | grep -i "setState() called after dispose"` stays empty.

---

## Observations (not fixed, recorded)

| ID | Observation | Why not fixed now |
|---|---|---|
| O-01 | The meter-reading box allows 8 digits (`LengthLimitingTextInputFormatter(8)`), while bill readings up to 9 digits are accepted. A 9-digit meter could never pass the "below bill" check. | Domestic meters have 5–7 digits; changing the UI limit is a product decision. A boundary value analysis example; see learning notes. |
| O-02 | `ReminderService.sync` runs once per change event, and deleting a meter fires several. If one sync is still scheduling while another has already cancelled everything, a reminder for a deleted meter could survive. | Not reproduced; the plugin is not injectable, so it can't be tested without refactoring. Fix idea: chain syncs on one `Future`. |

---

## Final regression run

| Suite | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **+142: All tests passed** (baseline 134) |
| `functions: npm test` | 15 pass, 0 fail |
| `functions: npm audit` | 0 vulnerabilities |
| `scripts/api_negative_tests.sh` | 16 pass, 1 fail (API-17, emulator-only, see S-03) |
