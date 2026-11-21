import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_failure.dart';

class MaintenanceEvidence {
  const MaintenanceEvidence({
    required this.id,
    required this.fileType,
    required this.caption,
    required this.createdAt,
  });

  final int id;
  final String fileType;
  final String caption;
  final DateTime? createdAt;

  factory MaintenanceEvidence.fromJson(Map<String, dynamic> json) =>
      MaintenanceEvidence(
        id: _intValue(json['id']),
        fileType: json['file_type']?.toString() ?? '',
        caption: json['caption']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

class MaintenanceWorkOrder {
  const MaintenanceWorkOrder({
    required this.id,
    required this.publicCode,
    required this.title,
    required this.description,
    required this.status,
    required this.workType,
    required this.assetCode,
    required this.assetName,
    required this.assigneeName,
    required this.supplierName,
    required this.scheduledFor,
    required this.startedAt,
    required this.completedAt,
    required this.estimatedCost,
    required this.actualCost,
    required this.evidence,
    required this.statusHistory,
  });

  final int id;
  final String publicCode;
  final String title;
  final String description;
  final String status;
  final String workType;
  final String assetCode;
  final String assetName;
  final String assigneeName;
  final String supplierName;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? estimatedCost;
  final String? actualCost;
  final List<MaintenanceEvidence> evidence;
  final List<Map<String, dynamic>> statusHistory;

  factory MaintenanceWorkOrder.fromJson(Map<String, dynamic> json) =>
      MaintenanceWorkOrder(
        id: _intValue(json['id']),
        publicCode: json['public_code']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        workType: json['work_type']?.toString() ?? '',
        assetCode: json['asset_code']?.toString() ?? '',
        assetName: json['asset_name']?.toString() ?? '',
        assigneeName: json['assignee_name']?.toString() ?? '',
        supplierName: json['supplier_name']?.toString() ?? '',
        scheduledFor: DateTime.tryParse(
          json['scheduled_for']?.toString() ?? '',
        ),
        startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
        completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
        estimatedCost: json['estimated_cost']?.toString(),
        actualCost: json['actual_cost']?.toString(),
        evidence: _mapList(
          json['attachments'],
        ).map(MaintenanceEvidence.fromJson).toList(growable: false),
        statusHistory: _mapList(json['status_history']),
      );
}

abstract interface class MaintenanceOrderDataSource {
  Future<({List<MaintenanceWorkOrder> items, int pages})> listOrders({
    int page = 1,
  });
  Future<MaintenanceWorkOrder> changeStatus(
    int id, {
    required String status,
    String notes = '',
  });
  Future<MaintenanceWorkOrder> uploadEvidence(
    int id, {
    required XFile file,
    String caption = '',
  });
}

class MaintenanceOrderRepository implements MaintenanceOrderDataSource {
  const MaintenanceOrderRepository(this._api);
  final ApiClient _api;

  @override
  Future<({List<MaintenanceWorkOrder> items, int pages})> listOrders({
    int page = 1,
  }) async {
    try {
      final response = await _api.get<dynamic>(
        ApiEndpoints.maintenance.orders,
        query: {'page': page},
      );
      final items = response is List
          ? response
          : response is Map
          ? response['results']
          : null;
      if (items is! List) throw _invalidResponse;
      final orders = items
          .map((item) {
            if (item is! Map) throw _invalidResponse;
            return _parseOrder(Map<String, dynamic>.from(item));
          })
          .toList(growable: false);
      return (
        items: orders,
        pages: response is Map
            ? ((response['pagination'] as Map?)?['total_pages'] as int? ?? 1)
            : 1,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar tus órdenes de trabajo.',
      );
    }
  }

  @override
  Future<MaintenanceWorkOrder> changeStatus(
    int id, {
    required String status,
    String notes = '',
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.maintenance.status(id),
        data: {'status': status, 'notes': notes.trim()},
      );
      if (response == null) throw _invalidResponse;
      return _parseOrder(response);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos actualizar la orden.',
      );
    }
  }

  @override
  Future<MaintenanceWorkOrder> uploadEvidence(
    int id, {
    required XFile file,
    String caption = '',
  }) async {
    try {
      if (await file.length() > 20 * 1024 * 1024) {
        throw const ApiFailure(
          code: 'file_too_large',
          message: 'La evidencia no puede superar 20 MB.',
        );
      }
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: file.name,
        ),
        'caption': caption.trim(),
      });
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.maintenance.attachments(id),
        data: form,
      );
      if (response == null) throw _invalidResponse;
      return _parseOrder(response);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos adjuntar la evidencia.',
      );
    }
  }

  MaintenanceWorkOrder _parseOrder(Map<String, dynamic> json) {
    try {
      final order = MaintenanceWorkOrder.fromJson(json);
      if (order.id <= 0 || order.publicCode.isEmpty) throw _invalidResponse;
      return order;
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = ApiFailure(
    code: 'invalid_response',
    message: 'El servidor devolvió datos de la orden incompletos.',
  );
}

int _intValue(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
