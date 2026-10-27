# Security Report

Defensive, code-level review of the repository at `3c66ce2`, plus local-only tests (unit tests, the Firebase emulator with an offline `demo-` project). No production service, third-party system or real account was attacked or changed. **No secret values appear in this report.**

Method: OWASP Mobile Top 10 (2024) and the OWASP API Security Top 10 (2023), applied to what this app actually has. It has no user accounts, so authentication, sessions, JWT and IDOR checks have nothing to test. That is noted, not skipped silently.

## 1. Summary

| ID | Finding | Risk | Status |
|---|---|---|---|
| S-01 | AI Logic (Gemini) callable by anyone with the app's public Firebase config while App Check is not enforced | **High** | Open: console actions |
| S-04 | Release APK signed with the debug key | **High** for release | Open: owner's keystore |
| S-02 | `body-parser` DoS advisory (GHSA-27r3-jxmh-p828, high) | Medium | **Fixed** |
| S-03 | Malformed JSON → HTML stack trace with file paths (emulator) | Low | Needs verification after deploy |
| S-05 | Device rate limit keyed on a client-chosen UUID | Low | Accepted risk (App Check is the real control) |
| S-06 | Server date regex accepts `2026-02-31` | Low | Open (app re-validates) |
| D-02 | NaN confidence became 1.0 on the phone | Low (integrity) | **Fixed** (see BUGS_AND_FIXES) |

## 2. Confirmed findings

### S-01: Gemini via Firebase AI Logic is open to anyone while App Check is unenforced (High)

**Evidence**

- [main.dart:119](../../app/lib/main.dart) activates App Check only when built with `APP_CHECK=true`; the default is off.
- README: *"App Check is off by default because sideloaded APKs cannot pass Play Integrity"*. During development the AI Logic App Check setting was switched to monitoring only.
- The Firebase API key and app ID are compiled into every APK. They are identifiers, not secrets: anyone can extract them with `apktool`.
- The limits of 20 questions per chat and 500 characters ([bill_chat.dart](../../app/lib/data/bill_chat.dart)) run **only on the phone**, so a script ignores them.

**Impact.** Anyone can use the project's Gemini free-tier quota through the AI Logic proxy. When it is used up, photo reading and the chat stop working for **all** users: denial of service and denial of wallet (OWASP API4: unrestricted resource consumption). On the Spark plan there is no bill, but on Blaze there would be.

**Mitigations (owner actions, in order):**

1. Google Cloud console → APIs & Services → Credentials. Restrict the Firebase Android API key to **Android apps**, with your package name and **release SHA-1**, and to the APIs it needs. This blocks casual reuse from scripts. It is spoofable, but cheap to set.
2. Firebase console → AI Logic → set a **per-user rate limit** (requests per minute).
3. In Google Cloud, set a **daily quota** on the Generative Language API.
4. For the Play Store build: register Play Integrity, build with `--dart-define=APP_CHECK=true`, then **enforce** App Check for AI Logic. Sideloaded test builds will then need debug tokens.

**Retest after the change:** call AI Logic from a script with the key but no App Check token. Expect HTTP 401/403.

### S-04: Release builds use the debug signing key (High, release blocker)

**Evidence.** [build.gradle.kts:41](../../app/android/app/build.gradle.kts) contains `signingConfig = signingConfigs.getByName("debug")`, followed by a `TODO`.

**Impact.**

- Google Play rejects debug-signed apps.
- For sideloaded users, the only key that can ever ship an update is this machine's debug keystore. Its password is the publicly known `android`, and it can't be rotated later.
- If the laptop is lost, users must uninstall the app, losing their data, to get updates.

**Mitigation:**

1. `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Reference it from a git-ignored `key.properties` file.
3. Use Play App Signing.
4. Back up the keystore offline.

**Not done here:** it needs your decision and your credentials.

### S-02: Vulnerable `body-parser` (Medium, fixed)

`npm audit` reported **body-parser 2.0.0–2.3.0: DoS via trailing bytes after a compressed request body**, rated high. The path is `firebase-functions@7.4.0 → express@5.3.0 → body-parser@2.3.0`.

**Reachability:** only if the optional Cloud Function is deployed (it isn't today). **Fix:** `npm audit fix`, a semver-compatible lockfile change: body-parser **2.3.0 → 2.4.0** and nothing else. **Retest:** `npm audit` reports 0 vulnerabilities, `npm test` passes 15/15, and CI now runs `npm audit --omit=dev --audit-level=high`.

### S-03: Stack trace on malformed JSON (Low, needs verification)

**Test:** API-17, `curl -X POST -H 'Content-Type: application/json' -d '{"deviceId":' …/extractBillText`.

**Observed in the emulator:** HTTP 400 (correct). The body is an HTML page with `SyntaxError` and the absolute paths of `body-parser` files on the developer's machine.

The trace comes from the emulator's own body parser, before the function runs. Production Cloud Run normally sets `NODE_ENV=production`, which hides stack traces, but **this was not verified** because nothing is deployed. **Retest after deploy:** run `BASE=https://asia-south1-<project>.cloudfunctions.net scripts/api_negative_tests.sh` and check that API-17 passes.

