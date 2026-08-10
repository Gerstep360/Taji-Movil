import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/config/api_config.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/features/auth/data/auth_dto.dart';

void main() {
  group('API architecture', () {
    test('keeps endpoints centralized and versioned', () {
      expect(ApiConfig.baseUrl, endsWith('/api/v1'));
      expect(ApiEndpoints.auth.login, '/auth/login/');
      expect(ApiEndpoints.auth.me, '/auth/me/');
    });

    test('normalizes login request at the boundary', () {
      const request = LoginRequest(
        email: '  RESIDENTE@Example.COM ',
        password: 'TajiSeguro2026!',
      );

      expect(request.toJson(), {
        'email': 'residente@example.com',
        'password': 'TajiSeguro2026!',
        'client': 'mobile',
      });
    });
  });
}
