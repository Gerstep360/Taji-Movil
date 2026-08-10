import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/taji_user.dart';
import 'auth_dto.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<TajiUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.auth.login,
        data: LoginRequest(email: email, password: password).toJson(),
      );
      final session = AuthSessionResponse.fromJson(json!);
      await _api.tokens.save(session.tokens);
      return session.user;
    } on DioException catch (error) {
      throw AuthException(
        _messageFrom(error, 'Correo o contraseña incorrectos.'),
      );
    }
  }

  Future<TajiUser?> restoreSession() async {
    if (!await _api.tokens.hasRefresh) return null;
    try {
      final json = await _api.get<Map<String, dynamic>>(ApiEndpoints.auth.me);
      return TajiUser.fromJson(json!['user'] as Map<String, dynamic>);
    } on DioException {
      await _api.tokens.clear();
      return null;
    }
  }

  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final request = RegisterRequest(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
      );
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.auth.register,
        data: request.toJson(),
      );
      return MessageResponse.fromJson(
        json,
        'Cuenta creada correctamente.',
      ).message;
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'No pudimos crear tu cuenta.'));
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final json = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.auth.forgotPassword,
        data: {'email': email.trim().toLowerCase()},
      );
      return MessageResponse.fromJson(json, 'Revisa tu correo.').message;
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'No pudimos enviar el enlace.'));
    }
  }

  Future<void> logout() async {
    final refresh = await _api.tokens.refresh;
    try {
      await _api.post<void>(
        ApiEndpoints.auth.logout,
        data: {'refresh': refresh},
      );
    } finally {
      await _api.tokens.clear();
    }
  }

  String _messageFrom(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      for (final value in data.values) {
        if (value is String) return value;
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con Taji. Revisa la red y assets/config/app_config.json.';
    }
    return fallback;
  }
}
