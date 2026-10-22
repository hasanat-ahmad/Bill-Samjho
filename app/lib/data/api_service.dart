import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'models/extracted_bill.dart';

/// Error codes match the backend (SDA §9.1) and the `errors` keys in
/// assets/i18n/*.json.
enum ApiError {
  offline('offline'),
  timeout('timeout'),
  notABill('not_a_bill'),
  unreadable('unreadable'),
  tooLarge('too_large'),
  rateLimited('rate_limited'),
  aiBusy('ai_busy'),
  unavailable('unavailable'),
  unknown('unknown');

  const ApiError(this.code);
  final String code;

  static ApiError fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => unknown);

  /// Errors fixed by taking a new photo rather than retrying the same one.
  bool get needsNewPhoto => this == notABill || this == unreadable || this == tooLarge;

  /// Errors where retrying the same photo can help.
  bool get canRetry => this == offline || this == timeout || this == aiBusy || this == unknown;
}

class ApiException implements Exception {
  const ApiException(this.error);
  final ApiError error;

  @override
  String toString() => 'ApiException(${error.code})';
}

/// Upload progress from 0 to 1.
typedef ProgressCallback = void Function(double sent);

abstract class ApiService {
  /// Sends a JPEG and returns the validated bill data read from it.
  /// Throws [ApiException].
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId, {ProgressCallback? onProgress});

  /// Reads bill data from the text of a bill web page. Throws [ApiException].
  Future<ExtractedBill> extractBillText(String text, String deviceId);

  bool get isMock => false;

  /// [appCheckToken] attests the request comes from the genuine app.
  factory ApiService.create({Future<String?> Function()? appCheckToken}) {
    if (Env.useMockApi) return MockApiService();
    final uri = Uri.tryParse(Env.extractUrl);
    if (uri == null || uri.host.isEmpty || !isAllowedBackend(uri, release: kReleaseMode)) {
      return UnavailableApiService();
    }
    return HttpApiService(uri, appCheckToken: appCheckToken);
  }
}

/// HTTPS only, so bill photos never travel in clear text. Debug builds may
/// also use plain HTTP to the local Firebase emulator on this machine.
bool isAllowedBackend(Uri uri, {required bool release}) {
  if (uri.scheme == 'https') return true;
  const localHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};
  return !release && uri.scheme == 'http' && localHosts.contains(uri.host);
}

