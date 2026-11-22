import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_failure.dart';

import 'models/asset_models.dart';
export 'models/asset_models.dart';

// Un único modelo CU24 de Cristel, compartido por inventario y lector.
typedef CondominiumAsset = Asset;

extension AssetViewData on Asset {
  String get type => assetTypeName;
  String get sector => sectorName ?? '';
  String get serial => serialNumber ?? '';
  String get descriptionText => description ?? '';
  String get brandText => brand ?? '';
  String get modelText => model ?? '';
  String get qrPayload => 'TAJI-ASSET.${qrUuid.replaceAll('-', '')}';
  String get statusLabel =>
      const {
        'ACTIVE': 'Activo',
        'MAINTENANCE': 'En mantenimiento',
        'OUT_OF_SERVICE': 'Fuera de servicio',
        'RETIRED': 'Retirado',
      }[status] ??
      status;
}

class AssetRepository {
  const AssetRepository(this.api);
  final ApiClient api;
  Future<({List<CondominiumAsset> items, int pages})> list({
    String search = '',
    int page = 1,
  }) async {
    try {
      final json = await api.get<Map<String, dynamic>>(
        ApiEndpoints.assets.collection,
        query: {'search': search, 'page': page},
      );
      if (json == null || json['results'] is! List) throw _invalid;
      return (
        items: (json['results'] as List)
            .map(
              (e) => CondominiumAsset.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false),
        pages: (json['pagination'] as Map?)?['total_pages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw ApiFailure.fromDio(
        e,
        fallback: 'No pudimos consultar los activos.',
      );
    }
  }

  Future<CondominiumAsset> scan(String payload) async {
    if (!RegExp(
      r'^TAJI-ASSET\.[a-fA-F0-9-]{32,36}$',
    ).hasMatch(payload.trim())) {
      throw const ApiFailure(
        code: 'invalid_qr',
        message: 'Este no es un código QR de activo Taji.',
      );
    }
    try {
      final json = await api.post<Map<String, dynamic>>(
        ApiEndpoints.assets.scan,
        data: {'qr_payload': payload.trim()},
      );
      if (json == null) throw _invalid;
      return CondominiumAsset.fromJson(json);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(
        e,
        fallback: 'No pudimos identificar el activo.',
      );
    }
  }

  Future<AssetHistory> history(int id) async {
    try {
      final json = await api.get<Map<String, dynamic>>(
        ApiEndpoints.assets.history(id),
      );
      if (json == null) throw _invalid;
      return AssetHistory.fromJson(json);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(
        e,
        fallback: 'No pudimos cargar el historial del activo.',
      );
    }
  }

  static const _invalid = ApiFailure(
    code: 'invalid_response',
    message: 'La respuesta del servidor está incompleta.',
  );
}
