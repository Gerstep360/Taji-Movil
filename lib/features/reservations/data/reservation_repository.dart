// CU27: reservas de áreas comunes (T121 consulta/disponibilidad, T122 solicitud/cancelación).
// Backend: /api/v1/paquete5/cu27/
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';

class Cu27Endpoints {
  const Cu27Endpoints._();

  static const areas = '/paquete5/cu27/areas/';
  static String availability(int areaId) => '/paquete5/cu27/areas/$areaId/availability/';
  static const reservations = '/paquete5/cu27/reservations/';
  static String cancel(int id) => '/paquete5/cu27/reservations/$id/cancel/';
}

int _int(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

String _str(Object? value) => value?.toString() ?? '';

int _bounded(int value, int min, int max) => value < min ? min : (value > max ? max : value);

DateTime? _date(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false)
    : const [];

class AreaSchedule {
  const AreaSchedule({required this.weekday, required this.opensAt, required this.closesAt});

  /// 0 = lunes … 6 = domingo (igual que el backend).
  final int weekday;
  final String opensAt;
  final String closesAt;

  factory AreaSchedule.fromJson(Map<String, dynamic> json) => AreaSchedule(
    weekday: _int(json['weekday']),
    opensAt: _str(json['opens_at']),
    closesAt: _str(json['closes_at']),
  );
}

class ReservableArea {
  const ReservableArea({
    required this.id,
    required this.name,
    required this.description,
    required this.sectorName,
    required this.capacity,
    required this.requiresApproval,
    required this.status,
    required this.statusLabel,
    required this.bookable,
    required this.schedules,
  });

  final int id;
  final String name;
  final String description;
  final String sectorName;
  final int? capacity;
  final bool requiresApproval;
  final String status;
  final String statusLabel;
  final bool bookable;
  final List<AreaSchedule> schedules;

  factory ReservableArea.fromJson(Map<String, dynamic> json) => ReservableArea(
    id: _int(json['id']),
    name: _str(json['name']),
    description: _str(json['description']),
    sectorName: _str(json['sector_name']),
    capacity: json['capacity'] == null ? null : _int(json['capacity']),
    requiresApproval: json['requires_approval'] == true,
    status: _str(json['status']),
    statusLabel: _str(json['status_label']),
    bookable: json['bookable'] == true,
    schedules: _maps(json['schedules']).map(AreaSchedule.fromJson).toList(growable: false),
  );
}

class TimeRange {
  const TimeRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  static TimeRange? fromJson(Map<String, dynamic> json) {
    final start = _date(json['start']);
    final end = _date(json['end']);
    return start == null || end == null ? null : TimeRange(start, end);
  }
}

class OccupiedRange {
  const OccupiedRange({required this.range, required this.kind, required this.status, required this.mine, required this.label});

  final TimeRange range;
  final String kind;
  final String status;
  final bool mine;
  final String label;

  bool get isBlock => kind == 'BLOCK';
}

class AreaAvailability {
  const AreaAvailability({
    required this.date,
    required this.bookable,
    required this.reason,
    required this.requiresApproval,
    required this.minDuration,
    required this.maxDuration,
    required this.free,
    required this.occupied,
  });

  final DateTime date;
  final bool bookable;
  final String reason;
  final bool requiresApproval;
  final Duration minDuration;
  final Duration maxDuration;
  final List<TimeRange> free;
  final List<OccupiedRange> occupied;

  factory AreaAvailability.fromJson(Map<String, dynamic> json) {
    final area = json['area'] is Map ? Map<String, dynamic>.from(json['area'] as Map) : const <String, dynamic>{};
    final date = DateTime.tryParse(_str(json['date'])) ?? DateTime.now();
    return AreaAvailability(
      date: DateTime(date.year, date.month, date.day),
      bookable: json['bookable'] == true,
      reason: _str(json['reason']),
      requiresApproval: area['requires_approval'] == true,
      minDuration: Duration(minutes: _bounded(_int(json['min_duration_minutes']), 15, 24 * 60)),
      maxDuration: Duration(minutes: _bounded(_int(json['max_duration_minutes']), 30, 24 * 60)),
      free: _maps(json['free']).map(TimeRange.fromJson).whereType<TimeRange>().toList(growable: false),
      occupied: _maps(json['occupied'])
          .map((item) {
            final range = TimeRange.fromJson(item);
            if (range == null) return null;
            return OccupiedRange(
              range: range,
              kind: _str(item['kind']),
              status: _str(item['status']),
              mine: item['mine'] == true,
              label: _str(item['label']),
            );
          })
          .whereType<OccupiedRange>()
          .toList(growable: false),
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.residentName,
    required this.start,
    required this.end,
    required this.status,
    required this.statusLabel,
    required this.purpose,
    required this.rejectionReason,
    required this.cancellationReason,
    required this.canCancel,
    required this.createdAt,
  });

  final int id;
  final int areaId;
  final String areaName;
  final String residentName;
  final DateTime start;
  final DateTime end;
  final String status;
  final String statusLabel;
  final String purpose;
  final String rejectionReason;
  final String cancellationReason;
  final bool canCancel;
  final DateTime? createdAt;

  bool get isActive => status == 'PENDING' || status == 'APPROVED';

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final start = _date(json['start_at']);
    final end = _date(json['end_at']);
    if (start == null || end == null) throw const FormatException('Reserva sin horario');
    final permissions = json['permissions'] is Map ? Map<String, dynamic>.from(json['permissions'] as Map) : const <String, dynamic>{};
    return Reservation(
      id: _int(json['id']),
      areaId: _int(json['common_area']),
      areaName: _str(json['common_area_name']),
      residentName: _str(json['resident_name']),
      start: start,
      end: end,
      status: _str(json['status']),
      statusLabel: _str(json['status_label']),
      purpose: _str(json['purpose']),
      rejectionReason: _str(json['rejection_reason']),
      cancellationReason: _str(json['cancellation_reason']),
      canCancel: permissions['cancel'] == true,
      createdAt: _date(json['created_at']),
    );
  }
}

