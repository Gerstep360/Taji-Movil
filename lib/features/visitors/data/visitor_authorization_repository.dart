import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/visitor_authorization.dart';

abstract class VisitorAuthorizationDataSource {
  Future<List<VisitorAuthorization>> list();
  Future<List<ResidentUnit>> listActiveUnits();
  Future<List<ActiveResident>> listActiveResidents();
  Future<VisitorAuthorization> create(VisitorAuthorizationInput input);
  Future<VisitorAuthorization> cancel(int id);
}

class VisitorAuthorizationRepository implements VisitorAuthorizationDataSource {
  const VisitorAuthorizationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<VisitorAuthorization>> list() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.visitorAuthorizations.collection,
      );
      final results = data?['results'] as List? ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(VisitorAuthorization.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar las autorizaciones de visita.',
      );
    }
  }

  @override
  Future<List<ResidentUnit>> listActiveUnits() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.units.collection,
        query: {'status': 'ACTIVE', 'page_size': 100},
      );
      final results = data?['results'] as List? ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(ResidentUnit.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar las unidades disponibles.',
      );
    }
  }

  @override
  Future<List<ActiveResident>> listActiveResidents() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.residents.collection,
        query: {'status': 'ACTIVE', 'page_size': 100},
      );
      final results = data?['results'] as List? ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(ActiveResident.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar los residentes disponibles.',
      );
    }
  }

  @override
  Future<VisitorAuthorization> create(VisitorAuthorizationInput input) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.visitorAuthorizations.collection,
        data: input.toJson(),
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'El servidor no devolvió la autorización registrada.',
        );
      }
      return VisitorAuthorization.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos registrar la autorización de visita.',
      );
    }
  }

  @override
  Future<VisitorAuthorization> cancel(int id) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.visitorAuthorizations.cancel(id),
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'El servidor no confirmó la cancelación.',
        );
      }
      return VisitorAuthorization.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos cancelar la autorización de visita.',
      );
    }
  }
}
