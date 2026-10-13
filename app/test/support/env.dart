import 'dart:convert';

import 'package:elpay/core/analytics.dart';
import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/core/net/connectivity.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:elpay/core/prefs.dart';
import 'package:elpay/data/accounts_repository.dart';
import 'package:elpay/data/api/mock_api.dart';
import 'package:elpay/data/bills_repository.dart';
import 'package:elpay/data/catalog_repository.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/data/payments_repository.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Тип Override лежит в отдельной точке входа riverpod 3 и из
// flutter_riverpod.dart не видно — иначе список подмен не типизировать.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

/// Фиксированное «сейчас» всех тестов.
///
/// Дата намеренно не сегодняшняя: если тест зелёный только первого числа
/// или только в марте, он не тест, а совпадение.
final DateTime testNow = DateTime(2026, 3, 10, 9, 30);

/// Стенд для тестов слоя данных.
///
/// Собирает то, что в бою собирает `main()`, но с подменёнными швами:
/// хранилище в памяти ([MemoryLocalStore]), фиксированные часы
/// ([MovableClock]), сеть с ручным выключателем ([ManualConnectivity]),
/// предсказуемые id и ключи идемпотентности ([SeqIdGen]) и демо-бэкенд
/// без задержки.
///
/// Именно из-за `MemoryLocalStore` тесты правил, кэша, очереди и
/// подключения счетов НЕ тащат `TestWidgetsFlutterBinding` и
/// `SharedPreferences.setMockInitialValues`: цепочка
/// «репозиторий → SharedPreferences» разорвана контрактом [LocalStore].
///
/// Биндинг нужен ровно одному сценарию — [container], потому что
/// `AppPrefs` лежит на SharedPreferences. Тест, который зовёт [container],
/// обязан начинаться с `TestWidgetsFlutterBinding.ensureInitialized()`.
///
/// ```dart
/// final env = makeEnv();
/// addTearDown(env.dispose);
/// final found = await env.accounts.search(const AccountQuery.byAccount('31-00562'));
/// ```
class TestEnv {
  TestEnv._({
    required this.store,
    required this.net,
    required this.clock,
    required this.ids,
    required this.api,
    required this.outbox,
    required this.accounts,
    required this.bills,
    required this.catalog,
    required this.payments,
    required this.accountsTtl,
    required this.latency,
  });

  /// Хранилище в памяти: одно на «устройство». Чтобы проверить перезапуск,
  /// берут [restart] — он строит новые объекты поверх ЭТОГО же хранилища.
  final MemoryLocalStore store;

  final ManualConnectivity net;

  /// Часы, которые двигаются только руками теста: `env.advance(ttl * 2)`.
  final MovableClock clock;

  /// Выдаёт 'loc_bill_1', 'accounts.connect-1' — ключи в ожиданиях теста
  /// можно писать буквами, а не сверять регулярным выражением.
  final SeqIdGen ids;

  final MockElPayApi api;
  final Outbox outbox;

  final DefaultAccountsRepository accounts;
  final DefaultBillsRepository bills;
  final DefaultCatalogRepository catalog;
  final StubPaymentsRepository payments;

  /// Какой TTL отдан кэшу счетов — чтобы тест не повторял это число.
  final Duration accountsTtl;

  /// Задержка демо-бэкенда. По умолчанию ноль: прогон не ждёт 420 мс
  /// на каждый запрос.
  final Duration latency;

  final List<ProviderContainer> _containers = [];

  DateTime get now => clock.value;

  void advance(Duration d) => clock.advance(d);

  /// Сеть пропала / вернулась.
  void offline() => net.setOnline(false);
  void online() => net.setOnline(true);

  /// Перезапуск приложения: прежнее хранилище, новые репозитории и новый
  /// демо-бэкенд. Ровно этим проверяется, что id счетов не разъезжаются.
  TestEnv restart() => makeEnv(
        store: store,
        now: clock.value,
        online: net.isOnline,
        latency: latency,
        accountsTtl: accountsTtl,
      );