abstract class ReservationDataSource {
  Future<List<ReservableArea>> listAreas();
  Future<AreaAvailability> availability(int areaId, DateTime day);
  Future<List<Reservation>> myReservations({required bool upcoming});
  Future<Reservation> create({required int areaId, required DateTime start, required DateTime end, String purpose = ''});
  Future<Reservation> cancel(int id, {String reason = ''});
}

class ReservationRepository implements ReservationDataSource {
  ReservationRepository(this._api);

  final ApiClient _api;

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Future<List<ReservableArea>> listAreas() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(Cu27Endpoints.areas, query: {'page_size': 100});
      return _results(response).map(ReservableArea.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos cargar las áreas comunes.');
    } on FormatException {
      throw _invalid;
    }
  }

  @override
  Future<AreaAvailability> availability(int areaId, DateTime day) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(Cu27Endpoints.availability(areaId), query: {'date': dateKey(day)});
      if (response == null) throw _invalid;
      return AreaAvailability.fromJson(response);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos consultar la disponibilidad.');
    }
  }

  @override
  Future<List<Reservation>> myReservations({required bool upcoming}) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(Cu27Endpoints.reservations, query: {
        'mine': 'true',
        'when': upcoming ? 'upcoming' : 'past',
        'ordering': upcoming ? 'start_at' : '-start_at',
        'page_size': 50,
      });
      return _results(response).map(Reservation.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos cargar tus reservas.');
    } on FormatException {
      throw _invalid;
    }
  }

  @override
  Future<Reservation> create({required int areaId, required DateTime start, required DateTime end, String purpose = ''}) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(Cu27Endpoints.reservations, data: {
        'common_area': areaId,
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'purpose': purpose.trim(),
      });
      if (response == null) throw _invalid;
      return Reservation.fromJson(response);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos registrar la reserva.');
    } on FormatException {
      throw _invalid;
    }
  }

  @override
  Future<Reservation> cancel(int id, {String reason = ''}) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(Cu27Endpoints.cancel(id), data: {'reason': reason.trim()});
      if (response == null) throw _invalid;
      return Reservation.fromJson(response);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos cancelar la reserva.');
    } on FormatException {
      throw _invalid;
    }
  }

  List<Map<String, dynamic>> _results(Map<String, dynamic>? response) {
    if (response == null || response['results'] is! List) throw _invalid;
    return _maps(response['results']);
  }

  static const _invalid = ApiFailure(code: 'invalid_response', message: 'El servidor devolvió datos de reservas incompletos.');
}
