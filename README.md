# Bill Samjho — بل سمجھو

Android app that reads a photo of a Pakistani electricity bill (WAPDA DISCOs and K-Electric) and explains it in simple Urdu, by text and voice. It says whether the bill looks normal and warns about the 200-unit protected limit.

Full requirements and design: [bill-samjho-srs-sda.md](bill-samjho-srs-sda.md).

```
app/         Flutter app (Android only)
functions/   Firebase Cloud Function `extractBill` (TypeScript, Gemini)
firebase.json, firestore.rules
```

**Key principle:** AI only reads the image. The rules engine on the phone makes every judgement and fills every number into fixed Urdu templates.

## Run the app (no backend needed)

Without a backend URL the app runs in mock mode and returns a sample LESCO bill.

```sh
cd app
flutter pub get
flutter run                                   # mock mode (default when EXTRACT_URL is not set)
flutter test                                  # rules engine, repository and UI flow tests
```

With the real backend:

```sh
flutter run --dart-define=EXTRACT_URL=https://asia-south1-<project-id>.cloudfunctions.net/extractBill

# Play Store: the bundle delivers one CPU architecture per phone
flutter build appbundle --release --dart-define=EXTRACT_URL=...
# Sideloading: one APK per architecture (most phones need app-arm64-v8a-release.apk)
flutter build apk --release --split-per-abi --dart-define=EXTRACT_URL=...
```

A plain `flutter build apk` makes a universal APK (~54 MB) holding all three architectures; the per-architecture APKs stay under the 25 MB limit (NFR-06).

## Firebase setup

The app works without Firebase: it uses the bundled tariff config and no crash reporting. To connect it:

1. Create a Firebase project and **upgrade it to the Blaze plan** (required for Cloud Functions and Secret Manager).
2. Link the Android app. This creates `app/android/app/google-services.json`; Gradle then turns on the Firebase and Crashlytics plugins automatically.
   ```sh
   dart pub global activate flutterfire_cli
   cd app && flutterfire configure --platforms=android
   ```
3. Deploy the backend:
   ```sh
   firebase use <project-id>
   cp functions/.env.example functions/.env        # set GEMINI_MODEL
   firebase functions:secrets:set GEMINI_API_KEY   # key stays on the server only
   firebase deploy --only functions,firestore
   ```
4. In the Firestore console, add a **TTL policy** on collection `rateLimits`, field `expiresAt`, so old rate-limit counters are deleted.
5. In **Remote Config**, add parameter `tariff_config` (type JSON) with the contents of `app/assets/tariff_config_default.json`. Tariff changes then reach users without an app release.

## Backend

`POST /extractBill`, multipart: `image` (JPEG ≤ 500 KB) and `deviceId` (UUID).

| Status | Body | Meaning |
|---|---|---|
| 200 | ExtractedBill JSON (snake_case) | Read successfully |
| 400 | `{"error":"not_a_bill"}` / `{"error":"unreadable"}` | Wrong photo or unclear |
| 413 | `{"error":"too_large"}` | Image over 500 KB |
| 429 | `{"error":"rate_limited"}` | 30 requests per device per day |
| 503 | `{"error":"ai_busy"}` | Gemini unavailable |

The image is parsed in memory and never stored or logged. Firestore holds only per-device daily counters.

```sh
cd functions && npm install && npm test
```

## Before release: VERIFY / TODO

- [ ] **Tariff rates and slab method** in `tariff_config_default.json` against the latest NEPRA notification, including the "all units at one slab rate above 200" rule for non-protected consumers.
- [ ] **Gemini model name** in `functions/.env` (`GEMINI_MODEL`).
- [ ] **Urdu text review** by a native speaker: `app/assets/urdu_strings.json` and `Labels` in `app/lib/core/constants.dart`.
- [ ] Release signing config in `app/android/app/build.gradle.kts` (currently debug keys).
- [ ] Test with 20 real bills from at least 3 DISCOs (acceptance target: ≥ 18 read correctly).
- [ ] Rate limiting trusts the device ID sent by the app; consider Firebase App Check if abuse appears.