  /// Подмены Riverpod поверх того же стенда.
  ///
  /// Отдельно от [container], потому что виджет-тесту нужен список для
  /// `ProviderScope(overrides: ...)`, а не готовый контейнер.
  /// ТРЕБУЕТ `TestWidgetsFlutterBinding.ensureInitialized()` в начале
  /// `main()` — из-за `AppPrefs` поверх SharedPreferences.
  ///
  /// [session] — кого считать вошедшим пользователем. null (по умолчанию)
  /// оставляет сессию пустой: на первом запуске её и нет.
  Future<List<Override>> overrides({
    List<Override> extra = const [],
    AccountsRepository? accountsRepo,
    BillsRepository? billsRepo,
    CatalogRepository? catalogRepo,
    PaymentsRepository? paymentsRepo,
    Session? session,
    bool onboarded = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (session != null) 'flutter.session': jsonEncode(session.toJson()),
      if (session != null) 'flutter.onboarded': onboarded,
    });
    final prefs = await AppPrefs.open();
    return [
      prefsProvider.overrideWithValue(prefs),
      localStoreProvider.overrideWithValue(store),
      // Часы и генератор id — тоже швы: без них даты в состоянии зависят
      // от дня запуска, а id — от миллисекунды.
      clockProvider.overrideWithValue(clock.call),
      idGenProvider.overrideWithValue(ids),
      connectivityProvider.overrideWithValue(net),
      outboxProvider.overrideWithValue(outbox),
      apiProvider.overrideWithValue(api),
      analyticsProvider.overrideWithValue(const NoopAnalytics()),
      // Репозитории подменяются ИМЕНОВАННЫМИ параметрами, а не через
      // [extra]: Riverpod 3 запрещает две подмены одного провайдера
      // в одном контейнере, и список из `extra` молча ломал бы стенд.
      billsRepoProvider.overrideWithValue(billsRepo ?? bills),
      accountsRepoProvider.overrideWithValue(accountsRepo ?? accounts),
      catalogRepoProvider.overrideWithValue(catalogRepo ?? catalog),
      paymentsRepoProvider.overrideWithValue(paymentsRepo ?? payments),
      ...extra,
    ];
  }

  /// Контейнер Riverpod поверх того же стенда.
  ///
  /// Нужен только тестам состояния и виджетов: слой данных контейнера
  /// не требует. ТРЕБУЕТ `TestWidgetsFlutterBinding.ensureInitialized()`
  /// в начале `main()` — из-за `AppPrefs` поверх SharedPreferences.
  Future<ProviderContainer> container({
    List<Override> extra = const [],
    AccountsRepository? accountsRepo,
    BillsRepository? billsRepo,
    CatalogRepository? catalogRepo,
    PaymentsRepository? paymentsRepo,
    Session? session,
  }) async {
    final c = ProviderContainer(
      overrides: await overrides(
        extra: extra,
        accountsRepo: accountsRepo,
        billsRepo: billsRepo,
        catalogRepo: catalogRepo,
        paymentsRepo: paymentsRepo,
        session: session,
      ),
    );
    _containers.add(c);
    return c;
  }

  /// Закрыть всё, что открыл стенд. Вешается через `addTearDown`.
  void dispose() {
    for (final c in _containers) {
      c.dispose();
    }
    _containers.clear();
    net.dispose();
  }
}

/// Собрать стенд.
///
/// [store] передают только там, где нужно ПЕРЕЖИТЬ перезапуск: обычный
/// тест получает чистое хранилище и ничего о нём не знает.
TestEnv makeEnv({
  DateTime? now,
  bool online = true,
  Duration latency = Duration.zero,
  MemoryLocalStore? store,
  Duration accountsTtl = const Duration(minutes: 15),
}) {
  // Логи в прогоне тестов — шум: ошибки видно по упавшему ожиданию.
  Log.enabled = false;

  final memory = store ?? MemoryLocalStore();
  final clock = MovableClock(now ?? testNow);
  final net = ManualConnectivity(online: online);
  final ids = SeqIdGen();

  final api = MockElPayApi(
    store: memory,
    connectivity: net,
    clock: clock.call,
    latency: latency,
  );
  final outbox = Outbox(memory);

  return TestEnv._(
    store: memory,
    net: net,
    clock: clock,
    ids: ids,
    api: api,
    outbox: outbox,
    accountsTtl: accountsTtl,
    latency: latency,
    accounts: DefaultAccountsRepository(
      api: api,
      store: memory,
      connectivity: net,
      outbox: outbox,
      ids: ids,
      clock: clock.call,
      ttl: accountsTtl,
    ),
    bills: DefaultBillsRepository(
      api: api,
      store: memory,
      clock: clock.call,
    ),
    catalog: DefaultCatalogRepository(
      api: api,
      store: memory,
      clock: clock.call,
      // Каталог берём через тот же шов, что и остальное: подмена источника
      // проверяется вместе с политикой кэша, а не в обход неё.
      source: () => api.catalog(locale: 'ru'),
    ),
    payments: StubPaymentsRepository(clock: clock.call, latency: Duration.zero),
  );
}

/// Дать отработать фоновым обновлениям, которые состояние запускает
/// «вдогонку» и не ждёт.
///
/// Например `AccountsNotifier.sync` после удачного обновления зовёт
/// `billsProvider.notifier.refresh()` БЕЗ await: начисления перечитываются
/// сами. Если тест закончится раньше, контейнер успеет закрыться, и
/// незаконченное обновление упадёт в «Ref used after dispose» — уже после
/// того, как тест прошёл. Несколько прокруток очереди микрозадач дешевле
/// фальшивого ожидания по таймеру.
Future<void> settleProviders({int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Дождаться условия, которое наступит само: наблюдатель сети разгрузит
/// очередь, состояние перечитает список.
///
/// Цепочка «поток состояния сети → слушатель → flushOutbox → запрос →
/// запись кэша» проходит через несколько очередей задач, и угадывать
/// нужное число прокруток руками бессмысленно. Если условие так и не
/// наступило, тест падает на следующем за этим вызовом ожидании — молча
/// зелёным он не станет.
Future<void> waitFor(bool Function() ready, {int rounds = 500}) async {
  for (var i = 0; i < rounds && !ready(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
