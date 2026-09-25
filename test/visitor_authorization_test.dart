import 'package:flutter_test/flutter_test.dart';
import 'package:taji/features/visitors/data/visitor_authorization_repository.dart';
import 'package:taji/features/visitors/models/visitor_authorization.dart';
import 'package:taji/features/visitors/state/visitor_authorization_controller.dart';

class _FakeRepository implements VisitorAuthorizationDataSource {
  final List<VisitorAuthorization> items = [];
  bool fail = false;

  @override
  Future<List<VisitorAuthorization>> list() async => List.of(items);

  @override
  Future<List<ResidentUnit>> listActiveUnits() async => const [
    ResidentUnit(id: 10, code: 'Torre A - 101'),
  ];

  @override
  Future<List<ActiveResident>> listActiveResidents() async => const [
    ActiveResident(id: 1, fullName: 'Ana Pérez', documentNumber: '123456'),
  ];

  @override
  Future<VisitorAuthorization> create(VisitorAuthorizationInput input) async {
    if (fail) throw StateError('error');
    final item = VisitorAuthorization(
      id: items.length + 1,
      visitorName: '${input.visitorFirstName} ${input.visitorLastName}',
      documentId: input.documentId,
      unitId: input.unitId,
      unit: 'Torre A - 101',
      reason: input.reason,
      validFrom: input.validFrom,
      validUntil: input.validUntil,
      status: 'AUTHORIZED',
    );
    items.add(item);
    return item;
  }

  @override
  Future<VisitorAuthorization> cancel(int id) async {
    final current = items.firstWhere((item) => item.id == id);
    final cancelled = VisitorAuthorization(
      id: current.id,
      visitorName: current.visitorName,
      documentId: current.documentId,
      unitId: current.unitId,
      unit: current.unit,
      reason: current.reason,
      validFrom: current.validFrom,
      validUntil: current.validUntil,
      status: 'CANCELLED',
      cancelledAt: DateTime.now(),
    );
    items[items.indexOf(current)] = cancelled;
    return cancelled;
  }
}

void main() {
  VisitorAuthorizationInput input({DateTime? until}) =>
      VisitorAuthorizationInput(
        visitorFirstName: 'Ana',
        visitorLastName: 'Pérez',
        documentType: 'CI',
        documentId: '123456',
        phone: '71234567',
        unitId: 10,
        reason: 'Reunión familiar',
        validFrom: DateTime.now().add(const Duration(minutes: 5)),
        validUntil: until ?? DateTime.now().add(const Duration(hours: 1)),
      );

  test('registra una autorización completa', () async {
    final repository = _FakeRepository();
    final controller = VisitorAuthorizationController(repository);

    expect(await controller.add(input()), isTrue);
    expect(controller.authorizations, hasLength(1));
    expect(controller.authorizations.single.visitorName, 'Ana Pérez');
    expect(controller.authorizations.single.isCancelled, isFalse);
  });

  test('no agrega registros cuando la operación es inválida', () {
    final controller = VisitorAuthorizationController(_FakeRepository());

    expect(
      () => controller.add(
        input(until: DateTime.now().subtract(const Duration(hours: 1))),
      ),
      throwsArgumentError,
    );
    expect(controller.authorizations, isEmpty);
  });

  test('cancela una autorización sin eliminarla del historial', () async {
    final repository = _FakeRepository();
    final controller = VisitorAuthorizationController(repository);
    await controller.add(input());

    expect(await controller.cancel(1), isTrue);
    expect(controller.authorizations.single.isCancelled, isTrue);
  });
}
