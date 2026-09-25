enum AppRoute {
  splash('/splash'),
  login('/iniciar-sesion'),
  register('/crear-cuenta'),
  forgotPassword('/recuperar-contrasena'),
  visitorAuthorizations('/autorizaciones-visita'),
  home('/inicio');

  const AppRoute(this.path);
  final String path;
}
