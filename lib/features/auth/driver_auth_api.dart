// DDE-Mart driver app — workforce auth API (original).
//
// OTP-only login with role=driver. Mirrors POST /api/v1/work/auth/*.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class DriverAuthApi {
  DriverAuthApi(this._dio);

  final Dio _dio;

  Future<String?> otpRequest(String phone) async {
    final response = await _dio.post(
      '/work/auth/otp/request',
      data: {'phone': phone, 'role': 'driver'},
    );
    final data = (response.data as Map)['data'] as Map;
    return data['debug_code'] as String?;
  }

  Future<Map<String, dynamic>> otpVerify({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post(
      '/work/auth/otp/verify',
      data: {'phone': phone, 'role': 'driver', 'code': code},
    );
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> logout() async {
    await _dio.post('/driver/logout');
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/driver/me');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }
}

final driverAuthApiProvider = Provider<DriverAuthApi>(
  (ref) => DriverAuthApi(ref.watch(dioProvider)),
);
