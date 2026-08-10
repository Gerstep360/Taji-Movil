import '../../../core/network/token_store.dart';
import '../models/taji_user.dart';

class LoginRequest {
  const LoginRequest({required this.email, required this.password});
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email.trim().toLowerCase(),
    'password': password,
    'client': 'mobile',
  };
}

class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
  });
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'email': email.trim().toLowerCase(),
    'phone': phone.trim(),
    'password': password,
    'password_confirm': password,
  };
}

class AuthSessionResponse {
  const AuthSessionResponse({required this.user, required this.tokens});
  final TajiUser user;
  final TokenPair tokens;

  factory AuthSessionResponse.fromJson(Map<String, dynamic> json) {
    final tokenJson = json['tokens'] as Map<String, dynamic>;
    return AuthSessionResponse(
      user: TajiUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: TokenPair(
        access: tokenJson['access'] as String,
        refresh: tokenJson['refresh'] as String,
      ),
    );
  }
}

class MessageResponse {
  const MessageResponse(this.message);
  final String message;

  factory MessageResponse.fromJson(
    Map<String, dynamic>? json,
    String fallback,
  ) {
    return MessageResponse(json?['message'] as String? ?? fallback);
  }
}
