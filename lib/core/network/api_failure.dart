import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.fields = const {},
    this.traceId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, List<String>> fields;

  /// Referencia del servidor para fallos no controlados (503/500).
  ///
  /// Sin ella, quien reporta "la base de datos no está disponible" no puede
  /// decir qué petición fue, y el operador tiene que adivinar entre varias
  /// líneas del log. Es el mismo identificador que viaja en la respuesta.
  final String? traceId;

  String get displayMessage {
    final base;
    if (fields.isEmpty) {
      base = message;
    } else {
      final first = fields.entries.first;
      base = first.value.isEmpty
          ? message
          : '${_fieldLabel(first.key)}: ${first.value.first}';
    }
    // Solo en fallos no controlados: un rechazo de negocio no lleva referencia.
    final reference = traceId;
    return reference == null ? base : '$base (ref. $reference)';
  }

  factory ApiFailure.fromDio(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      final envelope = data['error'];
      if (envelope is Map) {
        final fields = _readFields(envelope['fields']);
        final rawTrace = envelope['trace_id'];
        return ApiFailure(
          code: envelope['code']?.toString() ?? 'request_failed',
          message: envelope['message']?.toString() ?? fallback,
          statusCode: error.response?.statusCode,
          fields: fields,
          traceId: rawTrace is String && rawTrace.isNotEmpty ? rawTrace : null,
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
      // `trace_id` es la referencia del fallo, no un campo de formulario: si no
      // se excluye, un 503 se mostraría como "Datos: no disponible" en vez de
      // como el mensaje que el servidor envío.
      if (entry.key == 'detail' ||
          entry.key == 'message' ||
          entry.key == 'code' ||
          entry.key == 'trace_id' ||
          entry.key == 'exception') {
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
        // CU09: el backend rechaza la emisión del pase con estos códigos.
        'status_not_allowed': 'Visita',
        'visit_window_ended': 'Visita',
        'ttl_minutes': 'Vigencia del QR',
        'visitor_first_name': 'Nombre',
        'visitor_last_name': 'Apellido',
        'visitor_document_number': 'Documento',
        'unit_id': 'Unidad',
        'valid_from': 'Fecha inicial',
        'valid_until': 'Fecha final',
        'purpose': 'Motivo',
        'token': 'Enlace',
      }[field] ??
      'Datos';

  @override
  String toString() => displayMessage;
}
