import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/visit_qr.dart';

/// Contrato de datos de CU09 (emisión/consulta del QR) y CU10 (validación).
///
/// Existe como interfaz para que los controladores sean testeables con un doble
/// en memoria, igual que `VisitorAuthorizationDataSource`.
abstract class VisitQrDataSource {
  /// Estado de vigencia del QR de una autorización, sin exponer el token.
  Future<VisitQrTicket> status(int authorizationId);

  /// Emite el QR de la autorización. `force` rota uno todavía vigente.
  Future<VisitQrTicket> generate(
    int authorizationId, {
    int? ttlMinutes,
    bool force = false,
  });

  /// Veredicto de un escaneo. El backend responde 200 tanto si aprueba como si
  /// rechaza, así que un `ApiFailure` aquí siempre es un fallo de transporte,
  /// de sesión o de permiso, nunca un rechazo de ingreso.
  Future<VisitQrValidation> validate({
    required String token,
    String? notes,
    String? deviceId,
  });

  /// Catálogo de motivos de rechazo publicado por el backend.
  Future<List<VisitQrRejectionReason>> rejectionReasons();
}

class VisitQrRepository implements VisitQrDataSource {
  const VisitQrRepository(this._api);

  final ApiClient _api;

  @override
  Future<VisitQrTicket> status(int authorizationId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.visitQr.detail(authorizationId),
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'El servidor no devolvió el estado del QR.',
        );
      }
      return VisitQrTicket.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar el QR de la visita.',
      );
    }
  }

  @override
  Future<VisitQrTicket> generate(
    int authorizationId, {
    int? ttlMinutes,
    bool force = false,
  }) async {
    try {
      // El backend devuelve 201 en la primera emisión y 200 cuando el QR ya
      // estaba vigente (idempotente) o cuando se rota. `payload` solo viene
      // poblado en el 201 y en la rotación; en el 200 idempotente llega `null`
      // porque el token en claro no se puede recuperar después.
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.visitQr.generate(authorizationId),
        data: {
          if (ttlMinutes != null) 'ttl_minutes': ttlMinutes,
          if (force) 'force': true,
        },
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'El servidor no devolvió el QR generado.',
        );
      }
      return VisitQrTicket.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos generar el QR de la visita.',
      );
    }
  }

  @override
  Future<VisitQrValidation> validate({
    required String token,
    String? notes,
    String? deviceId,
  }) async {
    try {
      // Se envía el texto capturado tal cual. El backend normaliza el payload
      // `TAJI1.<uuid>.<token>`, el token aislado y los deep links
      // `taji://visit/validate?code=...`, así que el lector no debe recortar
      // ni reinterpretar lo que la cámara leyó.
      final data = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.visitQr.validate,
        data: {
          'token': token,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        },
      );
      if (data == null) {
        throw const ApiFailure(
          code: 'invalid_response',
          message: 'El servidor no devolvió el resultado de la validación.',
        );
      }
      return VisitQrValidation.fromJson(data);
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos validar el QR escaneado.',
      );
    }
  }

  @override
  Future<List<VisitQrRejectionReason>> rejectionReasons() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.visitQr.validateReasons,
      );
      final reasons = data?['reasons'] as List? ?? const [];
      return reasons
          .whereType<Map<String, dynamic>>()
          .map(VisitQrRejectionReason.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiFailure.fromDio(
        error,
        fallback: 'No pudimos consultar los motivos de rechazo.',
      );
    }
  }
}
