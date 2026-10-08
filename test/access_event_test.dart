import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/domain/models/access_event_models.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/security/data/access_event_repository.dart';
import 'package:taji/features/security/screens/access_events_screen.dart';
import 'package:taji/features/security/state/access_events_controller.dart';

Map<String, dynamic> eventJson({String type = 'ENTRY'}) => {
  'id': 7,
  'person_id': type == 'DENIED' ? null : 12,
  'person': type == 'DENIED'
      ? null
      : {
          'id': 12,
          'full_name': 'Ana Márquez',
          'document_number': '1234567',
        },
  'visitor_name': type == 'DENIED' ? 'Carlos Visitante' : '',
  'visitor_document_number': type == 'DENIED' ? '7654321' : '',
  'unit_id': 4,
  'unit': {
    'id': 4,
    'code': 'C-04',
    'unit_type': 'Casa',
    'sector_name': 'Los Pinos',
  },
  'guard_staff_id': 2,
  'authorization_id': null,
  'event_type': type,
  'event_type_display': type == 'DENIED' ? 'Denegado' : 'Entrada',
  'validation_method': 'MANUAL',
  'validation_method_display': 'Manual',
  'validation_result': type == 'DENIED' ? 'REJECTED' : 'APPROVED',
  'validation_result_display': type == 'DENIED' ? 'Rechazado' : 'Aprobado',
  'occurred_at': '2026-10-07T12:00:00Z',
  'notes': 'Control de portería',
};

class _FakeApi implements ApiClient {
  Object? response;
  DioException? failure;
  String? path;
  Map<String, dynamic>? query;
  Object? body;

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    this.query = query;
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

class _FakeAccessEvents implements AccessEventDataSource {
  int creates = 0;
  Map<String, Object?>? payload;
  Object? failure;
  List<AccessEventItemModel> events = [];

  @override
  Future<AccessEventPage> list({int page = 1, String? eventType}) async =>
      AccessEventPage(
        eventType == null
            ? events
            : events.where((event) => event.eventType == eventType).toList(),
        page: page,
        pages: 2,
      );

  @override
  Future<List<AccessPersonOptionModel>> searchPeople(String search) async => [
    AccessPersonOptionModel(
      id: 12,
      fullName: 'Ana Márquez',
      documentNumber: '1234567',
      units: const [AccessPersonUnitModel(id: 4, code: 'C-04')],
    ),
  ];

  @override
  Future<List<AccessUnitOptionModel>> searchUnits(String search) async => [
    const AccessUnitOptionModel(
      id: 4,
      code: 'C-04',
      type: 'Casa',
      sector: 'Los Pinos',
    ),
  ];

