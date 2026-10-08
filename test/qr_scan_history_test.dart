import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/features/visitors/data/qr_scan_history_repository.dart';
import 'package:taji/features/visitors/models/qr_scan_history.dart';
import 'package:taji/features/visitors/screens/qr_scan_history_screen.dart';
import 'package:taji/features/visitors/state/qr_scan_history_controller.dart';

/// Fila de la bitácora tal como la devuelve el backend.
Map<String, dynamic> _scanJson({
  int id = 1,
  String result = 'VALID',
  String reason = 'VALID',
  String visitor = 'Ana Torres',
  String occurredAt = '2026-10-03T15:00:00Z',
}) => {
  'id': id,
  'result': result,
  'result_display': switch (result) {
    'VALID' => 'Válido',
    'REJECTED' => 'Denegado',
    _ => 'Código desconocido',
  },
  'reason': reason,
  'message': 'Autorización de visita vigente. Ingreso permitido.',
  'occurred_at': occurredAt,
  'authorization_id': 5,
  'visitor_name': visitor,
  'visitor_document_number': '8800001',
  'unit_code': 'A-101',
  'guard_staff': {
    'id': 3,
    'employee_code': 'G-01',
    'staff_type': 'SECURITY',
    'status': 'ACTIVE',
    'full_name': 'Luis Roca',
  },
  'device_id': 'android',
  'notes': '',
};

/// El sobre de `visit-qr/scans/` es `{count, page, page_size, total_pages,
/// summary, results}`, distinto del `{results, pagination}` de CU12.
Map<String, dynamic> _pageJson({
  int count = 2,
  int page = 1,
  int totalPages = 1,
  List<Map<String, dynamic>>? rows,
}) => {
  'count': count,
  'page': page,
  'page_size': 20,
  'total_pages': totalPages,
  'summary': {
    'total': count,
    'approved': 1,
    'rejected': 1,
    'not_found': 0,
    'failed': 1,
    'success_rate': 50.0,
  },
  'results': rows ??
      [
        _scanJson(),
        _scanJson(
          id: 2,
          result: 'REJECTED',
          reason: 'VISIT_CANCELLED',
          visitor: 'Luis Paz',
        ),
      ],
};

class _FakeScanHistoryRepository implements QrScanHistoryDataSource {
  _FakeScanHistoryRepository({this.throwOn, this.empty = false});

  Object? throwOn;

  /// Devuelve la bitácora sin ninguna fila, para probar los estados vacíos.
  final bool empty;
  int historyCalls = 0;
  final List<Map<String, dynamic>> lastQueries = [];

  @override
  Future<QrScanHistoryPage> history(QrScanFilters filters) async {
    historyCalls++;
    lastQueries.add(filters.toQuery());
    final error = throwOn;
    if (error != null) throw error;

    if (empty) {
      return QrScanHistoryPage.fromJson(
        _pageJson(count: 0, rows: const <Map<String, dynamic>>[]),
      );
    }
    return QrScanHistoryPage.fromJson(_pageJson());
  }

  @override
  Future<List<QrScanGuardOption>> guards() async => const [
        QrScanGuardOption(id: 3, fullName: 'Luis Roca'),
      ];
}

QrScanHistoryController _controller(_FakeScanHistoryRepository repository) =>
    QrScanHistoryController(repository);

