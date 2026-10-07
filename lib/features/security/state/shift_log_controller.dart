import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';
import '../data/security_shift_repository.dart';
import '../data/shift_log_repository.dart';

class ShiftLogController extends ChangeNotifier {
  ShiftLogController(this._logs, this._shifts);
  final ShiftLogDataSource _logs;
  final SecurityShiftDataSource _shifts;
  bool _disposed = false;
  bool _fresh = false;
  bool loading = false;
  bool saving = false;
  bool showHistory = false;
  int page = 1;
  int pages = 1;
  SecurityShiftModel? current;
  List<ShiftLogEntryModel> entries = [];
  String? error;
  String? formError;
  String? success;
  bool get canRegister =>
      _fresh &&
      !loading &&
      !saving &&
      !showHistory &&
      current?.status == 'OPEN';

  Future<void> setHistory(bool value) async {
    if (loading || saving || showHistory == value) return;
    showHistory = value;
    entries = [];
    await refresh();
  }

  Future<void> refresh({int nextPage = 1}) async {
    if (_disposed || loading || saving) return;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _shifts.current();
      if (_disposed) return;
      current = result.shift;
      if (!showHistory && current == null) {
        entries = [];
        page = 1;
        pages = 1;
      } else {
        final result = await _logs.list(
          shift: showHistory ? null : current!.id,
          page: nextPage,
        );
        if (_disposed) return;
        entries = result.entries;
        page = result.page;
        pages = result.pages;
      }
      _fresh = true;
    } on Object catch (failure) {
      _fresh = false;
      error = _message(failure, 'No pudimos actualizar las novedades.');
    } finally {
      loading = false;
      _notify();
    }
  }

  void clearFormError() {
    formError = null;
    _notify();
  }

  Future<bool> create({
    required String type,
    required String severity,
    required String title,
    required String description,
    int? expectedShift,
  }) async {
    if (_disposed || saving || loading) return false;
    formError = null;
    if (!canRegister) {
      formError = 'Debes tener un turno en curso para registrar novedades.';
      _notify();
      return false;
    }
    if (expectedShift != null && expectedShift != current!.id) {
      formError = 'Tu turno cambió. Vuelve a la lista antes de registrar.';
      _notify();
      return false;
    }
    if (!ShiftLogEntryModel.types.containsKey(type) ||
        !ShiftLogEntryModel.severities.containsKey(severity) ||
        title.trim().isEmpty ||
        title.trim().length > 120 ||
        description.trim().isEmpty ||
        description.trim().length > 5000) {
      formError =
          'Completa el tipo, la prioridad, el título (máximo 120) y la descripción (máximo 5000).';
      _notify();
      return false;
    }
    saving = true;
    success = null;
    _notify();
    try {
      final entry = await _logs.create(
        type: type,
        severity: severity,
        title: title.trim(),
        description: description.trim(),
        expectedShift: current!.id,
      );
      if (_disposed) return true;
      entries = [entry, ...entries];
      success = 'Registro guardado en tu turno.';
      return true;
    } on Object catch (failure) {
      formError = _message(failure, 'No pudimos guardar el registro.');
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  String _message(Object failure, String fallback) {
    if (failure is ApiFailure) {
      final fields = failure.fields.values.expand((items) => items).join(' ');
      return fields.isEmpty ? failure.displayMessage : fields;
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
