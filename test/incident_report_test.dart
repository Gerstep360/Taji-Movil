import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/incidents/data/evidence_picker.dart';
import 'package:taji/features/incidents/data/incident_repository.dart';
import 'package:taji/features/incidents/models/incident_report.dart';
import 'package:taji/features/incidents/screens/incident_report_screen.dart';
import 'package:taji/features/incidents/state/incident_report_controller.dart';

/// PNG de 1x1 válido: las miniaturas se decodifican sin errores en el test.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

EvidenceFile photo(String name, {int? size}) => EvidenceFile(
  name: name,
  bytes: size == null ? _png : Uint8List(size),
);

Map<String, dynamic> optionsJson() => {
  'categories': [
    {
      'id': 1,
      'code': 'PLUMBING',
      'name': 'Plomería',
      'description': 'Fugas y cañerías',
      'default_priority': {'code': 'HIGH', 'name': 'Alta'},
    },
    {
      'id': 2,
      'code': 'NOISE',
      'name': 'Ruido',
      'description': '',
      'default_priority': {'code': 'LOW', 'name': 'Baja'},
    },
  ],
  'priorities': [
    {'id': 1, 'code': 'HIGH', 'name': 'Alta', 'rank': 1, 'target_minutes': 60},
  ],
  'sectors': [
    {
      'id': 10,
      'code': 'TA',
      'name': 'Torre A',
      'sector_type': 'TOWER',
      'parent': null,
    },
    {
      'id': 11,
      'code': 'PQ',
      'name': 'Parqueo',
      'sector_type': 'AREA',
      'parent': null,
    },
  ],
  'units': [
    {'id': 100, 'code': 'A-101', 'unit_type': 'APARTMENT', 'sector': 10},
    {'id': 101, 'code': 'A-102', 'unit_type': 'APARTMENT', 'sector': 10},
    {'id': 200, 'code': 'P-01', 'unit_type': 'PARKING', 'sector': 11},
  ],
  'assets': [
    {'id': 5, 'code': 'BOMBA-1', 'name': 'Bomba de agua', 'sector': 10},
    {'id': 6, 'code': 'PORTON', 'name': 'Portón', 'sector': 11},
  ],
  'evidence_rules': {
    'field_name': 'evidences',
    'max_files': 5,
    'max_file_size_bytes': 5242880,
    'allowed_extensions': ['jpeg', 'jpg', 'pdf', 'png', 'webp'],
    'allowed_mime_types': [
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    ],
  },
};

Map<String, dynamic> createdJson() => {
  'id': 33,
  'public_code': 'INC-2026-0033',
  'status': 'REPORTED',
  'status_display': 'Reportada',
  'title': '',
  'description': 'Hay una fuga de agua en el pasillo',
  'category': {'id': 1, 'code': 'PLUMBING', 'name': 'Plomería'},
  'priority': {'id': 1, 'code': 'HIGH', 'name': 'Alta', 'rank': 1},
  'sector': {'id': 10, 'code': 'TA', 'name': 'Torre A'},
  'unit': {'id': 100, 'code': 'A-101'},
  'asset': null,
  'reporter': {'id': 7, 'full_name': 'Ana Rojas'},
  'evidences': [
    {
      'id': 1,
      'file_type': 'image/png',
      'file_name': 'fuga.png',
      'created_at': '2026-10-26T10:00:00Z',
    },
  ],
  'created_at': '2026-10-26T10:00:00Z',
  'updated_at': '2026-10-26T10:00:00Z',
  'condominium': 1,
};

DioException httpError(int status, Object data) {
  final request = RequestOptions(path: ApiEndpoints.incidents.collection);
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: data),
  );
}

class _FakeApi implements ApiClient {
  Object? response;
  DioException? failure;
  String? path;
  Object? body;

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    if (failure != null) throw failure!;
    return response as T?;
  }

  @override
  Future<T?> post<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    if (failure != null) throw failure!;
    return response as T?;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIncidents implements IncidentDataSource {
  IncidentOptions catalog = IncidentOptions.fromJson(optionsJson());
  Object? optionsFailure;
  Object? failure;
  Completer<ReportedIncident>? pending;
  IncidentDraft? last;
  int reports = 0;

  @override
  Future<IncidentOptions> options() async {
    if (optionsFailure != null) throw optionsFailure!;
    return catalog;
  }

  @override
  Future<ReportedIncident> report(IncidentDraft draft) async {
    reports++;
    last = draft;
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return ReportedIncident.fromJson(createdJson());
  }
}

