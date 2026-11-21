import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../models/incident_report.dart';

abstract class IncidentDataSource {
  Future<IncidentOptions> options();
  Future<ReportedIncident> report(IncidentDraft draft);
}

class IncidentRepository implements IncidentDataSource {
  const IncidentRepository(this._api);

  final ApiClient _api;

  Future<T> _request<T>(Future<T> Function() action, String fallback) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: fallback);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<IncidentOptions> options() => _request(() async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.incidents.options,
    );
    if (data == null) throw _invalid;
    return IncidentOptions.fromJson(data);
  }, 'No pudimos cargar las opciones para reportar.');

  @override
  Future<ReportedIncident> report(IncidentDraft draft) => _request(() async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.incidents.collection,
      data: buildForm(draft),
    );
    if (data == null) throw _invalid;
    return ReportedIncident.fromJson(data);
  }, 'No pudimos registrar la incidencia.');

  /// Multipart con solo los campos que el usuario puede decidir.
  static FormData buildForm(IncidentDraft draft) {
    final title = draft.title.trim();
    final form = FormData()
      ..fields.addAll([
        MapEntry('description', draft.description.trim()),
        if (title.isNotEmpty) MapEntry('title', title),
        MapEntry('category', '${draft.categoryId}'),
        MapEntry('sector', '${draft.sectorId}'),
        if (draft.unitId != null) MapEntry('unit', '${draft.unitId}'),
        if (draft.assetId != null) MapEntry('asset', '${draft.assetId}'),
      ]);
    for (final file in draft.evidences) {
      form.files.add(
        MapEntry(
          'evidences',
          MultipartFile.fromBytes(
            file.bytes,
            filename: file.name,
            contentType: DioMediaType.parse(file.resolvedMimeType),
          ),
        ),
      );
    }
    return form;
  }

  static const _invalid = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de la incidencia incompletos.',
  );
}
