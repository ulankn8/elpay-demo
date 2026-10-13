import 'package:elpay/core/clock.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/result.dart';
import 'package:elpay/data/accounts_repository.dart';
import 'package:elpay/data/api/elpay_api.dart';
import 'package:elpay/data/cache_policy.dart';
import 'package:elpay/data/connect_rules.dart';
import 'package:elpay/data/models.dart';

/// Управляемый фейк [AccountsRepository].
///
/// Демо-бэкенд ведёт себя как настоящий, и это хорошо для сценарных
/// тестов — но ровно поэтому им не проверить то, что должно происходить
/// РЕДКО: отказ по одному счёту из трёх, второй отказ подряд, повтор
/// подключения с тем же ключом. Фейк даёт этим случаям выключатель:
///
///   * [failNext] — следующие вызовы падают названной ошибкой;
///   * [failConnect] — конкретный кандидат падает всегда (частичный успех);
///   * [online] — сеть пропала: подключение уходит «в очередь»;
///   * [callsOf] — сколько раз метод вызвали (повтор не должен дублировать);
///   * [keys] и [keyOf] — какие ключи идемпотентности доехали до источника.
///
/// Идемпотентность фейк соблюдает так же, как обязан боевой шлюз: повтор
/// с тем же ключом отдаёт ПРЕЖНИЙ результат и второй счёт не создаёт.
class FakeAccountsRepository implements AccountsRepository {
  FakeAccountsRepository({
    List<AccountCandidate> candidates = const [],
    List<ConnectedAccount> connected = const [],
    Clock? clock,
    IdGen? ids,
    this.confirmCode = '4815',
  })  : candidates = [...candidates],
        _connected = [...connected],
        _clock = clock ?? systemClock,
        ids = ids ?? SeqIdGen();

  /// Что «лежит в реестрах поставщиков». Список открыт: тест дописывает
  /// кандидата прямо в него.
  final List<AccountCandidate> candidates;

  final List<ConnectedAccount> _connected;

  /// Код подтверждения владения: всё остальное даёт validation по полю code.
  final String confirmCode;

  final IdGen ids;
  final Clock _clock;

  /// Начисления, созданные подключением. Bill на 0 сом здесь не появится —
  /// фейк держит то же правило, что демо-бэкенд и бой.
  final List<Bill> charges = [];

  /// Сколько раз вызывали каждый метод.
  final Map<String, int> calls = {};

  /// Ключи идемпотентности в порядке поступления.
  final List<IdempotencyKey> keys = [];

  /// candidateId (или accountId у отключения) → ключ последней попытки.
  final Map<String, IdempotencyKey> keyOf = {};

  /// Кандидаты, ушедшие «в очередь», потому что сети не было.
  final List<String> queued = [];

  /// Сеть есть. false — методы, которым нужна сеть, падают network,
  /// а подключение помечается как ушедшее в очередь.
  bool online = true;

  /// Очередь отказов для [failNext].
  final List<AppFailure> _failures = [];

  /// candidateId → отказ, который повторяется при каждой попытке.
  final Map<String, AppFailure> _byCandidate = {};

  /// Выполненные попытки: ключ идемпотентности → что получилось.
  final Map<String, ConnectResult> _done = {};

  DateTime? _syncedAt;

  // ───────────────────────────── управление ─────────────────────────────

  /// Следующие [times] вызовов падают с [failure].
  void failNext(AppFailure failure, {int times = 1}) {
    for (var i = 0; i < times; i++) {
      _failures.add(failure);
    }
  }

  /// Этот кандидат не подключится никогда — так строится частичный успех.
  void failConnect(String candidateId, AppFailure failure) =>
      _byCandidate[candidateId] = failure;

  void clearFailures() {
    _failures.clear();
    _byCandidate.clear();
  }

  int callsOf(String method) => calls[method] ?? 0;

  /// Подключённые счета — то, что видит экран списка.
  List<ConnectedAccount> get connected => List.unmodifiable(_connected);

  void _hit(String method) => calls[method] = callsOf(method) + 1;

  AppFailure? _takeFailure() => _failures.isEmpty ? null : _failures.removeAt(0);

  /// Запомнить ключ попытки: не передали — выдаём свой, как боевой
  /// репозиторий.
  IdempotencyKey _remember(String subject, IdempotencyKey? key, String scope) {
    final attempt = key ?? ids.key(scope);
    keys.add(attempt);
    keyOf[subject] = attempt;
    return attempt;
  }

  // ─────────────────────────────── чтение ───────────────────────────────

