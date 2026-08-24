import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/config/api_config.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/network/token_store.dart';
import 'package:taji/core/router/app_routes.dart';
import 'package:taji/features/auth/data/auth_session_store.dart';
import 'package:taji/features/auth/models/taji_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('T101 centraliza rutas estables', () {
    expect(AppRoute.login.path, '/iniciar-sesion');
    expect(AppRoute.register.path, '/crear-cuenta');
    expect(AppRoute.home.path, '/inicio');
  });

  test('interpreta el contrato uniforme de error del backend', () {
    final request = RequestOptions(path: '/auth/register/');
    final failure = ApiFailure.fromDio(
      DioException(
        requestOptions: request,
        response: Response<Map<String, dynamic>>(
          requestOptions: request,
          statusCode: 400,
          data: {
            'error': {
              'code': 'validation_error',
              'message': 'Revisa los campos indicados.',
              'fields': {
                'email': ['Ya existe una cuenta con este correo.'],
              },
            },
          },
        ),
      ),
      fallback: 'No pudimos crear tu cuenta.',
    );

    expect(failure.code, 'validation_error');
    expect(failure.statusCode, 400);
    expect(
      failure.displayMessage,
      'Correo: Ya existe una cuenta con este correo.',
    );
  });

  test(
    'tokens permanecen en el almacenamiento seguro hasta cerrar sesión',
    () async {
      final store = TokenStore();
      await store.save(
        const TokenPair(access: 'access-1', refresh: 'refresh-1'),
      );
      await store.updateAccess('access-2', rotatedRefresh: 'refresh-2');

      expect(await store.access, 'access-2');
      expect(await store.refresh, 'refresh-2');

      await store.clear();
      expect(await store.access, isNull);
      expect(await store.refresh, isNull);
    },
  );

  test(
    'perfil autenticado se puede restaurar desde almacenamiento seguro',
    () async {
      const user = TajiUser(
        id: 7,
        email: 'residente@taji.app',
        firstName: 'Ana',
        lastName: 'Rojas',
        fullName: 'Ana Rojas',
        phone: '+59170000000',
        role: TajiRole(
          slug: 'residente',
          name: 'Copropietario / Residente',
          description: '',
          permissions: ['report_incidents'],
        ),
      );
      final store = AuthSessionStore();
      await store.saveUser(user);

      final restored = await store.readUser();
      expect(restored?.email, user.email);
      expect(restored?.role?.permissions, user.role?.permissions);

      await store.clear();
      expect(await store.readUser(), isNull);
    },
  );

  test('ApiConfig acepta LAN privada y rechaza HTTP público', () async {
    await ApiConfig.initialize(
      bundle: _JsonBundle({
        'apiBaseUrl': 'http://192.168.1.20:8000/api/v1/',
        'connectTimeoutMs': 3000,
        'receiveTimeoutMs': 4000,
      }),
    );
    expect(ApiConfig.baseUrl, 'http://192.168.1.20:8000/api/v1');
    expect(ApiConfig.connectTimeout, const Duration(seconds: 3));

    expect(
      () => ApiConfig.initialize(
        bundle: _JsonBundle({'apiBaseUrl': 'http://api.example.com/api/v1'}),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _JsonBundle extends AssetBundle {
  _JsonBundle(this.value);
  final Map<String, Object> value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    return ByteData.sublistView(bytes);
  }
}
