import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/models/security_models.dart';
import 'shift_log_repository.dart';

class HandoverPage {
  const HandoverPage(this.entries, {this.page = 1, this.pages = 1});
  final List<ShiftHandoverModel> entries;
  final int page;
  final int pages;
}

abstract class HandoverDataSource {
  Future<HandoverPage> list({int page = 1, int? outgoingShift});
  Future<List<SecurityShiftModel>> candidates(int outgoingShift);
  Future<List<ShiftLogEntryModel>> records(int outgoingShift);
  Future<ShiftHandoverModel> detail(int id);
  Future<ShiftHandoverModel> deliver({
    required int outgoingShift,
    required int incomingShift,
    required String summary,
  });
  Future<ShiftHandoverModel> receive(int id);
}

class HandoverRepository implements HandoverDataSource {
  const HandoverRepository(this._api);
  final ApiClient _api;
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar o guardar la entrega.',
      );
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  @override
  Future<HandoverPage> list({int page = 1, int? outgoingShift}) =>
      _request(() async {
        final data = await _api.get<Map<String, dynamic>>(
          ApiEndpoints.handovers,
          query: {
            'page': page,
            if (outgoingShift != null) 'outgoing_shift': outgoingShift,
          },
        );
        if (data == null ||
            data['results'] is! List ||
            data['pagination'] is! Map) {
          throw _invalid;
        }
        final pagination = data['pagination'] as Map;
        return HandoverPage(
          (data['results'] as List)
              .map(
                (item) => ShiftHandoverModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
          page: pagination['page'] as int,
          pages: pagination['total_pages'] as int,
        );
      });
  @override
  Future<List<SecurityShiftModel>> candidates(int outgoingShift) =>
      _request(() async {
        final data = await _api.get<List<dynamic>>(
          '${ApiEndpoints.handovers}candidatos/',
          query: {'outgoing_shift': outgoingShift},
        );
        if (data == null) throw _invalid;
        return data
            .map(
              (item) => SecurityShiftModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      });
  @override
  Future<List<ShiftLogEntryModel>> records(int outgoingShift) async {
    final logs = ShiftLogRepository(_api);
    final entries = <ShiftLogEntryModel>[];
    var page = 1;
    while (true) {
      final result = await logs.list(shift: outgoingShift, page: page);
      entries.addAll(result.entries);
      if (page >= result.pages) return entries;
      page++;
    }
  }

  @override
  Future<ShiftHandoverModel> detail(int id) => _request(() async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiEndpoints.handovers}$id/',
    );
    if (data == null) throw _invalid;
    return ShiftHandoverModel.fromJson(data);
  });
  @override
  Future<ShiftHandoverModel> deliver({
    required int outgoingShift,
    required int incomingShift,
    required String summary,
  }) => _request(() async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.handovers,
      data: {
        'outgoing_shift': outgoingShift,
        'incoming_shift': incomingShift,
        'summary': summary.trim(),
      },
    );
    if (data == null) throw _invalid;
    return ShiftHandoverModel.fromJson(data);
  });
  @override
  Future<ShiftHandoverModel> receive(int id) => _request(() async {
    final data = await _api.post<Map<String, dynamic>>(
      '${ApiEndpoints.handovers}$id/recibir/',
    );
    if (data == null) throw _invalid;
    return ShiftHandoverModel.fromJson(data);
  });
  static const _invalid = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de entrega incompletos.',
  );
}
