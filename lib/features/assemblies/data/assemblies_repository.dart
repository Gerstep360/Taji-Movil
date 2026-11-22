import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../models/assembly_models.dart';

class AssembliesRepository {
  const AssembliesRepository(this._api);
  final ApiClient _api;

  Future<AssembliesPageData> list({int page = 1, String? status}) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.assemblies,
        query: {
          'page': page,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'No se recibieron las asambleas.',
        );
      }
      final items = (data['results'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AssemblyItem.fromJson)
          .toList();
      final pagination = data['pagination'] as Map<String, dynamic>?;
      return AssembliesPageData(
        items,
        (pagination?['total_pages'] as num?)?.toInt() ?? 1,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar las asambleas.',
      );
    }
  }

  Future<List<AgreementItem>> agreements(int assemblyId) async {
    try {
      final data = await _api.get<List<dynamic>>(
        ApiEndpoints.assemblyAgreements(assemblyId),
      );
      return (data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AgreementItem.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar los acuerdos.',
      );
    }
  }
}
