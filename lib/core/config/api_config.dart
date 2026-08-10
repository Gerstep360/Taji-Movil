import 'dart:convert';

import 'package:flutter/services.dart';

class ApiConfig {
  ApiConfig._();

  static const assetPath = 'assets/config/app_config.json';
  static String _baseUrl = 'http://localhost:8000/api/v1';
  static Duration _connectTimeout = const Duration(seconds: 12);
  static Duration _receiveTimeout = const Duration(seconds: 12);

  static String get baseUrl => _baseUrl;
  static Duration get connectTimeout => _connectTimeout;
  static Duration get receiveTimeout => _receiveTimeout;

  /// Carga la configuración empaquetada en el APK/IPA.
  /// No depende de --dart-define, por lo que funciona igual en release.
  static Future<void> initialize({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    final json = jsonDecode(source) as Map<String, dynamic>;
    _baseUrl = _normalize(_requiredString(json, 'apiBaseUrl'));
    _connectTimeout = Duration(
      milliseconds: _positiveInt(json, 'connectTimeoutMs', fallback: 12000),
    );
    _receiveTimeout = Duration(
      milliseconds: _positiveInt(json, 'receiveTimeoutMs', fallback: 12000),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Falta $key en $assetPath.');
    }
    return value;
  }

  static int _positiveInt(
    Map<String, dynamic> json,
    String key, {
    required int fallback,
  }) {
    final value = json[key];
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  static String _normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'/$'), '');
}
