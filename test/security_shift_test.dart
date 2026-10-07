import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_failure.dart';
import 'package:taji/core/router/app_router.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/domain/models/security_models.dart';
import 'package:taji/features/auth/data/auth_repository.dart';
import 'package:taji/features/auth/models/taji_user.dart';
import 'package:taji/features/auth/state/auth_controller.dart';
import 'package:taji/features/security/data/security_shift_repository.dart';
import 'package:taji/features/security/screens/security_shifts_screen.dart';
import 'package:taji/features/security/state/security_shift_controller.dart';

final _start = DateTime.parse('2026-10-06T08:00:00-04:00');
final _end = _start.add(const Duration(hours: 8));

Map<String, dynamic> _json({
  String status = 'SCHEDULED',
  DateTime? now,
  int? otherOpen,
  String notes = '',
}) => {
  'id': 12,
  'guard_staff': 7,
  'guard_name': 'Davidson Guardia',
  'guard_employee_code': 'PER-00007',
  'condominium_name': 'Condominio de prueba',
  'scheduled_start': _start.toIso8601String(),
  'scheduled_end': _end.toIso8601String(),
  'opened_at': status == 'OPEN' || status == 'CLOSED'
      ? _start.toIso8601String()
      : null,
  'closed_at': status == 'CLOSED' ? (now ?? _end).toIso8601String() : null,
  'status': status,
  'opening_notes': '',
  'closing_notes': notes,
  'observation': 'Garita principal',
  'created_at': _start.toIso8601String(),
  'timing': {
    'server_time': (now ?? _start).toIso8601String(),
    'start_allowed_at': _start
        .subtract(const Duration(minutes: 15))
        .toIso8601String(),
    'other_open_shift_id': otherOpen,
  },
};

class _FakeSource implements SecurityShiftDataSource {
  _FakeSource(this.shift);
  SecurityShiftModel? shift;
  Object? failure;
  int starts = 0;
  int closes = 0;
  String sentNotes = '';
  Completer<SecurityShiftModel>? delayedStart;
  List<SecurityShiftModel> upcomingItems = [];
  List<SecurityShiftModel> historyItems = [];

  void _check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<CurrentSecurityShift> current() async {
    _check();
    return CurrentSecurityShift(
      shift: shift,
      message: shift == null ? 'No tienes turno para hoy.' : '',
    );
  }

  @override
  Future<List<SecurityShiftModel>> upcoming() async {
    _check();
    return upcomingItems;
  }

  @override
  Future<List<SecurityShiftModel>> history() async {
    _check();
    return historyItems;
  }

  @override
  Future<SecurityShiftModel> start(int id, {String notes = ''}) async {
    starts++;
    _check();
    sentNotes = notes;
    final pending = delayedStart;
    if (pending != null) return pending.future;
    shift = SecurityShiftModel.fromJson(_json(status: 'OPEN'));
    return shift!;
  }

  @override
  Future<SecurityShiftModel> close(int id, {String notes = ''}) async {
    closes++;
    _check();
    sentNotes = notes;
    final result = SecurityShiftModel.fromJson(
      _json(status: 'CLOSED', notes: notes),
    );
    historyItems = [result];
    shift = null;
    return result;
  }
}

class _FakeApi implements ApiClient {
  dynamic result;
  DioException? failure;
  String? path;
  Object? body;

  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    if (failure != null) throw failure!;
    return result as T?;
  }

  @override
  Future<T?> post<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    if (failure != null) throw failure!;
    return result as T?;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TajiUser _user(String role) => TajiUser.fromJson({
  'id': 7,
  'email': 'guardia@test.local',
  'first_name': 'Davidson',
  'last_name': 'Guardia',
  'full_name': 'Davidson Guardia',
  'role': {'slug': role, 'name': role, 'permissions': []},
});

