import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../models/taji_user.dart';

class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? tajiSecureStorage;

  static const _userKey = 'taji_session_user';
  final FlutterSecureStorage _storage;

  Future<void> saveUser(TajiUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<TajiUser?> readUser() async {
    final source = await _storage.read(key: _userKey);
    if (source == null || source.isEmpty) return null;
    try {
      return TajiUser.fromJson(jsonDecode(source) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _userKey);
}
