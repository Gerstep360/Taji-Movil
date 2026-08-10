import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/taji_user.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._repository);
  final AuthRepository _repository;

  AuthStatus status = AuthStatus.initializing;
  TajiUser? user;
  bool busy = false;
  String? error;

  Future<void> initialize() async {
    user = await _repository.restoreSession();
    status = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _begin();
    try {
      user = await _repository.login(email: email, password: password);
      status = AuthStatus.authenticated;
      return true;
    } on AuthException catch (exception) {
      error = exception.message;
      return false;
    } finally {
      _end();
    }
  }

  Future<void> logout() async {
    _begin();
    try {
      await _repository.logout();
    } finally {
      user = null;
      status = AuthStatus.unauthenticated;
      _end();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _begin() {
    busy = true;
    error = null;
    notifyListeners();
  }

  void _end() {
    busy = false;
    notifyListeners();
  }
}
