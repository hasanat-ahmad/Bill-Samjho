# Bill Samjho — SRS & Software Design Document

Version 1.0 · 2026-10-21 · Author: Hasanat Ahmad

> **For Claude Code:** Build the MVP described here. Keep it simple; the users are ordinary Pakistani households, many with low literacy. Do not add features that are not listed. Follow the build order in Section 12. Where a value is marked `VERIFY`, keep it in config and leave a TODO; do not hard-code it.

---

## PART A — SOFTWARE REQUIREMENTS SPECIFICATION (SRS)

## 1. Introduction

### 1.1 Purpose
Bill Samjho is an Android app (Flutter) that reads a photo of a Pakistani electricity bill and explains it in simple Urdu, by text **and voice**. It tells the user whether the bill looks normal, and warns about the 200-unit protected limit.

### 1.2 Scope (MVP)
In scope:
- Electricity bills from WAPDA DISCOs (LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HESCO, SEPCO, QESCO, TESCO, HAZECO) and K-Electric.
- Scan bill with camera or pick from gallery.
- Urdu explanation with voice.
- Simple verdict: Normal / Check this / Possibly wrong.
- 200-unit protected status helper.
- Saved bill history per connection.
- Complaint helper (copy/share text, call 118).

Out of scope (do NOT build now): gas bills, user accounts/login, payments, fetching bills by reference number, WhatsApp bot, meter-photo reminders, regional languages other than Urdu, iOS release.

### 1.3 Definitions
| Term | Meaning |
|---|---|
| DISCO | Electricity distribution company (e.g. LESCO, IESCO) |
| Units | kWh consumed this month |
| Protected consumer | Household that used ≤ 200 units in each of the last 6 months; gets lower rates |
| FPA | Fuel Price Adjustment, a monthly nationwide charge |
| QTR | Quarterly tariff adjustment |
| Verdict | The app's one-word judgement of the bill |

### 1.4 Users
| User | Description |
|---|---|
| Elderly / low-literacy bill payer | Reads Urdu with difficulty or not at all; needs voice and icons |
| Household on a tight budget | Uses 150–250 units; wants to stay under 200 |
| Young family member | Helps parents check bills; can read English/Urdu |

### 1.5 Assumptions & constraints
- Cheap Android phones (Android 8+, 2 GB RAM), slow or unstable internet.
- App is unofficial; it advises, it never claims a bill *is* wrong.
- Tariff rates change; they must come from remote config, not code.

## 2. Functional Requirements

Priority: **M** = must (MVP), **S** = should (MVP if time allows).

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | On first launch, show a one-screen intro with a voice button and a privacy notice ("Your bill photo is sent to read it, then deleted. Nothing is stored online."). User taps "Shuru karein" to continue. No login. | M |
| FR-02 | User can add a connection with a nickname (e.g. "Ghar") chosen from presets (Ghar, Dukaan, Ammi Abbu ka ghar) or typed. | M |
| FR-03 | User can scan a bill with the camera using a document scanner (auto crop) or pick an image from the gallery. | M |
| FR-04 | Before upload, the app compresses the image to ≤ 300 KB (long edge 1600 px, JPEG quality ~80). | M |
| FR-05 | The app sends the image to the backend, which returns structured bill data (Section 9.2). | M |
| FR-06 | If extraction fails or confidence is low, show a friendly Urdu message with a big "Dobara tasveer lein" (retake) button. | M |
| FR-07 | The app shows the extracted key fields (month, units, total, due date) and lets the user correct units and total with simple number inputs before analysis. | M |
| FR-08 | The app runs the rules engine (Section 10) locally and produces a verdict + list of findings. | M |
| FR-09 | Result screen shows: verdict badge (colour + icon + word), total amount in large digits, units, and a list of findings in Urdu. | M |
| FR-10 | A large speaker button reads the full explanation aloud in Urdu. Each finding also has its own small play button. | M |
| FR-11 | Result screen shows a "200 unit meter": units used vs 200 with a simple bar and Urdu text. | M |
| FR-12 | Bill is saved locally under its connection (data + compressed image). | M |
| FR-13 | History screen per connection: list of saved bills (month, units, total, verdict) and a simple bar chart of units with a line at 200. | S |
| FR-14 | Complaint helper (shown when verdict is not Normal): pre-filled Urdu complaint text containing reference number, month, units, and the finding; buttons: Copy, Share (WhatsApp etc.), Call 118. | M |
| FR-15 | "Charges ka matlab" screen: static Urdu glossary explaining each bill line (FPA, QTR, GST, ED, fixed charges, arrears, late surcharge), each with a play button. | S |
| FR-16 | User can delete a bill or a connection. | M |
| FR-17 | Settings: voice speed (slow/normal), text size (normal/large), clear all data. | S |
| FR-18 | App fetches the latest tariff config at start (Firebase Remote Config); falls back to the bundled copy when offline. | M |