### S-05: Rate limit by device UUID (Low, accepted)

`deviceId` is generated by the client, so an attacker can send a new one with each request. The 300/day per-IP limit (stored as an HMAC) and App Check remain. This is acceptable **only with App Check enforced** (see S-01).

### S-06: Server accepts impossible dates (Low)

`DATE` in [validate.ts](../../functions/src/validate.ts) only checks `day ≤ 31`. The app re-validates and drops such dates (D-01 fix), so users are not affected. Fix it the same way when the backend is next changed.

## 3. Checked and found sound

| Area | What was checked | Result |
|---|---|---|
| Secrets in git | Full history of all branches: Google API keys, private keys, `.env`/secret/keystore/`google-services.json` files | **None ever committed.** `.gitignore` covers `functions/.secret.local`, `.env*`, `google-services.json`. Local secret files exist and are ignored (checked by name only). |
| Personal data in repo | Test fixtures and git history for real names or reference numbers | Synthetic only ("Sample Consumer", `07 11234 1234567`) |
| Transport | `network_security_config.xml`, manifest | Cleartext off; system CAs only (user CAs not trusted); backend must be `https://` (tested in `security_test`) |
| Storage | `LocalStore`, `StorageKey` | Hive AES-256, key in Android Keystore; `allowBackup=false`; data-extraction rules exclude all domains |
| Exported components | Manifest | Only the launcher activity; notification receivers `exported=false`; **no deep links**, so no external route injection |
| WebView | `lookup_screen.dart` | Navigation allow-list `https://bill.pitc.com.pk` only; no JavaScript channel; only digits interpolated into injected JS; cookies and cache cleared on close |
| Injection / XSS | Chat answers, bill text | Rendered as plain `Text` (no HTML or markdown renderer); bill text is length-capped and stripped of control and bidi characters on both phone and server |
| Prompt injection | Bill page text sent to Gemini | Output forced into a JSON schema, re-validated; the AI never makes the verdict (rules engine does); chat prompt includes only validated numbers and capped strings |
| SSRF / path traversal / command injection | Functions and app | No user-controlled URLs fetched server-side; image file names are server-generated UUIDs; no shell execution |
| API input validation | 17 negative API tests | Wrong method 405, wrong content type 400, missing or invalid fields 400, oversize 413; **identical error bodies** `{"error":"…"}` with `Cache-Control: no-store` and `nosniff`; no Gemini call reached |
| Firestore | `firestore.rules` | All client reads and writes denied |
| Logging | `main.dart`, `debugPrint` uses | `debugPrint` is a no-op in release; logs print only `runtimeType`, never bill data; the function logs only model name and status |
| Permissions | Manifest | INTERNET, network state, RECORD_AUDIO (asked on first mic tap), RECEIVE_BOOT_COMPLETED; no storage, camera or location permissions |
| Remote config | `TariffConfig._checkRanges` | Out-of-range values rejected (tested) |

**Not applicable:** passwords, sessions, cookies, JWT, CSRF, CORS (`cors: false`, server-to-app only), multi-user IDOR. There are no accounts, and each phone only holds its own data.

## 4. Dependency audit

| Ecosystem | Command | Result |
|---|---|---|
| npm (functions) | `npm audit` | Before: 1 high. After: **0** |
| Dart/Flutter | `flutter pub outdated` (informational) | Dart has no built-in advisory database like `npm audit`; GitHub Dependabot can scan `pubspec.lock`. **Not run in this audit**: recommend enabling Dependabot alerts on the repository. |
| Install scripts | `functions/package.json` | No `preinstall`/`postinstall` scripts in the project; dependencies are well-known Google packages |

## 5. Remaining security limitations

- Nothing here was tested against the **live** Firebase project, by design.
- A rooted phone can read app files (photo copies are protected by the OS sandbox only). This is documented in SECURITY.md.
- No certificate pinning, by deliberate choice because Google rotates certificates. Documented.
- On Gemini's free tier, Google may use inputs to improve its products. The app tells users, and the PITC lookup path avoids AI.
