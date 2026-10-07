import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';
import '../data/security_shift_repository.dart';

class SecurityShiftController extends ChangeNotifier {
  SecurityShiftController(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SecurityShiftDataSource _repository;
  final DateTime Function() _clock;
  Duration _serverOffset = Duration.zero;
  Timer? _ticker;
  bool _disposed = false;
  bool _fresh = false;
  bool loading = false;
  bool busy = false;
  String? error;
  String? actionError;
  String? success;
  SecurityShiftModel? currentShift;
  String currentMessage = '';
  List<SecurityShiftModel> upcoming = const [];
  List<SecurityShiftModel> history = const [];

  DateTime get now => _clock().add(_serverOffset);
  bool get canStart =>
      _fresh &&
      !loading &&
      !busy &&
      currentShift != null &&
      currentShift!.startBlockReason(now).isEmpty;
  bool get canClose =>
      _fresh && !loading && !busy && currentShift?.status == 'OPEN';
  bool get closeReasonRequired =>
      currentShift?.closeReasonRequired(now) ?? false;

  Future<void> initialize() async {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed || loading || busy) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _load();
    } on Object catch (failure) {
      _fresh = false;
      error = _message(
        failure,
        'No pudimos actualizar tus turnos. Inténtalo nuevamente.',
      );
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      _repository.current(),
      _repository.upcoming(),
      _repository.history(),
    ]);
    if (_disposed) return;
    final current = results[0] as CurrentSecurityShift;
    currentShift = current.shift;
    currentMessage = current.message;
    upcoming = results[1] as List<SecurityShiftModel>;
    history = results[2] as List<SecurityShiftModel>;
    final shifts = [
      if (currentShift != null) currentShift!,
      ...upcoming,
      ...history,
    ];
    final times = shifts.map((shift) => shift.serverTime).whereType<DateTime>();
    _serverOffset = times.isEmpty
        ? Duration.zero
        : times.first.difference(_clock());
    _fresh = true;
  }

  void clearActionError() {
    actionError = null;
    _notify();
  }

  Future<bool> start({String notes = ''}) => _act(starting: true, notes: notes);
  Future<bool> close({String notes = ''}) =>
      _act(starting: false, notes: notes);

  Future<bool> _act({required bool starting, required String notes}) async {
    final shift = currentShift;
    if (_disposed || shift == null || busy || loading || !_fresh) return false;
    actionError = null;
    final reason = starting ? shift.startBlockReason(now) : '';
    if (reason.isNotEmpty) {
      actionError = reason;
      _notify();
      return false;
    }
    if (!starting && shift.status != 'OPEN') return false;
    final cleanNotes = notes.trim();
    if (!starting && closeReasonRequired && cleanNotes.isEmpty) {
      actionError =
          'Indica el motivo del cierre anticipado o posterior al horario.';
      _notify();
      return false;
    }
    busy = true;
    error = null;
    success = null;
    _notify();
    try {
      final updated = starting
          ? await _repository.start(shift.id, notes: cleanNotes)
          : await _repository.close(shift.id, notes: cleanNotes);
      if (_disposed) return true;
      currentShift = updated;
      success = starting
          ? 'Turno iniciado correctamente.'
          : 'Turno cerrado correctamente.';
      try {
        await _load();
      } on Object {
        _fresh = false;
        error =
            'El cambio se guardó, pero no pudimos actualizar la lista. Pulsa Actualizar.';
      }
      return true;
    } on Object catch (failure) {
      actionError = _message(failure, 'No pudimos guardar el cambio de turno.');
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  String _message(Object failure, String fallback) {
    if (failure is ApiFailure) {
      final notes = failure.fields['notes'];
      return notes?.isNotEmpty == true
          ? notes!.join(' ')
          : failure.displayMessage;
    }
    return fallback;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
