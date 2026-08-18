import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/auth_session.dart';

/// Stores only login state and a client identifier in operating-system secure storage.
/// Clipboard history and clipboard payloads are never persisted here.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'clip_sync_';
  final FlutterSecureStorage _storage;

  Future<AuthSession?> readSession() async {
    final allValues = await _storage.readAll();
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
      await _storage.write(key: '$_prefix${entry.key}', value: entry.value);
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
      await _storage.delete(key: '$_prefix$key');
    }
  }

  Future<String> readOrCreateClientUid() async {
    final existing = await _storage.read(key: '${_prefix}clientUid');
    if (existing != null) return existing;
    final created = const Uuid().v4().replaceAll('-', '').toUpperCase();
    await _storage.write(key: '${_prefix}clientUid', value: created);
    return created;
  }

  Future<void> writeGoogleAccessToken(String token) =>
      _storage.write(key: '${_prefix}googleAccessToken', value: token);

  Future<String?> readGoogleAccessToken() =>
      _storage.read(key: '${_prefix}googleAccessToken');

  Future<void> clearGoogleAccessToken() =>
      _storage.delete(key: '${_prefix}googleAccessToken');
}
