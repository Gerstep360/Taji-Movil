import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/access_event_models.dart';

class AccessEventPage {
  const AccessEventPage(this.events, {this.page = 1, this.pages = 1});

  final List<AccessEventItemModel> events;
  final int page;
  final int pages;
}

abstract class AccessEventDataSource {
  Future<AccessEventPage> list({int page = 1, String? eventType});
  Future<List<AccessPersonOptionModel>> searchPeople(String search);
  Future<List<AccessUnitOptionModel>> searchUnits(String search);
  Future<AccessEventItemModel> create({
    int? personId,
    String visitorName = '',
    String visitorDocumentNumber = '',
    required int unitId,
    required String eventType,
    required String validationMethod,
    required String notes,
  });
}

class AccessEventRepository implements AccessEventDataSource {
  const AccessEventRepository(this._api);

  final ApiClient _api;

  @override
  Future<AccessEventPage> list({int page = 1, String? eventType}) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.accessEvents.collection,
        query: {
          'page': page,
          'page_size': 20,
          if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
        },
      );
      if (data == null || data['results'] is! List || data['pagination'] is! Map) {
        throw _invalid;
      }
      final pagination = Map<String, dynamic>.from(data['pagination'] as Map);
      final events = (data['results'] as List).map((item) {
        if (item is! Map) throw _invalid;
        return AccessEventItemModel.fromJson(Map<String, dynamic>.from(item));
      }).toList(growable: false);
      return AccessEventPage(
        List.unmodifiable(events),
        page: _readPage(pagination['page'], page),
        pages: _readPage(pagination['total_pages'], 1),
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos cargar el historial de accesos.',
      );
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<List<AccessPersonOptionModel>> searchPeople(String search) async {
    if (search.trim().length < 2) return const [];
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.accessEvents.people,
        query: {'search': search.trim()},
      );
      return _parseResults(
        data,
        AccessPersonOptionModel.fromJson,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos buscar personas.');
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<List<AccessUnitOptionModel>> searchUnits(String search) async {
    if (search.trim().isEmpty) return const [];
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.accessEvents.units,
        query: {'search': search.trim()},
      );
      return _parseResults(data, AccessUnitOptionModel.fromJson);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos buscar unidades.');
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<AccessEventItemModel> create({
    int? personId,
    String visitorName = '',
    String visitorDocumentNumber = '',
    required int unitId,
    required String eventType,
    required String validationMethod,
    required String notes,
  }) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.accessEvents.collection,
        data: {
          if (personId != null) 'person_id': personId,
          if (personId == null) ...{
            'visitor_name': visitorName.trim(),
            'visitor_document_number': visitorDocumentNumber.trim(),
          },
          'unit_id': unitId,
          'event_type': eventType,
          'validation_method': validationMethod,
          'validation_result': eventType == 'DENIED' ? 'REJECTED' : 'APPROVED',
          'notes': notes.trim(),
        },
      );
      if (data == null) throw _invalid;
      return AccessEventItemModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos registrar el acceso.');
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  static List<T> _parseResults<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (data == null || data['results'] is! List) throw _invalid;
    return List.unmodifiable(
      (data['results'] as List).map((item) {
        if (item is! Map) throw _invalid;
        return parse(Map<String, dynamic>.from(item));
      }),
    );
  }

  static int _readPage(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static const _invalid = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de control de accesos incompletos.',
  );
}