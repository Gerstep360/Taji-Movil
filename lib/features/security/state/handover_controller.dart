import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';
import '../data/handover_repository.dart';
import '../data/security_shift_repository.dart';

class HandoverController extends ChangeNotifier {
  HandoverController(this._source, this._shifts);
  final HandoverDataSource _source;
  final SecurityShiftDataSource _shifts;
  bool _disposed = false;
  bool _fresh = false;
  bool loading = false;
  bool preparing = false;
  bool busy = false;
  SecurityShiftModel? current;
  ShiftHandoverModel? outgoingHandover;
  ShiftHandoverModel? selected;
  List<ShiftHandoverModel> entries = [];
  List<SecurityShiftModel> candidates = [];
  List<ShiftLogEntryModel> records = [];
  int? preparedShift;
  int page = 1;
  int pages = 1;
  String? error;
  String? formError;
  String? success;
  bool get canDeliver =>
      _fresh &&
      !loading &&
      !busy &&
      !preparing &&
      current?.status == 'OPEN' &&
      outgoingHandover == null;
  bool canReceive(ShiftHandoverModel entry) =>
      _fresh &&
      !loading &&
      !busy &&
      current?.status == 'OPEN' &&
      entry.status == 'PENDING' &&
      entry.incomingShiftId == current?.id;

  Future<void> _load(int nextPage) async {
    final shift = await _shifts.current();
    final results = await Future.wait<HandoverPage>([
      _source.list(page: nextPage),
      if (shift.shift != null) _source.list(outgoingShift: shift.shift!.id),
    ]);
    if (_disposed) return;
    current = shift.shift;
    entries = results.first.entries;
    page = results.first.page;
    pages = results.first.pages;
    outgoingHandover = results.length > 1 && results[1].entries.isNotEmpty
        ? results[1].entries.first
        : null;
    _fresh = true;
  }

  Future<void> refresh({int nextPage = 1}) async {
    if (_disposed || loading || busy || preparing) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _load(nextPage);
    } on Object catch (failure) {
      _fresh = false;
      error = _message(failure);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> prepare() async {
    if (!canDeliver || _disposed) return false;
    final id = current!.id;
    preparing = true;
    error = null;
    formError = null;
    preparedShift = null;
    _notify();
    try {
      final result = await Future.wait<Object>([
        _source.candidates(id),
        _source.records(id),
      ]);
      if (_disposed) return false;
      candidates = result[0] as List<SecurityShiftModel>;
      records = result[1] as List<ShiftLogEntryModel>;
      preparedShift = id;
      return true;
    } on Object catch (failure) {
      error = _message(failure);
      return false;
    } finally {
      preparing = false;
      _notify();
    }
  }

  Future<bool> loadDetail(int id) async {
    if (_disposed || loading || busy || preparing) return false;
    loading = true;
    error = null;
    formError = null;
    selected = null;
    _notify();
    try {
      final detail = await _source.detail(id);
      if (_disposed) return false;
      selected = detail;
      return true;
    } on Object catch (failure) {
      error = _message(failure);
      return false;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> deliver(
    int incoming,
    String summary, {
    required int outgoing,
  }) async {
    if (_disposed || busy || loading || preparing) return false;
    formError = null;
    if (!canDeliver || current!.id != outgoing || preparedShift != outgoing) {
      formError = 'Tu turno cambió o ya fue entregado. Actualiza la lista.';
      _notify();
      return false;
    }
    if (!candidates.any((shift) => shift.id == incoming) ||
        summary.trim().isEmpty ||
        summary.trim().length > 5000) {
      formError =
          'Selecciona un relevo válido y completa el resumen (máximo 5000 caracteres).';
      _notify();
      return false;
    }
    return _act(
      () => _source.deliver(
        outgoingShift: outgoing,
        incomingShift: incoming,
        summary: summary.trim(),
      ),
      'Entrega registrada. Pendiente de recepción.',
    );
  }

  Future<bool> receive(
    ShiftHandoverModel entry, {
    required bool reviewed,
  }) async {
    if (_disposed || busy || loading || preparing) return false;
    formError = null;
    if (!reviewed || !canReceive(entry)) {
      formError =
          'Debes iniciar el turno destinatario y revisar la entrega antes de confirmar.';
      _notify();
      return false;
    }
    return _act(() => _source.receive(entry.id), 'Recepción confirmada.');
  }

  Future<bool> _act(
    Future<ShiftHandoverModel> Function() action,
    String message,
  ) async {
    busy = true;
    success = null;
    _notify();
    try {
      final saved = await action();
      if (_disposed) return true;
      selected = saved;
      success = message;
      try {
        await _load(1);
      } on Object {
        _fresh = false;
        error =
            'El cambio se guardó, pero no se pudo actualizar la lista. Pulsa Actualizar.';
      }
      return true;
    } on Object catch (failure) {
      formError = _message(failure);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  String _message(Object failure) {
    if (failure is ApiFailure) {
      final fields = failure.fields.values.expand((items) => items).join(' ');
      return fields.isEmpty ? failure.displayMessage : fields;
    }
    return 'No pudimos consultar o guardar la entrega. Inténtalo nuevamente.';
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
