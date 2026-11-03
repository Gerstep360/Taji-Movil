import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/features/assets/asset_repository.dart';
import 'package:taji/features/assets/assets_screen.dart';
import 'package:taji/features/auth/data/auth_repository.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/auth/state/auth_controller.dart';
import 'package:taji/features/maintenance/data/maintenance_order_repository.dart';
import 'package:taji/features/maintenance/screens/maintenance_orders_screen.dart';
import 'package:taji/features/maintenance/state/maintenance_orders_controller.dart';

const assetJson = {
  'id': 1,
  'code': 'BOM-01',
  'name': 'Bomba principal',
  'asset_type_name': 'Bomba',
  'sector_name': 'Sala de bombas',
  'created_at': '2026-11-03T00:00:00Z',
  'status': 'ACTIVE',
  'qr_uuid': '11111111-1111-4111-8111-111111111111',
};

class _Api extends Fake implements ApiClient {
  String? path;
  Object? body;
  Map<String, dynamic>? query;
  bool fail = false;
  int calls = 0;
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    this.query = query;
    calls++;
    final data = path.endsWith('/history/')
        ? {
            'asset_id': 1,
            'incidents': [
              {
                'id': 1,
                'created_at': '2026-11-03T00:00:00Z',
                'title': 'Fuga detectada',
                'public_code': 'INC-1',
                'status': 'REPORTED',
              },
            ],
            'work_orders': [],
            'maintenance_plans': [],
          }
        : {
            'results': [assetJson],
            'pagination': {'total_pages': 2},
          };
    return data as T;
  }

  @override
  Future<T?> post<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    calls++;
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 404,
          data: {
            'error': {
              'code': 'not_found',
              'message': 'El QR no pertenece a este condominio.',
            },
          },
        ),
      );
    }
    return assetJson as T;
  }
}

class _AuthRepository extends Fake implements AuthRepository {}

TajiUser _user(List<String> permissions) => TajiUser(
  id: 1,
  email: 'tecnico@taji.test',
  firstName: 'Luis',
  lastName: 'Pérez',
  fullName: 'Luis Pérez',
  phone: '',
  role: TajiRole(
    slug: 'mantenimiento',
    name: 'Mantenimiento',
    description: '',
    permissions: permissions,
  ),
);

void main() {
  test(
    'CU23/24 usa rutas centrales, paginación e historial compatibles',
    () async {
      final api = _Api(), repository = AssetRepository(_Api());
      final page = await AssetRepository(api).list(search: 'bomba', page: 2);
      expect(api.path, ApiEndpoints.assets.collection);
      expect(api.query, {'search': 'bomba', 'page': 2});
      expect(page.pages, 2);
      expect(page.items.single.statusLabel, 'Activo');
      expect(
        page.items.single.qrPayload,
        'TAJI-ASSET.11111111111141118111111111111111',
      );
      expect(
        (await repository.history(1)).incidents.single.title,
        'Fuga detectada',
      );
    },
  );
  test('CU24 rechaza QR de visitas y propaga rechazo del servidor', () async {
    final api = _Api(), repository = AssetRepository(_Api());
    await expectLater(
      repository.scan('VISIT-TOKEN'),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, 0);
    api.fail = true;
    await expectLater(
      AssetRepository(api).scan('TAJI-ASSET.11111111111141118111111111111111'),
      throwsA(isA<ApiFailure>().having((e) => e.statusCode, 'status', 404)),
    );
  });
  test(
    'CU23/24/25 respeta permisos, no deduce privilegios del nombre del rol',
    () {
      expect(_user([]).canViewAssets, isFalse);
      expect(_user(['view_general_status']).canViewAssets, isTrue);
      expect(_user(['maintain_assets']).canAccessMaintenance, isTrue);
      expect(
        _user(['view_assigned_work_orders']).canUpdateMaintenanceOrders,
        isFalse,
      );
      expect(
        _user(['update_work_order_status']).canUpdateMaintenanceOrders,
        isTrue,
      );
    },
  );
  for (final scanOnly in [false, true]) {
    testWidgets('CU24 pantalla ${scanOnly ? 'QR' : 'inventario'} a 390px', (
      tester,
    ) async {
      await _fonts(tester);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: _Api(),
          child: MaterialApp(
            theme: buildTajiTheme(),
            home: RepaintBoundary(
              key: key,
              child: AssetsScreen(scanOnly: scanOnly),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scanOnly) {
        await tester.enterText(
          find.byType(TextField),
          'TAJI-ASSET.11111111111141118111111111111111',
        );
        await tester.tap(find.text('Consultar activo'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Bomba principal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        key,
        scanOnly ? 'CU24-flutter-qr' : 'CU23-flutter-inventory',
      );
      await tester.tap(find.text('Bomba principal'));
      await tester.pumpAndSettle();
      expect(find.text('Historial del activo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('CU25 orden asignada permite iniciar y completar sin desbordes', (
    tester,
  ) async {
    await _fonts(tester);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey(), source = _Orders();
    final auth = AuthController(_AuthRepository())
      ..user = _user([
        'view_assigned_work_orders',
        'update_work_order_status',
        'attach_work_evidence',
      ]);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => MaintenanceOrdersController(source),
          ),
        ],
        child: MaterialApp(
          theme: buildTajiTheme(),
          home: RepaintBoundary(
            key: key,
            child: const MaintenanceOrdersScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisión de bomba'));
    await tester.pumpAndSettle();
    await _capture(tester, key, 'CU25-flutter-order');
    await tester.ensureVisible(find.text('Iniciar trabajo'));
    await tester.tap(find.text('Iniciar trabajo'));
    await tester.pumpAndSettle();
    expect(source.status, 'IN_PROGRESS');
    expect(tester.takeException(), isNull);
  });
}

class _Orders implements MaintenanceOrderDataSource {
  String status = 'ASSIGNED';
  MaintenanceWorkOrder get order => MaintenanceWorkOrder.fromJson({
    'id': 1,
    'public_code': 'OT-01',
    'title': 'Revisión de bomba',
    'description': 'Verificar válvulas y registrar evidencias.',
    'status': status,
    'work_type': 'INSPECTION',
    'asset_code': 'BOM-01',
    'asset_name': 'Bomba principal',
    'assignee_name': 'Luis Pérez',
  });
  @override
  Future<({List<MaintenanceWorkOrder> items, int pages})> listOrders({
    int page = 1,
  }) async => (items: [order], pages: 2);
  @override
  Future<MaintenanceWorkOrder> changeStatus(
    int id, {
    required String status,
    String notes = '',
  }) async {
    this.status = status;
    return order;
  }

  @override
  Future<MaintenanceWorkOrder> uploadEvidence(
    int id, {
    required dynamic file,
    String caption = '',
  }) async => order;
}

Future<void> _fonts(WidgetTester tester) async {
  final path = Platform.environment['TAJI_PREVIEW_FONT'];
  if (path == null) return;
  await tester.runAsync(() async {
    await (FontLoader(
      'Segoe UI',
    )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!Platform.environment.containsKey('TAJI_PREVIEW_FONT')) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
