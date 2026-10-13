import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/cache/local_store.dart';
import '../core/clock.dart';
import '../core/failure.dart';
import '../core/logger.dart';
import '../core/result.dart';

/// Данные плюс их происхождение: из кэша они или из источника и когда
/// обновлялись.
///
/// Экран спрашивает один раз и сам решает, рисовать ли плашку офлайна и
/// строку «обновлено в ...». Раньше для этого в каждом состоянии завёлся бы
/// свой `fromCache` и свой `syncedAt`, и они разъезжались: список обновился,
/// а подпись осталась от прошлой загрузки.
@immutable
class Cached<T> {
  const Cached(this.value, {this.fromCache = false, this.updatedAt});

  /// Данные соответствуют источнику: только что пришли из сети либо лежат
  /// в кэше и TTL ещё не истёк. Плашку офлайна рисовать не надо.
  const Cached.fresh(T value, DateTime at) : this(value, updatedAt: at);

  /// Показываем сохранённое, потому что источник не ответил. Именно по этому
  /// признаку экран рисует OfflineBanner и подпись с временем обновления.
  const Cached.stale(T value, DateTime? at)
      : this(value, fromCache: true, updatedAt: at);

  final T value;

  /// Источник не ответил, и это сохранённая копия.
  final bool fromCache;

  /// Когда данные последний раз приходили из источника. null — время записи
  /// неизвестно (кэш писали до появления отметок или запись стёрли).
  final DateTime? updatedAt;

  /// Данные актуальны. Обратная сторона [fromCache] — читается в условиях
  /// понятнее, чем `!fromCache`.
  bool get isFresh => !fromCache;

  /// Пересобрать значение, сохранив происхождение: `cached.map((l) => l.length)`.
  /// Нужно репозиториям, которые отдают наружу не то же, что кладут в кэш.
  Cached<R> map<R>(R Function(T value) f) =>
      Cached<R>(f(value), fromCache: fromCache, updatedAt: updatedAt);

  @override
  String toString() =>
      'Cached(${fromCache ? 'кэш' : 'источник'}, updatedAt: $updatedAt)';
}

/// Политика доставки данных: «сначала кэш, потом сеть», один раз для всех
/// репозиториев.
///
/// Общая для демо и боя: подменяется ИСТОЧНИК (ElPayApi), а не политика,
/// поэтому офлайн-путь, обкатанный на демо, — тот же, что встретит живой
/// бэкенд. До этого каждый репозиторий писал свои восемь строк про TTL,
/// запись кэша и откат на сохранённое, и они уже успели разъехаться:
/// в bills_repository проверка TTL была, в accounts_repository — нет, и
/// непустой кэш счетов не обновлялся никогда.
///
/// Три исхода [load] и ровно то, что видит пользователь:
///   * кэш свежий (TTL не истёк) — `Ok(Cached.fresh)`, в сеть не идём;
///   * источник ответил — `Ok(Cached.fresh)`, кэш перезаписан;
///   * источник упал, кэш есть — `Ok(Cached.stale)`, экран рисует офлайн;
///   * источник упал, кэша нет — `Fail(failure)`, экран рисует ошибку;
///   * источник ответил 401/403 — `Fail(failure)` ВСЕГДА, даже с кэшем:
///     «нужно войти заново» обязано дойти до экрана, а не спрятаться
///     под плашкой офлайна.
///
/// Зависит только от контракта [LocalStore], а не от SharedPreferences,
/// поэтому тесты политики обходятся `MemoryLocalStore` без биндинга
/// flutter_test.
///
/// ```dart
/// final policy = CachePolicy.list<ConnectedAccount>(
///   store: store,
///   key: CacheKeys.accounts,
///   ttl: const Duration(minutes: 15),
///   item: ConnectedAccount.fromJson,
///   row: (a) => a.toJson(),
/// );
/// final result = await policy.load(refresh: refresh, fetch: api.accounts);
/// ```
class CachePolicy<T> {
  const CachePolicy({
    required this.store,
    required this.key,
    required this.ttl,
    required this.decode,
    required this.encode,
    this.clock,
  });

  /// Политика для данных, которые лежат ОДНИМ объектом, а не списком
  /// (каталог платежей). Внутри всё равно хранится список из одной записи —
  /// у [LocalStore] одна форма чтения для всех ключей кэша.
  CachePolicy.object({
    required LocalStore store,
    required String key,
    required Duration ttl,
    required T Function(Map<String, dynamic> json) decode,
    required Map<String, dynamic> Function(T value) encode,
    Clock? clock,
  }) : this(
          store: store,
          key: key,
          ttl: ttl,
          clock: clock,
          decode: (rows) => rows.isEmpty
              ? throw const FormatException('пустая запись кэша')
              : decode(rows.first),
          encode: (value) => [encode(value)],
        );