void main() {
  test(
    'reads the CU13 API contract and preserves existing model compatibility',
    () {
      final shift = SecurityShiftModel.fromJson(_json());
      expect(shift.guardStaffId, 7);
      expect(shift.guardName, 'Davidson Guardia');
      expect(
        shift.startAllowedAt,
        _start.subtract(const Duration(minutes: 15)),
      );
      expect(SecurityShiftModel.fromJson(shift.toJson()).guardStaffId, 7);
      final legacy = _json()
        ..remove('guard_staff')
        ..remove('timing');
      legacy['guard_staff_id'] = 7;
      expect(SecurityShiftModel.fromJson(legacy).guardStaffId, 7);
    },
  );

  test('start boundaries, late arrival and the end of the schedule', () {
    final shift = SecurityShiftModel.fromJson(_json());
    expect(
      shift.startBlockReason(_start.subtract(const Duration(minutes: 16))),
      isNotEmpty,
    );
    expect(
      shift.startBlockReason(_start.subtract(const Duration(minutes: 15))),
      isEmpty,
    );
    expect(
      shift.startBlockReason(_start.add(const Duration(hours: 1))),
      isEmpty,
    );
    expect(shift.startBlockReason(_end), isNotEmpty);
    expect(shift.timingNotice(_end), contains('Sin iniciar'));
    final blocked = SecurityShiftModel.fromJson(_json(otherOpen: 3));
    expect(blocked.startBlockReason(_start), contains('otro turno abierto'));
  });

  test(
    'open shifts never close automatically and need a reason outside the planned end',
    () {
      final shift = SecurityShiftModel.fromJson(_json(status: 'OPEN'));
      expect(shift.closeReasonRequired(_start), isTrue);
      expect(shift.closeReasonRequired(_end), isFalse);
      expect(
        shift.closeReasonRequired(_end.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(shift.timingNotice(_end), contains('cierre pendiente'));
      expect(shift.status, 'OPEN');
    },
  );

  test(
    'the server clock governs actions when the phone time is wrong',
    () async {
      final serverNow = _start.subtract(const Duration(hours: 1));
      final source = _FakeSource(
        SecurityShiftModel.fromJson(_json(now: serverNow)),
      );
      final controller = SecurityShiftController(
        source,
        clock: () => serverNow.add(const Duration(hours: 3)),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.now, serverNow);
      expect(controller.canStart, isFalse);
      expect(await controller.start(), isFalse);
      expect(source.starts, 0);
    },
  );

  test(
    'prevents closing without reason, trims the reason and refreshes history',
    () async {
      final source = _FakeSource(
        SecurityShiftModel.fromJson(_json(status: 'OPEN')),
      );
      final controller = SecurityShiftController(source, clock: () => _start);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.close(notes: '  '), isFalse);
      expect(source.closes, 0);
      expect(await controller.close(notes: '  Permiso de salida  '), isTrue);
      expect(source.sentNotes, 'Permiso de salida');
      expect(controller.currentShift, isNull);
      expect(controller.history.single.closingNotes, 'Permiso de salida');
    },
  );

  test(
    'failed refresh disables actions on stale data and preserves the error',
    () async {
      final source = _FakeSource(SecurityShiftModel.fromJson(_json()));
      final controller = SecurityShiftController(source, clock: () => _start);
      addTearDown(controller.dispose);
      await controller.initialize();
      source.failure = const ApiFailure(
        code: 'network_unavailable',
        message: 'Sin conexión',
      );
      await controller.refresh();
      expect(controller.error, 'Sin conexión');
      expect(controller.canStart, isFalse);
      expect(await controller.start(), isFalse);
      expect(source.starts, 0);
    },
  );

  test('API validation is retained for the action dialog', () async {
    final source = _FakeSource(
      SecurityShiftModel.fromJson(_json(status: 'OPEN')),
    );
    final controller = SecurityShiftController(source, clock: () => _start);
    addTearDown(controller.dispose);
    await controller.initialize();
    source.failure = const ApiFailure(
      code: 'validation_error',
      message: 'Revisa los campos',
      fields: {
        'notes': ['Motivo requerido'],
      },
    );
    expect(await controller.close(notes: 'Motivo'), isFalse);
    expect(controller.actionError, 'Motivo requerido');
    expect(controller.currentShift!.status, 'OPEN');
  });

  test('ignores double taps and finishes safely after disposal', () async {
    final source = _FakeSource(SecurityShiftModel.fromJson(_json()));
    source.delayedStart = Completer<SecurityShiftModel>();
    final controller = SecurityShiftController(source, clock: () => _start);
    await controller.initialize();
    final first = controller.start();
    expect(await controller.start(), isFalse);
    expect(source.starts, 1);
    controller.dispose();
    source.delayedStart!.complete(
      SecurityShiftModel.fromJson(_json(status: 'OPEN')),
    );
    expect(await first, isTrue);
  });

  test(
    'repository handles current turn, empty current and lists using the real paths',
    () async {
      final api = _FakeApi()..result = _json();
      final repository = SecurityShiftRepository(api);
      expect((await repository.current()).shift!.id, 12);
      expect(api.path, '/security/turnos/actual/');
      api.result = {'shift': null, 'message': 'Sin turno'};
      expect((await repository.current()).message, 'Sin turno');
      api.result = [_json()];
      expect(await repository.upcoming(), hasLength(1));
      expect(api.path, '/security/turnos/proximos/');
      api.result = {
        'results': [_json()],
      };
      expect(await repository.history(), hasLength(1));
      expect(api.path, '/security/turnos/historial/');
      api.result = _json(status: 'OPEN');
      expect((await repository.start(12, notes: '  Entrada  ')).status, 'OPEN');
      expect(api.path, '/security/turnos/12/iniciar/');
      expect(api.body, {'notes': 'Entrada'});
      api.result = _json(status: 'CLOSED');
      await repository.close(12, notes: 'Motivo');
      expect(api.path, '/security/turnos/12/cerrar/');
      expect(api.body, {'notes': 'Motivo'});
    },
  );

  test('repository converts 403 errors and refuses malformed data', () async {
    final api = _FakeApi()..result = {'id': 12};
    final repository = SecurityShiftRepository(api);
    await expectLater(repository.current(), throwsA(isA<ApiFailure>()));
    api.failure = DioException(
      requestOptions: RequestOptions(path: '/security/turnos/actual/'),
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 403,
        data: {
          'error': {'code': 'permission_denied', 'message': 'Acceso denegado'},
        },
      ),
      type: DioExceptionType.badResponse,
    );
    await expectLater(
      repository.current(),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.statusCode,
          'status',
          403,
        ),
      ),
    );
  });

  test('guard aliases have access but residents do not', () {
    for (final role in ['seguridad', 'guardia', 'security']) {
      expect(_user(role).canUseSecurityShifts, isTrue);
    }
    expect(_user('residente').canUseSecurityShifts, isFalse);
  });

  Future<void> screen(WidgetTester tester, _FakeSource source) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTajiTheme(),
        home: Provider<SecurityShiftDataSource>.value(
          value: source,
          child: const SecurityShiftsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'phone view displays the assigned shift and blocks an early start',
    (tester) async {
      final source = _FakeSource(
        SecurityShiftModel.fromJson(
          _json(now: _start.subtract(const Duration(hours: 1))),
        ),
      );
      await screen(tester, source);
      expect(find.text('Davidson Guardia'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('start-shift')),
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('start-shift')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'closing an overdue shift requests the reason and displays it in history',
    (tester) async {
      final source = _FakeSource(
        SecurityShiftModel.fromJson(
          _json(status: 'OPEN', now: _end.add(const Duration(minutes: 1))),
        ),
      );
      await screen(tester, source);
      await tester.scrollUntilVisible(
        find.byKey(const Key('close-shift')),
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(
        find.text('Horario finalizado, cierre pendiente.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('close-shift')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-shift-action'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('shift-action-notes')),
        'Demora del relevo',
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(source.closes, 1);
      expect(source.sentNotes, 'Demora del relevo');
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Demora del relevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty and next shift tabs remain usable without an assigned turn',
    (tester) async {
      final source = _FakeSource(null)
        ..upcomingItems = [SecurityShiftModel.fromJson(_json())];
      await screen(tester, source);
      expect(find.text('No tienes turno para hoy.'), findsOneWidget);
      await tester.tap(find.text('Próximos'));
      await tester.pumpAndSettle();
      expect(find.text('Davidson Guardia'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the actual router denies CU13 to an authenticated resident', (
    tester,
  ) async {
    final source = _FakeSource(null);
    final auth = AuthController(AuthRepository(_FakeApi()))
      ..user = _user('residente')
      ..status = AuthStatus.authenticated;
    final router = AppRouter.create(auth);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<SecurityShiftDataSource>.value(value: source),
        ],
        child: MaterialApp.router(
          theme: buildTajiTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/mis-turnos');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/inicio');
    expect(find.text('Mis turnos de seguridad'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
