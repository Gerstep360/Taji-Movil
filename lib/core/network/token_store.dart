import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage.dart';

class TokenPair {
  const TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? tajiSecureStorage;

  static const _accessKey = 'taji_access_token';
  static const _refreshKey = 'taji_refresh_token';
  static const _tenantIdKey = 'taji_active_tenant_id';

  final FlutterSecureStorage _storage;

  String? _access;
  String? _refresh;
  String? _tenantId;
  bool _loaded = false;

  Future<String?> get access async {
    await _loadOnce();
    return _access;
  }

  Future<String?> get refresh async {
    await _loadOnce();
    return _refresh;
  }

  Future<String?> get tenantId async {
    await _loadOnce();
    return _tenantId;
  }

  Future<bool> get hasRefresh async => (await refresh)?.isNotEmpty == true;

  Future<void> save(TokenPair pair) async {
    _access = pair.access;
    _refresh = pair.refresh;
    _loaded = true;
    await Future.wait([
      _storage.write(key: _accessKey, value: pair.access),
      _storage.write(key: _refreshKey, value: pair.refresh),
    ]);
  }

  Future<void> setTenantId(String? id) async {
    _tenantId = id;
    if (id == null) {
      await _storage.delete(key: _tenantIdKey);
    } else {
      await _storage.write(key: _tenantIdKey, value: id);
    }
  }

  Future<void> updateAccess(String access, {String? rotatedRefresh}) async {
    _access = access;
    _refresh = rotatedRefresh ?? _refresh;
    _loaded = true;
    await Future.wait([
      _storage.write(key: _accessKey, value: access),
      if (rotatedRefresh != null)
        _storage.write(key: _refreshKey, value: rotatedRefresh),
    ]);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _tenantId = null;
    _loaded = true;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _tenantIdKey),
    ]);
  }

  Future<void> _loadOnce() async {
    if (_loaded) return;
    final values = await Future.wait([
      _storage.read(key: _accessKey),
      _storage.read(key: _refreshKey),
      _storage.read(key: _tenantIdKey),
    ]);
    _access = values[0];
    _refresh = values[1];
    _tenantId = values[2];
    _loaded = true;
  }
}
