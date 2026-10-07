enum AppRoute {
  splash('/splash'),
  login('/iniciar-sesion'),
  register('/crear-cuenta'),
  forgotPassword('/recuperar-contrasena'),
  visitConsultation('/visitas-dentro'),
  home('/inicio');

  const AppRoute(this.path);
  final String path;
}