  @override
  List<ConnectedAccount> cachedAccounts() => List.unmodifiable(_connected);

  @override
  DateTime? lastSyncAt() => _syncedAt;

  @override
  Future<Result<Cached<List<ConnectedAccount>>>> load({bool refresh = false}) async {
    _hit('load');
    final failure = _takeFailure();
    if (failure != null) {
      // Данные есть — это офлайн, а не ошибка экрана: ровно так ведёт
      // себя CachePolicy.
      if (_connected.isNotEmpty) {
        return Ok(Cached<List<ConnectedAccount>>.stale(connected, _syncedAt));
      }
      return Fail(failure);
    }
    return Ok(Cached<List<ConnectedAccount>>.fresh(connected, _clock()));
  }

  @override
  Future<Result<List<ConnectedAccount>>> accounts({bool refresh = false}) async =>
      (await load(refresh: refresh)).map((c) => c.value);

  @override
  Future<Result<List<AccountCandidate>>> search(AccountQuery query) async {
    _hit('search');
    if (!online) return const Fail(AppFailure.network('поиск счёта требует сети'));
    final failure = _takeFailure();
    if (failure != null) return Fail(failure);

    final mine = {for (final a in _connected) _key(a.providerId, a.accountNo)};
    return Ok([
      for (final c in _match(query))
        c.copyWith(alreadyConnected: mine.contains(_key(c.providerId, c.accountNo))),
    ]);
  }

  // ─────────────────────────────── запись ───────────────────────────────

  @override
  Future<Result<AccountCandidate>> confirm({
    required String candidateId,
    required String code,
  }) async {
    _hit('confirm');
    if (!online) return const Fail(AppFailure.network());
    final failure = _takeFailure();
    if (failure != null) return Fail(failure);

    final index = candidates.indexWhere((c) => c.id == candidateId);
    if (index < 0) return const Fail(AppFailure.notFound('счёт не найден'));
    if (code.trim() != confirmCode) {
      return const Fail(AppFailure.validation('код не подошёл', field: 'code'));
    }
    final confirmed = candidates[index].copyWith(needsConfirm: false);
    candidates[index] = confirmed;
    return Ok(confirmed);
  }

  @override
  Future<Result<ConnectResult>> connect({
    required String candidateId,
    required String objectId,
    IdempotencyKey? key,
  }) async {
    _hit('connect');
    final attempt = _remember(candidateId, key, ConnectRules.connectScope);

    // Повтор по кнопке и повтор из очереди идут с тем же ключом: отдаём
    // прежний результат, а не делаем второй счёт.
    final already = _done[attempt.value];
    if (already != null) {
      _hit('connect.repeat');
      return Ok(already);
    }

    if (!online) {
      queued.add(candidateId);
      return const Fail(AppFailure.network('подключим, когда появится сеть'));
    }

    final failure = _byCandidate[candidateId] ?? _takeFailure();
    if (failure != null) return Fail(failure);

    final candidate = candidates.where((c) => c.id == candidateId).firstOrNull;
    if (candidate == null) return const Fail(AppFailure.notFound('счёт не найден'));
    if (_connected.any((a) => _key(a.providerId, a.accountNo) ==
        _key(candidate.providerId, candidate.accountNo))) {
      return const Fail(AppFailure.validation('счёт уже подключён'));
    }

    final now = _clock();
    final account = ConnectedAccount(
      // id детерминированный: тест сверяет его буквами.
      id: 'acc-$candidateId',
      providerId: candidate.providerId,
      title: candidate.providerTitle,
      subtitle: candidate.serviceTitle,
      cat: candidate.cat,
      accountNo: candidate.accountNo,
      objectId: objectId,
      holder: candidate.holder,
      address: candidate.address,
      connectedAt: now,
      dueDay: candidate.dueDay,
      syncedAt: now,
    );
    _connected.add(account);

    Bill? bill;
    // Начисление — только если оно выставлено: Bill на 0 сом попадает
    // «к оплате» и роняет разбивку на главной делением на нулевой итог.
    if (candidate.amount > 0) {
      bill = Bill(
        id: 'bill-$candidateId',
        accountId: account.id,
        title: account.title,
        subtitle: account.subtitle,
        cat: account.cat,
        amount: candidate.amount,
        objectId: objectId,
        period: candidate.period,
        due: ConnectRules.dueDateOf(candidate.dueDay, now),
        account: candidate.accountNo,
        calc: candidate.calc,
      );
      charges.add(bill);
    }

    final result = ConnectResult(account: account, bill: bill);
    _done[attempt.value] = result;
    return Ok(result);
  }

