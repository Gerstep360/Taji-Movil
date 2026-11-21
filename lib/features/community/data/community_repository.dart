import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/community_models.dart';

/// CU26 / T121: fuentes de datos para la consulta de áreas comunes.
///
/// El backend expone la consulta como tres recursos independientes:
///   `GET /community/areas/`
///   `GET /community/area-schedules/?common_area=<id>`
///   `GET /community/area-blocks/?common_area=<id>`
abstract interface class CommunityDataSource {
  Future<List<CommonAreaModel>> listAreas();
  Future<List<CommonAreaScheduleModel>> listSchedules(int commonAreaId);
  Future<List<CommonAreaBlockModel>> listBlocks(int commonAreaId);
}

class CommunityRepository implements CommunityDataSource {
  const CommunityRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<CommonAreaModel>> listAreas() async {
    // Los condominios tienen pocas áreas, pero respeta la paginación por si
    // el catálogo crece. Tope de seguridad para no encadenar páginas sin fin.
    final areas = <CommonAreaModel>[];
    var page = 1;
    var pages = 1;
    do {
      final (items, totalPages) = await _getList(
        ApiEndpoints.community.areas,
        query: {'page': page, 'page_size': 50},
        fallback: 'No pudimos consultar las áreas comunes.',
      );
      areas.addAll(
        items.map((item) {
          try {
            return _parseArea(item);
          } on Object {
            throw _invalidResponse;
          }
        }),
      );
      pages = totalPages;
      page++;
    } while (page <= pages && page <= 25);
    return areas;
  }

  @override
  Future<List<CommonAreaScheduleModel>> listSchedules(int commonAreaId) async {
    final (items, _) = await _getList(
      ApiEndpoints.community.areaSchedules,
      query: {'common_area': commonAreaId, 'page_size': 100},
      fallback: 'No pudimos consultar los horarios del área.',
    );
    return items
        .map((item) {
          try {
            return _parseSchedule(item, commonAreaId);
          } on Object {
            throw _invalidResponse;
          }
        })
        .toList(growable: false)
      ..sort((a, b) => a.weekday.compareTo(b.weekday));
  }

  @override
  Future<List<CommonAreaBlockModel>> listBlocks(int commonAreaId) async {
    final (items, _) = await _getList(
      ApiEndpoints.community.areaBlocks,
      query: {'common_area': commonAreaId, 'page_size': 100},
      fallback: 'No pudimos consultar los bloqueos del área.',
    );
    return items
        .map((item) {
          try {
            return _parseBlock(item, commonAreaId);
          } on Object {
            throw _invalidResponse;
          }
        })
        .toList(growable: false)
      ..sort((a, b) => a.blockedFrom.compareTo(b.blockedFrom));
  }

  /// Acepta tanto una lista plana como el envoltorio `{results, pagination}`
  /// que usan los endpoints paginados del backend.
  Future<(List<Map<String, dynamic>>, int)> _getList(
    String path, {
    required Map<String, dynamic> query,
    required String fallback,
  }) async {
    try {
      final response = await _api.get<dynamic>(path, query: query);
      final rawItems = response is List
          ? response
          : response is Map
          ? response['results']
          : null;
      if (rawItems is! List) throw _invalidResponse;
      final items = rawItems
          .map((item) {
            if (item is! Map) throw _invalidResponse;
            return Map<String, dynamic>.from(item);
          })
          .toList(growable: false);
      final pages = response is Map
          ? _readInt(
              (response['pagination'] as Map?)?['total_pages'],
              fallback: 1,
            )
          : 1;
      return (items, pages < 1 ? 1 : pages);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: fallback);
    }
  }

  CommonAreaModel _parseArea(Map<String, dynamic> json) => CommonAreaModel(
    id: _readId(json, 'id'),
    sectorId: _readNullableInt(json['sector_id'] ?? json['sector']),
    name: json['name']?.toString().trim() ?? '',
    description: json['description']?.toString().trim() ?? '',
    capacity: _readNullableInt(json['capacity']),
    requiresApproval: json['requires_approval'] == true,
    status: (json['status']?.toString().trim() ?? '').toUpperCase(),
    createdAt: _readDate(json['created_at']) ?? DateTime(1970),
    updatedAt: _readDate(json['updated_at']) ?? DateTime(1970),
  );

  CommonAreaScheduleModel _parseSchedule(
    Map<String, dynamic> json,
    int commonAreaId,
  ) => CommonAreaScheduleModel(
    id: _readInt(json['id'], fallback: 0),
    // El filtro llega como `common_area`; el serializador puede exponer la
    // llave como `common_area_id` o repetir `common_area`.
    commonAreaId:
        _readNullableInt(json['common_area_id'] ?? json['common_area']) ??
        commonAreaId,
    weekday: _readInt(json['weekday'], fallback: -1),
    opensAt: _readTime(json['opens_at']),
    closesAt: _readTime(json['closes_at']),
    isActive: json['is_active'] != false,
  );

  CommonAreaBlockModel _parseBlock(
    Map<String, dynamic> json,
    int commonAreaId,
  ) {
    final blockedFrom = _readDate(json['blocked_from']);
    final blockedUntil = _readDate(json['blocked_until']);
    if (blockedFrom == null || blockedUntil == null) {
      throw const FormatException('Bloqueo sin ventana de tiempo válida.');
    }
    return CommonAreaBlockModel(
      id: _readInt(json['id'], fallback: 0),
      commonAreaId:
          _readNullableInt(json['common_area_id'] ?? json['common_area']) ??
          commonAreaId,
      workOrderId: _readNullableInt(
        json['work_order_id'] ?? json['work_order'],
      ),
      blockedFrom: blockedFrom,
      blockedUntil: blockedUntil,
      reason: json['reason']?.toString().trim() ?? '',
      createdByUserId: _readNullableInt(
        json['created_by_user_id'] ?? json['created_by'],
      ),
      createdAt: _readDate(json['created_at']) ?? blockedFrom,
    );
  }

  static const _invalidResponse = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos incompletos de las áreas comunes.',
  );
}

int _readId(Map<String, dynamic> json, String key) {
  final id = _readNullableInt(json[key]);
  if (id == null || id <= 0) {
    throw const FormatException('Área común sin identificador válido.');
  }
  return id;
}

int _readInt(Object? value, {int fallback = 0}) =>
    _readNullableInt(value) ?? fallback;

int? _readNullableInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _readTime(Object? value) {
  final raw = value?.toString().trim() ?? '';
  // DRF expone los campos time como "HH:MM:SS" o "HH:MM"; recorta a "HH:MM".
  if (raw.length >= 5) return raw.substring(0, 5);
  return raw;
}

DateTime? _readDate(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  // Acepta tanto "2026-11-14T08:00:00" como "2026-11-14 08:00:00".
  final normalized = raw.length > 10 && raw[10] == ' '
      ? '${raw.substring(0, 10)}T${raw.substring(11)}'
      : raw;
  return DateTime.tryParse(normalized)?.toLocal();
}
