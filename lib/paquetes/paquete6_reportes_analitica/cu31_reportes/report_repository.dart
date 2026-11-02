import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'report_models.dart';

class ReportsRepository {
  ReportsRepository(this.api);
  final ApiClient api;
  static const root = ApiEndpoints.reports;
  Future<ReportCatalog> catalog() async {
    final data = await api.get<Map<String, dynamic>>('${root}catalog/');
    if (data == null) {
      throw StateError('No se recibió el catálogo. Reintenta la consulta.');
    }
    return ReportCatalog.fromJson(data);
  }

  Future<ReportPreview> preview(ReportQuery query) async {
    final data = await api.post<Map<String, dynamic>>(
      '${root}preview/',
      data: query.toJson(),
    );
    if (data == null) {
      throw StateError('No se recibió el reporte. Reintenta la consulta.');
    }
    return ReportPreview.fromJson(data);
  }

  Future<Map<String, dynamic>> voice(String text) async {
    final data = await api.post<Map<String, dynamic>>(
      '${root}voice-query/',
      data: {'voice_text': text.trim(), 'auto_narrate': false},
    );
    if (data == null) {
      throw StateError(
        'No se pudo interpretar la consulta. Puedes usar los filtros.',
      );
    }
    return data;
  }

  Future<String> narrate(ReportPreview preview) async {
    final data = await api.post<Map<String, dynamic>>(
      '${root}voice-narrate/',
      data: {'source': preview.source, 'total_count': preview.total},
    );
    if (data == null) throw StateError('No se recibió el resumen.');
    return '${data['spoken_summary'] ?? ''}';
  }

  Future<Uint8List> export(ReportQuery query, String format) async {
    final bytes = await api.postBytes(
      '${root}export/',
      data: {...query.toJson(), 'format': format},
    );
    if (bytes.isEmpty) {
      throw StateError('El archivo llegó vacío. Intenta nuevamente.');
    }
    if (bytes.length > 20 * 1024 * 1024) {
      throw StateError(
        'El archivo es demasiado grande para compartir desde el teléfono. Aplica más filtros.',
      );
    }
    return bytes;
  }
}
