import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../models/qr_scan_history.dart';

/// Lector de la bitácora de escaneos de portería.
///
/// Complementa al historial en memoria del escáner: aquel se pierde al cerrar la
/// aplicación, este lee el registro del servidor, que además distingue QR
/// denegados de QR que no existen.
class QrScanHistoryDataSource {
  const QrScanHistoryDataSource(this._api);

  final ApiClient _api;

  Future<QrScanHistoryPage> history(QrScanFilters filters) async {
    try {
      final json = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.visitQr.scanHistory,
        query: filters.toQuery(),
      );
      return QrScanHistoryPage.fromJson(json ?? const {});
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No se pudo cargar la bitácora de escaneos.',
      );
    }
  }

  /// Guardias con actividad de escaneo, para poblar el filtro.
  Future<List<QrScanGuardOption>> guards() async {
    try {
      final json = await _api.get<List<dynamic>>(ApiEndpoints.visitQr.scanGuards);
      if (json == null) return const [];
      return json
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => QrScanGuardOption(
              id: (row['id'] as num?)?.toInt() ?? 0,
              fullName: (row['full_name'] as String?) ?? '',
            ),
          )
          .where((guard) => guard.id != 0)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No se pudo cargar la lista de guardias.',
      );
    }
  }
}

/// Opción del selector de guardia.
class QrScanGuardOption {
  const QrScanGuardOption({required this.id, required this.fullName});

  final int id;
  final String fullName;
}
