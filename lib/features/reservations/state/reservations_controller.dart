import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/reservation_repository.dart';

/// Paso con el que se ofrecen horas de inicio y duraciones.
const slotStep = Duration(minutes: 30);

/// Horas de inicio posibles dentro de un rango libre, alineadas a [slotStep]
/// y dejando espacio para la duración mínima.
List<DateTime> startOptions(TimeRange free, Duration minDuration) {
  final stepMinutes = slotStep.inMinutes;
  final startMinutes = free.start.hour * 60 + free.start.minute;
  final exact = free.start.second == 0 && free.start.millisecond == 0 && free.start.microsecond == 0;
  final aligned = startMinutes % stepMinutes == 0 && exact
      ? free.start
      : DateTime(free.start.year, free.start.month, free.start.day)
          .add(Duration(minutes: (startMinutes ~/ stepMinutes + 1) * stepMinutes));
  final options = <DateTime>[];
  for (var current = aligned; !current.add(minDuration).isAfter(free.end); current = current.add(slotStep)) {
    options.add(current);
  }
  return options;
}

/// Duraciones posibles desde [start] sin salir del rango libre ni del máximo.
List<Duration> durationOptions(TimeRange free, DateTime start, Duration minDuration, Duration maxDuration) {
  final available = free.end.difference(start);
  final options = <Duration>[];
  for (var d = minDuration; d <= maxDuration && d <= available; d += slotStep) {
    options.add(d);
  }
  return options;
}

class ReservationsController extends ChangeNotifier {
  ReservationsController(this._repository);

  final ReservationDataSource _repository;

  List<ReservableArea> areas = const [];
  ReservableArea? selectedArea;
  DateTime selectedDay = _today();
  AreaAvailability? availability;
  List<Reservation> upcoming = const [];
  List<Reservation> past = const [];

  bool loadingAreas = false;
  bool loadingAvailability = false;
  bool loadingMine = false;
  bool busy = false;
  String? error;
  String? success;
  int _availabilityRequest = 0;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Días que se ofrecen en la tira de fechas (hoy + 20 días).
  List<DateTime> get dayOptions => List.generate(21, (i) => _today().add(Duration(days: i)));

  Future<void> initialize() async {
    await Future.wait([loadAreas(), loadMine()]);
  }

  Future<void> loadAreas() async {
    if (loadingAreas) return;
    loadingAreas = true;
    error = null;
    notifyListeners();
    try {
      areas = await _repository.listAreas();
      final previousId = selectedArea?.id;
      selectedArea = _first(areas, (a) => a.id == previousId) ?? _first(areas, (a) => a.bookable) ?? _first(areas, (_) => true);
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos cargar las áreas comunes.');
    } finally {
      loadingAreas = false;
      notifyListeners();
    }
    await loadAvailability();
  }

  Future<void> loadAvailability() async {
    final area = selectedArea;
    if (area == null) {
      availability = null;
      notifyListeners();
      return;
    }
    final request = ++_availabilityRequest;
    loadingAvailability = true;
    notifyListeners();
    try {
      final result = await _repository.availability(area.id, selectedDay);
      if (request != _availabilityRequest) return; // llegó una respuesta más nueva
      availability = result;
    } on Object catch (failure) {
      if (request != _availabilityRequest) return;
      availability = null;
      error = _message(failure, 'No pudimos consultar la disponibilidad.');
    } finally {
      if (request == _availabilityRequest) {
        loadingAvailability = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMine() async {
    if (loadingMine) return;
    loadingMine = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.myReservations(upcoming: true),
        _repository.myReservations(upcoming: false),
      ]);
      upcoming = results[0];
      past = results[1];
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos cargar tus reservas.');
    } finally {
      loadingMine = false;
      notifyListeners();
    }
  }

  void selectArea(ReservableArea area) {
    if (selectedArea?.id == area.id) return;
    selectedArea = area;
    availability = null;
    loadAvailability();
  }

  void selectDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized == selectedDay) return;
    selectedDay = normalized;
    availability = null;
    loadAvailability();
  }

  Future<Reservation?> create({required DateTime start, required DateTime end, String purpose = ''}) async {
    final area = selectedArea;
    if (area == null || busy) return null;
    busy = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final created = await _repository.create(areaId: area.id, start: start, end: end, purpose: purpose);
      success = created.status == 'PENDING'
          ? 'Solicitud enviada. La administración debe aprobarla.'
          : 'Reserva confirmada.';
      await Future.wait([loadAvailability(), loadMine()]);
      return created;
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos registrar la reserva.');
      await loadAvailability();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> cancel(Reservation reservation, {String reason = ''}) async {
    if (busy || !reservation.canCancel) return false;
    busy = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      await _repository.cancel(reservation.id, reason: reason);
      success = 'Reserva cancelada.';
      await Future.wait([loadMine(), loadAvailability()]);
      return true;
    } on Object catch (failure) {
      error = _message(failure, 'No pudimos cancelar la reserva.');
      await loadMine();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    error = null;
    success = null;
    notifyListeners();
  }

  String _message(Object failure, String fallback) => failure is ApiFailure ? failure.displayMessage : fallback;

  static T? _first<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