  @override
  Future<ConnectBatch> connectPlan(ConnectPlan plan) async {
    _hit('connectPlan');
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
          queued: failure.isNetwork && !online,
        ),
      ));
    }
    return ConnectBatch(items);
  }

  @override
  Future<Result<void>> disconnect(String accountId, {IdempotencyKey? key}) async {
    _hit('disconnect');
    final attempt = _remember(accountId, key, ConnectRules.disconnectScope);
    if (_done.containsKey(attempt.value)) {
      // Повтор из очереди не должен падать в notFound только потому,
      // что счёта уже нет.
      _hit('disconnect.repeat');
      return const Ok(null);
    }
    if (!online) return const Fail(AppFailure.network('отключим, когда появится сеть'));

    final failure = _takeFailure();
    if (failure != null) return Fail(failure);

    final account = _connected.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const Fail(AppFailure.notFound('счёт не подключён'));

    _connected.removeWhere((a) => a.id == accountId);
    charges.removeWhere((b) => b.accountId == accountId);
    _done[attempt.value] = ConnectResult(account: account);
    return const Ok(null);
  }

  @override
  Future<Result<ConnectedAccount>> move({
    required String accountId,
    required String objectId,
  }) async {
    _hit('move');
    if (!online) return const Fail(AppFailure.network('перенос требует сети'));
    final failure = _takeFailure();
    if (failure != null) return Fail(failure);

    final index = _connected.indexWhere((a) => a.id == accountId);
    if (index < 0) return const Fail(AppFailure.notFound('счёт не подключён'));
    final moved = _connected[index].copyWith(objectId: objectId);
    _connected[index] = moved;
    return Ok(moved);
  }

  @override
  Future<Result<SyncResult>> sync({List<String> accountIds = const []}) async {
    _hit('sync');
    if (!online) return const Fail(AppFailure.network());
    final failure = _takeFailure();
    if (failure != null) {
      // Общий отказ помечает все счета: статус виден в списке.
      for (var i = 0; i < _connected.length; i++) {
        _connected[i] = _connected[i]
            .copyWith(status: AccountSyncStatus.failed, lastError: failure.message);
      }
      return Fail(failure);
    }

    final now = _clock();
    final known = {for (final a in _connected) a.id};
    // Названы счета, которых источник не знает, — частичный отказ,
    // а не общая ошибка.
    final failed = <String, String>{
      for (final id in accountIds)
        if (!known.contains(id)) id: 'notFound',
    };
    final targets = accountIds.isEmpty ? known : accountIds.toSet();
    for (var i = 0; i < _connected.length; i++) {
      final a = _connected[i];
      if (!targets.contains(a.id)) continue;
      _connected[i] =
          a.copyWith(status: AccountSyncStatus.ok, syncedAt: now, clearError: true);
    }
    _syncedAt = now;

    return Ok(SyncResult(
      bills: List.unmodifiable(charges),
      accounts: connected,
      syncedAt: now,
      failed: failed,
    ));
  }

  /// Очереди у фейка нет: офлайн-путь проверяется на боевом репозитории
  /// с настоящим [Outbox] (см. test/support/env.dart).
  @override
  Future<int> flushOutbox() async {
    _hit('flushOutbox');
    return 0;
  }

  // ─────────────────────────────── поиск ───────────────────────────────

  List<AccountCandidate> _match(AccountQuery query) {
    final pool = [
      for (final c in candidates)
        if (query.providerId == null || c.providerId == query.providerId) c,
    ];
    if (query.isByAccount) {
      final key = AccountMask.keyOf(query.accountNo);
      return [
        for (final c in pool)
          if (AccountMask.keyOf(c.accountNo) == key) c,
      ];
    }
    final want = <String>{
      ..._words(query.city),
      ..._words(query.street),
      ..._words(query.house),
      ..._words(query.flat),
    };
    return [
      for (final c in pool)
        if (want.every(_words(c.address).contains)) c,
    ];
  }

  static String _key(String providerId, String accountNo) =>
      '$providerId|${AccountMask.keyOf(accountNo)}';

  /// Значащие слова адреса: регистр, «ё» и знаки не должны мешать поиску.
  static Set<String> _words(String raw) => {
        for (final part
            in raw.toLowerCase().replaceAll('ё', 'е').split(RegExp(r'[^0-9a-zа-я]+')))
          if (part.isNotEmpty && !const {'ул', 'д', 'кв', 'г'}.contains(part)) part,
      };
}
