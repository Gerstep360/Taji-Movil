class ApiEndpoints {
  ApiEndpoints._();

  static const health = '/health/';

  static const auth = _AuthEndpoints();
  static const visitorAuthorizations = _VisitorAuthorizationEndpoints();
  static const units = _UnitEndpoints();
  static const residents = _ResidentEndpoints();
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
