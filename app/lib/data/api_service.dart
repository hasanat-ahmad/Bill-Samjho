import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../core/constants.dart';
import 'models/extracted_bill.dart';

/// Error codes match the backend (SDA §9.1) and the `errors` keys in
/// assets/urdu_strings.json.
enum ApiError {
  offline('offline'),
  timeout('timeout'),
  notABill('not_a_bill'),
  unreadable('unreadable'),
  tooLarge('too_large'),
  rateLimited('rate_limited'),
  aiBusy('ai_busy'),
  unknown('unknown');

  const ApiError(this.code);
  final String code;

  static ApiError fromCode(String? code) =>
      values.firstWhere((e) => e.code == code, orElse: () => unknown);

  /// Errors fixed by taking a new photo rather than retrying the same one.
  bool get needsNewPhoto => this == notABill || this == unreadable || this == tooLarge;
}

class ApiException implements Exception {
  const ApiException(this.error);
  final ApiError error;

  @override
  String toString() => 'ApiException(${error.code})';
}

abstract class ApiService {
  /// Sends a JPEG and returns the bill data read from it.
  /// Throws [ApiException].
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId);

  factory ApiService.create() =>
      Env.useMockApi ? MockApiService() : HttpApiService(Env.extractUrl);
}

class HttpApiService implements ApiService {
  HttpApiService(String url, {Dio? dio, Connectivity? connectivity})
      : _url = url,
        _connectivity = connectivity ?? Connectivity(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConstants.requestTimeout,
              sendTimeout: AppConstants.requestTimeout,
              receiveTimeout: AppConstants.requestTimeout,
            ));

  final String _url;
  final Dio _dio;
  final Connectivity _connectivity;

  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId) async {
    final network = await _connectivity.checkConnectivity();
    if (network.every((n) => n == ConnectivityResult.none)) {
      throw const ApiException(ApiError.offline);
    }

    final form = FormData.fromMap({
      'deviceId': deviceId,
      'image': MultipartFile.fromBytes(jpeg, filename: 'bill.jpg', contentType: DioMediaType('image', 'jpeg')),
    });

    try {
      final res = await _dio
          .post<Map<String, dynamic>>(_url, data: form)
          .timeout(AppConstants.requestTimeout);
      final bill = ExtractedBill.fromJson(res.data!);
      if (bill.confidence < AppConstants.minConfidence) {
        throw const ApiException(ApiError.unreadable);
      }
      return bill;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException(_mapDioError(e));
    } on TimeoutException {
      throw const ApiException(ApiError.timeout);
    } catch (_) {
      throw const ApiException(ApiError.unknown);
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
        final code = data is Map ? data['error'] as String? : null;
        if (code != null) return ApiError.fromCode(code);
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

/// Returns a sample LESCO bill after a short delay, for development
/// without the backend (`--dart-define=USE_MOCK_API=true`).
class MockApiService implements ApiService {
  @override
  Future<ExtractedBill> extractBill(Uint8List jpeg, String deviceId) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return ExtractedBill.fromJson(sampleBillJson);
  }

  static const sampleBillJson = <String, dynamic>{
    'disco': 'LESCO',
    'reference_no': '07 11234 1234567 U',
    'bill_month': '2026-09',
    'previous_reading': 18420,
    'present_reading': 18606,
    'units': 186,
    'tariff_category': 'A-1a(01)',
    'energy_charges': 4730.26,
    'fixed_charges': 0,
    'fpa': 152.40,
    'qtr_adjustment': 0,
    'gst': 878.50,
    'income_tax': 0,
    'electricity_duty': 70.95,
    'tv_fee': 35,
    'arrears': 0,
    'total_due': 5867,
    'late_surcharge': 470,
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
