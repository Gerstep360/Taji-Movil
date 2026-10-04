enum AppRoute {
  splash('/splash'),
  login('/iniciar-sesion'),
  register('/crear-cuenta'),
  forgotPassword('/recuperar-contrasena'),
  home('/inicio'),
  faceVerification('/verificacion-facial'),
  visitorAuthorizations('/autorizaciones-visita'),
  visitQr('/qr-visita/:authorizationId'),
  visitQrScanner('/escanear-qr');

  const AppRoute(this.path);
  final String path;

  /// Ruta concreta de la pantalla de QR para una autorización dada.
  static String visitQrFor(int authorizationId) =>
      '/qr-visita/$authorizationId';
}
