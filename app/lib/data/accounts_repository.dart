import 'package:flutter/foundation.dart';

import '../core/analytics.dart';
import '../core/cache/local_store.dart';
import '../core/clock.dart';
import '../core/failure.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/net/connectivity.dart';
import '../core/net/outbox.dart';
import '../core/result.dart';
import 'api/elpay_api.dart';
import 'cache_policy.dart';
import 'connect_rules.dart';
import 'models.dart';

/// Подключение счетов: поиск, подтверждение, подключение, отключение,
/// перенос и обновление начислений.
///
/// Репозиторий — единственное место, которое знает про сеть, кэш и очередь.
/// Экраны получают [Result] и больше ничего.
abstract class AccountsRepository {
  /// Подключённые счета вместе с происхождением данных: из кэша они или
  /// из сети и когда обновлялись. Один ответ на три вопроса экрана —
  /// что показать, рисовать ли плашку офлайна и какое время подписать.
  Future<Result<Cached<List<ConnectedAccount>>>> load({bool refresh = false});

  /// Тот же вызов, но без происхождения.
  ///
  /// ПЕРЕХОДНЫЙ ШОВ: состояние (state/) ещё читает список напрямую.
  /// Когда `AccountsNotifier` перейдёт на [load], этот метод уходит.
  Future<Result<List<ConnectedAccount>>> accounts({bool refresh = false});

  /// Что лежит в кэше прямо сейчас — для мгновенной отрисовки.
  List<ConnectedAccount> cachedAccounts();

  /// Когда начисления обновлялись в последний раз.
  DateTime? lastSyncAt();

  /// Поиск счёта. Результат нужен сейчас, поэтому без сети возвращается
  /// отказ, а в очередь поиск НЕ кладётся.
  Future<Result<List<AccountCandidate>>> search(AccountQuery query);

  Future<Result<AccountCandidate>> confirm({required String candidateId, required String code});

  /// Подключение одного счёта. [key] — ключ попытки: повтор по кнопке и
  /// повтор из очереди идут с тем же ключом, поэтому счёт не подключится
  /// дважды. Не передан — ключ выдаётся здесь.
  Future<Result<ConnectResult>> connect({
    required String candidateId,
    required String objectId,
    IdempotencyKey? key,
  });

  /// Подключение по плану правил — с ЧЕСТНЫМ частичным успехом: видно,
  /// какой счёт не подключился и почему.
  Future<ConnectBatch> connectPlan(ConnectPlan plan);

  Future<Result<void>> disconnect(String accountId, {IdempotencyKey? key});

  /// Перенос счёта на другой объект — вместо «отключить и подключить
  /// заново»: повторное подключение теряет историю и может снова
  /// потребовать код.
  Future<Result<ConnectedAccount>> move({
    required String accountId,
    required String objectId,
  });

  /// Обновление начислений. Пустой [accountIds] — по всем счетам,
  /// непустой — только по названным («повторить только упавшие»).
  Future<Result<SyncResult>> sync({List<String> accountIds = const []});

  /// Отправляет отложенные операции, когда сеть вернулась.
  /// Возвращает, сколько ушло.
  Future<int> flushOutbox();
}

/// Чем закончилась попытка подключить ОДИН счёт.
@immutable
class ConnectItemResult {
  const ConnectItemResult({
    required this.candidateId,
    required this.title,
    this.account,
    this.bill,
    this.failure,
    this.queued = false,
    this.pending = false,
  });

  final String candidateId;

  /// Название поставщика — чтобы сообщение об отказе называло счёт,
  /// а не id кандидата.
  final String title;

  final ConnectedAccount? account;

  /// Начисление, если поставщик его уже выставил.
  final Bill? bill;

  final AppFailure? failure;

  /// Ушло в очередь: подключим, когда появится сеть.
  final bool queued;

  /// Поставщик подтвердит подключение позже.
  final bool pending;

  bool get isOk => account != null;
}

