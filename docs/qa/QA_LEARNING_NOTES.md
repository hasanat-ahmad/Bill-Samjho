# QA Learning Notes: what this audit teaches, using your own app

Each section starts from something real that happened in this audit, then names the concept.

---

## 1. The best bug of the audit: D-01, "2026-10-5"

**In simple words.** The app checked a date with one rule and read it with a different, stricter rule. A date that passed the check could still not be read.

**How a user would experience it.** Nothing looks wrong on the day they save the bill. A week later, no reminder arrives, for *any* of their meters. The chat button for that bill does nothing. This is the worst kind of bug: **silent**, and **far from its cause**.

**How a QA engineer finds it.** Not by clicking around. I asked one question at the trust boundary (`fromUntrusted`): *"What does this check accept that the code later can't handle?"* Then I tested the answer directly instead of guessing:

```
isIsoDate('2026-10-5')     → true          (the check says OK)
DateTime.parse('2026-10-5') → FormatException  (the reader disagrees)
DateTime.parse('2026-02-31') → 2026-03-03       (silently wrong!)
```

**Concepts it shows:**

- **Boundary Value Analysis** (which you know). The interesting values are at the edges of the format: one digit vs two, day 28/29/30/31, month 0 and 13. `format_test.dart` tests exactly these.
- **Equivalence partitioning** (new). Split all inputs into groups the code should treat the same way: *canonical dates*, *valid-but-short dates*, *impossible dates*, *not dates*. Test one value from each group. The bug lived in the "valid but short" group that nobody had tested.
- **Integration bug** (new). Each piece was "correct" alone. The bug is in the *contract* between the validator and the parser.

**Severity vs priority** (which you know):

- Severity is **Major**: a core feature, reminders, silently stops.
- Priority is **P2**, not P1: it needs an unusual AI output to trigger.

A typo on the home screen would be the reverse: low severity, high priority, because everyone sees it.

**Manual reproduction.** You can't type a date into the app, so you would reproduce it at the API boundary instead. Make the model return `"due_date": "2026-10-5"`, or call `ExtractedBill.fromUntrusted` in a test, which is what we did. Lesson: when a UI can't reach a bug, **test at a lower level**.

**Prevention.** Validate *and normalise* at the boundary, storing one canonical form. Then use the *same* function for checking and for reading.

---

## 2. Negative testing found a "quiet" bug: D-02, `NaN.clamp(0, 1) == 1.0`

You already know **positive** testing (valid input works) and **negative** testing (invalid input fails safely). The key word is *safely*.

A NaN confidence didn't crash anything, so a quick negative test might pass it. But the result was **wrong**: an unreadable photo was treated as 100% confident. **"No crash" is not the same as "correct."** Your assertions must check the *value*:

```dart
expect(b.confidence, 0); // not just "returnsNormally"
```

This is the same idea as the API rule in your notes: *"200 OK with the wrong user's data must still fail the test."*

**Assertion quality** (new idea): weak assertions such as "no exception" or "status 200" let bugs through; strong assertions such as "exactly this value" or "exactly this error body" catch them.

---

## 3. API testing: `scripts/api_negative_tests.sh`

This maps directly to your Postman and status-code knowledge:

| Your concept | In the script |
|---|---|
| HTTP methods | API-01: GET → **405 Method Not Allowed** |
| Content type | API-03: JSON sent to a multipart endpoint → **400** |
| Request validation | API-05: `deviceId=abc` → **400** |
| Payload size | API-08: 600 KB → **413 Payload Too Large** |
| Auth | AUTH-01: no App Check token → **401** (blocked locally) |
| Rate limiting | RL-01: 31st request → **429** (blocked: costs quota) |
| Response validation | Every test checks the *exact* body `{"error":"unreadable"}` |
| Security headers | Every test checks `Cache-Control: no-store`, `nosniff` |

**Information disclosure.** API-17 returned the right status (400) but **failed** because the body contained a stack trace with file paths. A status-only assertion would have missed it.

Write this exact test in Postman as an exercise:

```js
pm.test("400", () => pm.response.to.have.status(400));
pm.test("no stack trace", () => pm.expect(pm.response.text()).to.not.match(/node_modules|at .+\(/));
```

**Emulator vs production** (new idea): a test environment is not production. The stack trace came from the *emulator's* server. The honest result is "failed in emulator; production **unverified**", not "vulnerable" and not "safe".

---

## 4. Retesting vs regression vs sanity: what we actually did

