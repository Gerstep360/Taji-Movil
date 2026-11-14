import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_failure.dart';
import '../data/maintenance_order_repository.dart';

class MaintenanceOrdersController extends ChangeNotifier {
  MaintenanceOrdersController(this._repository);

  final MaintenanceOrderDataSource _repository;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  int page = 1, pages = 1;
  Future<void> goToPage(int next) async {
    if (_disposed || loading || busy || next < 1 || next > pages) return;
    page = next;
    await refresh();
  }

  bool loading = false;
  bool busy = false;
  String? error;
  String? success;
  List<MaintenanceWorkOrder> orders = const [];

  Future<void> refresh() async {
    if (_disposed || loading || busy) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _repository.listOrders(page: page);
      if (_disposed) return;
      orders = response.items;
      pages = response.pages < 1 ? 1 : response.pages;
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos cargar tus órdenes.');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> changeStatus(
    MaintenanceWorkOrder order, {
    required String status,
    String notes = '',
  }) async {
    if (_disposed ||
        busy ||
        loading ||
        !_allowedTransition(order.status, status)) {
      return false;
    }
    return _runAction(
      () => _repository.changeStatus(order.id, status: status, notes: notes),
      status == 'COMPLETED'
          ? 'Orden completada correctamente.'
          : 'Estado actualizado correctamente.',
    );
  }

  Future<bool> uploadEvidence(
    MaintenanceWorkOrder order, {
    required XFile file,
    String caption = '',
  }) async {
    if (_disposed || busy || loading || _isClosed(order.status)) return false;
    return _runAction(
      () => _repository.uploadEvidence(order.id, file: file, caption: caption),
      'Evidencia adjuntada correctamente.',
    );
  }

  Future<bool> _runAction(
    Future<MaintenanceWorkOrder> Function() action,
    String successMessage,
  ) async {
    busy = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final updated = await action();
      orders = orders
          .map((order) => order.id == updated.id ? updated : order)
          .toList(growable: false);
      success = successMessage;
      return true;
    } on Object catch (failure) {
      error = _message(failure, 'No se pudo guardar el cambio.');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _message(Object failure, String fallback) =>
      failure is ApiFailure ? failure.displayMessage : fallback;

  bool _isClosed(String status) =>
      status == 'COMPLETED' || status == 'CANCELLED';

  bool _allowedTransition(String current, String next) => switch (current) {
    'ASSIGNED' => next == 'IN_PROGRESS',
    'IN_PROGRESS' => next == 'PAUSED' || next == 'COMPLETED',
    'PAUSED' => next == 'IN_PROGRESS',
    _ => false,
  };
}