/// Итог пакетного подключения.
///
/// НЕ `Result`: частичный успех в него не укладывается. Два счёта
/// подключились, третий упал — это не «ошибка» и не «успех», и интерфейс
/// обязан показать оба факта. Раньше про упавший счёт пользователь
/// не узнавал вообще: ошибка затиралась, если хоть что-то прошло.
@immutable
class ConnectBatch {
  const ConnectBatch(this.items);

  static const empty = ConnectBatch([]);

  final List<ConnectItemResult> items;

  List<ConnectedAccount> get connected => [
        for (final i in items)
          if (i.account != null) i.account!,
      ];

  /// Начисления, которые пришли вместе со счетами: дописываются в ленту,
  /// чтобы счёт появился на главной без полного перезапроса.
  List<Bill> get charges => [
        for (final i in items)
          if (i.bill != null) i.bill!,
      ];

  List<ConnectItemResult> get failed => [
        for (final i in items)
          if (!i.isOk && !i.queued) i,
      ];

  /// Кандидаты, оставшиеся в очереди до появления сети.
  List<String> get queued => [
        for (final i in items)
          if (i.queued) i.candidateId,
      ];

  int get total => items.length;

  bool get isSuccess => items.isNotEmpty && connected.length == items.length;
  bool get isPartial => connected.isNotEmpty && connected.length < items.length;
  bool get isTotalFailure => items.isNotEmpty && connected.isEmpty;

  /// Первая причина отказа — для снека, когда не прошло вообще ничего.
  AppFailure? get firstFailure {
    for (final i in items) {
      if (i.failure != null) return i.failure;
    }
    return null;
  }
}

class DefaultAccountsRepository implements AccountsRepository {
  DefaultAccountsRepository({
    required this.api,
    required this.store,
    required this.connectivity,
    required this.outbox,
    this.analytics = const NoopAnalytics(),
    IdGen? ids,
    Clock? clock,
    this.ttl = const Duration(minutes: 15),
  })  : ids = ids ?? DefaultIdGen(clock: clock),
        _clock = clock ?? systemClock;

  final ElPayApi api;
  final LocalStore store;
  final ConnectivityService connectivity;
  final Outbox outbox;
  final Analytics analytics;

  /// Генерация ключей идемпотентности. Инъектируется, чтобы тест видел
  /// предсказуемые ключи.
  final IdGen ids;

  /// Насколько кэш счетов считается свежим.
  final Duration ttl;

  final Clock _clock;

  static const _tag = 'accounts';

  /// Вид операции в очереди. Строки — часть формата хранения, поэтому
  /// лежат константами, а не литералами по коду.
  static const kindConnect = 'connect_account';
  static const kindDisconnect = 'disconnect_account';

  /// Политика «сначала кэш, потом сеть» — одна на репозиторий. До неё
  /// здесь не проверялся TTL: непустой кэш отдавался всегда и никогда
  /// не обновлялся.
  late final CachePolicy<List<ConnectedAccount>> _cache = CachePolicy.list(
    store: store,
    key: CacheKeys.accounts,
    ttl: ttl,
    item: ConnectedAccount.fromJson,
    row: (a) => a.toJson(),
    clock: _clock,
  );

  @override
  List<ConnectedAccount> cachedAccounts() => _cache.read() ?? const [];

  /// Правка кэша счетов на месте: подключили, отключили, перенесли.
  ///
  /// Если полного списка в кэше ещё нет (счета не загружали ни разу),
  /// правка всё равно пишется, но С УСТАРЕВШЕЙ отметкой времени: новый счёт
  /// сразу виден, а следующий [load] не примет список из одного счёта
  /// за свежий и сходит в источник за остальными. Без этого подключение
  /// с главной спрятало бы все прежние счета до истечения TTL.
  Future<void> _patchCache(
    List<ConnectedAccount> Function(List<ConnectedAccount> current) edit,
  ) async {
    final current = _cache.read();
    if (current != null) {
      await _cache.write(edit(current), now: _clock());
      return;
    }
    Log.d(_tag, 'полного списка счетов нет: правка пишется как устаревшая');
    await _cache.write(edit(const []), now: _clock().subtract(ttl * 2));
  }

  @override
  DateTime? lastSyncAt() => _cache.updatedAt();