## 3. Non-Functional Requirements

| ID | Area | Requirement |
|---|---|---|
| NFR-01 | Simplicity | Max 2 taps from Home to start a scan. Every main action is a large button with icon + Urdu label. |
| NFR-02 | Language | UI in Urdu (RTL) with Noto Nastaliq Urdu font. Numbers shown in Western digits (e.g. 2,450) for clarity. |
| NFR-03 | Accessibility | Minimum text 18 sp; tap targets ≥ 56 dp; verdict never relies on colour alone (icon + word + voice). |
| NFR-04 | Performance | Scan-to-result ≤ 10 s on 4G, ≤ 30 s on 3G. Show a progress message in Urdu while waiting. |
| NFR-05 | Offline | Home, history, saved results and glossary work offline. Scans require internet; show a clear message if offline. |
| NFR-06 | Size | Release APK ≤ 25 MB. |
| NFR-07 | Privacy | No account, no CNIC, no phone number. Backend does not store images or results. All user data stays on device. |
| NFR-08 | Security | Gemini API key only on the backend (Secret Manager), never in the app. Backend rate-limited per device ID. |
| NFR-09 | Reliability | AI output is validated; any number shown in an explanation comes from validated data, never invented by AI. |
| NFR-10 | Maintainability | Tariffs, thresholds and Urdu templates in config/JSON, not scattered in code. Rules engine fully unit-tested. |
| NFR-11 | Cost | Target < Rs 2 per scan. |

## 4. Use Cases

**UC-1 Scan and understand a bill**
1. User taps "Naya bill" on Home.
2. Picks connection (or creates one on the spot).
3. Scans bill.
4. App shows "Bill parh rahe hain..." progress.
5. App shows confirm screen (month, units, total); user taps "Theek hai".
6. Result screen appears; explanation auto-plays once.
Alt 4a: extraction fails → retake message. Alt 5a: user corrects a number → analysis uses the corrected value.

**UC-2 Complain about a suspicious bill**
1. On Result (verdict ≠ Normal), user taps "Shikayat".
2. Sees pre-filled text; taps Share or Call 118.

**UC-3 Check history**
1. On Home, user taps a connection card → History.
2. Taps a past bill → its Result screen.

---

## PART B — SOFTWARE DESIGN & ARCHITECTURE (SDA)

## 5. Architecture Overview

```
┌──────────────────────── Flutter App (Android) ────────────────────────┐
│ UI (Screens) ──► Cubits ──► Repositories ──► Services                 │
│                                   │            ├─ ScanService (camera)│
│                                   │            ├─ ApiService (HTTP)   │
│                                   │            ├─ TtsService          │
│                                   │            └─ TariffConfigService │
│                                   ├─ RulesEngine (pure Dart)          │
│                                   └─ LocalStore (Hive)                │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │ HTTPS POST /extract (image)
                     ┌──────────────▼──────────────┐
                     │ Firebase Cloud Function      │──► Gemini Flash
                     │ (TypeScript) extractBill     │    (JSON schema output)
                     │ validate → return JSON       │
                     └──────────────────────────────┘
        Firebase Remote Config: tariff_config (JSON)
```

Key principle: **AI only reads the image. The rules engine on the phone makes every judgement and fills every number into fixed Urdu templates.**

## 6. Tech Stack

| Layer | Choice |
|---|---|
| App | Flutter (latest stable), Dart 3, Android only |
| State management | flutter_bloc (Cubit only, no complex Blocs) |
| Navigation | go_router |
| Local storage | hive_ce + hive_ce_flutter |
| Scanner | google_mlkit_document_scanner (fallback: image_picker) |
| Image compress | flutter_image_compress |
| HTTP | dio |
| Voice | flutter_tts (language `ur-PK`) |
| Charts | fl_chart |
| Config | firebase_core + firebase_remote_config |
| Share/call | share_plus, url_launcher |
| Fonts | Noto Nastaliq Urdu (bundled asset) |
| Backend | Firebase Cloud Functions (2nd gen, TypeScript, Node 20+), `@google/genai` SDK |
| AI model | Gemini Flash — model name from env var `GEMINI_MODEL` |
| Monitoring | firebase_crashlytics |

## 7. Project Structure

