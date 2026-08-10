class ApiEndpoints {
  ApiEndpoints._();

  static const health = '/health/';

  static const auth = _AuthEndpoints();
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
