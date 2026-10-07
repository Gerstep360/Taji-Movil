import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/domain/models/security_models.dart';
import 'package:taji/features/security/data/handover_repository.dart';
import 'package:taji/features/security/data/security_shift_repository.dart';
import 'package:taji/features/security/screens/handovers_screen.dart';
import 'package:taji/features/security/state/handover_controller.dart';

Map<String, dynamic> shiftJson({int id = 1, String status = 'OPEN'}) => {
  'id': id,
  'guard_staff': id == 1 ? 2 : 4,
  'guard_name': id == 1 ? 'Davidson' : 'Marco',
  'condominium_name': 'Bosque',
  'scheduled_start': id == 1
      ? '2026-10-06T08:00:00-04:00'
      : '2026-10-06T16:01:00-04:00',
  'scheduled_end': id == 1
      ? '2026-10-06T16:00:00-04:00'
      : '2026-10-06T23:59:00-04:00',
  'status': status,
  'created_at': '2026-10-06T08:00:00-04:00',
};
Map<String, dynamic> logJson() => {
  'id': 7,
  'shift': 1,
  'created_by_user': 2,
  'entry_type': 'ALERT',
  'severity': 'HIGH',
  'title': 'Portón',
  'description': 'Pendiente revisión',
  'occurred_at': '2026-10-06T15:00:00-04:00',
  'created_at': '2026-10-06T15:00:00-04:00',
};
Map<String, dynamic> handoverJson({String status = 'PENDING'}) => {
  'id': 5,
  'outgoing_shift': 1,
  'incoming_shift': 3,
  'outgoing_detail': shiftJson(),
  'incoming_detail': shiftJson(id: 3, status: 'SCHEDULED'),
  'summary': 'Revisar portón',
  'delivered_by_user': 2,
  'received_by_user': status == 'RECEIVED' ? 4 : null,
  'delivered_at': '2026-10-06T16:00:00-04:00',
  'received_at': status == 'RECEIVED' ? '2026-10-06T16:02:00-04:00' : null,
  'status': status,
  'log_entries': [logJson()],
};