```
bill_samjho/
├─ app/                          # Flutter app
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ app.dart                # MaterialApp.router, RTL, theme
│  │  ├─ core/
│  │  │  ├─ theme.dart
│  │  │  ├─ router.dart
│  │  │  └─ constants.dart
│  │  ├─ data/
│  │  │  ├─ models/              # Connection, Bill, ExtractedBill, Finding, TariffConfig
│  │  │  ├─ local_store.dart     # Hive boxes
│  │  │  ├─ api_service.dart
│  │  │  ├─ tariff_config_service.dart
│  │  │  └─ bill_repository.dart
│  │  ├─ domain/
│  │  │  ├─ rules_engine.dart    # pure Dart, no Flutter imports
│  │  │  └─ explanation_builder.dart
│  │  ├─ services/
│  │  │  ├─ scan_service.dart
│  │  │  └─ tts_service.dart
│  │  └─ features/
│  │     ├─ onboarding/
│  │     ├─ home/
│  │     ├─ scan/                # scan + confirm screens, ScanCubit
│  │     ├─ result/              # ResultCubit, complaint sheet
│  │     ├─ history/
│  │     ├─ glossary/
│  │     └─ settings/
│  ├─ assets/
│  │  ├─ fonts/
│  │  ├─ tariff_config_default.json
│  │  └─ urdu_strings.json       # templates + glossary
│  └─ test/
│     └─ rules_engine_test.dart
└─ functions/                    # Firebase Cloud Functions
   ├─ src/index.ts               # extractBill
   ├─ src/schema.ts              # Gemini response schema
   └─ src/validate.ts
```

## 8. Data Models (Dart)

```dart
class Connection {
  String id;            // uuid
  String nickname;      // "Ghar"
  String? disco;        // filled from first bill
  String? referenceNo;  // filled from first bill
  DateTime createdAt;
}

class Bill {
  String id;
  String connectionId;
  ExtractedBill data;
  String verdict;            // "normal" | "check" | "wrong"
  List<Finding> findings;
  String imagePath;          // local compressed copy
  DateTime createdAt;
}

class ExtractedBill {
  String? disco;
  String? referenceNo;
  String billMonth;          // "2026-09"
  int? previousReading;
  int? presentReading;
  int units;
  String? tariffCategory;    // as printed, e.g. "A-1a(01)"
  double? energyCharges;     // "Cost of electricity"
  double? fixedCharges;
  double? fpa;
  double? qtrAdjustment;
  double? gst;
  double? incomeTax;
  double? electricityDuty;
  double? tvFee;
  double? arrears;
  double totalDue;           // payable within due date
  double? lateSurcharge;
  String? dueDate;           // "2026-10-15"
  List<HistoryEntry> history; // 12-month table printed on bill
  double confidence;          // 0..1 from backend
}

class HistoryEntry { String month; int units; double? amount; }

class Finding {
  String ruleId;            // "R1".."R7"
  String severity;          // "info" | "check" | "wrong"
  String urduText;          // built from template
}
```

Hive boxes: `connections`, `bills`, `settings`.

## 9. Backend Design

### 9.1 Endpoint
`POST /extractBill` (HTTPS callable or onRequest)
- Request: `multipart/form-data` with `image` (JPEG ≤ 500 KB) and `deviceId` (random UUID generated on first launch).
- Response 200: `ExtractedBill` JSON (Section 8 field names in snake_case).
- Errors: `400 not_a_bill`, `400 unreadable`, `413 too_large`, `429 rate_limited` (30 requests/device/day), `503 ai_busy`.
- Image is processed in memory and never written to storage or logs.

### 9.2 Gemini call
- Use structured output (`responseMimeType: application/json` + `responseSchema`) matching `ExtractedBill`, plus `is_electricity_bill: boolean` and `confidence: number`.
- Temperature 0.
- Prompt (system):

```
You read photos of Pakistani electricity bills (WAPDA DISCOs and K-Electric).
Extract only values printed on the bill. Never guess or calculate.
If a field is not visible, return null.
Units = units consumed this month as printed.
total_due = amount payable within due date.
history = the month-wise units/amount table printed on the bill, if present.
If the image is not an electricity bill, set is_electricity_bill=false.
Set confidence between 0 and 1 for how clearly you could read units and total_due.
```

### 9.3 Validation (validate.ts)
Reject with `unreadable` if any:
- `is_electricity_bill` false → return `not_a_bill` instead.
- `units` or `total_due` missing.
- `units` < 0 or > 5000.
- Both readings present and `present - previous ≠ units` (allow K-Electric multiplier: skip check if difference × multiplier matches, else flag low confidence rather than reject).
- `confidence` < 0.6.

## 10. Rules Engine (pure Dart)

