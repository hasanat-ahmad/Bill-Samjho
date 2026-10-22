import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'api_service.dart';
import 'models/extracted_bill.dart';

/// Reads bills with Gemini through Firebase AI Logic. This works on Firebase's
/// free Spark plan: the Gemini key stays in Firebase's proxy (never in the
/// app) and nothing is billed. Mirrors functions/src (prompt, schema and
/// validation), which remains the option for a paid backend.
class FirebaseAiApiService implements ApiService {
  FirebaseAiApiService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Best first; the next is tried when one is overloaded or out of quota.
  static const models = ['gemini-3.5-flash', 'gemini-3.5-flash-lite', 'gemini-flash-latest'];

  /// Total time for all attempts (SDA §12: 20 s request timeout).
  static const _budget = Duration(seconds: 18);

  @override
  bool get isMock => false;

  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId, {ProgressCallback? onProgress}) async {
    await _requireNetwork();
    onProgress?.call(1); // the photo goes up with the request
    return _read([InlineDataPart('image/jpeg', jpeg), TextPart('Read this bill.')]);
  }

  @override
  Future<ExtractedBill> extractBillText(String text, String deviceId) async {
    await _requireNetwork();
    final page = text.length > 20000 ? text.substring(0, 20000) : text;
    return _read([
      TextPart('Read this bill. It is the text of the official PITC duplicate-bill web page, not a photo.\n'
          '<bill_page>\n$page\n</bill_page>'),
    ]);
  }

  Future<void> _requireNetwork() async {
    final network = await _connectivity.checkConnectivity();
    if (network.every((n) => n == ConnectivityResult.none)) throw const ApiException(ApiError.offline);
  }

  Future<ExtractedBill> _read(List<Part> parts) async {
    final deadline = DateTime.now().add(_budget);
    var lastError = ApiError.aiBusy;
    for (final name in models) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining < const Duration(seconds: 2)) break;
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: name,
          systemInstruction: Content.system(systemPrompt),
          generationConfig: GenerationConfig(
            temperature: 0,
            responseMimeType: 'application/json',
            responseSchema: billSchema,
          ),
        );
        final response = await model.generateContent([Content.multi(parts)]).timeout(remaining);
        return parseModelOutput(response.text);
      } on ApiException {
        rethrow;
      } on QuotaExceeded {
        lastError = ApiError.rateLimited; // free-tier limit for this model; try the next
      } on ServerException catch (e) {
        // Setup problems (AI Logic not enabled, key restrictions) also arrive
        // as server errors; retrying other models cannot fix them.
        if (isSetupError(e.message)) throw const ApiException(ApiError.unavailable);
        lastError = ApiError.aiBusy; // overloaded; try the next
      } on TimeoutException {
        lastError = ApiError.timeout;
      } on SocketException {
        throw const ApiException(ApiError.offline);
      } on FirebaseAIException catch (e) {
        // Not set up (AI Logic not enabled), key problems: retrying won't help.
        debugPrint('Firebase AI error: ${e.runtimeType}');
        throw const ApiException(ApiError.unavailable);
      } catch (e) {
        debugPrint('Gemini call failed: ${e.runtimeType}');
        lastError = ApiError.aiBusy;
      }
    }
    throw ApiException(lastError);
  }

  @visibleForTesting
  static bool isSetupError(String message) =>
      RegExp(r'PERMISSION_DENIED|has not been used|is disabled|API key|API_KEY', caseSensitive: false).hasMatch(message);

  /// Same rules as functions/src/validate.ts, then the app's strict parsing.
  @visibleForTesting
  static ExtractedBill parseModelOutput(String? text) {
    final Object? raw;
    try {
      raw = jsonDecode(text ?? '');
    } on FormatException {
      throw const ApiException(ApiError.unreadable);
    }
    if (raw is! Map<String, dynamic>) throw const ApiException(ApiError.unreadable);
    if (raw['is_electricity_bill'] == false) throw const ApiException(ApiError.notABill);

    final json = Map<String, dynamic>.from(raw);
    var confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    if (confidence < AppConstants.minConfidence) throw const ApiException(ApiError.unreadable);

    // Readings that do not add up (and no meter multiplier explains it) mean
    // the photo was hard to read: ask the user to check the numbers closely.
    final prev = (json['previous_reading'] as num?)?.round();
    final pres = (json['present_reading'] as num?)?.round();
    final units = (json['units'] as num?)?.round();
    if (prev != null && pres != null && units != null && pres - prev != units) {
      final mf = (json['meter_multiplier'] as num?)?.toDouble();
      if (mf == null || ((pres - prev) * mf - units).abs() > 1) {
        confidence = confidence < AppConstants.minConfidence ? confidence : AppConstants.minConfidence;
      }
    }
    json['confidence'] = confidence;

    try {
      return ExtractedBill.fromUntrusted(json);
    } on FormatException {
      throw const ApiException(ApiError.unreadable);
    }
  }

  /// Same as functions/src/schema.ts SYSTEM_PROMPT.
  static const systemPrompt = '''You read photos of Pakistani electricity bills (WAPDA DISCOs and K-Electric).
Extract only values printed on the bill. Never guess or calculate.
If a field is not visible, return null.
Units = units consumed this month as printed.
total_due = amount payable within due date.
history = the month-wise units/amount table printed on the bill, if present.
If the image is not an electricity bill, set is_electricity_bill=false.
Set confidence between 0 and 1 for how clearly you could read units and total_due.
Write months as YYYY-MM and dates as YYYY-MM-DD. Write amounts as plain numbers without commas.

Hints for Pakistani bills (text may be in English and Urdu):
- Common labels: "Units Consumed", "Bill Month" (e.g. "SEP 26" means 2026-09), "Due Date" (e.g. "15 OCT 26" means 2026-10-15),
  "Payable Within Due Date", "Payable After Due Date", "Cost of Electricity", "Fixed Charges", "F.P.A" or "Fuel Price Adjustment",
  "QTR Tariff Adj", "GST", "Arrears", "Previous" and "Present" readings, "Reference No".
- energy_charges is only the "Cost of Electricity" line, not the total. "F.C. Surcharge" (financing cost) is NOT the fuel price adjustment.
  "Total Electricity Charges" on newer bills is also not energy_charges.
- Some newer bills print only the total and a QR code. Then return null for charge lines that are not printed; do not compute them.
- late_surcharge = the "L.P. Surcharge" (late payment) amount if printed; otherwise null.
- If the payable amount is marked "CR" or "Credit Bill", it is a credit: return total_due as a negative number (e.g. "297 CR" means -297).
- The reference number is usually 14 digits, sometimes followed by a letter such as U or R; copy it as printed.''';

  static Schema _num([String? d]) => Schema.number(description: d, nullable: true);
  static Schema _int([String? d]) => Schema.integer(description: d, nullable: true);
  static Schema _str([String? d]) => Schema.string(description: d, nullable: true);

  /// Same fields as functions/src/schema.ts BILL_SCHEMA.
  static final billSchema = Schema.object(
    properties: {
      'is_electricity_bill': Schema.boolean(),
      'confidence': Schema.number(description: '0..1, how clearly units and total_due were read'),
      'disco': _str('Company short name, e.g. LESCO, IESCO, K-Electric'),
      'reference_no': _str('Reference / account number as printed'),
      'bill_month': _str('Billing month, YYYY-MM'),
      'previous_reading': _int(),
      'present_reading': _int(),
      'meter_multiplier': _num('Meter multiplying factor (MF) if printed, else null'),
      'units': _int('Units consumed this month as printed'),
      'tariff_category': _str('Tariff as printed, e.g. A-1a(01)'),
      'protected_consumer': Schema.boolean(
        description: "true if the bill's category says Protected, false if Unprotected or Non-Protected, null if not printed",
        nullable: true,
      ),
      'energy_charges': _num('Cost of electricity / energy charges'),
      'fixed_charges': _num(),
      'fpa': _num('Fuel price adjustment'),
      'qtr_adjustment': _num('Quarterly tariff adjustment'),
      'gst': _num(),
      'income_tax': _num(),
      'electricity_duty': _num(),
      'tv_fee': _num(),
      'arrears': _num(),
      'total_due': _num('Amount payable within due date'),
      'late_surcharge': _num('Extra amount if paid after due date'),
      'due_date': _str('YYYY-MM-DD'),
      'history': Schema.array(
        items: Schema.object(properties: {
          'month': Schema.string(description: 'YYYY-MM'),
          'units': Schema.integer(),
          'amount': _num(),
        }, optionalProperties: ['amount']),
      ),
    },
    optionalProperties: [
      'disco', 'reference_no', 'bill_month', 'previous_reading', 'present_reading', 'meter_multiplier',
      'tariff_category', 'protected_consumer', 'energy_charges', 'fixed_charges', 'fpa', 'qtr_adjustment', 'gst',
      'income_tax', 'electricity_duty', 'tv_fee', 'arrears', 'late_surcharge', 'due_date',
    ],
  );
}
