import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.fields = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, List<String>> fields;

  String get displayMessage {
    if (fields.isEmpty) return message;
    final first = fields.entries.first;
    if (first.value.isEmpty) return message;
    return '${_fieldLabel(first.key)}: ${first.value.first}';
  }

  factory ApiFailure.fromDio(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      final envelope = data['error'];
      if (envelope is Map) {
        final fields = _readFields(envelope['fields']);
        return ApiFailure(
          code: envelope['code']?.toString() ?? 'request_failed',
          message: envelope['message']?.toString() ?? fallback,
          statusCode: error.response?.statusCode,
          fields: fields,
        );
      }

      final detail = data['detail'];
      if (detail is String) {
        return ApiFailure(
          code: 'request_failed',
          message: detail,
          statusCode: error.response?.statusCode,
        );
      }
      final fields = _readFields(data);
      if (fields.isNotEmpty) {
        return ApiFailure(
          code: 'validation_error',
          message: 'Revisa los campos indicados.',
          statusCode: error.response?.statusCode,
          fields: fields,
        );
      }
    }

    if (_isNetworkFailure(error)) {
      return const ApiFailure(
        code: 'network_unavailable',
        message:
            'No pudimos conectar con Taji. Revisa tu red e inténtalo otra vez.',
      );
    }
    return ApiFailure(
      code: 'request_failed',
      message: fallback,
      statusCode: error.response?.statusCode,
    );
  }

  static bool isNetworkFailure(DioException error) => _isNetworkFailure(error);

  static Map<String, List<String>> _readFields(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      if (entry.key == 'detail' ||
          entry.key == 'message' ||
          entry.key == 'code') {
        continue;
      }
      final value = entry.value;
      if (value is List) {
        result[entry.key.toString()] = value
            .map((item) => item.toString())
            .toList();
      } else if (value is String) {
        result[entry.key.toString()] = [value];
      }
    }
    return result;
  }

  static bool _isNetworkFailure(DioException error) => {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  }.contains(error.type);

  static String _fieldLabel(String field) =>
      {
        'email': 'Correo',
        'first_name': 'Nombres',
        'last_name': 'Apellidos',
        'phone': 'Teléfono',
        'password': 'Contraseña',
        'password_confirm': 'Confirmación',
        'token': 'Enlace',
      }[field] ??
      'Datos';

  @override
  String toString() => displayMessage;
}
