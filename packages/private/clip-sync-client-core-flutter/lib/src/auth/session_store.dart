import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/auth_session.dart';

/// Stores only login state and a client identifier in operating-system secure storage.
/// Clipboard history and clipboard payloads are never persisted here.
class SessionStore {
  SessionStore({
    FlutterSecureStorage? storage,
    this.allowVolatileFallback = false,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'clip_sync_';
  final FlutterSecureStorage _storage;

  /// Keeps session values only for this process if secure storage is denied.
  ///
  /// This is intended for ad-hoc-signed local builds. It never writes fallback
  /// values to an ordinary file.
  final bool allowVolatileFallback;
  final Map<String, String> _volatileValues = {};
  bool _usingVolatileStorage = false;

  Future<Map<String, String>> _readAll() async {
    if (_usingVolatileStorage) return Map.of(_volatileValues);
    try {
      final values = await _storage.readAll();
      _volatileValues.addAll(values);
      return values;
    } on PlatformException {
      if (!allowVolatileFallback) rethrow;
      _usingVolatileStorage = true;
      return Map.of(_volatileValues);
    }
  }

  Future<String?> _read(String key) async {
    if (_usingVolatileStorage) return _volatileValues[key];
    try {
      final value = await _storage.read(key: key);
      if (value != null) _volatileValues[key] = value;
      return value;
    } on PlatformException {
      if (!allowVolatileFallback) rethrow;
      _usingVolatileStorage = true;
      return _volatileValues[key];
    }
  }

  Future<void> _write(String key, String value) async {
    _volatileValues[key] = value;
    if (_usingVolatileStorage) return;
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException {
      if (!allowVolatileFallback) rethrow;
      _usingVolatileStorage = true;
    }
  }

  Future<void> _delete(String key) async {
    _volatileValues.remove(key);
    if (_usingVolatileStorage) return;
    try {
      await _storage.delete(key: key);
    } on PlatformException {
      if (!allowVolatileFallback) rethrow;
      _usingVolatileStorage = true;
    }
  }

  Future<AuthSession?> readSession() async {
    final allValues = await _readAll();
    final values = <String, String>{};
    for (final key in [
      'accessToken',
      'expiresAt',
      'accountUid',
      'email',
      'clipboardUid',
    ]) {
      final value = allValues['$_prefix$key'];
      if (value == null) return null;
      values[key] = value;
    }
    final session = AuthSession.fromStorage(values);
    if (session.isExpired) {
      await clearSession();
      return null;
    }
    return session;
  }

  Future<void> writeSession(AuthSession session) async {
    for (final entry in session.toStorage().entries) {
      await _write('$_prefix${entry.key}', entry.value);
    }
  }

  Future<void> clearSession() async {
    for (final key in [
      'accessToken',
      'expiresAt',
      'accountUid',
      'email',
      'clipboardUid',
    ]) {
      await _delete('$_prefix$key');
    }
  }

  Future<String> readOrCreateClientUid() async {
    final existing = await _read('${_prefix}clientUid');
    if (existing != null) return existing;
    final created = const Uuid().v4().replaceAll('-', '').toUpperCase();
    await _write('${_prefix}clientUid', created);
    return created;
  }

  Future<void> writeGoogleAccessToken(String token) =>
      _write('${_prefix}googleAccessToken', token);

  Future<String?> readGoogleAccessToken() =>
      _read('${_prefix}googleAccessToken');

  Future<void> clearGoogleAccessToken() =>
      _delete('${_prefix}googleAccessToken');
}
