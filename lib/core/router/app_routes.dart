enum AppRoute {
  splash('/splash'),
  login('/iniciar-sesion'),
  register('/crear-cuenta'),
  forgotPassword('/recuperar-contrasena'),
  home('/inicio'),
  incidents('/incidencias'),
  reportIncident('/reportar-incidencia'),
  reports('/reportes'),
  maintenanceOrders('/mantenimiento'),
  assets('/activos'),
  assetQr('/identificar-activo-qr'),
  management('/gestion/:moduleKey'),
  incidentAnalysis('/clasificacion-ia'),
  accessEvents('/control-accesos'),
  newAccessEvent('/control-accesos/nuevo'),
  securityShifts('/mis-turnos'),
  shiftLogs('/novedades-turno'),
  handovers('/entregas-turno'),
  faceVerification('/verificacion-facial'),
  visitorAuthorizations('/autorizaciones-visita'),
  visitQr('/qr-visita/:authorizationId'),
  visitQrScanner('/escanear-qr'),
  qrScanHistory('/bitacora-escaneos'),
  visitConsultation('/visitas-dentro'),
  // CU26 / T121: consulta de áreas comunes y disponibilidad.
  communityAreas('/areas-comunes'),
  reservations('/reservas'),
  // CU28 / T123: centro de comunicados y notificaciones.
  announcements('/comunicados');

  const AppRoute(this.path);
  final String path;

  static String visitQrFor(int authorizationId) =>
      '/qr-visita/$authorizationId';
}
