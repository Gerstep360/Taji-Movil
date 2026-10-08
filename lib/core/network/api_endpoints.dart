class ApiEndpoints {
  ApiEndpoints._();

  static const health = '/health/';
  static const visitConsultation = '/security/cu12/visits/';
  static const shiftLogs = '/security/novedades-turno/';
  static const handovers = '/security/entregas-turno/';

  static const auth = _AuthEndpoints();
  static const security = _SecurityEndpoints();
  static const securityShifts = _SecurityShiftEndpoints();
  static const visitorAuthorizations = _VisitorAuthorizationEndpoints();
  static const visitQr = _VisitQrEndpoints();
  static const units = _UnitEndpoints();
  static const residents = _ResidentEndpoints();
  static const publicCondominiums = '/saas/condominiums/public/';
}

class _SecurityShiftEndpoints {
  const _SecurityShiftEndpoints();

  final String current = '/security/turnos/actual/';
  final String upcoming = '/security/turnos/proximos/';
  final String history = '/security/turnos/historial/';
  String start(int id) => '/security/turnos/$id/iniciar/';
  String close(int id) => '/security/turnos/$id/cerrar/';
}

class _SecurityEndpoints {
  const _SecurityEndpoints();

  final String biometricsEnroll = '/security/cu17/biometrics/enroll/';
  final String faceMatch = '/security/cu17/face-verification/match/';
  final String faceConfirm = '/security/cu17/face-verification/confirm/';
  final String faceLogs = '/security/cu17/face-verification/';
}

class _ResidentEndpoints {
  const _ResidentEndpoints();

  final String collection = '/residents/';
}

class _UnitEndpoints {
  const _UnitEndpoints();

  final String collection = '/units/';
}

class _VisitorAuthorizationEndpoints {
  const _VisitorAuthorizationEndpoints();

  final String collection = '/visit-authorizations/';
  String cancel(int id) => '/visit-authorizations/$id/cancel/';
}

/// Rutas de CU09 (emisión y consulta del QR) y CU10 (validación en portería).
///
/// El backend monta CU10 antes que CU09 porque `visit-qr/validate/` es un
/// segmento fijo y no debe competir con el patrón numérico `visit-qr/<pk>/`.
class _VisitQrEndpoints {
  const _VisitQrEndpoints();

  /// Estado de vigencia del QR de una autorización. Nunca devuelve el token.
  String detail(int authorizationId) => '/visit-qr/$authorizationId/';

  /// Emite el QR con vigencia limitada. `force` rota uno todavía vigente.
  String generate(int authorizationId) =>
      '/visit-qr/$authorizationId/generate/';

  /// Veredicto de un escaneo hecho por el personal de seguridad.
  final String validate = '/visit-qr/validate/';

  /// Catálogo de motivos de rechazo, para no codificar textos en la app.
  final String validateReasons = '/visit-qr/validate/reasons/';

  /// Bitácora de escaneos de portería, con los totales de la ventana.
  ///
  /// A diferencia de la lista en memoria del lector, esta sobrevive al cierre
  /// de la app: el registro vive en el servidor.
  final String scanHistory = '/security/visit-qr/scans/';

  /// Guardias con actividad de escaneo, para filtrar la bitácora.
  final String scanGuards = '/security/visit-qr/scans/guards/';
}

class _AuthEndpoints {
  const _AuthEndpoints();

  final String login = '/auth/login/';
  final String register = '/auth/register/';
  final String refresh = '/auth/refresh/';
  final String logout = '/auth/logout/';
  final String me = '/auth/me/';
  final String forgotPassword = '/auth/forgot-password/';
  final String resetPassword = '/auth/reset-password/';
}
