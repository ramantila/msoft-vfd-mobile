import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

/// Persists the authenticated [Session] in secure storage (Keychain on iOS,
/// EncryptedSharedPreferences on Android) and caches it in memory so
/// [readToken] — called on every outgoing API request — stays fast and
/// synchronous-feeling without hitting the storage plugin each time.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _key = 'csp_session';
  final _storage = const FlutterSecureStorage();

  Session? _cached;

  Session? get current => _cached;

  Future<String?> readToken() async {
    if (_cached != null) return _cached!.token;
    return (await load())?.token;
  }

  Future<Session?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      _cached = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cached;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(Session session) async {
    _cached = session;
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}
