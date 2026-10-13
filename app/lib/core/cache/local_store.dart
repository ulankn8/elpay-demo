import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger.dart';

/// Локальное хранилище JSON — контракт.
///
/// Нужно, чтобы приложение открывалось мгновенно и работало без сети:
/// репозиторий сначала отдаёт сохранённое, потом обновляет из источника.
///
/// Это АБСТРАКЦИЯ, а не класс поверх SharedPreferences: она разрывает
/// цепочку «репозиторий → SharedPreferences» сразу во всех репозиториях.
/// Поэтому тесты кэша, очереди и подключения счетов больше не тащат
/// TestWidgetsFlutterBinding и setMockInitialValues — им хватает
/// [MemoryLocalStore]. Когда данных станет много, рядом встанет
/// SqliteLocalStore, и контракт снова не изменится.
///
/// Реализации: [PrefsLocalStore] — бой, [MemoryLocalStore] — тесты.
abstract class LocalStore {
  const LocalStore();

  /// Боевое хранилище. Оставлено статической фабрикой, чтобы существующие
  /// вызовы `await LocalStore.open()` в main.dart и тестах не правились.
  static Future<LocalStore> open() async => PrefsLocalStore.open();

  /// Когда ключ обновляли в последний раз.
  DateTime? updatedAt(String key);

  Future<void> writeJson(String key, Object? value, {required DateTime now});

  /// Карта по ключу или null, если ничего не сохранено либо запись битая.
  Map<String, dynamic>? readMap(String key);

  /// Список по ключу или null.
  List<Map<String, dynamic>>? readList(String key);

  Future<void> remove(String key);

  /// Стереть весь кэш — при выходе из аккаунта и удалении профиля.
  Future<void> clear();

  /// Данные старше [ttl] или их нет вовсе. Правило одно для всех
  /// реализаций, поэтому живёт здесь, а не копируется в каждую.
  bool isStale(String key, Duration ttl, {required DateTime now}) {
    final at = updatedAt(key);
    return at == null || now.difference(at) > ttl;
  }
}

/// Боевое хранилище поверх SharedPreferences.
///
/// Все ключи лежат под префиксом 'cache.', поэтому [clear] стирает кэш
/// и не задевает настройки из AppPrefs (сессия, язык, тема, код-пароль).
class PrefsLocalStore extends LocalStore {
  PrefsLocalStore(this._p);

  final SharedPreferences _p;

  static Future<PrefsLocalStore> open() async =>
      PrefsLocalStore(await SharedPreferences.getInstance());

  static const _prefix = 'cache.';
  static const _stampSuffix = '.at';

  String _k(String key) => '$_prefix$key';
  String _stampKey(String key) => '$_prefix$key$_stampSuffix';

  @override
  DateTime? updatedAt(String key) {
    final ms = _p.getInt(_stampKey(key));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> writeJson(String key, Object? value, {required DateTime now}) async {
    try {
      await _p.setString(_k(key), jsonEncode(value));
      await _p.setInt(_stampKey(key), now.millisecondsSinceEpoch);
    } catch (e, st) {
      Log.e('cache', 'не удалось записать $key', e, st);
    }
  }

  @override
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

  @override
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

  @override
  Future<void> remove(String key) async {
    await _p.remove(_k(key));
    await _p.remove(_stampKey(key));
  }

  @override
  Future<void> clear() async {
    final keys = _p.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _p.remove(k);
    }
    Log.i('cache', 'очищено записей: ${keys.length}');
  }
}

/// Хранилище в памяти — для тестов.
///
/// Ведёт себя как боевое, включая стирание битой записи при чтении:
/// тест «битый JSON в кэше не ломает чтение» проверяет ту же ветку кода,
/// что отработает на телефоне. Переживает пересоздание репозитория,
/// но не пересоздание самого себя — поэтому тест перезапуска приложения
/// держит ОДИН экземпляр и строит поверх него новые репозитории.
class MemoryLocalStore extends LocalStore {
  MemoryLocalStore();

  final Map<String, String> _data = {};
  final Map<String, DateTime> _stamps = {};

  /// Какие ключи сейчас заняты — для проверок в тестах.
  Iterable<String> get keys => _data.keys;

  bool get isEmpty => _data.isEmpty;

  /// Сколько раз хранилище писали. Проверка «sync дожидается записи кэша».
  int writes = 0;

  @override
  DateTime? updatedAt(String key) => _stamps[key];

  @override
  Future<void> writeJson(String key, Object? value, {required DateTime now}) async {
    _data[key] = jsonEncode(value);
    _stamps[key] = now;
    writes++;
  }

  @override
  Map<String, dynamic>? readMap(String key) {
    final raw = _data[key];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      Log.w('cache', 'битая запись $key, стираем');
      _data.remove(key);
      return null;
    }
  }

  @override
  List<Map<String, dynamic>>? readList(String key) {
    final raw = _data[key];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      Log.w('cache', 'битая запись $key, стираем');
      _data.remove(key);
      return null;
    }
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
    _stamps.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
    _stamps.clear();
  }

  /// Положить в ключ заведомо битый JSON — проверка живучести чтения.
  void corrupt(String key, {required DateTime now}) {
    _data[key] = '{не json';
    _stamps[key] = now;
  }

  /// Сырое содержимое ключа — чтобы тест видел, ЧТО записали.
  String? raw(String key) => _data[key];
}

/// Ключи кэша в одном месте — чтобы не разъезжались по файлам.
class CacheKeys {
  const CacheKeys._();

  static const objects = 'objects';
  static const bills = 'bills';
  static const accounts = 'accounts';
  static const history = 'history';

  /// Купленные билеты маркета.
  static const tickets = 'tickets';
  static const stories = 'stories';
  static const notices = 'notices';
  static const outbox = 'outbox';

  /// Каталог платежей: категории, поставщики, способы оплаты, маски счетов.
  static const catalog = 'catalog';

  /// Состояние демо-бэкенда (MockElPayApi): подключённые счета, начисления,
  /// подтверждённые кандидаты. Лежит в том же хранилище под своим ключом,
  /// поэтому после перезапуска id не расходятся и отключение не падает
  /// в notFound.
  static const mockServer = 'mockServer';
}