Input: `ExtractedBill current`, `List<Bill> pastBillsForConnection`, `TariffConfig config`.
Output: `verdict` + `List<Finding>`.
Verdict = worst severity among findings (`wrong` > `check` > `info`/none → `normal`).

### 10.1 Tariff config (Remote Config key `tariff_config`, bundled default in assets)

```json
{
  "version": "2026-10",
  "source_url": "https://nepra.org.pk",
  "protected_limit_units": 200,
  "protected_months": 6,
  "near_limit_units": 180,
  "slabs": {
    "protected": [
      {"from": 1, "to": 100, "rate": 10.54},
      {"from": 101, "to": 200, "rate": 13.01}
    ],
    "non_protected": [
      {"from": 1, "to": 100, "rate": 22.44},
      {"from": 101, "to": 200, "rate": 28.91},
      {"from": 201, "to": 300, "rate": 33.10},
      {"from": 301, "to": 400, "rate": 37.99},
      {"from": 401, "to": 500, "rate": 40.22},
      {"from": 501, "to": 600, "rate": 41.62},
      {"from": 601, "to": 700, "rate": 42.76},
      {"from": 701, "to": null, "rate": 47.69}
    ]
  },
  "non_protected_flat_above_units": 200,
  "energy_tolerance_percent": 3
}
```
`VERIFY`: all rates and the slab method against the latest NEPRA notification before release. Rates above are from 2026 news reports.

Energy charge calculation:
- Protected and non-protected ≤ 200 units: incremental slabs (first 100 at slab 1 rate, rest at slab 2 rate).
- Non-protected > `non_protected_flat_above_units`: all units × the rate of the slab the total falls in (`VERIFY`).

### 10.2 Rules

| Rule | Condition | Severity | Urdu template key |
|---|---|---|---|
| R1 Energy check | `energyCharges` present AND `|computed − energyCharges| / computed × 100 > energy_tolerance_percent`. Try both protected and non-protected; pass if either matches. | wrong | `r1_energy_mismatch` |
| R2 Big jump | Average units of same-length history (use bill `history` + saved bills, last 6 months) exists AND `units > avg × 1.4`. `wrong` if `units > avg × 2`. | check / wrong | `r2_jump` |
| R3 Same reading | `units` equals previous month's units exactly AND previous month exists, OR `presentReading == previousReading` while units > 0 | check | `r3_estimated` |
| R4 Protected lost | `units > 200` this month, OR any month in last 6 (from history) > 200 | check | `r4_protected_lost` (include month when status may return = last month > 200 + 6 months) |
| R5 Near limit | `near_limit_units ≤ units ≤ 200` | info | `r5_near_limit` |
| R6 Arrears | `arrears > 0` | check | `r6_arrears` |
| R7 Adjustments | `fpa` or `qtrAdjustment` > 0 | info | `r7_adjustments` |

Always add a summary finding (not a rule) first: `summary` template with units, total and due date.

Unit tests (required): slab boundaries 0, 100, 101, 180, 200, 201, 300, 701 units; each rule fires and does not fire; verdict ordering; missing optional fields never crash.

### 10.3 Urdu templates (assets/urdu_strings.json)
Templates use `{placeholders}`. Have a native Urdu speaker review before release.

```json
{
  "summary": "اس مہینے آپ نے {units} یونٹ بجلی استعمال کی۔ آپ کا بل {total} روپے ہے، جو {due_date} تک جمع کروانا ہے۔",
  "verdict_normal": "آپ کا بل عام لگ رہا ہے۔",
  "verdict_check": "آپ کے بل میں کچھ باتیں دیکھنے والی ہیں۔",
  "verdict_wrong": "آپ کا بل شاید غلط ہے۔ پہلے کاغذ والے بل سے ملا لیں۔",
  "r1_energy_mismatch": "یونٹس کے حساب سے بجلی کی قیمت تقریباً {expected} روپے بنتی ہے، لیکن بل پر {printed} روپے لکھے ہیں۔",
  "r2_jump": "اس مہینے کے یونٹ پچھلے مہینوں کی اوسط {avg} یونٹ سے بہت زیادہ ہیں۔ میٹر ریڈنگ چیک کریں۔",
  "r3_estimated": "یہ ریڈنگ اندازے سے لگائی گئی لگتی ہے۔ اپنے میٹر کی تصویر لے کر ملا لیں۔",
  "r4_protected_lost": "آپ نے کسی مہینے 200 سے زیادہ یونٹ استعمال کیے، اس لیے سستا ریٹ نہیں مل رہا۔ اگر اگلے 6 مہینے 200 سے کم رہیں تو سستا ریٹ واپس مل سکتا ہے۔",
  "r5_near_limit": "آپ 200 یونٹ کی حد کے قریب ہیں۔ صرف {left} یونٹ باقی ہیں۔",
  "r6_arrears": "اس بل میں پچھلا بقایا {arrears} روپے شامل ہے۔ اگر آپ نے پچھلا بل جمع کروایا تھا تو رسید سنبھال کر رکھیں۔",
  "r7_adjustments": "بل میں فیول اور سہ ماہی ایڈجسٹمنٹ شامل ہے۔ یہ پورے ملک کے لیے ہوتی ہے، آپ کی غلطی نہیں۔",
  "complaint": "السلام علیکم، میرا ریفرنس نمبر {ref} ہے۔ {month} کے بل میں {units} یونٹ لکھے ہیں۔ مسئلہ: {finding}۔ براہ کرم چیک کر کے درست کریں۔"
}
```