  @override
  Future<AccessEventItemModel> create({
    int? personId,
    String visitorName = '',
    String visitorDocumentNumber = '',
    required int unitId,
    required String eventType,
    required String validationMethod,
    required String notes,
  }) async {
    creates++;
    payload = {
      'person_id': personId,
      'visitor_name': visitorName,
      'visitor_document_number': visitorDocumentNumber,
      'unit_id': unitId,
      'event_type': eventType,
      'validation_method': validationMethod,
      'notes': notes,
    };
    if (failure != null) throw failure!;
    return AccessEventItemModel.fromJson(eventJson(type: eventType));
  }
}

void main() {
  group('CU11 access event data', () {
    test('registering the control module requires its permission or admin role', () {
      const guard = TajiUser(
        id: 1,
        email: 'guard@taji.test',
        firstName: 'Ana',
        lastName: 'Guardia',
        fullName: 'Ana Guardia',
        phone: '',
        role: TajiRole(
          slug: 'seguridad',
          name: 'Seguridad',
          description: '',
          permissions: [],
        ),
      );
      const authorizedGuard = TajiUser(
        id: 2,
        email: 'guard2@taji.test',
        firstName: 'Luis',
        lastName: 'Guardia',
        fullName: 'Luis Guardia',
        phone: '',
        role: TajiRole(
          slug: 'seguridad',
          name: 'Seguridad',
          description: '',
          permissions: ['register_entry_exit'],
        ),
      );

      expect(guard.canRegisterAccessEvents, isFalse);
      expect(authorizedGuard.canRegisterAccessEvents, isTrue);
    });

    test('centralizes the three CU11 API endpoints', () {
      expect(ApiEndpoints.accessEvents.collection, '/security/access-events/');
      expect(ApiEndpoints.accessEvents.people, '/security/access-events/people/');
      expect(ApiEndpoints.accessEvents.units, '/security/access-events/units/');
    });

    test('parses a registered person and its unit destination', () {
      final event = AccessEventItemModel.fromJson(eventJson());

      expect(event.displayName, 'Ana Márquez');
      expect(event.destination, 'C-04 · Los Pinos');
      expect(event.eventTypeLabel, 'Entrada');
      expect(event.validationResultLabel, 'Aprobado');
    });

    test('parses an unregistered visitor and rejected access', () {
      final event = AccessEventItemModel.fromJson(eventJson(type: 'DENIED'));

      expect(event.personId, isNull);
      expect(event.displayName, 'Carlos Visitante');
      expect(event.visitorDocumentNumber, '7654321');
      expect(event.eventTypeLabel, 'Denegado');
      expect(event.validationResult, 'REJECTED');
    });

    test('repository uses CU11 lookup endpoints and registers exact payload', () async {
      final api = _FakeApi();
      final repository = AccessEventRepository(api);

      api.response = {
        'results': [
          {
            'id': 12,
            'full_name': 'Ana Márquez',
            'document_number': '1234567',
            'units': [
              {'id': 4, 'code': 'C-04'},
            ],
          },
        ],
      };
      final people = await repository.searchPeople('Ana');
      expect(api.path, ApiEndpoints.accessEvents.people);
      expect(api.query, {'search': 'Ana'});
      expect(people.single.units.single.code, 'C-04');

      api.response = {
        'results': [
          {
            'id': 4,
            'code': 'C-04',
            'unit_type': 'Casa',
            'sector': 'Los Pinos',
          },
        ],
      };
      final units = await repository.searchUnits('C-04');
      expect(api.path, ApiEndpoints.accessEvents.units);
      expect(units.single.sector, 'Los Pinos');

      api.response = eventJson(type: 'DENIED');
      await repository.create(
        visitorName: 'Carlos Visitante',
        visitorDocumentNumber: '7654321',
        unitId: 4,
        eventType: 'DENIED',
        validationMethod: 'MANUAL',
        notes: 'Sin autorización',
      );
      expect(api.path, ApiEndpoints.accessEvents.collection);
      expect(api.body, {
        'visitor_name': 'Carlos Visitante',
        'visitor_document_number': '7654321',
        'unit_id': 4,
        'event_type': 'DENIED',
        'validation_method': 'MANUAL',
        'validation_result': 'REJECTED',
        'notes': 'Sin autorización',
      });

      api.response = eventJson();
      await repository.create(
        personId: 12,
        unitId: 4,
        eventType: 'EXIT',
        validationMethod: 'MANUAL',
        notes: 'Salida registrada',
      );
      expect(api.body, {
        'person_id': 12,
        'unit_id': 4,
        'event_type': 'EXIT',
        'validation_method': 'MANUAL',
        'validation_result': 'APPROVED',
        'notes': 'Salida registrada',
      });
    });

    test('repository validates the paginated access history contract', () async {
      final api = _FakeApi()
        ..response = {
          'results': [eventJson(type: 'DENIED')],
          'pagination': {'page': 2, 'total_pages': 4},
        };
      final repository = AccessEventRepository(api);

      final result = await repository.list(page: 2, eventType: 'DENIED');

      expect(api.path, ApiEndpoints.accessEvents.collection);
      expect(api.query, {'page': 2, 'page_size': 20, 'event_type': 'DENIED'});
      expect(result.page, 2);
      expect(result.pages, 4);
      expect(result.events.single.validationResult, 'REJECTED');
    });

    test('registration controller validates selection and forces DENIED rejected', () async {
      final source = _FakeAccessEvents();
      final controller = AccessEventRegistrationController(source);
      addTearDown(controller.dispose);

      expect(
        await controller.create(
          isRegistered: true,
          unitId: 4,
          eventType: 'ENTRY',
          validationMethod: 'MANUAL',
          notes: '',
        ),
        isFalse,
      );
      expect(source.creates, 0);
      expect(controller.error, contains('persona'));

      expect(
        await controller.create(
          isRegistered: false,
          visitorName: ' Carlos Visitante ',
          visitorDocumentNumber: ' 7654321 ',
          unitId: 4,
          eventType: 'DENIED',
          validationMethod: 'MANUAL',
          notes: ' Sin autorización ',
        ),
        isTrue,
      );
      expect(source.payload?['person_id'], isNull);
      expect(source.payload?['visitor_name'], 'Carlos Visitante');
      expect(source.payload?['visitor_document_number'], '7654321');
      expect(controller.error, isNull);
    });
  });

  testWidgets('form adapts between registered and new visitor modes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _FakeAccessEvents();

    await tester.pumpWidget(
      MaterialApp(home: AccessEventFormScreen(source: source)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-person-search')), findsOneWidget);
    expect(find.byKey(const Key('access-unit-search')), findsOneWidget);
    expect(find.byKey(const Key('access-event-type-DENIED')), findsOneWidget);

    await tester.tap(find.text('Visitante nuevo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-person-search')), findsNothing);
    expect(find.byKey(const Key('access-visitor-name')), findsOneWidget);
    expect(find.byKey(const Key('access-visitor-document')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history renders the visitor destination on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _FakeAccessEvents()
      ..events = [AccessEventItemModel.fromJson(eventJson(type: 'DENIED'))];

    await tester.pumpWidget(
      Provider<AccessEventDataSource>.value(
        value: source,
        child: MaterialApp(theme: buildTajiTheme(), home: const AccessEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carlos Visitante'), findsOneWidget);
    expect(find.text('Carnet: 7654321'), findsOneWidget);
    expect(find.text('Destino: C-04 · Los Pinos'), findsOneWidget);
    expect(find.text('Denegado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}