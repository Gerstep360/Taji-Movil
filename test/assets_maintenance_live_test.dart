import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/network/token_store.dart';
import 'package:taji/features/assets/asset_repository.dart';
import 'package:taji/features/maintenance/data/maintenance_order_repository.dart';
import 'package:taji/features/incidents/incident_tracking.dart';

/// Solo contra el servidor efímero de Backend/scripts/serve_cu24_test_api.py.
/// No altera .env, app_config.json ni la base de datos del usuario.
class _Tokens extends TokenStore {
  String? value, tenant;
  @override
  Future<String?> get access async => value;
  @override
  Future<String?> get tenantId async => tenant;
  @override
  Future<String?> get refresh async => null;
}

void main() {
  final base = Platform.environment['CU24_LIVE_URL'];
  test(
    'Flutter y Django reales: JWT móvil, activos, QR, órdenes y seguimiento',
    () async {
      expect(base, 'http://localhost:18766');
      final tokens = _Tokens();
      // Cliente de pruebas con JWT en memoria, sin invocar el almacén nativo.
      final client = ApiClient(tokenStore: tokens);
      client.dio.options.baseUrl = '$base/api/v1';
      addTearDown(() => client.dio.close());
      final session = await client.post<Map<String, dynamic>>(
        ApiEndpoints.auth.login,
        data: {
          'email': 'administrador@cu24.test',
          'password': 'OnlyLocal-CU24-123!',
          'client': 'mobile',
        },
      );
      tokens.value = (session!['tokens'] as Map)['access'] as String;
      final me = await client.get<Map<String, dynamic>>(ApiEndpoints.auth.me);
      tokens.tenant = ((me!['user'] as Map)['active_tenant'] as Map)['id']
          .toString();
      final repository = AssetRepository(client);
      final assets = await repository.list();
      expect(assets.items, isNotEmpty);
      final scanned = await repository.scan(
        'TAJI-ASSET.11111111111141118111111111111111',
      );
      expect(scanned.code, 'ACT-11111111');
    expect((await repository.history(scanned.id)).maintenancePlans, isNotEmpty);
      await expectLater(
        repository.scan('TAJI-ASSET.22222222111141118111111111111111'),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'http status', 404),
        ),
      );
      final orders = await MaintenanceOrderRepository(client).listOrders();
      expect(orders.items.any((order) => order.assetName.isNotEmpty), isTrue);
      final incident = await IncidentTrackingRepository(
        client,
      ).detail('INC-CU24-LIVE');
      expect(incident.title, 'Fuga en la bomba');
    },
    skip: base == null
        ? 'Requiere CU24_LIVE_URL y servidor efímero de pruebas.'
        : false,
  );
}