class Shifts implements SecurityShiftDataSource {
  SecurityShiftModel? value = SecurityShiftModel.fromJson(shiftJson());
  @override
  Future<CurrentSecurityShift> current() async =>
      CurrentSecurityShift(shift: value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Source implements HandoverDataSource {
  List<ShiftHandoverModel> entries = [];
  List<SecurityShiftModel> relays = [
    SecurityShiftModel.fromJson(shiftJson(id: 3, status: 'SCHEDULED')),
  ];
  Object? failure;
  int deliveries = 0;
  int receipts = 0;
  int requestedPage = 1;
  String? sentSummary;
  int? sentIncoming;
  int? sentOutgoing;
  Completer<ShiftHandoverModel>? pending;
  void check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<HandoverPage> list({int page = 1, int? outgoingShift}) async {
    check();
    requestedPage = page;
    return HandoverPage(
      outgoingShift == null
          ? entries
          : entries
                .where((entry) => entry.outgoingShiftId == outgoingShift)
                .toList(),
      page: page,
      pages: 2,
    );
  }

  @override
  Future<List<SecurityShiftModel>> candidates(int outgoingShift) async {
    check();
    return relays;
  }

  @override
  Future<List<ShiftLogEntryModel>> records(int outgoingShift) async {
    check();
    return [ShiftLogEntryModel.fromJson(logJson())];
  }

  @override
  Future<ShiftHandoverModel> detail(int id) async {
    check();
    return entries.firstWhere((entry) => entry.id == id);
  }

  @override
  Future<ShiftHandoverModel> deliver({
    required int outgoingShift,
    required int incomingShift,
    required String summary,
  }) async {
    deliveries++;
    sentSummary = summary;
    sentIncoming = incomingShift;
    sentOutgoing = outgoingShift;
    check();
    final result = pending == null
        ? ShiftHandoverModel.fromJson({...handoverJson(), 'summary': summary})
        : await pending!.future;
    entries = [result];
    return result;
  }

  @override
  Future<ShiftHandoverModel> receive(int id) async {
    receipts++;
    check();
    final result = ShiftHandoverModel.fromJson(
      handoverJson(status: 'RECEIVED'),
    );
    entries = [result];
    return result;
  }
}

class Api implements ApiClient {
  Object? response;
  DioException? failure;
  String? path;
  Map<String, dynamic>? query;
  Object? body;
  Object? Function(String, Map<String, dynamic>?)? handler;
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    this.query = query;
    if (failure != null) throw failure!;
    return (handler == null ? response : handler!(path, query)) as T?;
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

void main() {
  test(
    'modelo interpreta identidad, turnos y novedades sin romper contrato anterior',
    () {
      final entry = ShiftHandoverModel.fromJson(handoverJson());
      expect(entry.outgoingShiftId, 1);
      expect(entry.incomingShiftId, 3);
      expect(entry.incomingDetail?.guardName, 'Marco');
      expect(entry.logEntries.single.title, 'Portón');
      expect(entry.statusLabel, 'Pendiente de recepción');
      expect(ShiftHandoverModel.fromJson(entry.toJson()).incomingShiftId, 3);
    },
  );
  test(
    'repositorio usa rutas, filtros y payload sin identidad manipulable',
    () async {
      final api = Api()
        ..response = {
          'results': [handoverJson()],
          'pagination': {'page': 2, 'total_pages': 3},
        };
      final repo = HandoverRepository(api);
      final page = await repo.list(page: 2, outgoingShift: 1);
      expect(api.path, '/security/entregas-turno/');
      expect(api.query, {'page': 2, 'outgoing_shift': 1});
      expect(page.pages, 3);
      api.response = [shiftJson(id: 3, status: 'SCHEDULED')];
      expect((await repo.candidates(1)).single.id, 3);
      expect(api.path, '/security/entregas-turno/candidatos/');
      api.response = handoverJson();
      await repo.detail(5);
      expect(api.path, '/security/entregas-turno/5/');
      await repo.deliver(
        outgoingShift: 1,
        incomingShift: 3,
        summary: ' Revisar ',
      );
      expect(api.body, {
        'outgoing_shift': 1,
        'incoming_shift': 3,
        'summary': 'Revisar',
      });
      await repo.receive(5);
      expect(api.path, '/security/entregas-turno/5/recibir/');
      expect(api.body, isNull);
    },
  );
  test('preparación lee todas las páginas de CU14', () async {
    final api = Api()
      ..handler = (path, query) => {
        'results': [logJson()],
        'pagination': {'page': query!['page'], 'total_pages': 2},
      };
    final result = await HandoverRepository(api).records(1);
    expect(result.length, 2);
    expect(api.query?['page'], 2);
  });
  test('repositorio rechaza datos incompletos y conserva errores', () async {
    final api = Api()..response = {'results': 'bad'};
    final repo = HandoverRepository(api);
    await expectLater(repo.list(), throwsA(isA<ApiFailure>()));
    api.failure = DioException(
      requestOptions: RequestOptions(),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 403,
        data: {
          'error': {
            'code': 'permission_denied',
            'message': 'Solo destinatario',
          },
        },
      ),
    );
    await expectLater(
      repo.receive(5),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.displayMessage,
          'message',
          'Solo destinatario',
        ),
      ),
    );
  });
  test(
    'prepara y entrega resumen sin iniciar ni cerrar turnos y evita duplicados',
    () async {
      final source = Source();
      final shifts = Shifts();
      final c = HandoverController(source, shifts);
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.canDeliver, true);
      expect(await c.prepare(), true);
      expect(c.records.single.title, 'Portón');
      expect(await c.deliver(3, ' Revisar portón ', outgoing: 1), true);
      expect(source.sentSummary, 'Revisar portón');
      expect(shifts.value?.status, 'OPEN');
      expect(c.outgoingHandover?.status, 'PENDING');
      expect(c.canDeliver, false);
      expect(await c.deliver(3, 'Otro', outgoing: 1), false);
      expect(source.deliveries, 1);
    },
  );
  test('no entrega sin turno abierto, sin relevo o sin resumen', () async {
    final source = Source();
    final shifts = Shifts()..value = null;
    final c = HandoverController(source, shifts);
    addTearDown(c.dispose);
    await c.refresh();
    expect(await c.prepare(), false);
    shifts.value = SecurityShiftModel.fromJson(shiftJson());
    await c.refresh();
    await c.prepare();
    expect(await c.deliver(3, ' ', outgoing: 1), false);
    expect(await c.deliver(99, 'Resumen', outgoing: 1), false);
    expect(source.deliveries, 0);
  });
  test(
    'solo turno entrante abierto permite recibir y requiere revisión',
    () async {
      final entry = ShiftHandoverModel.fromJson(handoverJson());
      final source = Source()..entries = [entry];
      final shifts = Shifts();
      final c = HandoverController(source, shifts);
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.canReceive(entry), false);
      shifts.value = SecurityShiftModel.fromJson(
        shiftJson(id: 3, status: 'SCHEDULED'),
      );
      await c.refresh();
      expect(c.canReceive(entry), false);
      shifts.value = SecurityShiftModel.fromJson(shiftJson(id: 3));
      await c.refresh();
      expect(c.canReceive(entry), true);
      expect(await c.receive(entry, reviewed: false), false);
      expect(source.receipts, 0);
      expect(await c.receive(entry, reviewed: true), true);
      expect(c.selected?.status, 'RECEIVED');
      expect(shifts.value?.status, 'OPEN');
      expect(c.canReceive(c.selected!), false);
    },
  );
  test(
    'cambio de turno invalida formulario preparado y fallo de refresco bloquea acciones',
    () async {
      final source = Source();
      final shifts = Shifts();
      final c = HandoverController(source, shifts);
      addTearDown(c.dispose);
      await c.refresh();
      await c.prepare();
      shifts.value = SecurityShiftModel.fromJson(shiftJson(id: 9));
      await c.refresh();
      expect(await c.deliver(3, 'Resumen', outgoing: 1), false);
      expect(source.deliveries, 0);
      source.failure = const ApiFailure(
        code: 'offline',
        message: 'Sin conexión',
      );
      await c.refresh();
      expect(c.canDeliver, false);
      expect(c.error, 'Sin conexión');
    },
  );
  test(
    'doble envío y disposición durante entrega no duplican operación',
    () async {
      final source = Source()..pending = Completer<ShiftHandoverModel>();
      final c = HandoverController(source, Shifts());
      await c.refresh();
      await c.prepare();
      final action = c.deliver(3, 'Resumen', outgoing: 1);
      expect(await c.deliver(3, 'Resumen', outgoing: 1), false);
      expect(source.deliveries, 1);
      c.dispose();
      source.pending!.complete(ShiftHandoverModel.fromJson(handoverJson()));
      expect(await action, true);
    },
  );
  test(
    'errores de validación se muestran en formulario sin marcar éxito',
    () async {
      final source = Source();
      final c = HandoverController(source, Shifts());
      addTearDown(c.dispose);
      await c.refresh();
      await c.prepare();
      source.failure = const ApiFailure(
        code: 'validation_error',
        message: 'Error',
        fields: {
          'incoming_shift': ['Relevo cancelado.'],
        },
      );
      expect(await c.deliver(3, 'Resumen', outgoing: 1), false);
      expect(c.formError, 'Relevo cancelado.');
      expect(c.success, isNull);
    },
  );
  Future<void> screen(WidgetTester tester, Source source, Shifts shifts) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTajiTheme(),
        home: MultiProvider(
          providers: [
            Provider<HandoverDataSource>.value(value: source),
            Provider<SecurityShiftDataSource>.value(value: shifts),
          ],
          child: const HandoversScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'un relevo se preselecciona y entrega después de revisión explícita',
    (tester) async {
      final source = Source();
      await screen(tester, source, Shifts());
      await tester.tap(find.byKey(const Key('prepare-handover')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byKey(const Key('relay-shift')),
            )
            .initialValue,
        3,
      );
      await tester.enterText(
        find.byKey(const Key('handover-summary')),
        'Revisar portón',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('deliver-handover')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('deliver-handover')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('delivery-reviewed')));
      await tester.tap(find.byKey(const Key('delivery-reviewed')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('deliver-handover')));
      await tester.tap(find.byKey(const Key('deliver-handover')));
      await tester.pumpAndSettle();
      expect(source.deliveries, 1);
      expect(
        find.text('Entrega registrada. Pendiente de recepción.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('varios relevos requieren elegir y ninguno no habilita entrega', (
    tester,
  ) async {
    final source = Source()
      ..relays = [
        SecurityShiftModel.fromJson(shiftJson(id: 3)),
        SecurityShiftModel.fromJson(shiftJson(id: 4)),
      ];
    await screen(tester, source, Shifts());
    await tester.tap(find.byKey(const Key('prepare-handover')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('relay-shift')),
          )
          .initialValue,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await screen(tester, Source()..relays = [], Shifts());
    await tester.tap(find.byKey(const Key('prepare-handover')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No hay relevos válidos. Solicita al administrador que programe el turno correspondiente.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('deliver-handover')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('deliver-handover')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'destinatario revisa novedades y confirma recepción sin cierre automático',
    (tester) async {
      final source = Source()
        ..entries = [ShiftHandoverModel.fromJson(handoverJson())];
      await screen(
        tester,
        source,
        Shifts()..value = SecurityShiftModel.fromJson(shiftJson(id: 3)),
      );
      await tester.ensureVisible(find.text('Ver resumen y novedades'));
      await tester.tap(find.text('Ver resumen y novedades'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar portón'), findsOneWidget);
      expect(find.text('Portón'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('receive-handover')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('receipt-reviewed')));
      await tester.tap(find.byKey(const Key('receipt-reviewed')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('receive-handover')));
      await tester.tap(find.byKey(const Key('receive-handover')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-receipt')));
      await tester.pumpAndSettle();
      expect(source.receipts, 1);
      expect(find.text('Recibida'), findsOneWidget);
      expect(find.byKey(const Key('receive-handover')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
