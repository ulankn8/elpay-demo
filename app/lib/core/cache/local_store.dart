import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';

/// Локальное хранилище JSON поверх SharedPreferences.
///
/// Нужно, чтобы приложение открывалось мгновенно и работало без сети:
/// репозиторий сначала отдаёт сохранённое, потом обновляет из источника.
/// Когда данных станет много, сюда подставится SQLite — контракт не изменится.
class LocalStore {
  LocalStore(this._p);

  final SharedPreferences _p;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  static const _prefix = 'cache.';
  static const _stampSuffix = '.at';

  String _k(String key) => '$_prefix$key';
  String _stampKey(String key) => '$_prefix$key$_stampSuffix';

  /// Когда ключ обновляли в последний раз.
  DateTime? updatedAt(String key) {
    final ms = _p.getInt(_stampKey(key));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Данные старше [ttl] или их нет вовсе.
  bool isStale(String key, Duration ttl, {required DateTime now}) {
    final at = updatedAt(key);
    return at == null || now.difference(at) > ttl;
  }

  Future<void> writeJson(String key, Object? value, {required DateTime now}) async {
    try {
      await _p.setString(_k(key), jsonEncode(value));
      await _p.setInt(_stampKey(key), now.millisecondsSinceEpoch);
    } catch (e, st) {
      Log.e('cache', 'не удалось записать $key', e, st);
    }
  }

  /// Карта по ключу или null, если ничего не сохранено либо запись битая.
  Map<String, dynamic>? readMap(String key) {
    final raw = _p.getString(_k(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      Log.w('cache', 'битая запись $key, стираем');
      _p.remove(_k(key));
      return null;
    }
  }

  /// Список по ключу или null.
  List<Map<String, dynamic>>? readList(String key) {
    final raw = _p.getString(_k(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      Log.w('cache', 'битая запись $key, стираем');
      _p.remove(_k(key));
      return null;
    }
  }

  Future<void> remove(String key) async {
    await _p.remove(_k(key));
    await _p.remove(_stampKey(key));
  }

  /// Стереть весь кэш — при выходе из аккаунта и удалении профиля.
  Future<void> clear() async {
    final keys = _p.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _p.remove(k);
    }
    Log.i('cache', 'очищено записей: ${keys.length}');
  }
}

/// Ключи кэша в одном месте — чтобы не разъезжались по файлам.
class CacheKeys {
  const CacheKeys._();

  static const objects = 'objects';
  static const bills = 'bills';
  static const accounts = 'accounts';
  static const history = 'history';
  static const stories = 'stories';
  static const notices = 'notices';
  static const outbox = 'outbox';
}
