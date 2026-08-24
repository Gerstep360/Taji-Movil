import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../models/taji_user.dart';
import 'auth_dto.dart';
import 'auth_session_store.dart';

class AuthException implements Exception {
  const AuthException(this.failure);

  final ApiFailure failure;
  String get message => failure.displayMessage;
  String get code => failure.code;
  Map<String, List<String>> get fields => failure.fields;
}

class AuthRepository {
  AuthRepository(this._api, {AuthSessionStore? sessionStore})
    : _session = sessionStore ?? AuthSessionStore();

  final ApiClient _api;
  final AuthSessionStore _session;

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
      await Future.wait([
        _api.tokens.save(session.tokens),
        _session.saveUser(session.user),
      ]);
      return session.user;
    } on DioException catch (error) {
      throw AuthException(
        ApiFailure.fromDio(error, fallback: 'Correo o contraseña incorrectos.'),
      );
    }
  }

  Future<TajiUser?> restoreSession() async {
    if (!await _api.tokens.hasRefresh) {
      await _session.clear();
      return null;
    }
    final cachedUser = await _session.readUser();
    try {
      final json = await _api.get<Map<String, dynamic>>(ApiEndpoints.auth.me);
      final user = TajiUser.fromJson(json!['user'] as Map<String, dynamic>);
      await _session.saveUser(user);
      return user;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        await Future.wait([_api.tokens.clear(), _session.clear()]);
        return null;
      }
      // Sin red o con una caída temporal conservamos la sesión local; el
      // interceptor renovará el access token cuando el servidor vuelva.
      return cachedUser;
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
      throw AuthException(
        ApiFailure.fromDio(error, fallback: 'No pudimos crear tu cuenta.'),
      );
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
      throw AuthException(
        ApiFailure.fromDio(error, fallback: 'No pudimos enviar el enlace.'),
      );
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
      await Future.wait([_api.tokens.clear(), _session.clear()]);
    }
  }
}
