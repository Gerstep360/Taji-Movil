import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';

class ShiftLogPage {
  const ShiftLogPage(this.entries, {this.page = 1, this.pages = 1});
  final List<ShiftLogEntryModel> entries;
  final int page;
  final int pages;
}

abstract class ShiftLogDataSource {
  Future<ShiftLogPage> list({int? shift, int page = 1});
  Future<ShiftLogEntryModel> create({
    required String type,
    required String severity,
    required String title,
    required String description,
    int? expectedShift,
  });
}

class ShiftLogRepository implements ShiftLogDataSource {
  const ShiftLogRepository(this._api);
  final ApiClient _api;

  @override
  Future<ShiftLogPage> list({int? shift, int page = 1}) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.shiftLogs,
        query: {'page': page, if (shift != null) 'shift': shift},
      );
      if (data == null ||
          data['results'] is! List ||
          data['pagination'] is! Map) {
        throw _invalid;
      }
      final pagination = data['pagination'] as Map;
      return ShiftLogPage(
        (data['results'] as List).map((item) {
          if (item is! Map) throw _invalid;
          return ShiftLogEntryModel.fromJson(Map<String, dynamic>.from(item));
        }).toList(),
        page: pagination['page'] as int,
        pages: pagination['total_pages'] as int,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos cargar las novedades.',
      );
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<ShiftLogEntryModel> create({
    required String type,
    required String severity,
    required String title,
    required String description,
    int? expectedShift,
  }) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.shiftLogs,
        data: {
          'entry_type': type,
          'severity': severity,
          'title': title.trim(),
          'description': description.trim(),
          if (expectedShift != null) 'expected_shift': expectedShift,
        },
      );
      if (data == null) throw _invalid;
      return ShiftLogEntryModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos registrar la novedad.',
      );
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  static const _invalid = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de novedades incompletos.',
  );
}