  /// Самый частый случай: список моделей с `fromJson`/`toJson`.
  /// Избавляет репозитории от двух одинаковых замыканий на каждый ключ.
  static CachePolicy<List<E>> list<E>({
    required LocalStore store,
    required String key,
    required Duration ttl,
    required E Function(Map<String, dynamic> json) item,
    required Map<String, dynamic> Function(E value) row,
    Clock? clock,
  }) =>
      CachePolicy<List<E>>(
        store: store,
        key: key,
        ttl: ttl,
        clock: clock,
        decode: (rows) => [for (final r in rows) item(r)],
        encode: (values) => [for (final v in values) row(v)],
      );

  final LocalStore store;

  /// Ключ из [CacheKeys] — не свободная строка, иначе ключи разъезжаются.
  final String key;

  /// Сколько данные считаются свежими. Истёк — идём в источник, но
  /// сохранённое не выбрасываем: оно пригодится, если источник молчит.
  final Duration ttl;

  final T Function(List<Map<String, dynamic>> rows) decode;
  final List<Map<String, dynamic>> Function(T value) encode;

  /// Часы. Нужны там, где вызывающий не хочет передавать `now` в каждый
  /// метод; тест подставляет `MovableClock(...).call` и двигает время руками.
  /// Явный `now` в методе приоритетнее часов.
  final Clock? clock;

  static const _tag = 'cache';

  /// Что лежит в кэше прямо сейчас. null — записи нет ИЛИ она не читается.
  ///
  /// Пустой список в ответе и отсутствие записи — разные вещи: «у тебя нет
  /// подключённых счетов» мы помним и не ходим за этим в сеть каждый раз,
  /// а вот отсутствие записи означает, что мы не знаем ничего.
  T? read() {
    final rows = store.readList(key);
    if (rows == null) return null;
    try {
      return decode(rows);
    } catch (e, st) {
      // Запись читается как JSON, но не разбирается в модель: формат
      // изменился или данные битые. Стираем, иначе она будет мешать вечно.
      Log.e(_tag, 'запись $key не разобралась, стираем', e, st);
      unawaited(clear());
      return null;
    }
  }

  /// Положить данные в кэш. [now] — момент записи, по нему считается TTL.
  Future<void> write(T value, {DateTime? now}) =>
      store.writeJson(key, encode(value), now: _at(now));

  /// TTL ещё не истёк. Записи нет — не свежо.
  bool isFresh({DateTime? now}) => !store.isStale(key, ttl, now: _at(now));

  /// Когда ключ обновляли в последний раз — для подписи «обновлено в ...».
  DateTime? updatedAt() => store.updatedAt(key);

  /// Забыть этот ключ. Нужно при выходе из аккаунта и при смене формата.
  Future<void> clear() => store.remove(key);

  /// Свежий кэш отдаём сразу; иначе идём в [fetch] и пишем результат.
  ///
  /// [refresh] = true — в сеть идём всегда (pull-to-refresh и кнопка
  /// «Повторить»), но при отказе по-прежнему откатываемся на сохранённое:
  /// пользователь дёрнул список в офлайне и не должен получить пустой экран.
  ///
  /// Исключения из [fetch] превращаются в AppFailure через `guard`, поэтому
  /// источнику разрешено бросать — выше по стеку исключений уже нет.
  Future<Result<Cached<T>>> load({
    bool refresh = false,
    DateTime? now,
    required Future<T> Function() fetch,
  }) async {
    final at = _at(now);
    final cache = read();

    if (!refresh && cache != null && isFresh(now: at)) {
      Log.d(_tag, '$key: кэш свежий, в сеть не идём');
      return Ok(Cached<T>.fresh(cache, updatedAt() ?? at));
    }

    switch (await guard(fetch)) {
      case Ok<T>(:final value):
        await write(value, now: at);
        return Ok(Cached<T>.fresh(value, at));
      case Fail<T>(:final failure):
        // Отказ, который требует действия пользователя, кэшем не прикрыть:
        // 401/403 означают «войди заново», а под сохранёнными данными экран
        // нарисовал бы плашку офлайна, и войти не предложил бы никто.
        // Остальные отказы по-прежнему откатываются на сохранённое.
        if (cache != null && failure.kind != FailureKind.auth) {
          // Данные есть, свежих нет — это не ошибка экрана, а офлайн.
          Log.w(_tag, '$key: источник молчит (${failure.message}), отдаём сохранённое');
          return Ok(Cached<T>.stale(cache, updatedAt()));
        }
        Log.w(_tag, '$key: источник молчит (${failure.message}) и кэша нет');
        return Fail<Cached<T>>(failure);
    }
  }

  /// Явный `now` важнее часов, часы важнее системного времени. Так политика
  /// остаётся детерминированной в тестах и не требует часов в бою.
  DateTime _at(DateTime? now) => now ?? clock?.call() ?? DateTime.now();
}
