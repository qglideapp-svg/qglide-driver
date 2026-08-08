import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores auth tokens in platform secure storage (Keychain / Keystore).
class SecureSessionStorage {
  SecureSessionStorage._();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiresAtKey = 'token_expires_at';
  static const _legacyAccessTokenKey = 'access_token';
  static const _legacyRefreshTokenKey = 'refresh_token';
  static const _legacyTokenExpiresAtKey = 'token_expires_at';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static var _migrationDone = false;

  static Future<void> _migrateFromSharedPreferencesIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (_migrationDone) return;

    final legacyAccess = prefs.getString(_legacyAccessTokenKey);
    final legacyRefresh = prefs.getString(_legacyRefreshTokenKey);
    final legacyExpiresAt = prefs.getInt(_legacyTokenExpiresAtKey);

    if ((legacyAccess == null || legacyAccess.isEmpty) &&
        (legacyRefresh == null || legacyRefresh.isEmpty)) {
      _migrationDone = true;
      return;
    }

    final secureAccess = await _storage.read(key: _accessTokenKey);
    final secureRefresh = await _storage.read(key: _refreshTokenKey);
    if ((secureAccess == null || secureAccess.isEmpty) &&
        legacyAccess != null &&
        legacyAccess.isNotEmpty) {
      await _storage.write(key: _accessTokenKey, value: legacyAccess);
    }
    if ((secureRefresh == null || secureRefresh.isEmpty) &&
        legacyRefresh != null &&
        legacyRefresh.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: legacyRefresh);
    }
    if (legacyExpiresAt != null) {
      final secureExpires = await _storage.read(key: _tokenExpiresAtKey);
      if (secureExpires == null || secureExpires.isEmpty) {
        await _storage.write(
          key: _tokenExpiresAtKey,
          value: legacyExpiresAt.toString(),
        );
      }
    }

    await prefs.remove(_legacyAccessTokenKey);
    await prefs.remove(_legacyRefreshTokenKey);
    await prefs.remove(_legacyTokenExpiresAtKey);
    _migrationDone = true;
  }

  static Future<SecureSessionSnapshot> read({
    required SharedPreferences? prefs,
  }) async {
    if (prefs != null) {
      await _migrateFromSharedPreferencesIfNeeded(prefs);
    }

    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final expiresRaw = await _storage.read(key: _tokenExpiresAtKey);
    int? expiresAtMs;
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      expiresAtMs = int.tryParse(expiresRaw);
    }

    return SecureSessionSnapshot(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAtMs: expiresAtMs,
    );
  }

  static Future<void> write({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _tokenExpiresAtKey,
        value: expiresAt.millisecondsSinceEpoch.toString(),
      );
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiresAtKey);
  }
}

class SecureSessionSnapshot {
  const SecureSessionSnapshot({
    this.accessToken,
    this.refreshToken,
    this.expiresAtMs,
  });

  final String? accessToken;
  final String? refreshToken;
  final int? expiresAtMs;
}
