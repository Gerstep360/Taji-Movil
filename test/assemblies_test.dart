import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/features/assemblies/data/assemblies_repository.dart';
import 'package:taji/features/assemblies/models/assembly_models.dart';
import 'package:taji/features/assemblies/screens/assemblies_screen.dart';
import 'package:taji/features/assemblies/state/assemblies_controller.dart';

Map<String, dynamic> _assembly({
  int id = 1,
  String title = 'Asamblea general',
  String status = 'FINISHED',
  bool full = true,
}) => {
  'id': id,
  'title': title,
  'description': 'Presupuesto anual',
  'scheduled_at': '2026-12-05T22:30:00Z',
  'location': 'Salón comunal',
  'status': status,
  'status_display': status == 'FINISHED' ? 'Finalizada' : 'Programada',
  if (full) ...{
    'minutes_text': 'Se aprobó el presupuesto.',
    'created_by_name': 'Ana Admin',
    'agreements_count': 2,
    'open_agreements_count': 1,
  },
};

Map<String, dynamic> _agreement({
  int id = 10,
  String status = 'IN_PROGRESS',
  bool overdue = false,
  String? actualCost,
}) => {
  'id': id,
  'assembly': 1,
  'assembly_title': 'Asamblea general',
  'title': 'Reparar portón',
  'description': 'Cambiar motor',
  'responsible_user': 4,
  'responsible_name': 'Dario Directiva',
  'due_at': '2026-12-20T16:00:00Z',
  'estimated_budget': '1500.50',
  'actual_cost': actualCost,
  'status': status,
  'status_display': status == 'OVERDUE' ? 'Vencido' : 'En curso',
  'is_overdue': overdue,
  'completed_at': null,
  'attachments_count': 1,
};

class _FakeApi implements ApiClient {
  Object? listResponse;
  Object? agreementsResponse;
  DioException? failure;
  final calls = <String>[];
  Map<String, dynamic>? lastQuery;

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    lastQuery = query;
    if (failure != null) throw failure!;
    return (path.endsWith('/agreements/') ? agreementsResponse : listResponse)
        as T?;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _page(List<Map<String, dynamic>> rows, {int pages = 1}) => {
  'pagination': {
    'page': 1,
    'page_size': 20,
    'total_items': rows.length,
    'total_pages': pages,
  },
  'results': rows,
};

void main() {
  group('modelos', () {
    test('la vista de administración trae acta y contadores', () {
      final item = AssemblyItem.fromJson(_assembly());
      expect(item.hasFullAccess, isTrue);
      expect(item.minutesText, 'Se aprobó el presupuesto.');
      expect(item.agreementsCount, 2);
      expect(item.openAgreementsCount, 1);
    });

    test('la vista de residente no trae acta y se reconoce como reducida', () {
      final item = AssemblyItem.fromJson(
        _assembly(status: 'SCHEDULED', full: false),
      );
      expect(item.hasFullAccess, isFalse);
      expect(item.minutesText, isNull);
      expect(item.agreementsCount, 0);
    });

    test('un acuerdo conserva responsable, importes y vencimiento', () {
      final item = AgreementItem.fromJson(
        _agreement(status: 'OVERDUE', overdue: true, actualCost: '90.00'),
      );
      expect(item.responsibleName, 'Dario Directiva');
      expect(item.estimatedBudget, '1500.50');
      expect(item.actualCost, '90.00');
      expect(item.isOverdue, isTrue);
      expect(item.dueAt, isNotNull);
    });
  });

  group('repositorio y controladores', () {
    test('lista asambleas con filtro de estado y paginación', () async {
      final api = _FakeApi()
        ..listResponse = _page([_assembly(), _assembly(id: 2)], pages: 3);
      final controller = AssembliesController(AssembliesRepository(api));

      await controller.load(selectedStatus: 'FINISHED');

      expect(api.calls.single, '/assemblies/');
      expect(api.lastQuery, {'page': 1, 'status': 'FINISHED'});
      expect(controller.items.map((item) => item.id), [1, 2]);
      expect(controller.pages, 3);
      expect(controller.error, isNull);
      expect(controller.loading, isFalse);
      controller.dispose();
    });

    test('sin filtro no manda el parámetro status', () async {
      final api = _FakeApi()..listResponse = _page([_assembly()]);
      final controller = AssembliesController(AssembliesRepository(api));
      await controller.load();
      expect(api.lastQuery, {'page': 1});
      controller.dispose();
    });

    test('un residente no puede filtrar y la lista queda reducida', () async {
      final api = _FakeApi()
        ..listResponse = _page([_assembly(status: 'SCHEDULED', full: false)]);
      final controller = AssembliesController(AssembliesRepository(api));
      await controller.load();
      expect(controller.canFilter, isFalse);
      controller.dispose();
    });

    test('un error del backend se muestra sin lanzar', () async {
      final api = _FakeApi()
        ..failure = DioException(
          requestOptions: RequestOptions(path: '/assemblies/'),
          type: DioExceptionType.connectionError,
        );
      final controller = AssembliesController(AssembliesRepository(api));
      await controller.load();
      expect(controller.items, isEmpty);
      expect(controller.error, isNotNull);
      controller.dispose();
    });

    test('el detalle carga los acuerdos solo con acceso completo', () async {
      final api = _FakeApi()
        ..agreementsResponse = [_agreement(), _agreement(id: 11)];
      final full = AssemblyDetailController(
        AssembliesRepository(api),
        AssemblyItem.fromJson(_assembly()),
      );
      await full.load();
      expect(api.calls.single, '/assemblies/1/agreements/');
      expect(full.agreements.length, 2);

      final reduced = AssemblyDetailController(
        AssembliesRepository(api),
        AssemblyItem.fromJson(_assembly(status: 'SCHEDULED', full: false)),
      );
      await reduced.load();
      expect(api.calls.length, 1, reason: 'el residente no consulta acuerdos');
      expect(reduced.agreements, isEmpty);
      full.dispose();
      reduced.dispose();
    });
  });

  group('pantalla', () {
    testWidgets('muestra la lista y abre el detalle con sus acuerdos', (
      tester,
    ) async {
      final api = _FakeApi()
        ..listResponse = _page([_assembly()])
        ..agreementsResponse = [_agreement()];
      await tester.pumpWidget(
        MaterialApp(home: AssembliesScreen(repository: AssembliesRepository(api))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asamblea general'), findsOneWidget);
      expect(find.text('Finalizada'), findsOneWidget);
      expect(find.text('1 acuerdos abiertos de 2'), findsOneWidget);

      await tester.tap(find.text('Asamblea general'));
      await tester.pumpAndSettle();

      expect(find.text('Se aprobó el presupuesto.'), findsOneWidget);
      expect(find.text('Reparar portón'), findsOneWidget);
      expect(find.text('Responsable: Dario Directiva'), findsOneWidget);
      expect(find.text('Presupuesto: 1500.50'), findsOneWidget);
      expect(find.text('Costo real: —'), findsOneWidget);
    });

    testWidgets('sin asambleas muestra un mensaje vacío', (tester) async {
      final api = _FakeApi()..listResponse = _page([]);
      await tester.pumpWidget(
        MaterialApp(home: AssembliesScreen(repository: AssembliesRepository(api))),
      );
      await tester.pumpAndSettle();
      expect(find.text('No hay asambleas para mostrar.'), findsOneWidget);
    });
  });
}
