import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/domain/models/security_models.dart';
import 'package:taji/features/security/data/security_shift_repository.dart';
import 'package:taji/features/security/data/shift_log_repository.dart';
import 'package:taji/features/security/screens/shift_logs_screen.dart';
import 'package:taji/features/security/state/shift_log_controller.dart';

Map<String, dynamic> entryJson() => {
  'id': 1,
  'shift': 12,
  'created_by_user': 2,
  'entry_type': 'INCIDENT',
  'severity': 'HIGH',
  'title': 'Portón',
  'description': 'No cierra',
  'guard_name': 'Davidson',
  'condominium_name': 'Bosque',
  'occurred_at': '2026-10-06T12:00:00-04:00',
  'created_at': '2026-10-06T12:00:00-04:00',
};
SecurityShiftModel shift([String status = 'OPEN']) =>
    SecurityShiftModel.fromJson({
      'id': 12,
      'guard_staff': 2,
      'guard_name': 'Davidson',
      'scheduled_start': '2026-10-06T08:00:00-04:00',
      'scheduled_end': '2026-10-06T16:00:00-04:00',
      'status': status,
      'created_at': '2026-10-06T08:00:00-04:00',
    });

class Shifts implements SecurityShiftDataSource {
  SecurityShiftModel? value = shift();
  @override
  Future<CurrentSecurityShift> current() async =>
      CurrentSecurityShift(shift: value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Logs implements ShiftLogDataSource {
  int creates = 0;
  int? filterShift;
  int requestedPage = 1;
  Object? failure;
  Map<String, Object?>? payload;
  Completer<ShiftLogEntryModel>? pending;
  List<ShiftLogEntryModel> entries = [];
  @override
  Future<ShiftLogPage> list({int? shift, int page = 1}) async {
    if (failure != null) throw failure!;
    filterShift = shift;
    requestedPage = page;
    return ShiftLogPage(entries, page: page, pages: 2);
  }

  @override
  Future<ShiftLogEntryModel> create({
    required String type,
    required String severity,
    required String title,
    required String description,
    int? expectedShift,
  }) async {
    creates++;
    payload = {
      'type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'expected_shift': expectedShift,
    };
    if (failure != null) throw failure!;
    final entry = pending == null
        ? ShiftLogEntryModel.fromJson({
            ...entryJson(),
            'title': title,
            'description': description,
          })
        : await pending!.future;
    entries = [entry, ...entries];
    return entry;
  }
}

class Api implements ApiClient {
  Object? response;
  DioException? failure;
  String? path;
  Object? body;
  Map<String, dynamic>? query;
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

void main() {
  test('interpreta CU14 y mantiene compatibilidad con modelo anterior', () {
    final entry = ShiftLogEntryModel.fromJson(entryJson());
    expect(entry.shiftId, 12);
    expect(entry.createdByUserId, 2);
    expect(entry.typeLabel, 'Incidente');
    expect(entry.severityLabel, 'Alta');
    expect(entry.guardName, 'Davidson');
    expect(ShiftLogEntryModel.fromJson(entry.toJson()).shiftId, 12);
    final legacy = {...entryJson()}
      ..remove('shift')
      ..remove('created_by_user');
    expect(
      ShiftLogEntryModel.fromJson({
        ...legacy,
        'shift_id': 12,
        'created_by_user_id': 2,
      }).shiftId,
      12,
    );
  });
  test(
    'repositorio pagina y filtra por turno sin confiar en identidad enviada',
    () async {
      final api = Api()
        ..response = {
          'results': [entryJson()],
          'pagination': {'page': 2, 'total_pages': 3},
        };
      final repo = ShiftLogRepository(api);
      final result = await repo.list(shift: 12, page: 2);
      expect(api.path, '/security/novedades-turno/');
      expect(api.query, {'page': 2, 'shift': 12});
      expect(result.pages, 3);
      expect(result.entries.single.shiftId, 12);
      api.response = entryJson();
      await repo.create(
        type: 'ALERT',
        severity: 'HIGH',
        title: ' Portón ',
        description: ' No cierra ',
        expectedShift: 12,
      );
      expect(api.body, {
        'entry_type': 'ALERT',
        'severity': 'HIGH',
        'title': 'Portón',
        'description': 'No cierra',
        'expected_shift': 12,
      });
    },
  );
  test(
    'repositorio detecta respuesta inválida y errores del backend',
    () async {
      final api = Api()..response = {'results': 'incorrecto'};
      final repo = ShiftLogRepository(api);
      await expectLater(repo.list(), throwsA(isA<ApiFailure>()));
      api.failure = DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 400,
          data: {
            'error': {
              'code': 'validation_error',
              'message': 'Sin turno',
              'fields': {
                'shift': ['Inicia el turno.'],
              },
            },
          },
        ),
      );
      await expectLater(
        repo.create(
          type: 'NOTE',
          severity: 'INFO',
          title: 'a',
          description: 'b',
        ),
        throwsA(
          isA<ApiFailure>().having((e) => e.fields['shift'], 'fields', [
            'Inicia el turno.',
          ]),
        ),
      );
    },
  );
  test(
    'turno abierto habilita registro, limpia texto y conserva historial paginado',
    () async {
      final logs = Logs();
      final controller = ShiftLogController(logs, Shifts());
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.canRegister, true);
      expect(logs.filterShift, 12);
      expect(
        await controller.create(
          type: 'NOTE',
          severity: 'INFO',
          title: '  Puerta ',
          description: ' Cerrada ',
        ),
        true,
      );
      expect(logs.payload?['title'], 'Puerta');
      expect(logs.payload?['expected_shift'], 12);
      await controller.setHistory(true);
      expect(logs.filterShift, isNull);
      expect(controller.canRegister, false);
      await controller.refresh(nextPage: 2);
      expect(logs.requestedPage, 2);
    },
  );
  test(
    'sin turno abierto y en turnos programados o cerrados no permite crear',
    () async {
      for (final value in [null, shift('SCHEDULED'), shift('CLOSED')]) {
        final logs = Logs();
        final controller = ShiftLogController(logs, Shifts()..value = value);
        await controller.refresh();
        expect(controller.canRegister, false);
        expect(
          await controller.create(
            type: 'NOTE',
            severity: 'INFO',
            title: 'a',
            description: 'b',
          ),
          false,
        );
        expect(logs.creates, 0);
        controller.dispose();
      }
    },
  );
  test('valida campos y evita guardar un formulario de otro turno', () async {
    final logs = Logs();
    final controller = ShiftLogController(logs, Shifts());
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(
      await controller.create(
        type: 'NOTE',
        severity: 'INFO',
        title: ' ',
        description: 'b',
      ),
      false,
    );
    expect(
      await controller.create(
        type: 'HANDOVER_NOTE',
        severity: 'INFO',
        title: 'a',
        description: 'b',
      ),
      false,
    );
    expect(
      await controller.create(
        type: 'NOTE',
        severity: 'INFO',
        title: 'a',
        description: 'b',
        expectedShift: 99,
      ),
      false,
    );
    expect(logs.creates, 0);
  });
  test(
    'fallo de carga bloquea datos desactualizados y permite reintentar',
    () async {
      final logs = Logs();
      final controller = ShiftLogController(logs, Shifts());
      addTearDown(controller.dispose);
      await controller.refresh();
      logs.failure = const ApiFailure(code: 'offline', message: 'Sin conexión');
      await controller.refresh();
      expect(controller.canRegister, false);
      expect(controller.error, 'Sin conexión');
      logs.failure = null;
      await controller.refresh();
      expect(controller.canRegister, true);
    },
  );
  test('error de guardado conserva detalle en formulario', () async {
    final logs = Logs();
    final controller = ShiftLogController(logs, Shifts());
    addTearDown(controller.dispose);
    await controller.refresh();
    logs.failure = const ApiFailure(
      code: 'validation_error',
      message: 'No válido',
      fields: {
        'shift': ['Turno cerrado.'],
      },
    );
    expect(
      await controller.create(
        type: 'NOTE',
        severity: 'INFO',
        title: 'a',
        description: 'b',
      ),
      false,
    );
    expect(controller.formError, 'Turno cerrado.');
    expect(controller.entries, isEmpty);
  });
  test(
    'ignora doble envío y se dispone durante guardado sin notificar',
    () async {
      final logs = Logs()..pending = Completer<ShiftLogEntryModel>();
      final controller = ShiftLogController(logs, Shifts());
      await controller.refresh();
      final saving = controller.create(
        type: 'NOTE',
        severity: 'INFO',
        title: 'a',
        description: 'b',
      );
      expect(
        await controller.create(
          type: 'NOTE',
          severity: 'INFO',
          title: 'a',
          description: 'b',
        ),
        false,
      );
      expect(logs.creates, 1);
      controller.dispose();
      logs.pending!.complete(ShiftLogEntryModel.fromJson(entryJson()));
      expect(await saving, true);
    },
  );