### 10.4 Explanation builder
Join: verdict sentence → summary → findings (ordered wrong, check, info). Pass the same text to TTS. Numbers formatted with thousands separators. If `ur-PK` TTS voice is not installed, show the text and a one-time tip: "Urdu awaz ke liye Google Speech Services install karein" with a Play Store link.

## 11. Screens (UI Design)

All screens RTL, large buttons, one main action per screen.

| # | Screen | Contents |
|---|---|---|
| S1 | Intro (first launch only) | App name, one-line purpose, play button, privacy note, "شروع کریں" button |
| S2 | Home | Connection cards (nickname, last month units, verdict badge, mini 200-unit bar). Big floating button "نیا بل" with camera icon. Small glossary and settings icons in app bar. Empty state: illustration + "اپنا پہلا بل اسکین کریں" |
| S3 | Pick connection | Bottom sheet listing connections + "نیا کنکشن" (preset nickname chips + text field) |
| S4 | Scanning / loading | Document scanner opens; then loading screen "بل پڑھ رہے ہیں..." with animated icon; cancel button |
| S5 | Confirm | Month, units, total, due date in large text; units and total editable; "ٹھیک ہے" button |
| S6 | Result | Verdict banner (green tick "ٹھیک ہے" / amber "دیکھیں" / red "شاید غلط"), big total, speaker button (auto-plays once), 200-unit bar, findings list each with play icon, "شکایت" button if not normal |
| S7 | Complaint sheet | Pre-filled text box, Copy, Share, Call 118 buttons |
| S8 | History | Bar chart of units with 200 line; list of bills; delete via long-press with confirm |
| S9 | Glossary | List of bill terms, each with short Urdu meaning + play button |
| S10 | Settings | Voice speed, text size, delete all data |

Colours: green `#2E7D32`, amber `#F9A825`, red `#C62828`, primary `#1565C0`, background white. Each verdict also has an icon (check, exclamation, cross).

## 12. Build Order (for Claude Code)

1. Create Flutter app + Firebase project wiring (Android only), RTL + Urdu font, theme, go_router with empty screens.
2. Models + Hive LocalStore + BillRepository with unit tests.
3. TariffConfigService (Remote Config + bundled default) and RulesEngine with full unit tests (Section 10.2).
4. ExplanationBuilder + TtsService.
5. Cloud Function `extractBill` with schema, prompt, validation, rate limit. Add a local mock mode (`USE_MOCK_API=true`) that returns a sample bill so the app can be developed without the backend.
6. ScanService (document scanner + gallery + compression) and Scan/Confirm screens.
7. Result screen + Complaint sheet.
8. Home + History + Glossary + Settings.
9. Error states: offline, timeout (20 s), not_a_bill, unreadable, rate_limited, ai_busy — each with Urdu message and retry.
10. Polish: large text mode, empty states, app icon, release build ≤ 25 MB.

## 13. Acceptance Criteria (MVP done when)

- A new user can scan a real bill and hear an Urdu explanation within 3 taps from Home.
- Rules engine tests pass for all boundary cases.
- 20 real bills from at least 3 DISCOs: units and total extracted correctly in ≥ 18.
- App works offline for Home, History, saved Results and Glossary.
- No API key in the APK; backend stores no images.
- 5 non-technical users can complete UC-1 without help.

## 14. Risks

| Risk | Handling |
|---|---|
| AI misreads a number | Confirm screen lets user fix units/total; verdict wording is always "possibly", never "definitely" |
| Tariff changes | Remote Config update, no app release needed |
| Different bill layouts | Test with sample bills from each DISCO; adjust prompt hints |
| Urdu TTS missing on phone | Text always shown; tip to install Google Speech Services |