void main() {
  group('QrScanHistoryPage.fromJson', () {
    test('mapea el sobre de la bitácora con sus totales', () {
      final page = QrScanHistoryPage.fromJson(_pageJson());

      expect(page.count, 2);
      expect(page.page, 1);
      expect(page.entries, hasLength(2));
      expect(page.summary.approved, 1);
      expect(page.summary.rejected, 1);
      expect(page.summary.failed, 1);
      expect(page.summary.successRate, 50.0);
    });

    test('distingue QR denegado de QR no registrado', () {
      final page = QrScanHistoryPage.fromJson(
        _pageJson(
          rows: [
            _scanJson(result: 'NOT_FOUND', reason: 'NOT_FOUND', visitor: ''),
          ],
        ),
      );

      final entry = page.entries.single;
      expect(entry.result, QrScanResult.notFound);
      expect(entry.approved, isFalse);
      expect(entry.reasonLabel, 'QR no registrado');
    });

    test('traduce los motivos a texto legible', () {
      final page = QrScanHistoryPage.fromJson(
        _pageJson(
          rows: [
            _scanJson(result: 'REJECTED', reason: 'VISIT_CANCELLED'),
          ],
        ),
      );

      expect(page.entries.single.reasonLabel, 'Visita cancelada');
    });

    test('cae a un motivo sin traducir en lugar de romperse', () {
      expect(scanReasonLabel('CODE_NUEVO'), 'CODE_NUEVO');
    });

    test('sobrevive a una respuesta con campos ausentes', () {
      final page = QrScanHistoryPage.fromJson(const {
        'results': <dynamic>[],
      });

      expect(page.entries, isEmpty);
      expect(page.totalPages, 1);
      expect(page.summary.total, 0);
    });
  });

  group('QrScanFilters', () {
    test('no manda filtros vacíos al backend', () {
      const filters = QrScanFilters();

      expect(filters.toQuery(), {'days': 7, 'page': 1, 'page_size': 20});
    });

    test('recorta el texto de búsqueda antes de enviarlo', () {
      const filters = QrScanFilters(search: '  Ana  ');

      expect(filters.toQuery()['search'], 'Ana');
    });

    test('paginar no borra el resto de filtros', () {
      const filters = QrScanFilters(
        result: QrScanResult.notFound,
        days: 30,
        page: 1,
      );

      final next = filters.copyWith(page: 3);

      expect(next.page, 3);
      expect(next.result, QrScanResult.notFound);
      expect(next.days, 30);
    });
  });

  group('QrScanHistoryController', () {
    test('carga el historial y expone los totales', () async {
      final repository = _FakeScanHistoryRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.entries, hasLength(2));
      expect(controller.summary.approved, 1);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('muestra el error sin dejar la pantalla en cargando', () async {
      final controller = _controller(
        _FakeScanHistoryRepository(throwOn: const ApiFailure(code: 'x', message: 'sin red')),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.error, 'sin red');
      expect(controller.loading, isFalse);
      expect(controller.entries, isEmpty);
    });

    test('aplicar filtros vuelve a la primera página', () async {
      final repository = _FakeScanHistoryRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.applyFilters(result: QrScanResult.valid, days: 30);

      expect(repository.lastQueries.last['result'], 'VALID');
      expect(repository.lastQueries.last['days'], 30);
      expect(repository.lastQueries.last['page'], 1);
    });

    test('ignora una respuesta que llega tarde', () async {
      final controller = _controller(_FakeScanHistoryRepository());
      addTearDown(controller.dispose);

      // Dos cargas encadenadas: la segunda debe mandar sobre la primera.
      await Future.wait([controller.load(), controller.load()]);

      expect(controller.entries, isNotEmpty);
      expect(controller.loading, isFalse);
    });

    test('limpiar filtros vuelve a la ventana por defecto', () async {
      final repository = _FakeScanHistoryRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.applyFilters(result: QrScanResult.valid, days: 30);
      await controller.clearFilters();

      expect(repository.lastQueries.last['days'], 7);
      expect(repository.lastQueries.last.containsKey('result'), isFalse);
    });

    test('un fallo al cargar guardias no rompe la pantalla', () async {
      final repository = _FakeScanHistoryRepository();
      final controller = QrScanHistoryController(
        _ThrowingGuardsRepository(repository),
      );
      addTearDown(controller.dispose);

      await controller.loadGuards();

      expect(controller.guards, isEmpty);
      expect(controller.loading, isFalse);
    });
  });

  group('QrScanHistoryScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      QrScanHistoryDataSource repository,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTajiTheme(),
          home: Provider<QrScanHistoryDataSource>.value(
            value: repository,
            child: const QrScanHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra los totales y los escaneos registrados', (tester) async {
      await pumpScreen(tester, _FakeScanHistoryRepository());

      expect(find.text('Bitácora de escaneos'), findsOneWidget);
      // Totales de la ventana.
      expect(find.text('Escaneos'), findsOneWidget);
      expect(find.text('Autorizados'), findsOneWidget);
      expect(find.text('Fallidos'), findsOneWidget);
      // Filas.
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('Luis Paz'), findsOneWidget);
      // El motivo llega traducido, no como codigo.
      expect(find.text('Visita cancelada'), findsOneWidget);
    });

    testWidgets('el estado vacío distingue "sin datos" de "sin coincidencias"', (
      tester,
    ) async {
      await pumpScreen(tester, _FakeScanHistoryRepository(empty: true));

      // Sin filtros: la bitácora está simplemente vacía.
      expect(
        find.text('Todavía no se ha escaneado ningún código QR.'),
        findsOneWidget,
      );

      // Con un filtro aplicado: el mensaje debe explicar que fue la búsqueda.
      await tester.enterText(find.byType(TextField), 'nadie');
      await tester.tap(find.text('Filtrar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No hay escaneos que coincidan con los filtros aplicados.'),
        findsOneWidget,
      );
    });

    testWidgets('un error de red se muestra sin romper la pantalla', (tester) async {
      await pumpScreen(
        tester,
        _FakeScanHistoryRepository(
          throwOn: const ApiFailure(code: 'x', message: 'Sin conexión con el servidor'),
        ),
      );

      expect(find.text('Sin conexión con el servidor'), findsOneWidget);
      expect(find.text('Bitácora de escaneos'), findsOneWidget);
    });
  });
}

/// Repositorio que falla solo al pedir la lista de guardias.
class _ThrowingGuardsRepository implements QrScanHistoryDataSource {
  _ThrowingGuardsRepository(this._inner);

  final QrScanHistoryDataSource _inner;

  @override
  Future<QrScanHistoryPage> history(QrScanFilters filters) => _inner.history(filters);

  @override
  Future<List<QrScanGuardOption>> guards() async =>
      throw const ApiFailure(code: 'x', message: 'sin permiso');
}
