import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics.dart';
import '../core/app_config.dart';
import '../core/cache/local_store.dart';
import '../core/clock.dart';
import '../core/ids.dart';
import '../core/net/connectivity.dart';
import '../core/net/outbox.dart';
import '../core/prefs.dart';
import '../data/accounts_repository.dart';
import '../data/api/api_client.dart';
import '../data/api/elpay_api.dart';
import '../data/api/http_api.dart';
import '../data/api/mock_api.dart';
import '../data/auth_repository.dart';
import '../data/bills_repository.dart';
import '../data/catalog_repository.dart';
import '../data/connect_rules.dart';
import '../data/payments_repository.dart';
import '../data/stories_repository.dart';

/// Состояние разъехалось по файлам (bills, accounts, connect, catalog,
/// sync, app_state), а здесь остался только DI — и реэкспорт, чтобы
/// единственный импорт `state/providers.dart` у экранов не правился.
export 'accounts.dart';
export 'app_state.dart';
export 'bills.dart';
export 'catalog.dart';
export 'connect.dart';
export 'sync.dart';

// ───────────────────────── окружение ─────────────────────────

/// Заполняется в main() — SharedPreferences читается один раз при старте.
final prefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());

/// Локальный кэш: тоже создаётся в main() поверх тех же SharedPreferences.
/// В тестах подменяется на MemoryLocalStore.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

/// Настройки сборки: демо или боевой API, включены ли платежи.
final configProvider = Provider<AppConfig>((ref) => AppConfig.current);

/// «Сейчас» одной строкой: тест подставляет фиксированные часы, и даты
/// перестают зависеть от дня запуска.
final clockProvider = Provider<Clock>((ref) => systemClock);

/// Генерация id и ключей идемпотентности.
final idGenProvider = Provider<IdGen>((ref) => DefaultIdGen(clock: ref.watch(clockProvider)));

/// Правила подключения счёта: чистые и синхронные, без состояния.
final rulesProvider = Provider<ConnectRules>((ref) => const ConnectRules());

final analyticsProvider = Provider<Analytics>((ref) => const DebugAnalytics());

/// Состояние сети.
///
/// В демо переключается вручную — так показывают офлайн-сценарий.
/// В боевой сборке здесь должна встать реализация поверх connectivity_plus;
/// пока её НЕТ, и это честное ограничение: без сети приложение узнаёт
/// об этом по упавшему запросу, а не заранее (новый пакет в эту задачу
/// не входит).
final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ManualConnectivity();
  ref.onDispose(service.dispose);
  return service;
});

/// Поток «есть сеть / нет сети». Отдаёт только изменения, поэтому для
/// текущего значения есть onlineNowProvider в state/sync.dart.
final isOnlineProvider = StreamProvider<bool>((ref) => ref.watch(connectivityProvider).changes);

/// Очередь отложенных операций. Разгружает её ровно один слушатель —
/// syncWatcherProvider в state/sync.dart.
final outboxProvider = Provider<Outbox>((ref) => Outbox(ref.watch(localStoreProvider)));

// ───────────────────────── источник данных ─────────────────────────

/// ЕДИНСТВЕННЫЙ ШОВ НА БЭКЕНД: подмена демо на бой — эта одна строка.
///
/// Демо-реализация держит своё состояние в том же LocalStore под своим
/// ключом, поэтому после перезапуска id не расходятся и отключение
/// не падает в notFound.
final apiProvider = Provider<ElPayApi>((ref) {
  final config = ref.watch(configProvider);
  if (config.useMockData) {
    return MockElPayApi(
      store: ref.watch(localStoreProvider),
      connectivity: ref.watch(connectivityProvider),
      clock: ref.watch(clockProvider),
    );
  }
  final client = ApiClient(config: config);
  ref.onDispose(client.close);
  return HttpElPayApi(client);
});

// ───────────────────────── репозитории ─────────────────────────

final authRepoProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(clock: ref.watch(clockProvider), ids: ref.watch(idGenProvider)),
);

final paymentsRepoProvider = Provider<PaymentsRepository>(
  (ref) => StubPaymentsRepository(clock: ref.watch(clockProvider)),
);

final storiesRepoProvider = Provider<StoriesRepository>((ref) => MockStoriesRepository());

final billsRepoProvider = Provider<BillsRepository>((ref) => DefaultBillsRepository(
      api: ref.watch(apiProvider),
      store: ref.watch(localStoreProvider),
      clock: ref.watch(clockProvider),
    ));

final accountsRepoProvider = Provider<AccountsRepository>((ref) => DefaultAccountsRepository(
      api: ref.watch(apiProvider),
      store: ref.watch(localStoreProvider),
      connectivity: ref.watch(connectivityProvider),
      outbox: ref.watch(outboxProvider),
      analytics: ref.watch(analyticsProvider),
      ids: ref.watch(idGenProvider),
      clock: ref.watch(clockProvider),
    ));

/// Каталог платежей.
///
/// БОЕВОЙ ИСТОЧНИК ВИДЕН ЗДЕСЬ, а не только в значении по умолчанию:
/// пока каталог брался из демо-набора, `GET /catalog` в сборке
/// `USE_MOCK=false` не вызывался никогда — поставщики, маски лицевых
/// счетов и способы оплаты оставались демонстрационными поверх живого
/// бэкенда, а маска демо-поставщика отбивала правильный номер ДО сети.
/// В демо источник не подменяем: его выбирает apiProvider, и
/// `MockElPayApi` отдаёт тот же `Demo.catalog`.
final catalogRepoProvider = Provider<CatalogRepository>((ref) {
  final api = ref.watch(apiProvider);
  // Язык каталога: названия услуг приходят с сервера переведёнными,
  // поэтому берём выбранный язык, а не константу 'ru'. Читается один раз
  // при создании — каталог живёт 12 часов, и дёргать его на каждое
  // переключение языка незачем.
  final locale = ref.watch(prefsProvider).locale;
  return DefaultCatalogRepository(
    api: api,
    store: ref.watch(localStoreProvider),
    clock: ref.watch(clockProvider),
    locale: locale,
    source: ref.watch(configProvider).useMockData
        ? null
        : () => api.catalog(locale: locale),
  );
});
