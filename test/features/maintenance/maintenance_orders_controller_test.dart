import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taji/features/maintenance/data/maintenance_order_repository.dart';
import 'package:taji/features/maintenance/state/maintenance_orders_controller.dart';

void main() {
  late _FakeMaintenanceOrderDataSource source;
  late MaintenanceOrdersController controller;

  setUp(() {
    source = _FakeMaintenanceOrderDataSource();
    controller = MaintenanceOrdersController(source);
  });

  test(
    'disposal drops pending results without notifying a dead screen',
    () async {
      source.pending =
          Completer<({List<MaintenanceWorkOrder> items, int pages})>();
      final request = controller.refresh();
      controller.dispose();
      source.pending!.complete((items: [_order(status: 'ASSIGNED')], pages: 1));
      await request;
      expect(controller.orders, isEmpty);
    },
  );

  test('pagination rejects requests outside the valid page range', () async {
    source.pageCount = 3;
    await controller.refresh();
    await controller.goToPage(2);
    expect(source.lastPage, 2);
    await controller.goToPage(4);
    expect(source.lastPage, 2);
  });

  test(
    'loads and updates a work order after a valid status transition',
    () async {
      final assigned = _order(status: 'ASSIGNED');
      source.orders = [assigned];

      await controller.refresh();
      final changed = await controller.changeStatus(
        assigned,
        status: 'IN_PROGRESS',
        notes: 'Trabajo iniciado',
      );

      expect(changed, isTrue);
      expect(source.lastStatus, 'IN_PROGRESS');
      expect(source.lastNotes, 'Trabajo iniciado');
      expect(controller.orders.single.status, 'IN_PROGRESS');
      expect(controller.success, 'Estado actualizado correctamente.');
    },
  );

  test(
    'rejects invalid status transitions without calling the data source',
    () async {
      final pending = _order(status: 'PENDING');
      source.orders = [pending];
      await controller.refresh();

      final changed = await controller.changeStatus(
        pending,
        status: 'COMPLETED',
      );

      expect(changed, isFalse);
      expect(source.statusCalls, 0);
      expect(controller.orders.single.status, 'PENDING');
    },
  );

  test('does not upload evidence for a closed work order', () async {
    final completed = _order(status: 'COMPLETED');
    source.orders = [completed];
    await controller.refresh();

    final uploaded = await controller.uploadEvidence(
      completed,
      file: XFile('evidence.jpg'),
    );

    expect(uploaded, isFalse);
    expect(source.evidenceCalls, 0);
  });
}

MaintenanceWorkOrder _order({required String status}) => MaintenanceWorkOrder(
  id: 17,
  publicCode: 'OT-00017',
  title: 'Revisión de bomba',
  description: 'Inspección de rutina',
  status: status,
  workType: 'PREVENTIVE',
  assetCode: 'ACT-001',
  assetName: 'Bomba hidráulica',
  assigneeName: 'Técnico',
  supplierName: '',
  scheduledFor: null,
  startedAt: null,
  completedAt: null,
  estimatedCost: '100.00',
  actualCost: null,
  evidence: const [],
  statusHistory: const [],
);

class _FakeMaintenanceOrderDataSource implements MaintenanceOrderDataSource {
  Completer<({List<MaintenanceWorkOrder> items, int pages})>? pending;
  int pageCount = 1, lastPage = 1;
  List<MaintenanceWorkOrder> orders = [];
  int statusCalls = 0;
  int evidenceCalls = 0;
  String? lastStatus;
  String? lastNotes;

  @override
  Future<({List<MaintenanceWorkOrder> items, int pages})> listOrders({
    int page = 1,
  }) async {
    lastPage = page;
    return pending != null
        ? pending!.future
        : (items: orders, pages: pageCount);
  }

  @override
  Future<MaintenanceWorkOrder> changeStatus(
    int id, {
    required String status,
    String notes = '',
  }) async {
    statusCalls++;
    lastStatus = status;
    lastNotes = notes;
    final updated = _order(status: status);
    orders = [updated];
    return updated;
  }

  @override
  Future<MaintenanceWorkOrder> uploadEvidence(
    int id, {
    required XFile file,
    String caption = '',
  }) async {
    evidenceCalls++;
    return orders.single;
  }
}