  @override
  Future<Result<Cached<List<ConnectedAccount>>>> load({bool refresh = false}) =>
      _cache.load(refresh: refresh, fetch: api.accounts);

  @override
  Future<Result<List<ConnectedAccount>>> accounts({bool refresh = false}) async =>
      (await load(refresh: refresh)).map((c) => c.value);

  @override
  Future<Result<List<AccountCandidate>>> search(AccountQuery query) async {
    if (!connectivity.isOnline) {
      // Поиск в очередь не кладут: ответ нужен сейчас, а не когда-нибудь.
      return const Fail(AppFailure.network('поиск счёта требует сети'));
    }
    final result = await guard(() => api.search(query));
    result.fold(
      (list) => analytics.track(AnalyticsEvent.connectFound(list.length, query.method)),
      (f) => analytics.track(AnalyticsEvent.connectFailed(f.kind.name)),
    );
    return result;
  }

  @override
  Future<Result<AccountCandidate>> confirm({
    required String candidateId,
    required String code,
  }) =>
      guard(() => api.confirm(candidateId: candidateId, code: code));

  @override
  Future<Result<ConnectResult>> connect({
    required String candidateId,
    required String objectId,
    IdempotencyKey? key,
  }) async {
    final attempt = key ?? ids.key(ConnectRules.connectScope);

    if (!connectivity.isOnline) {
      // Без сети подключение не теряется: уйдёт из очереди, когда связь
      // появится, и уйдёт С ТЕМ ЖЕ ключом.
      await outbox.add(OutboxItem(
        id: 'connect-$candidateId',
        kind: kindConnect,
        payload: {
          'candidateId': candidateId,
          'objectId': objectId,
          'key': attempt.toJson(),
        },
        createdAt: _clock(),
      ));
      return const Fail(AppFailure.network('подключим, когда появится сеть'));
    }

    final result = await guard(
      () => api.connect(candidateId: candidateId, objectId: objectId, key: attempt),
    );
    return result.fold(
      (value) async {
        // Сверка по id: повтор по тому же ключу идемпотентности источник
        // отдаёт прежним результатом, и второй такой же счёт в кэш не нужен.
        await _patchCache((current) => [
              for (final a in current)
                if (a.id != value.account.id) a,
              value.account,
            ]);
        analytics.track(AnalyticsEvent.connectDone(1));
        return Ok(value);
      },
      (failure) {
        analytics.track(AnalyticsEvent.connectFailed(failure.kind.name));
        return Fail<ConnectResult>(failure);
      },
    );
  }

  @override
  Future<ConnectBatch> connectPlan(ConnectPlan plan) async {
    final items = <ConnectItemResult>[];

    for (final view in plan.items) {
      final result = await connect(
        candidateId: view.id,
        objectId: plan.objectId,
        key: plan.keyOf(view.id),
      );
      items.add(result.fold(
        (value) => ConnectItemResult(
          candidateId: view.id,
          title: view.title,
          account: value.account,
          bill: value.bill,
          pending: value.pending,
        ),
        (failure) => ConnectItemResult(
          candidateId: view.id,
          title: view.title,
          failure: failure,
          // Сеть пропала — операция уже лежит в очереди, и это не отказ.
          queued: failure.isNetwork && !connectivity.isOnline,
        ),
      ));
    }

    final batch = ConnectBatch(items);
    Log.i(
      _tag,
      'подключение: прошло ${batch.connected.length} из ${batch.total}, '
      'в очереди ${batch.queued.length}',
    );
    return batch;
  }

