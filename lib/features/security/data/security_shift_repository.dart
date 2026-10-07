import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';

class CurrentSecurityShift {
  const CurrentSecurityShift({this.shift, this.message = ''});
  final SecurityShiftModel? shift;
  final String message;
}

abstract class SecurityShiftDataSource {
  Future<CurrentSecurityShift> current();
  Future<List<SecurityShiftModel>> upcoming();
  Future<List<SecurityShiftModel>> history();
  Future<SecurityShiftModel> start(int id, {String notes = ''});
  Future<SecurityShiftModel> close(int id, {String notes = ''});
}

class SecurityShiftRepository implements SecurityShiftDataSource {
  const SecurityShiftRepository(this._api);
  final ApiClient _api;

  @override
  Future<CurrentSecurityShift> current() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.securityShifts.current,
      );
      if (data == null) throw _invalidResponse;
      if (data['id'] != null) return CurrentSecurityShift(shift: _shift(data));
      if (data['shift'] is Map) {
        return CurrentSecurityShift(
          shift: _shift(Map<String, dynamic>.from(data['shift'] as Map)),
        );
      }
      if (data.containsKey('shift') && data['shift'] == null) {
        return CurrentSecurityShift(
          message:
              data['message']?.toString() ??
              'No tienes un turno asignado para hoy.',
        );
      }
      throw _invalidResponse;
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar tu turno actual.',
      );
    }
  }

  @override
  Future<List<SecurityShiftModel>> upcoming() =>
      _list(ApiEndpoints.securityShifts.upcoming);

  @override
  Future<List<SecurityShiftModel>> history() =>
      _list(ApiEndpoints.securityShifts.history);

  Future<List<SecurityShiftModel>> _list(String path) async {
    try {
      final data = await _api.get<dynamic>(path);
      final items = data is List
          ? data
          : data is Map
          ? data['results']
          : null;
      if (items is! List) throw _invalidResponse;
      return items.map((item) {
        if (item is! Map) throw _invalidResponse;
        return _shift(Map<String, dynamic>.from(item));
      }).toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar tus turnos.',
      );
    }
  }

  @override
  Future<SecurityShiftModel> start(int id, {String notes = ''}) =>
      _action(ApiEndpoints.securityShifts.start(id), notes);

  @override
  Future<SecurityShiftModel> close(int id, {String notes = ''}) =>
      _action(ApiEndpoints.securityShifts.close(id), notes);

  Future<SecurityShiftModel> _action(String path, String notes) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        path,
        data: {'notes': notes.trim()},
      );
      if (data == null) throw _invalidResponse;
      return _shift(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos registrar el cambio de turno.',
      );
    }
  }

  SecurityShiftModel _shift(Map<String, dynamic> data) {
    try {
      return SecurityShiftModel.fromJson(data);
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de turno incompletos.',
  );
}