  Future<void> screen(WidgetTester tester, Logs logs, Shifts shifts) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTajiTheme(),
        home: MultiProvider(
          providers: [
            Provider<ShiftLogDataSource>.value(value: logs),
            Provider<SecurityShiftDataSource>.value(value: shifts),
          ],
          child: const ShiftLogsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'formulario valida, registra y vuelve a la lista en pantalla de celular',
    (tester) async {
      final logs = Logs();
      await screen(tester, logs, Shifts());
      await tester.tap(find.byKey(const Key('new-shift-log')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-shift-log')));
      await tester.tap(find.byKey(const Key('save-shift-log')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un título.'), findsOneWidget);
      expect(logs.creates, 0);
      await tester.enterText(find.byKey(const Key('log-title')), 'Portón');
      await tester.enterText(
        find.byKey(const Key('log-description')),
        'No cierra',
      );
      await tester.ensureVisible(find.byKey(const Key('save-shift-log')));
      await tester.tap(find.byKey(const Key('save-shift-log')));
      await tester.pumpAndSettle();
      expect(logs.creates, 1);
      expect(find.text('Portón'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('error de guardado queda visible sin perder lo escrito', (
    tester,
  ) async {
    final logs = Logs();
    await screen(tester, logs, Shifts());
    await tester.tap(find.byKey(const Key('new-shift-log')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-title')), 'Portón');
    await tester.enterText(
      find.byKey(const Key('log-description')),
      'No cierra',
    );
    logs.failure = const ApiFailure(code: 'offline', message: 'Sin conexión');
    await tester.ensureVisible(find.byKey(const Key('save-shift-log')));
    await tester.tap(find.byKey(const Key('save-shift-log')));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión').hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('log-title')))
          .controller!
          .text,
      'Portón',
    );
    expect(find.text('Nuevo registro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('formulario abierto no cambia de turno al volver a la app', (
    tester,
  ) async {
    final logs = Logs();
    final shifts = Shifts();
    await screen(tester, logs, shifts);
    await tester.tap(find.byKey(const Key('new-shift-log')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-title')), 'Portón');
    await tester.enterText(
      find.byKey(const Key('log-description')),
      'No cierra',
    );
    shifts.value = SecurityShiftModel.fromJson({...shift().toJson(), 'id': 99});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-shift-log')));
    await tester.tap(find.byKey(const Key('save-shift-log')));
    await tester.pumpAndSettle();
    expect(logs.creates, 0);
    expect(
      find.text('Tu turno cambió. Vuelve a la lista antes de registrar.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('turno cerrado conserva lista pero bloquea nuevo registro', (
    tester,
  ) async {
    await screen(
      tester,
      Logs()..entries = [ShiftLogEntryModel.fromJson(entryJson())],
      Shifts()..value = shift('CLOSED'),
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('new-shift-log')))
          .onPressed,
      isNull,
    );
    expect(find.text('Portón'), findsOneWidget);
    await tester.tap(find.text('Mi historial'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-shift-log')), findsNothing);
    expect(find.text('Portón'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
