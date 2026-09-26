// DDE-Mart driver app — HTTP layer (original).
//
// Dio client for the DDE-Mart API v1 driver surfaces
// (see admin-panel/docs/api-v1.md, Driver app section).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'ApiException($status): $message';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(authStoreProvider.notifier).token();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final response = error.response;
        if (response != null) {
          final data = response.data;
          final message = data is Map && data['message'] is String
              ? data['message'] as String
              : 'Request failed (${response.statusCode}).';
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              error: ApiException(message, status: response.statusCode),
            ),
          );
          return;
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

String apiMessage(Object error) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return 'Something went wrong. Please try again.';
}

class LaunchConfig {
  LaunchConfig({
    required this.maintenance,
    required this.minVersions,
    required this.supportEmail,
    required this.supportPhone,
  });

  factory LaunchConfig.fromJson(Map<String, dynamic> json) {
    final min = (json['min_versions'] as Map?) ?? {};
    final support = (json['support'] as Map?) ?? {};
    return LaunchConfig(
      maintenance: json['maintenance'] == true,
      minVersions: {
        'customer': '${min['customer'] ?? '1.0.0'}',
        'driver': '${min['driver'] ?? '1.0.0'}',
        'vendor': '${min['vendor'] ?? '1.0.0'}',
      },
      supportEmail: '${support['email'] ?? ''}',
      supportPhone: '${support['phone'] ?? ''}',
    );
  }

  final bool maintenance;
  final Map<String, String> minVersions;
  final String supportEmail;
  final String supportPhone;
}
