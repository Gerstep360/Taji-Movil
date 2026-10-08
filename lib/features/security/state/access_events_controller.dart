import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/models/access_event_models.dart';
import '../data/access_event_repository.dart';

class AccessEventsController extends ChangeNotifier {
  AccessEventsController(this._source);

  final AccessEventDataSource _source;
  bool _disposed = false;
  bool loading = false;
  int page = 1;
  int pages = 1;
  String? eventType;
  String? error;
  List<AccessEventItemModel> events = [];

  bool get canRegister => !loading;

  Future<void> refresh({int nextPage = 1}) async {
    if (_disposed || loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _source.list(page: nextPage, eventType: eventType);
      if (_disposed) return;
      events = result.events;
      page = result.page;
      pages = result.pages;
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos cargar el historial de accesos.');
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> filterBy(String? value) async {
    if (_disposed || loading || eventType == value) return;
    eventType = value;
    events = [];
    await refresh();
  }

  String _message(Object failure, String fallback) {
    if (failure is ApiFailure) {
      final fieldMessages = failure.fields.values
          .expand((messages) => messages)
          .join(' ');
      return fieldMessages.isEmpty ? failure.displayMessage : fieldMessages;
    }
    return fallback;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AccessEventRegistrationController extends ChangeNotifier {
  AccessEventRegistrationController(this._source);

  final AccessEventDataSource _source;
  bool _disposed = false;
  bool saving = false;
  String? error;

  Future<bool> create({
    required bool isRegistered,
    int? personId,
    String visitorName = '',
    String visitorDocumentNumber = '',
    required int? unitId,
    required String eventType,
    required String validationMethod,
    required String notes,
  }) async {
    if (_disposed || saving) return false;
    error = null;
    if (isRegistered && (personId == null || personId <= 0)) {
      error = 'Busca y selecciona una persona registrada.';
    } else if (!isRegistered &&
        (visitorName.trim().isEmpty || visitorDocumentNumber.trim().isEmpty)) {
      error = 'Completa el nombre y el número de carnet del visitante.';
    } else if (unitId == null || unitId <= 0) {
      error = 'Busca y selecciona la casa o unidad de destino.';
    } else if (!_eventTypes.contains(eventType)) {
      error = 'Selecciona Entrada, Salida o Acceso denegado.';
    } else if (!_validationMethods.contains(validationMethod)) {
      error = 'Selecciona un método de validación.';
    } else if (notes.trim().length > 300) {
      error = 'Las observaciones no pueden superar 300 caracteres.';
    }
    if (error != null) {
      _notify();
      return false;
    }

    saving = true;
    _notify();
    try {
      await _source.create(
        personId: isRegistered ? personId : null,
        visitorName: isRegistered ? '' : visitorName.trim(),
        visitorDocumentNumber: isRegistered ? '' : visitorDocumentNumber.trim(),
        unitId: unitId!,
        eventType: eventType,
        validationMethod: validationMethod,
        notes: notes.trim(),
      );
      return true;
    } on Object catch (failure) {
      error = _message(failure);
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  String _message(Object failure) {
    if (failure is ApiFailure) {
      final fieldMessages = failure.fields.values
          .expand((messages) => messages)
          .join(' ');
      return fieldMessages.isEmpty
          ? failure.displayMessage
          : fieldMessages;
    }
    return 'No pudimos registrar el acceso.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static const _eventTypes = {'ENTRY', 'EXIT', 'DENIED'};
  static const _validationMethods = {'MANUAL', 'QR', 'FACE'};

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}