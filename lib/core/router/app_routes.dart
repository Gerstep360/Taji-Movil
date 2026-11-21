enum AppRoute {
  splash('/'),
  login('/iniciar-sesion'),
  home('/inicio'),
  guestInvitation('/invitar-visita'),
  securityVisits('/seguridad/visitas'),
  faceVerification('/verificacion-facial'),
  visitQr('/qr-visita/:authorizationId'),
  visitQrScanner('/escanear-qr'),
  qrScanHistory('/bitacora-escaneos'),
  visitConsultation('/visitas-dentro'),
  // CU28 / T123: centro de comunicados y notificaciones.
  announcements('/comunicados');

  const AppRoute(this.path);
  final String path;
}
