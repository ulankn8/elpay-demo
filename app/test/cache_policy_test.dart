import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/data/cache_policy.dart';
import 'package:elpay/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fixtures.dart';

/// Политика «сначала кэш, потом сеть» — одна для всех репозиториев.
///
/// Тест идёт без биндинга и без SharedPreferences: политика зависит от
/// контракта [LocalStore], а не от его боевой реализации.
void main() {
  Log.enabled = false;

  const ttl = Duration(minutes: 15);

  ({MemoryLocalStore store, MovableClock clock, CachePolicy<List<PayObject>> policy})
      make() {
    final store = MemoryLocalStore();
    final clock = MovableClock(testNow);
    return (
      store: store,
      clock: clock,
      policy: CachePolicy.list<PayObject>(
        store: store,
        key: CacheKeys.objects,
        ttl: ttl,
        item: PayObject.fromJson,
        row: (o) => o.toJson(),
        clock: clock.call,
      ),
    );
  }

  test('Свежий кэш отдаётся без похода в сеть', () async {
    final env = make();
    await env.policy.write(const [homeObject]);

    var fetches = 0;
    final result = await env.policy.load(fetch: () async {
      fetches++;
      return const [parentsObject];
    });

    expect(fetches, 0, reason: 'TTL не истёк — в сеть идти не за чем');
    final cached = result.valueOrNull!;
    expect(cached.value.single.id, homeObject.id);
    expect(cached.isFresh, isTrue);
    expect(cached.fromCache, isFalse);
    expect(cached.updatedAt, testNow);
  });

  test('Протухший кэш обновляется из источника', () async {
    final env = make();
    await env.policy.write(const [homeObject]);
    env.clock.advance(ttl + const Duration(minutes: 1));

    var fetches = 0;
    final result = await env.policy.load(fetch: () async {
      fetches++;
      return const [parentsObject];
    });

    expect(fetches, 1);
    expect(result.valueOrNull!.value.single.id, parentsObject.id);
    expect(result.valueOrNull!.isFresh, isTrue);
    // Кэш перезаписан вместе с отметкой времени.
    expect(env.policy.read()!.single.id, parentsObject.id);
    expect(env.policy.updatedAt(), env.clock.value);
  });

  test('refresh идёт в источник даже при свежем кэше', () async {
    final env = make();
    await env.policy.write(const [homeObject]);

    var fetches = 0;
    final result = await env.policy.load(
      refresh: true,
      fetch: () async {
        fetches++;
        return const [parentsObject];
      },
    );

    // Потянули список вниз — пользователь просил именно сеть.
    expect(fetches, 1);
    expect(result.valueOrNull!.value.single.id, parentsObject.id);
  });

  test('Ошибка сети при непустом кэше отдаёт данные с пометкой fromCache', () async {
    final env = make();
    await env.policy.write(const [homeObject]);
    env.clock.advance(const Duration(hours: 1));

    final result = await env.policy.load(
      fetch: () async => throw const AppFailure.network(),
    );

    // Для экрана это не ошибка, а офлайн: показываем сохранённое.
    expect(result.isOk, isTrue);
    final cached = result.valueOrNull!;
    expect(cached.fromCache, isTrue);
    expect(cached.isFresh, isFalse);
    expect(cached.value.single.id, homeObject.id);
    expect(cached.updatedAt, testNow, reason: 'подпись «обновлено в ...» честная');
  });

  test('Ошибка сети при пустом кэше отдаёт Fail', () async {
    final env = make();

    final result = await env.policy.load(
      fetch: () async => throw const AppFailure.network('нет связи'),
    );

    expect(result.isFail, isTrue);
    expect(result.failureOrNull!.kind, FailureKind.network);
    expect(env.policy.read(), isNull);
  });

  test('Пустой список в кэше — это не отсутствие записи', () async {
    final env = make();
    await env.policy.write(const []);

    var fetches = 0;
    final result = await env.policy.load(fetch: () async {
      fetches++;
      return const [homeObject];
    });

    // «У тебя нет ни одного объекта» мы помним и не спрашиваем заново.
    expect(fetches, 0);
    expect(result.valueOrNull!.value, isEmpty);
    expect(env.policy.read(), isEmpty);
  });

  test('Битый JSON в кэше не ломает чтение и запись стирается', () async {
    final env = make();

    // Запись не читается как JSON вообще.
    env.store.corrupt(CacheKeys.objects, now: testNow);
    expect(env.policy.read(), isNull);
    expect(env.store.raw(CacheKeys.objects), isNull, reason: 'битая запись стёрта');

    // Запись читается как JSON, но не разбирается в модель: формат
    // изменился. Такая запись мешала бы вечно, поэтому тоже стирается.
    await env.store.writeJson(CacheKeys.objects, [
      {'нет': 'id'},
    ], now: testNow);
    expect(env.policy.read(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(env.store.raw(CacheKeys.objects), isNull);

    // И после этого политика продолжает работать: идёт в источник.
    final result = await env.policy.load(fetch: () async => const [homeObject]);
    expect(result.valueOrNull!.value.single.id, homeObject.id);
  });
}