class HttpApiService implements ApiService {
  HttpApiService(this._uri, {Dio? dio, Connectivity? connectivity, this.appCheckToken})
      : _connectivity = connectivity ?? Connectivity(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.requestTimeout,
              sendTimeout: AppConstants.requestTimeout,
              receiveTimeout: AppConstants.requestTimeout,
              followRedirects: false,
              responseType: ResponseType.json,
            ));

  final Uri _uri;
  final Dio _dio;
  final Connectivity _connectivity;
  final Future<String?> Function()? appCheckToken;

  @override
  bool get isMock => false;

  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId, {ProgressCallback? onProgress}) async {
    final network = await _connectivity.checkConnectivity();
    if (network.every((n) => n == ConnectivityResult.none)) {
      throw const ApiException(ApiError.offline);
    }

    final form = FormData.fromMap({
      'deviceId': deviceId,
      'image': MultipartFile.fromBytes(jpeg, filename: 'bill.jpg', contentType: DioMediaType('image', 'jpeg')),
    });
    return _post(_uri, form, onProgress: onProgress);
  }

  /// `extractBillText` lives next to `extractBill`.
  Uri get _textUri => _uri.replace(
        pathSegments: [..._uri.pathSegments.take(_uri.pathSegments.length - 1), 'extractBillText'],
      );

  @override
  Future<ExtractedBill> extractBillText(String text, String deviceId) async {
    final network = await _connectivity.checkConnectivity();
    if (network.every((n) => n == ConnectivityResult.none)) {
      throw const ApiException(ApiError.offline);
    }
    final body = {'deviceId': deviceId, 'text': text.length > 20000 ? text.substring(0, 20000) : text};
    return _post(_textUri, body);
  }

  Future<ExtractedBill> _post(Uri uri, Object data, {ProgressCallback? onProgress}) async {
    final token = await _safeToken();
    try {
      final res = await _dio
          .postUri<Object>(
            uri,
            data: data,
            options: Options(headers: {'X-Firebase-AppCheck': ?token}),
            onSendProgress: onProgress == null ? null : (sent, total) => onProgress(total > 0 ? sent / total : 0),
          )
          .timeout(AppConstants.requestTimeout);
      final body = res.data;
      if (body is! Map<String, dynamic>) throw const ApiException(ApiError.unknown);
      final bill = ExtractedBill.fromUntrusted(body);
      if (bill.confidence < AppConstants.minConfidence) {
        throw const ApiException(ApiError.unreadable);
      }
      return bill;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException(ApiError.unreadable);
    } on DioException catch (e) {
      throw ApiException(_mapDioError(e));
    } on TimeoutException {
      throw const ApiException(ApiError.timeout);
    } catch (_) {
      throw const ApiException(ApiError.unknown);
    }
  }

  Future<String?> _safeToken() async {
    try {
      return await appCheckToken?.call().timeout(const Duration(seconds: 5));
    } catch (_) {
      return null; // The backend decides whether a missing token is allowed.
    }
  }

  static ApiError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError.timeout;
      case DioExceptionType.connectionError:
        return ApiError.offline;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final code = data is Map ? data['error'] : null;
        if (code is String) return ApiError.fromCode(code);
        return switch (e.response?.statusCode) {
          413 => ApiError.tooLarge,
          429 => ApiError.rateLimited,
          503 => ApiError.aiBusy,
          _ => ApiError.unknown,
        };
      default:
        return ApiError.unknown;
    }
  }
}

/// Used when a release build has no valid HTTPS backend URL.
class UnavailableApiService implements ApiService {
  @override
  bool get isMock => false;

  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId, {ProgressCallback? onProgress}) =>
      Future.error(const ApiException(ApiError.unavailable));

  @override
  Future<ExtractedBill> extractBillText(String text, String deviceId) =>
      Future.error(const ApiException(ApiError.unavailable));
}

/// Returns a sample LESCO bill after a short delay, for development
/// without the backend (`--dart-define=USE_MOCK_API=true`). The app shows a
/// "demo mode" banner whenever this is active.
class MockApiService implements ApiService {
  @override
  bool get isMock => true;

  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId, {ProgressCallback? onProgress}) async {
    for (var i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      onProgress?.call(i / 5);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return ExtractedBill.fromUntrusted(sampleBillJson);
  }

  @override
  Future<ExtractedBill> extractBillText(String text, String deviceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return ExtractedBill.fromUntrusted(sampleBillJson);
  }

  static const sampleBillJson = <String, dynamic>{
    'disco': 'LESCO',
    'reference_no': '07 11234 1234567 U',
    'bill_month': '2026-09',
    'previous_reading': 18420,
    'present_reading': 18606,
    'units': 186,
    'tariff_category': 'A-1a(01)',
    // 186 units, non-protected (July was over 200): 186 × 28.91 (SRO 279(I)/2026)
    'energy_charges': 5377.26,
    'fixed_charges': 600, // 2 kW × Rs 300
    'fpa': 152.40,
    'qtr_adjustment': 0,
    'gst': 1103.34,
    'income_tax': 0,
    'electricity_duty': null, // abolished from July 2025
    'tv_fee': null, // abolished from July 2025
    'arrears': 0,
    'total_due': 7233,
    'late_surcharge': 723,
    'due_date': '2026-10-15',
    'history': [
      {'month': '2026-08', 'units': 178, 'amount': 4520},
      {'month': '2026-07', 'units': 212, 'amount': 7480},
      {'month': '2026-06', 'units': 195, 'amount': 4610},
      {'month': '2026-05', 'units': 160, 'amount': 2380},
      {'month': '2026-04', 'units': 120, 'amount': 1750},
      {'month': '2026-03', 'units': 110, 'amount': 1600},
    ],
    'confidence': 0.92,
  };
}
