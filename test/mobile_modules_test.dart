import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/features/auth/data/auth_repository.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/auth/state/auth_controller.dart';
import 'package:taji/features/management/module_catalog.dart';
import 'package:taji/features/management/module_repository.dart';
import 'package:taji/features/management/module_screen.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_models.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_repository.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/reports_screen.dart';
import 'cu31_reports_test.dart' show FakeReports, FakeVoice;

const sampleRow = <String, dynamic>{
  'id': 1,
  'name': 'Registro de prueba',
  'title': 'Registro de prueba',
  'code': 'A-01',
  'first_name': 'Luis',
  'last_name': 'Pérez',
  'full_name': 'Registro de prueba',
  'status': 'ACTIVE',
  'staff_type': 'MAINTENANCE',
  'description': 'Detalle del condominio',
  'slug': 'mantenimiento',
  'permissions': [
    {'code': 'maintain_assets', 'name': 'Mantener activos'},
  ],
};

class _Api extends Fake implements ApiClient {
  String? path;
  Object? body;
  Map<String, dynamic>? query;
  int getCount = 0;
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    this.query = query;
    getCount++;
    if (path == '/roles/permissions/') {
      return [
            {
              'code': 'maintain_assets',
              'name': 'Mantener activos',
              'description': 'Registrar mantenimiento',
            },
          ]
          as T;
    }
    if (path == '/roles/') return [sampleRow] as T;
    return {
          'results': [sampleRow],
          'pagination': {'total_pages': 1},
        }
        as T;
  }

  @override
  Future<T?> post<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return {'id': 2, ...data as Map<String, dynamic>} as T;
  }

  @override
  Future<T?> patch<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return {...sampleRow, ...data as Map<String, dynamic>} as T;
  }

  @override
  Future<Uint8List> postBytes(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return Uint8List.fromList('%PDF-1.4 test'.codeUnits);
  }
}

class _AuthRepo extends Fake implements AuthRepository {}

TajiUser testUser({bool admin = true, List<String> permissions = const []}) =>
    TajiUser(
      id: 1,
      email: 'test@taji.test',
      firstName: 'Luis',
      lastName: 'Pérez',
      fullName: 'Luis Pérez',
      phone: '',
      isSuperuser: admin,
      role: TajiRole(
        slug: admin ? 'administrador' : 'residente',
        name: 'Rol de prueba',
        description: '',
        permissions: permissions,
      ),
      activeTenant: const TajiTenant(
        id: 1,
        name: 'Condominio Taji',
        slug: 'taji',
      ),
    );

class _PdfReports extends FakeReports {
  @override
  Future<ReportCatalog> catalog() async {
    final previous = await super.catalog();
    previous.formats.insert(0, 'pdf');
    return previous;
  }
}

void main() {
  test(
    'all formerly pending management modules have a single real contract',
    () {
      expect(mobileModules.keys.toSet(), {
        'condominium',
        'roles',
        'staff',
        'sectors',
        'units',
        'residents',
        'resident-units',
        'audit',
        'areas',
        'reservations',
        'announcements',
        'assemblies',
        'agreements',
      });
      expect(
        mobileModules.values.every(
          (m) => m.endpoint.startsWith('/') && m.endpoint.endsWith('/'),
        ),
        isTrue,
      );
      expect(mobileModules['audit']!.readOnly, isTrue);
    },
  );
  test(
    'permissions stay enforced while community and reports are available',
    () {
      final resident = testUser(admin: false, permissions: ['reserve_areas']);
      expect(canReadModule(resident, mobileModules['roles']!), isFalse);
      expect(canReadModule(resident, mobileModules['audit']!), isFalse);
      expect(canReadModule(resident, mobileModules['reservations']!), isTrue);
      expect(canWriteModule(resident, mobileModules['areas']!), isFalse);
      expect(
        testUser(admin: false, permissions: ['view_reports']).canUseReports,
        isTrue,
      );
    },
  );
  test(
    'native repositories keep pagination and exact backend payloads',
    () async {
      final api = _Api(), repository = ModuleRepository(_Api());
      final source = ModuleRepository(api);
      await source.list(mobileModules['staff']!, page: 2, search: 'Luis');
      expect(api.path, '/staff/');
      expect(api.query, {'page': 2, 'page_size': 25, 'search': 'Luis'});
      await source.save(mobileModules['staff']!, {
        'first_name': 'Luis',
        'staff_type': 'MAINTENANCE',
      });
      expect(api.body, {'first_name': 'Luis', 'staff_type': 'MAINTENANCE'});
      await source.save(mobileModules['roles']!, {
        'permissions': ['maintain_assets'],
      }, original: sampleRow);
      expect(api.path, '/roles/mantenimiento/permissions/');
      expect((await repository.options('sectors')).single['id'], 1);
    },
  );
  test('PDF uses the same server contract and correct MIME type', () async {
    final api = _Api(), source = ReportsRepository(_Api());
    final query = ReportQuery(
      source: 'incidents',
      columns: ['public_code'],
      filters: [],
      ordering: [],
    );
    await ReportsRepository(api).export(query, 'pdf');
    expect(api.path, '/cu31/export/');
    expect((api.body as Map)['format'], 'pdf');
    expect(reportMimeType('pdf'), 'application/pdf');
    expect(
      (await source.export(query, 'pdf')).sublist(0, 5),
      '%PDF-'.codeUnits,
    );
  });
  for (final key in mobileModules.keys) {
    testWidgets('$key native module is usable at phone width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = AuthController(_AuthRepo())..user = testUser();
      addTearDown(auth.dispose);
      final boundary = GlobalKey();
      await fonts(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: _Api()),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: buildTajiTheme(),
              home: ModuleScreen(module: mobileModules[key]!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Registro de prueba'), findsOneWidget);
      if (key == 'staff' || key == 'announcements' || key == 'reservations') {
        await capture(tester, boundary, 'mobile-$key');
      }
      if (!mobileModules[key]!.readOnly) {
        if (!mobileModules[key]!.canCreate) {
          await tester.tap(find.byTooltip('Editar registro'));
        } else {
          await tester.tap(find.text('Nuevo'));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (key == 'staff') {
          await capture(tester, boundary, 'mobile-staff-form');
          await tester.scrollUntilVisible(
            find.text('Guardar cambios'),
            350,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Guardar cambios'));
          await tester.pumpAndSettle();
          expect(find.text('Completa este campo.'), findsWidgets);
          await capture(tester, boundary, 'mobile-staff-form');
        }
      }
    });
  }
  testWidgets('reports exposes PDF as an export choice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await fonts(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTajiTheme(),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ReportsWorkspace(
              repository: _PdfReports(),
              voice: FakeVoice(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generar vista previa'));
    await tester.tap(find.text('Generar vista previa'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Excel (.xlsx)'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Excel (.xlsx)'));
    await tester.pumpAndSettle();
    expect(find.text('PDF (.pdf)'), findsOneWidget);
    await tester.tap(find.text('PDF (.pdf)'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'mobile-report-pdf');
    expect(tester.takeException(), isNull);
  });
}

Future<void> fonts(WidgetTester tester) async {
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

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!Platform.environment.containsKey('TAJI_PREVIEW_FONT')) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
