class ApiEndpoints {
  ApiEndpoints._();

  static const health = '/health/';

  static const auth = _AuthEndpoints();
  static const security = _SecurityEndpoints();
}

class _SecurityEndpoints {
  const _SecurityEndpoints();

  final String biometricsEnroll = '/security/cu17/biometrics/enroll/';
  final String faceMatch = '/security/cu17/face-verification/match/';
  final String faceConfirm = '/security/cu17/face-verification/confirm/';
  final String faceLogs = '/security/cu17/face-verification/';
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
