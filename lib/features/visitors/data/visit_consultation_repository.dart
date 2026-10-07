import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../models/visit_consultation.dart';

class VisitConsultationPageData {
  const VisitConsultationPageData(this.items, this.pages);
  final List<VisitConsultationItem> items;
  final int pages;
}

class VisitConsultationRepository {
  const VisitConsultationRepository(this._api);
  final ApiClient _api;

  Future<VisitConsultationPageData> list(String section, int page) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.visitConsultation, query: {'section': section, 'page': page},
      );
      if (data == null) {
        throw const ApiFailure(code: 'invalid_response', message: 'No se recibieron las visitas.');
      }
      final items = (data['results'] as List? ?? [])
          .whereType<Map<String, dynamic>>().map(VisitConsultationItem.fromJson).toList();
      final pagination = data['pagination'] as Map<String, dynamic>?;
      return VisitConsultationPageData(items, (pagination?['total_pages'] as num?)?.toInt() ?? 1);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(error, fallback: 'No pudimos consultar las visitas.');
    }
  }
}