  @override
  Future<Result<void>> disconnect(String accountId, {IdempotencyKey? key}) async {
    final attempt = key ?? ids.key(ConnectRules.disconnectScope);
    final account = cachedAccounts().where((a) => a.id == accountId).firstOrNull;

    if (!connectivity.isOnline) {
      await outbox.add(OutboxItem(
        id: 'disconnect-$accountId',
        kind: kindDisconnect,
        payload: {'accountId': accountId, 'key': attempt.toJson()},
        createdAt: _clock(),
      ));
      if (account != null) {
        // Строка остаётся видимой со статусом «отключаем»: иначе счёт
        // пропадает из списка, а поставщик о нём ещё не знает.
        await _patchCache((current) => [
              for (final a in current)
                if (a.id == accountId) a.copyWith(pendingOp: AccountOp.disconnect) else a,
            ]);
      }
      return const Fail(AppFailure.network('отключим, когда появится сеть'));
    }

    final result = await guard(() => api.disconnect(accountId, key: attempt));
    if (result.isOk) {
      await _patchCache((current) => [
            for (final a in current)
              if (a.id != accountId) a,
          ]);
      if (account != null) {
        analytics.track(AnalyticsEvent.accountDisconnected(account.providerId));
      }
    }
    return result;
  }

  @override
  Future<Result<ConnectedAccount>> move({
    required String accountId,
    required String objectId,
  }) async {
    if (!connectivity.isOnline) {
      // Перенос в очередь не кладём: он не срочный, а разъехавшийся
      // объект у счёта запутает сильнее, чем честный отказ.
      return const Fail(AppFailure.network('перенос требует сети'));
    }
    final result = await guard(() => api.move(accountId: accountId, objectId: objectId));
    return result.fold(
      (moved) async {
        await _patchCache((current) => [
              for (final a in current)
                if (a.id == moved.id) moved else a,
            ]);
        return Ok(moved);
      },
      (failure) {
        Log.w(_tag, 'перенос не удался: ${failure.message}');
        return Fail<ConnectedAccount>(failure);
      },
    );
  }

  @override
  Future<Result<SyncResult>> sync({List<String> accountIds = const []}) async {
    if (!connectivity.isOnline) return const Fail(AppFailure.network());

    final result = await guard(() => api.syncCharges(accountIds: accountIds));
    return result.fold(
      (value) async {
        // Частичный отказ помечает ТОЛЬКО свои счета и не считается общей
        // ошибкой: остальные счета обновились, и список это показывает.
        final marked = [
          for (final a in value.accounts)
            if (value.failed.containsKey(a.id))
              a.copyWith(status: AccountSyncStatus.failed, lastError: value.failed[a.id])
            else
              a,
        ];
        await _cache.write(marked, now: _clock());
        if (value.hasFailures) {
          Log.w(_tag, 'обновились не все счета: ${value.failedIds.join(', ')}');
          analytics.track(AnalyticsEvent.syncFailed('partial'));
        }
        return Ok(SyncResult(
          bills: value.bills,
          accounts: marked,
          syncedAt: value.syncedAt,
          failed: value.failed,
        ));
      },
      (failure) async {
        analytics.track(AnalyticsEvent.syncFailed(failure.kind.name));
        // Помечаем счета как «не обновились» — статус виден в списке.
        // Запись ОБЯЗАТЕЛЬНО с await: без него пометка может не успеть
        // лечь в хранилище до возврата, и экран перечитает прежнее.
        final marked = [
          for (final a in cachedAccounts())
            a.copyWith(status: AccountSyncStatus.failed, lastError: failure.message),
        ];
        if (marked.isNotEmpty) await _cache.write(marked, now: _clock());
        return Fail<SyncResult>(failure);
      },
    );
  }

  @override
  Future<int> flushOutbox() async {
    // Без сети отправлять нечего, а попытка добавила бы в очередь копии
    // тех же операций: connect/disconnect в офлайне кладут себя заново.
    if (!connectivity.isOnline) return 0;

    return outbox.flush((item) async {
      switch (item.kind) {
        case kindConnect:
          final result = await connect(
            candidateId: '${item.payload['candidateId']}',
            objectId: '${item.payload['objectId']}',
            key: IdempotencyKey.tryFromJson(item.payload['key']),
          );
          return result.isOk;
        case kindDisconnect:
          final result = await disconnect(
            '${item.payload['accountId']}',
            key: IdempotencyKey.tryFromJson(item.payload['key']),
          );
          return result.isOk;
        default:
          // Чужая операция (платёж) — не наша забота, оставляем в очереди.
          return false;
      }
    });
  }
}
