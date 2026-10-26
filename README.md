# Bill Samjho — بل سمجھو

Android app that reads a photo of a Pakistani electricity bill (WAPDA DISCOs and K-Electric) and explains it in simple words, by text and voice, in **English (default) or Urdu**. It says whether the bill looks normal and warns about the 200-unit protected limit.

Full requirements and design: [bill-samjho-srs-sda.md](bill-samjho-srs-sda.md). Security design: [SECURITY.md](SECURITY.md).

```
app/         Flutter app (Android only)
functions/   Firebase Cloud Function `extractBill` (TypeScript, Gemini)
firebase.json, firestore.rules
```

Two ways to get a bill:

1. **Reference number (WAPDA companies):** the app opens the user's bill on PITC's official duplicate-bill website (`bill.pitc.com.pk`) inside the app, with the 14-digit reference number filled in. The user taps *Search* on the official page (and answers any CAPTCHA PITC shows); the app never submits the form or works around PITC's protections. Once the bill is showing, *Explain this bill* reads it on the phone (`assets/pitc/read_bill.js` + `PitcBillParser`). No AI and no backend are needed; if a page layout is not recognised, the page text is sent to the `extractBillText` function instead. The reference number is saved on the meter, so *Get latest bill* is one tap next month. Supported: LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HESCO, SEPCO, QESCO, TESCO, HAZECO. K-Electric bills are not on PITC; use a photo.
2. **Photo:** the bill photo is read by Gemini. By default through **Firebase AI Logic**, which works on Firebase's free Spark plan (the Gemini key stays in Firebase's proxy, never in the app, and nothing is billed). If a paid Blaze project is available, the `extractBill` Cloud Function can be used instead with `--dart-define=EXTRACT_URL=...`.

After a bill is read, the result screen also offers:

- **Next bill estimate** (no AI, works offline): units from the same month last year adjusted by the recent trend, else recent months, else this bill; or, with *Check with today's meter reading*, a projection from actual daily use since the bill's reading date. The amount scales the official energy cost by the bill's own total-to-energy ratio. Warns before the 200-unit limit with a daily-units budget. `lib/domain/forecaster.dart`.
- **Ask about this bill**: a chat helper (Gemini through Firebase AI Logic) grounded in the bill's validated numbers, the app's findings, the estimate, tariff facts and the glossary (`lib/domain/chat_prompt.dart`). Answers in the app language, short and simple, with voice; stays on electricity topics, never invents numbers, never says a bill is definitely wrong. Nothing is stored; max 20 questions per chat. Questions can be spoken: the mic turns speech (Urdu or English, following the app language) into text the user checks before sending (`lib/services/dictation_service.dart`).
- **Bill reminders** (on by default, Settings → Reminders): a notification 3 days before the due date, and one when the next bill should be out (20 days after the due date) that opens the meter's PITC page with the reference number filled in. Planned on the phone from the saved bills (`lib/domain/reminders.dart`), re-planned on every change; nothing is sent anywhere. The app cannot fetch the new bill itself: PITC's page needs the user to tap Search.
- **Appliance calculator**: pick appliances (fan, AC, motor, heater…), how many and hours a day; it shows the extra units and roughly what the bill becomes at this bill's own rates and taxes, and warns before the 200-unit limit (`lib/domain/appliances.dart`, `Forecaster.costAt`).

**Key principle:** AI only reads the image. The rules engine on the phone makes every judgement and fills every number into fixed templates.

## Changes from the SRS

| SRS | Now | Why |
|---|---|---|
| NFR-02: UI in Urdu | English by default; English/اردو switch on the first screen and in Settings. Urdu is fully right-to-left with Noto Nastaliq. | Product owner decision. |
| §8 `Finding.urduText` | `Finding.params` (raw values); text is built when shown | A saved bill is explained in whichever language is chosen later. |
| NFR-03: minimum text 18 sp, tap targets 56 dp | Standard Android sizes (body 15–16 sp, tap targets ≥ 48 dp); Settings → Text size → Large enlarges everything | Product owner found the large UI too big. |
| §1.2 out of scope: fetching bills by reference number | In scope: opens the bill on PITC's official site in the app and reads it | Product owner decision. |
| §10.3 `urdu_strings.json` | `assets/i18n/en.json` and `ur.json` (UI labels, templates, errors, glossary) | Two languages; a test checks both files have the same keys and placeholders. |

## Run the app

The reference-number lookup works without any backend. Photo scanning needs `EXTRACT_URL`; without it, scanning says it is not available. Sample data appears only with `--dart-define=USE_MOCK_API=true`, always with a "demo mode" banner.

The UI font, General Sans, may be embedded in the app but not shared as files (ITF Free Font License), so it is not in git. Fetch it once before the first build:

```sh
scripts/fetch_fonts.sh
```

```sh
cd app
flutter pub get
flutter run                                   # lookup works; photo scanning needs EXTRACT_URL
flutter run --dart-define=USE_MOCK_API=true   # sample bill, for UI work only
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

## Firebase setup (free Spark plan, current)

Project: `bill-samjho`. Already done: Android app registered (`app/android/app/google-services.json`, git-ignored) and tariffs deployed to Remote Config.

One manual step in the [Firebase console](https://console.firebase.google.com/project/bill-samjho/ailogic): **AI Logic → Get started → Gemini Developer API** (no billing). Photo scanning then works in the existing APK.

App Check is off by default because sideloaded APKs cannot pass Play Integrity. For a Google Play build: register Play Integrity in the console, build with `--dart-define=APP_CHECK=true`, then enforce App Check for AI Logic.

## Firebase setup (paid Blaze plan, optional)

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