| Step | Definition | What happened in this audit |
|---|---|---|
| Red | Write the test first; it must **fail** | 4 tests failed with the exact bug messages |
| **Retest** (confirmation test) | Run *the test for that bug* after the fix | The 4 tests now pass |
| **Sanity** | Narrow, quick check of nearby features | `reminders_test`, `forecaster_test`, `chat_test`, `pitc_parser_test` |
| **Regression** | Run *everything* to check nothing else broke | Full suite: 142/142, plus `flutter analyze` |

Why write the test **before** the fix? A test that never failed might not test anything. Seeing it go red, then green, proves it detects the bug.

**Smoke vs sanity:**

- **Smoke** is broad and shallow: does the build basically work? Example: `app_flow_test` UC-1, or SM-01 to SM-08 on a phone.
- **Sanity** is narrow and focused, after a specific change. Example: after fixing dates, check the date-related features.

---

## 5. Risk-based testing: why I read the code in this order

There are about 8,600 lines and not enough time to test everything equally. Order:

1. **Trust boundaries** (AI output, PITC page, backend): wrong data spreads everywhere.
2. **Money and units** (rules engine, forecaster): a wrong number breaks user trust.
3. **Unattended jobs** (reminders): nobody notices when they fail.
4. **Security config** (manifest, WebView, secrets).
5. UI last.

Both real defects were in areas 1 and 3. That is the point of risk-based testing.

---

## 6. Verifying before reporting: three "bugs" that weren't

Professional QA engineers often *disprove* their own suspicions. Here are three from this audit:

- **R4 return month.** "Over 200 in March → protected again in September" looked one month early. Then I read the template: *"Roughly **after** {month}"*. After September means October: correct.
- **Credit bills.** The total field rejects negative numbers, so I suspected credit bills couldn't be confirmed. The code edits them as positive and saves them as negative: correct, and tested.
- **Body-parser "high" advisory.** It *is* real, but the backend isn't deployed. So the rating is Medium, not High. **Severity must reflect actual reachability.**

A false bug report costs the developer time and costs you credibility.

---

## 7. SDLC vs STLC in this project

- **SDLC** (building): SRS → design (SDA) → code → release. Your `bill-samjho-srs-sda.md` is the requirements and design phase.
- **STLC** (testing): requirement analysis → test planning (TEST_PLAN.md) → test case design (§3) → environment setup (emulator, fonts) → execution → closure (QA_REPORT.md).

**Shift-left** (new idea): the SRS rule *"backend data is untrusted (NFR-09)"* existed from day one, and tests for it were written with the code. That is why the audit found only small gaps there, not big ones.

---

## 8. CI/CD

`.github/workflows/ci.yml` runs the analyzer, all tests, the backend tests and `npm audit` on every push. Before this, a test only ran when you remembered to run it.

It's still **not proven** until it runs green on GitHub. "I wrote a CI file" is not the same as "CI passes".

---

## 9. Mocking (you've been using it already)

`app_flow_test.dart` uses `MockApiService`, `FakeScanService` and `FakeChat`. These are **test doubles** that replace the camera, Gemini and the network, so tests are fast, free and deterministic. The trade-off: mocks can't catch problems in the *real* service. That's why the API tests and manual smoke tests (SM-03, SM-06) still exist.

---

## 10. Exercises for you

1. **BVA:** write a test for the units field on the confirm screen at -1, 0, 5000, 5001 (validator in `confirm_view.dart`). Which values should show "invalid number"?
2. **Equivalence partitioning:** list the partitions for the 14-digit reference number (`ReferenceNumber.parse`): Urdu digits, spaces, 13 digits, 15 digits, a trailing `R`. Write one test per partition.
3. **Bug report:** write a full report for O-01 (8-digit meter box vs 9-digit readings) using the D-01 template. Pick a severity and priority and justify both.
4. **API, in Postman:** rebuild API-01, API-05, API-08 and API-17 as a collection with assertions on status, body and headers. Run it against the emulator.
5. **Race condition (advanced):** read `ReminderService.sync` (O-02). Describe the exact order of events that leaves a reminder for a deleted meter. Then sketch a fix that chains syncs on one `Future`.
6. **Exploratory testing:** spend 20 minutes on the app in Urdu with TalkBack on. Write down anything confusing, with steps. This is a session-based exploratory test.
7. **Mutation thinking:** change `days > maxMeterDays` to `days >= maxMeterDays` in `forecaster.dart` and run `flutter test`. Does a test fail? It does now: BV-05 tests day 60. I ran this mutant during the audit, and *meter reading boundaries* failed, as it should. Then undo the change. Try the same with `> config.protectedLimitUnits` in the rules engine.
