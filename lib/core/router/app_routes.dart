enum AppRoute {
  splash('/splash'),
  login('/iniciar-sesion'),
  register('/crear-cuenta'),
  forgotPassword('/recuperar-contrasena'),
  home('/inicio'),
  securityShifts('/mis-turnos'),
  shiftLogs('/novedades-turno'),
  handovers('/entregas-turno'),
  faceVerification('/verificacion-facial'),
  visitorAuthorizations('/autorizaciones-visita'),
  visitQr('/qr-visita/:authorizationId'),
  visitQrScanner('/escanear-qr'),
  qrScanHistory('/bitacora-escaneos'),
  visitConsultation('/visitas-dentro');

  const AppRoute(this.path);
  final String path;

  /// Ruta concreta de la pantalla de QR para una autorización dada.
  static String visitQrFor(int authorizationId) =>
      '/qr-visita/$authorizationId';
}
