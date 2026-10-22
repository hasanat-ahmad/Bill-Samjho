# Security and privacy

Bill Samjho handles electricity bills, which show a household's name, address and reference number. The design goal is that this data stays on the user's phone, and that the backend cannot be abused to run up costs.

## What is collected

| Data | Where | How long |
|---|---|---|
| Bill photo | Sent to the backend over HTTPS, read by Gemini in memory | Never stored or logged on the server |
| Bill numbers, photo copy | On the phone only, encrypted | Until the user deletes them |
| Random device ID (UUID) | Phone, and as a rate-limit counter key on the server | Server counters expire after 2 days |
| IP address | Only as an HMAC (keyed hash) in a rate-limit counter | Expires after 2 days |

No account, phone number, CNIC or location is collected. The app requests no storage, camera or location permission: the camera and photo picker are system screens that return only the chosen photo.

## App (Android)

- **Encrypted storage.** Hive boxes are AES-256 encrypted; the key is generated on the phone and kept in the Android Keystore (`flutter_secure_storage`). If the Keystore is unusable the app keeps data in memory rather than write it unencrypted.
- **No backups.** `allowBackup=false` and data-extraction rules exclude everything from cloud backup and device transfer.
- **HTTPS only.** Cleartext traffic is disabled; only system certificate authorities are trusted (user-installed CAs are not). The backend URL must be `https://` or scanning is disabled. Redirects are not followed.
- **App Check.** Each request carries a Firebase App Check token (Play Integrity), so the backend can reject requests not coming from the genuine app.
- **Untrusted responses.** Backend data is validated again on the phone: required fields present and in range, text length-capped and stripped of control and bidi-override characters, optional values out of range dropped (`ExtractedBill.fromUntrusted`).
- **Remote tariffs are range-checked.** A mistyped or malicious Remote Config value is rejected and the previous config stays.
- **No sample data in release.** Demo mode is off in release builds unless explicitly enabled, and always shows a banner.
- **Photo hygiene.** Photos are re-encoded without EXIF (no GPS location); the full-size temporary file is deleted after compression.
- **No logging in release.** `debugPrint` is disabled; Crashlytics collects only in release and receives stack traces, not bill data.
- **Input hygiene.** Nicknames are length-limited and stripped of control and bidi characters; number fields accept digits only.
- **Obfuscation and shrinking.** R8 minify/shrink and Dart `--obfuscate` for release builds.

## Backend (Cloud Function)

- Gemini API key in Secret Manager, never in the app.
- App Check enforced (`REQUIRE_APP_CHECK=false` only for the local emulator).
- Checks before any AI cost: POST only, `multipart/form-data` only, body size ≤ ~516 KB (checked before parsing), UUID device ID, JPEG signature.
- Rate limits: 30/day per device and 300/day per IP (high because of carrier-grade NAT on Pakistani mobile networks), counted in one Firestore transaction. IPs are stored only as an HMAC with a secret.
- `maxInstances: 10` and a 20 s Gemini timeout bound cost and latency; a Gemini key quota is the final ceiling.
- Prompt injection: the model can only fill a fixed JSON schema, the output is validated and normalised, and every judgement is made by the rules engine on the phone — text from the image is never shown or executed.
- Responses are `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`; errors expose only a code.
- Firestore rules deny all client access.

## Known limits

- App Check depends on Google Play services; phones without them cannot scan when enforcement is on.
- A rooted phone can read app-private files; the photo copies are protected by the OS sandbox, not by app-level encryption.
- No certificate pinning: Google rotates the certificates for Cloud Functions endpoints, and pinning would break the app on rotation.

## Reporting a problem

Please report security issues privately to the maintainer rather than in a public issue.
