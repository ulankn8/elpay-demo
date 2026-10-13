import 'dart:async';

import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/net/connectivity.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:elpay/data/accounts_repository.dart';
import 'package:elpay/data/api/elpay_api.dart';
import 'package:elpay/data/api/mock_api.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/probe_api.dart';

/// Обновление начислений: статусы счетов, время синхронизации и кэш.
///
/// Здесь проверяется то, что демо-бэкендом не проверить, потому что он
/// честный: отказ источника при живой сети, частичный отказ по ИЗВЕСТНОМУ
/// счёту и повторный поход в сеть по истечении TTL. Для этого между
/// репозиторием и демо-бэкендом стоит [ProbeElPayApi] — он считает
/// обращения и умеет уронить один метод.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Боевой репозиторий поверх демо-бэкенда, но с прослойкой-счётчиком.
  /// Хранилище, часы и сеть — те же швы, что в [makeEnv]; стенд целиком
  /// не берём, потому что ему нужен неподменённый `MockElPayApi`.
  ({
    DefaultAccountsRepository repo,
    ProbeElPayApi probe,
    MemoryLocalStore store,
    MovableClock clock,
    ManualConnectivity net,
    Duration ttl,
  }) stand({Duration ttl = const Duration(minutes: 15), MemoryLocalStore? store}) {
    store ??= MemoryLocalStore();
    final clock = MovableClock(testNow);
    final net = ManualConnectivity();
    final probe = ProbeElPayApi(MockElPayApi(
      store: store,
      connectivity: net,
      clock: clock.call,
      latency: Duration.zero,
    ));
    addTearDown(net.dispose);
    return (
      repo: DefaultAccountsRepository(
        api: probe,
        store: store,
        connectivity: net,
        outbox: Outbox(store),
        ids: SeqIdGen(),
        clock: clock.call,
        ttl: ttl,
      ),
      probe: probe,
      store: store,
      clock: clock,
      net: net,
      ttl: ttl,
    );
  }

  group('Удачное обновление', () {
    test('sync обновляет syncedAt и ставит статус ok', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();

      final before = await container.read(accountsProvider.future);
      expect(before.accounts, isNotEmpty);

      final result = await container.read(accountsProvider.notifier).sync();
      await settleProviders();

      expect(result.isOk, isTrue);
      final after = container.read(accountsProvider).value!;
      expect(after.syncing, isFalse, reason: 'спиннер снят');
      expect(after.syncedAt, env.now);
      expect(after.failure, isNull);
      expect(after.accounts.every((a) => a.status == AccountSyncStatus.ok), isTrue);
      expect(after.accounts.every((a) => a.syncedAt == env.now), isTrue);
      // Подпись «обновлено в ...» берётся отсюда и должна быть той же.
      expect(container.read(lastSyncProvider), env.now);
    });

    test('Счёт, обновлённый сейчас, не вызывает подсказку «пора обновить»', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();

      await container.read(accountsProvider.future);
      await container.read(accountsProvider.notifier).sync();
      await settleProviders();

      expect(container.read(syncHintProvider), isFalse);

      // Полсуток спустя подсказка обязана появиться — иначе начисления
      // так и останутся прошлогодними.
      env.advance(const Duration(hours: 13));
      container.invalidate(syncHintProvider);
      expect(container.read(syncHintProvider), isTrue);
    });
  });

  group('Отказ обновления', () {
    test('Отказ синхронизации помечает счета failed и сохраняет lastError', () async {
      final s = stand();
      await s.repo.accounts();
      s.probe.failAlways('syncCharges', const AppFailure.server('поставщик не ответил'));

      final result = await s.repo.sync();

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.server);
      final saved = s.repo.cachedAccounts();
      expect(saved, isNotEmpty);
      expect(saved.every((a) => a.status == AccountSyncStatus.failed), isTrue);
      // Причина обязана дожить до списка: без неё в строке счёта стоит
      // «не обновилось» и ни слова о том, почему.
      expect(saved.every((a) => (a.lastError ?? '').isNotEmpty), isTrue);
      expect(saved.first.lastError, contains('поставщик не ответил'));
    });

    test('sync дожидается записи кэша перед возвратом', () async {
      // Хранилище с ЗАДЕРЖИВАЕМОЙ записью. У MemoryLocalStore тело writeJson
      // синхронное (async только по подписи), поэтому пометка оказывалась
      // в кэше ещё до возврата sync — и тест был зелёным даже со снятым
      // await, то есть ровно того дефекта, под который написан, поймать
      // не мог. В бою стоит PrefsLocalStore с двумя настоящими await.
      final gate = _GatedStore();
      final s = stand(store: gate);
      await s.repo.accounts();
      s.probe.failAlways('syncCharges', const AppFailure.server());
      final writesBefore = s.store.writes;

      gate.hold();
      var returned = false;
      final pending = s.repo.sync().then((_) => returned = true);
      await settleProviders();

      // Ни одного лишнего await после возврата: экран перечитывает кэш
      // сразу, и пометка «не обновилось» обязана там уже лежать.
      expect(s.store.writes, writesBefore, reason: 'запись ещё не доехала');
      expect(returned, isFalse, reason: 'sync вернулся раньше записи кэша');

      gate.release();
      await pending;

      expect(s.store.writes, greaterThan(writesBefore));
      expect(
        s.repo.cachedAccounts().first.status,
        AccountSyncStatus.failed,
        reason: 'запись кэша не fire-and-forget',
      );
    });

    test('Частичный отказ помечает только свои счета', () async {
      final s = stand();
      final all = (await s.repo.accounts()).valueOrNull!;
      expect(all.length, greaterThan(1));
      final victim = all.first.id;
      // Источник знает счёт, но обновить его не смог — это частичный отказ,
      // а не общая ошибка: остальные счета обновились.
      s.probe.onSyncResult = (real) => SyncResult(
            bills: real.bills,
            accounts: real.accounts,
            syncedAt: real.syncedAt,
            failed: {victim: 'реестр поставщика недоступен'},
          );

      final result = await s.repo.sync();

      expect(result.isOk, isTrue, reason: 'частичный отказ — не общая ошибка');
      final marked = result.valueOrNull!.accounts;
      final failed = marked.where((a) => a.status == AccountSyncStatus.failed);
      expect(failed, hasLength(1));
      expect(failed.single.id, victim);
      expect(failed.single.lastError, 'реестр поставщика недоступен');
      expect(
        marked.where((a) => a.id != victim).every((a) => a.status == AccountSyncStatus.ok),
        isTrue,
      );
    });

    test('Состояние после отказа помечает счета и не теряет список', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      final before = await container.read(accountsProvider.future);
      env.offline();

      final result = await container.read(accountsProvider.notifier).sync();

      expect(result.isFail, isTrue);
      final after = container.read(accountsProvider).value!;
      expect(after.syncing, isFalse);
      expect(after.failure, isNotNull);
      expect(after.accounts, hasLength(before.accounts.length));
      expect(after.failedToSync, hasLength(before.accounts.length));
      // Та самая строка, которую раньше стирал copyWith: причина отказа
      // должна дойти до списка счетов.
      expect(after.accounts.first.lastError, isNotNull);
      expect(after.accounts.first.lastError, isNotEmpty);
    });

    test('Повторить только упавшие — обновляются именно они', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      final notifier = container.read(accountsProvider.notifier);
      final all = await container.read(accountsProvider.future);
      // Время обновления ДО повтора: по нему и видно, за какими счетами
      // приложение действительно сходило.
      final was = {for (final a in all.accounts) a.id: a.syncedAt};
      env.offline();
      await notifier.sync();
      env.online();

      final victim = container.read(accountsProvider).value!.accounts.first;
      final result = await notifier.sync(accountIds: [victim.id]);
      await settleProviders();

      expect(result.isOk, isTrue);
      final after = container.read(accountsProvider).value!;
      expect(after.accounts, hasLength(all.accounts.length));
      final retried = after.accounts.firstWhere((a) => a.id == victim.id);
      expect(retried.status, AccountSyncStatus.ok);
      expect(retried.syncedAt, env.now, reason: 'упавший счёт обновлён заново');
      // Без этой проверки тест оставался зелёным, даже если список
      // accountIds выбросить целиком: демо-бэкенд отвечает ВСЕМИ счетами
      // в любом случае, и адресность наблюдаема только по тому, у кого
      // сдвинулось время обновления. «Повторить только упавшие» по трём
      // счетам дёргало бы реестры всех трёх поставщиков.
      expect(
        {
          for (final a in after.accounts)
            if (a.id != victim.id) a.id: a.syncedAt,
        },
        {
          for (final e in was.entries)
            if (e.key != victim.id) e.key: e.value,
        },
        reason: 'адресный повтор не ходит за остальными счетами',
      );
    });
  });

  group('Кэш счетов', () {
    test('accounts() повторно идёт в сеть по истечении TTL', () async {
      final s = stand(ttl: const Duration(minutes: 15));

      await s.repo.accounts();
      expect(s.probe.callsOf('accounts'), 1);

      // Кэш свежий — второй раз в сеть не идём.
      await s.repo.accounts();
      expect(s.probe.callsOf('accounts'), 1, reason: 'свежий кэш отдаётся без сети');

      s.clock.advance(s.ttl * 2);
      await s.repo.accounts();

      // Раньше непустой кэш отдавался всегда и не обновлялся НИКОГДА.
      expect(s.probe.callsOf('accounts'), 2);
    });

    test('refresh идёт в сеть даже при свежем кэше', () async {
      final s = stand();

      await s.repo.accounts();
      await s.repo.accounts(refresh: true);

      expect(s.probe.callsOf('accounts'), 2, reason: 'pull-to-refresh обязан спросить');
    });

    test('Отказ источника при непустом кэше отдаёт сохранённое с пометкой', () async {
      final s = stand();
      await s.repo.accounts();
      s.clock.advance(s.ttl * 2);
      s.probe.failAlways('accounts', const AppFailure.server());

      final result = await s.repo.load(refresh: true);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.value, isNotEmpty);
      // Экран обязан узнать, что данные сохранённые, — иначе плашки
      // офлайна не будет.
      expect(result.valueOrNull!.fromCache, isTrue);
    });
  });
}

/// Хранилище в памяти, у которого запись можно ЗАДЕРЖАТЬ.
///
/// Нужно одному тесту — «sync дожидается записи кэша». У MemoryLocalStore
/// точки приостановки нет вовсе: writeJson помечен async, но тело из трёх
/// синхронных строк, и Dart выполняет его до возврата future. Поэтому
/// снятый `await` у записи кэша ничем не наблюдался. Боевой
/// PrefsLocalStore ждёт SharedPreferences по-настоящему — здесь это
/// ожидание отдано под управление теста.
class _GatedStore extends MemoryLocalStore {
  Completer<void>? _gate;

  /// Задержать следующие записи до [release].
  void hold() => _gate = Completer<void>();

  void release() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> writeJson(String key, Object? value, {required DateTime now}) async {
    final gate = _gate;
    if (gate != null) await gate.future;
    await super.writeJson(key, value, now: now);
  }
}