class _FakePicker implements EvidencePicker {
  EvidenceFile? camera;
  List<EvidenceFile> gallery = [];
  bool cameraAllowed = true;
  int cameraCalls = 0;
  int? lastLimit;

  @override
  Future<bool> ensureCameraPermission(BuildContext context) async =>
      cameraAllowed;

  @override
  Future<EvidenceFile?> takePhoto() async {
    cameraCalls++;
    return camera;
  }

  @override
  Future<List<EvidenceFile>> pickFromGallery({required int limit}) async {
    lastLimit = limit;
    return gallery.take(limit).toList();
  }
}

TajiUser userWith(String slug, List<String> permissions) => TajiUser(
  id: 1,
  email: '$slug@taji.test',
  firstName: 'Ana',
  lastName: 'Rojas',
  fullName: 'Ana Rojas',
  phone: '',
  role: TajiRole(
    slug: slug,
    name: slug,
    description: '',
    permissions: permissions,
  ),
);

void main() {
  group('CU18 acceso y endpoints', () {
    test('centraliza los endpoints de incidencias', () {
      expect(ApiEndpoints.incidents.collection, '/incidents/');
      expect(ApiEndpoints.incidents.options, '/incidents/options/');
    });

    test('solo roles con report_incidents o manage_incidents reportan', () {
      expect(userWith('residente', ['report_incidents']).canReportIncidents, isTrue);
      expect(userWith('administrador', ['manage_incidents']).canReportIncidents, isTrue);
      expect(userWith('seguridad', ['validate_visits']).canReportIncidents, isFalse);
      expect(userWith('seguridad', ['report_incidents']).canReportIncidents, isTrue);
      // Sesiones antiguas sin lista de permisos: se usa el rol como respaldo.
      expect(userWith('residente', []).canReportIncidents, isTrue);
      expect(userWith('seguridad', []).canReportIncidents, isFalse);
    });
  });

  group('CU18 repositorio', () {
    test('lee el catálogo de opciones y las reglas de evidencia', () async {
      final api = _FakeApi()..response = optionsJson();
      final options = await IncidentRepository(api).options();

      expect(api.path, ApiEndpoints.incidents.options);
      expect(options.categories.map((c) => c.name), ['Plomería', 'Ruido']);
      expect(options.categories.first.defaultPriorityName, 'Alta');
      expect(options.sectors.firstWhere((s) => s.id == 11).name, 'Parqueo');
      expect(options.unitsForSector(10).map((u) => u.code), ['A-101', 'A-102']);
      expect(options.assetsForSector(11).single.name, 'Portón');
      expect(options.evidenceRules.maxFiles, 5);
      expect(options.evidenceRules.maxFileSizeBytes, 5242880);
      expect(options.evidenceRules.allowedExtensions, contains('webp'));
    });

    test('envía multipart sin prioridad ni datos del servidor', () async {
      final api = _FakeApi()..response = createdJson();
      final created = await IncidentRepository(api).report(
        IncidentDraft(
          description: '  Hay una fuga de agua en el pasillo  ',
          title: ' Fuga ',
          categoryId: 1,
          sectorId: 10,
          unitId: 100,
          evidences: [photo('fuga.png'), photo('pasillo.jpg')],
        ),
      );

      expect(api.path, ApiEndpoints.incidents.collection);
      expect(api.body, isA<FormData>());
      final form = api.body! as FormData;
      expect(Map.fromEntries(form.fields), {
        'description': 'Hay una fuga de agua en el pasillo',
        'title': 'Fuga',
        'category': '1',
        'sector': '10',
        'unit': '100',
      });
      final keys = form.fields.map((f) => f.key).toSet();
      for (final forbidden in ['priority', 'reporter', 'condominium', 'status', 'asset']) {
        expect(keys, isNot(contains(forbidden)));
      }
      expect(form.files.map((f) => f.key), ['evidences', 'evidences']);
      expect(form.files.map((f) => f.value.filename), ['fuga.png', 'pasillo.jpg']);
      expect(form.files.first.value.contentType.toString(), 'image/png');
      expect(form.files.last.value.contentType.toString(), 'image/jpeg');

      expect(created.id, 33);
      expect(created.publicCode, 'INC-2026-0033');
      expect(created.status, 'REPORTED');
      expect(created.statusDisplay, 'Reportada');
      expect(created.categoryName, 'Plomería');
      expect(created.priorityName, 'Alta');
      expect(created.sectorName, 'Torre A');
      expect(created.unitCode, 'A-101');
      expect(created.evidenceCount, 1);
    });

    test('omite título vacío y envía activo cuando se elige', () async {
      final api = _FakeApi()..response = createdJson();
      await IncidentRepository(api).report(
        const IncidentDraft(
          description: 'Portón no cierra',
          categoryId: 2,
          sectorId: 11,
          assetId: 6,
        ),
      );
      final form = api.body! as FormData;
      expect(Map.fromEntries(form.fields), {
        'description': 'Portón no cierra',
        'category': '2',
        'sector': '11',
        'asset': '6',
      });
      expect(form.files, isEmpty);
    });

    test('traduce 400, 403 y 503 a ApiFailure', () async {
      final api = _FakeApi();
      final repository = IncidentRepository(api);
      const draft = IncidentDraft(description: 'x', categoryId: 1, sectorId: 10);

      api.failure = httpError(400, {
        'error': {
          'code': 'validation_error',
          'message': 'Revisa los datos.',
          'fields': {
            'sector': ['El sector no pertenece al condominio.'],
          },
        },
      });
      await expectLater(
        repository.report(draft),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.statusCode, 'status', 400)
              .having((f) => f.fields['sector'], 'sector', [
                'El sector no pertenece al condominio.',
              ]),
        ),
      );

      api.failure = httpError(403, {
        'error': {'code': 'permission_denied', 'message': 'Sin permiso.'},
      });
      await expectLater(
        repository.report(draft),
        throwsA(isA<ApiFailure>().having((f) => f.statusCode, 'status', 403)),
      );

      api.failure = httpError(503, {
        'error': {
          'code': 'service_unavailable',
          'message': 'Servicio no disponible.',
          'trace_id': 'abc123',
        },
      });
      await expectLater(
        repository.report(draft),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.statusCode, 'status', 503)
              .having((f) => f.traceId, 'trace', 'abc123'),
        ),
      );
    });

    test('rechaza una respuesta 201 incompleta', () async {
      final api = _FakeApi()..response = {'id': 1};
      await expectLater(
        IncidentRepository(api).report(
          const IncidentDraft(description: 'x', categoryId: 1, sectorId: 10),
        ),
        throwsA(isA<ApiFailure>().having((f) => f.code, 'code', 'invalid_response')),
      );
    });
  });

  group('CU18 controlador', () {
    late _FakeIncidents source;
    late IncidentReportController controller;

    setUp(() async {
      source = _FakeIncidents();
      controller = IncidentReportController(source);
      await controller.loadOptions();
    });
    tearDown(() => controller.dispose());

    test('valida descripción, categoría y ubicación sin llamar al servidor', () async {
      expect(await controller.submit(description: '   '), isFalse);
      expect(source.reports, 0);
      expect(controller.fieldErrors['description'], isNotNull);
      expect(controller.fieldErrors['category'], isNotNull);
      expect(controller.fieldErrors['sector'], isNotNull);

      controller
        ..selectCategory(1)
        ..selectSector(10);
      expect(await controller.submit(description: 'a' * 5001), isFalse);
      expect(controller.fieldErrors['description'], contains('5000'));
      expect(
        await controller.submit(description: 'Fuga', title: 't' * 161),
        isFalse,
      );
      expect(controller.fieldErrors['title'], contains('160'));
      expect(source.reports, 0);
    });

    test('filtra unidades y activos por sector y limpia selecciones ajenas', () {
      controller.selectSector(10);
      expect(controller.availableUnits.map((u) => u.id), [100, 101]);
      expect(controller.availableAssets.map((a) => a.id), [5]);
      controller
        ..selectUnit(100)
        ..selectAsset(5)
        ..selectSector(11);
      expect(controller.unitId, isNull);
      expect(controller.assetId, isNull);
      expect(controller.availableUnits.map((u) => u.id), [200]);
    });

    test('aplica las reglas de evidencia del servidor', () {
      controller.addEvidences([photo('a.png'), photo('b.gif')]);
      expect(controller.evidences.map((e) => e.name), ['a.png']);
      expect(controller.evidenceError, contains('b.gif'));

      controller.addEvidences([photo('big.jpg', size: 5242881)]);
      expect(controller.evidences, hasLength(1));
      expect(controller.evidenceError, contains('5 MB'));

      controller.addEvidences(List.generate(6, (i) => photo('f$i.jpg')));
      expect(controller.evidences, hasLength(5));
      expect(controller.evidenceError, contains('5'));
      expect(controller.remainingEvidenceSlots, 0);

      controller.removeEvidence(0);
      expect(controller.evidences, hasLength(4));
      expect(controller.evidences.first.name, 'f0.jpg');
    });

    test('registra, expone estado de carga y evita doble envío', () async {
      source.pending = Completer<ReportedIncident>();
      controller
        ..selectCategory(1)
        ..selectSector(10)
        ..selectUnit(100)
        ..addEvidences([photo('fuga.png')]);

      final first = controller.submit(description: ' Fuga en el pasillo ');
      expect(controller.submitting, isTrue);
      expect(await controller.submit(description: 'Otra vez'), isFalse);

      source.pending!.complete(ReportedIncident.fromJson(createdJson()));
      expect(await first, isTrue);
      expect(source.reports, 1);
      expect(controller.submitting, isFalse);
      expect(controller.created?.publicCode, 'INC-2026-0033');
      expect(source.last?.description, 'Fuga en el pasillo');
      expect(source.last?.unitId, 100);
      expect(source.last?.evidences.single.name, 'fuga.png');

      controller.startNew();
      expect(controller.created, isNull);
      expect(controller.evidences, isEmpty);
      expect(controller.categoryId, isNull);
    });

    test('conserva el formulario y muestra errores de campo del servidor', () async {
      source.failure = ApiFailure(
        code: 'validation_error',
        message: 'Revisa los datos.',
        statusCode: 400,
        fields: const {
          'category': ['La categoría no está activa.'],
        },
      );
      controller
        ..selectCategory(2)
        ..selectSector(10)
        ..addEvidences([photo('a.png')]);

      expect(await controller.submit(description: 'Ruido'), isFalse);
      expect(controller.created, isNull);
      expect(controller.fieldErrors['category'], 'La categoría no está activa.');
      expect(controller.error, isNotNull);
      expect(controller.evidences, hasLength(1));
      expect(controller.categoryId, 2);
    });

    test('mensajes claros para 403, 401 y 503', () async {
      controller
        ..selectCategory(1)
        ..selectSector(10);

      source.failure = const ApiFailure(
        code: 'permission_denied',
        message: 'You do not have permission.',
        statusCode: 403,
      );
      await controller.submit(description: 'Fuga');
      expect(controller.error, contains('No tienes permiso'));

      source.failure = const ApiFailure(
        code: 'not_authenticated',
        message: 'x',
        statusCode: 401,
      );
      await controller.submit(description: 'Fuga');
      expect(controller.error, contains('sesión'));

      source.failure = const ApiFailure(
        code: 'service_unavailable',
        message: 'Servicio no disponible.',
        statusCode: 503,
        traceId: 'abc123',
      );
      await controller.submit(description: 'Fuga');
      expect(controller.error, contains('no está disponible'));
      expect(controller.error, contains('abc123'));
      expect(controller.created, isNull);
    });

    test('reporta el fallo al cargar opciones', () async {
      final failing = _FakeIncidents()
        ..optionsFailure = const ApiFailure(
          code: 'permission_denied',
          message: 'x',
          statusCode: 403,
        );
      final other = IncidentReportController(failing);
      addTearDown(other.dispose);
      await other.loadOptions();
      expect(other.options, isNull);
      expect(other.optionsError, contains('No tienes permiso'));
    });
  });

  group('CU18 pantalla', () {
    late _FakeIncidents source;
    late _FakePicker picker;

    setUp(() {
      source = _FakeIncidents();
      picker = _FakePicker();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      // La fuente de pruebas mide cada glifo como un cuadrado: a 390 px el
      // texto del botón compartido no cabe, aunque sí en un teléfono real.
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTajiTheme(),
          home: IncidentReportScreen(source: source, picker: picker),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String key, String label) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('incident-description')),
        'Hay una fuga de agua en el pasillo',
      );
      await choose(tester, 'incident-category', 'Plomería');
      await choose(tester, 'incident-sector', 'Torre A');
    }

    Future<void> tapSubmit(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('incident-submit')));
      await tester.tap(find.byKey(const Key('incident-submit')));
      await tester.pump();
    }

    testWidgets('muestra el formulario en lenguaje sencillo', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Nueva incidencia'), findsOneWidget);
      expect(find.text('Describe con tus palabras qué pasó'), findsOneWidget);
      expect(find.byKey(const Key('incident-category')), findsOneWidget);
      expect(find.byKey(const Key('incident-sector')), findsOneWidget);
      expect(find.byKey(const Key('incident-unit')), findsOneWidget);
      expect(find.byKey(const Key('incident-asset')), findsOneWidget);
      expect(find.byKey(const Key('incident-take-photo')), findsOneWidget);
      expect(find.byKey(const Key('incident-pick-gallery')), findsOneWidget);
      expect(find.text('Registrar incidencia'), findsOneWidget);
      expect(find.text('0 de 5 archivos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('valida campos obligatorios antes de enviar', (tester) async {
      await pumpScreen(tester);
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Cuéntanos qué pasó.'), findsOneWidget);
      expect(find.text('Elige una categoría.'), findsOneWidget);
      expect(find.text('Indica dónde ocurrió.'), findsOneWidget);
      expect(source.reports, 0);
    });

    testWidgets('selecciona categoría y muestra su prioridad sugerida', (tester) async {
      await pumpScreen(tester);
      await choose(tester, 'incident-category', 'Plomería');

      expect(find.text('Fugas y cañerías'), findsOneWidget);
      expect(find.textContaining('Alta'), findsOneWidget);
    });

    testWidgets('cámara y galería agregan vistas previas que se pueden quitar', (
      tester,
    ) async {
      picker
        ..camera = photo('camara.jpg')
        ..gallery = [photo('g1.png'), photo('g2.webp')];
      await pumpScreen(tester);

      await tester.ensureVisible(find.byKey(const Key('incident-take-photo')));
      await tester.tap(find.byKey(const Key('incident-take-photo')));
      await tester.pumpAndSettle();
      expect(picker.cameraCalls, 1);
      expect(find.byKey(const Key('incident-evidence-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('incident-pick-gallery')));
      await tester.pumpAndSettle();
      expect(picker.lastLimit, 4);
      expect(find.byKey(const Key('incident-evidence-2')), findsOneWidget);
      expect(find.text('3 de 5 archivos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('incident-evidence-remove-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('incident-evidence-2')), findsNothing);
      expect(find.text('2 de 5 archivos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin permiso de cámara no abre la cámara', (tester) async {
      picker
        ..cameraAllowed = false
        ..camera = photo('camara.jpg');
      await pumpScreen(tester);
      await tester.ensureVisible(find.byKey(const Key('incident-take-photo')));
      await tester.tap(find.byKey(const Key('incident-take-photo')));
      await tester.pumpAndSettle();

      expect(picker.cameraCalls, 0);
      expect(find.byKey(const Key('incident-evidence-0')), findsNothing);
    });

    testWidgets('muestra carga, bloquea doble envío y confirma con el código', (
      tester,
    ) async {
      source.pending = Completer<ReportedIncident>();
      await pumpScreen(tester);
      await fillValidForm(tester);

      await tapSubmit(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('incident-submit')));
      await tester.pump();
      expect(source.reports, 1);

      source.pending!.complete(ReportedIncident.fromJson(createdJson()));
      await tester.pumpAndSettle();

      expect(find.text('Incidencia registrada'), findsOneWidget);
      expect(find.text('INC-2026-0033'), findsOneWidget);
      expect(find.text('Reportada'), findsOneWidget);
      expect(source.last?.categoryId, 1);
      expect(source.last?.sectorId, 10);

      await tester.tap(find.text('Registrar otra incidencia'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('incident-description')), findsOneWidget);
    });

    testWidgets('un 403 muestra un mensaje claro y conserva lo escrito', (
      tester,
    ) async {
      source.failure = const ApiFailure(
        code: 'permission_denied',
        message: 'Forbidden',
        statusCode: 403,
      );
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('No tienes permiso'), findsOneWidget);
      expect(find.text('Hay una fuga de agua en el pasillo'), findsOneWidget);
      expect(find.text('Incidencia registrada'), findsNothing);
    });

    testWidgets('si no cargan las opciones permite reintentar', (tester) async {
      source.optionsFailure = const ApiFailure(
        code: 'network_unavailable',
        message: 'No pudimos conectar con Taji.',
      );
      await pumpScreen(tester);
      expect(find.text('No pudimos conectar con Taji.'), findsOneWidget);

      source.optionsFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('incident-description')), findsOneWidget);
    });
  });
}
