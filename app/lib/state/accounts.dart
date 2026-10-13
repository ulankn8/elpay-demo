import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../core/logger.dart';
import '../core/result.dart';
import '../data/accounts_repository.dart';
import '../data/api/elpay_api.dart';
import '../data/models.dart';
import 'providers.dart';

/// Подключённые счета вместе со статусом синхронизации.
///
/// НАСЛЕДУЕТ [Iterable] СОЗНАТЕЛЬНО, и это переходный шов: экраны счетов
/// и профиля ещё читают `accountsProvider` как простой список
/// (`list.isEmpty`, `list.where(...)`). Пока они не переведены на поля
/// состояния, состояние само ведёт себя как список своих счетов —
/// иначе их пришлось бы править в этой же задаче, а у каждого файла
/// ровно один автор. Когда экраны перейдут на [accounts], `extends`
/// убирается одной строкой.
@immutable
class AccountsState extends Iterable<ConnectedAccount> {
  const AccountsState({
    required this.accounts,
    this.syncedAt,
    this.syncing = false,
    this.fromCache = false,
    this.failure,
  });

  static const empty = AccountsState(accounts: []);

  final List<ConnectedAccount> accounts;

  /// Когда начисления обновлялись в последний раз — для подписи s.syncedAt.
  final DateTime? syncedAt;

  /// Идёт обновление начислений по всем счетам сразу.
  final bool syncing;

  /// Список показан из кэша: источник не ответил.
  final bool fromCache;

  final AppFailure? failure;

  @override
  Iterator<ConnectedAccount> get iterator => accounts.iterator;

  List<ConnectedAccount> byObject(String objectId) => [
        for (final a in accounts)
          if (a.objectId == objectId) a,
      ];

  /// Счета, которые в прошлый раз не обновились, — «повторить только упавшие».
  List<ConnectedAccount> get failedToSync => [
        for (final a in accounts)
          if (a.status == AccountSyncStatus.failed) a,
      ];

  /// Счета с операцией в очереди: подключаем или отключаем.
  List<ConnectedAccount> get pending => [
        for (final a in accounts)
          if (a.isPending) a,
      ];

  ConnectedAccount? byId(String accountId) {
    for (final a in accounts) {
      if (a.id == accountId) return a;
    }
    return null;
  }

  /// [clearFailure] — стереть ошибку явно: иначе она пропадала молча
  /// от любого соседнего обновления списка.
  AccountsState copyWith({
    List<ConnectedAccount>? accounts,
    DateTime? syncedAt,
    bool? syncing,
    bool? fromCache,
    AppFailure? failure,
    bool clearFailure = false,
  }) =>
      AccountsState(
        accounts: accounts ?? this.accounts,
        syncedAt: syncedAt ?? this.syncedAt,
        syncing: syncing ?? this.syncing,
        fromCache: fromCache ?? this.fromCache,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// Список подключённых счетов: сначала из кэша, потом из источника.
class AccountsNotifier extends AsyncNotifier<AccountsState> {
  static const _tag = 'accounts-state';

  AccountsRepository get _repo => ref.read(accountsRepoProvider);

  @override
  Future<AccountsState> build() async {
    final cached = _repo.cachedAccounts();
    // Подключённое читается из хранилища синхронно, поэтому список
    // рисуется мгновенно — даже если приложение открыли без сети.
    if (cached.isNotEmpty) {
      state = AsyncData(AccountsState(
        accounts: cached,
        fromCache: true,
        syncedAt: _repo.lastSyncAt(),
      ));
    }

    final result = await _repo.load();
    return result.fold(
      (data) => AccountsState(
        accounts: data.value,
        fromCache: data.fromCache,
        syncedAt: data.updatedAt,
      ),
      (failure) {
        if (cached.isEmpty) throw failure;
        return AccountsState(
          accounts: cached,
          fromCache: true,
          syncedAt: _repo.lastSyncAt(),
          failure: failure,
        );
      },
    );
  }

  /// pull-to-refresh и кнопка «Повторить».
  Future<void> refresh() async {
    final current = state.value ?? AccountsState.empty;
    final result = await _repo.load(refresh: true);
    state = AsyncData(result.fold(
      (data) => AccountsState(
        accounts: data.value,
        fromCache: data.fromCache,
        syncedAt: data.updatedAt,
      ),
      (failure) => current.copyWith(failure: failure, fromCache: true),
    ));
  }

  /// «Обновить начисления»: затронутым счетам сразу ставится syncing,
  /// затем ok или failed.
  ///
  /// Частичный отказ помечает ТОЛЬКО свои счета и не считается общей
  /// ошибкой: остальные счета обновились, и список это показывает.
  Future<Result<SyncResult>> sync({List<String> accountIds = const []}) async {
    final current = state.value ?? AccountsState.empty;
    final targets = accountIds.toSet();
    bool touched(ConnectedAccount a) => targets.isEmpty || targets.contains(a.id);

    _set(current.copyWith(
      syncing: true,
      clearFailure: true,
      accounts: [
        for (final a in current.accounts)
          if (touched(a)) a.copyWith(status: AccountSyncStatus.syncing, clearError: true) else a,
      ],
    ));

    final result = await _repo.sync(accountIds: accountIds);
    return result.fold(
      (value) {
        _set(current.copyWith(
          accounts: value.accounts,
          syncedAt: value.syncedAt,
          syncing: false,
          fromCache: false,
          clearFailure: true,
        ));
        // Начисления изменились — перечитываем их из источника.
        ref.read(billsProvider.notifier).refresh();
        return Ok(value);
      },
      (failure) {
        Log.w(_tag, 'начисления не обновились: ${failure.message}');
        _set(current.copyWith(
          syncing: false,
          failure: failure,
          accounts: [
            for (final a in current.accounts)
              if (touched(a))
                a.copyWith(status: AccountSyncStatus.failed, lastError: failure.message)
              else
                a,
          ],
        ));
        return Fail<SyncResult>(failure);
      },
    );
  }

  /// Оптимистично убирает счёт; при отказе возвращает на место.
  ///
  /// [force] — отключить, даже если прошлая попытка ещё висит в очереди.
  Future<Result<void>> disconnect(String accountId, {bool force = false}) async {
    final current = state.value ?? AccountsState.empty;
    final account = current.byId(accountId);
    if (account == null) {
      return Fail(AppFailure.notFound('счёт $accountId не найден'));
    }
    final check = ref.read(rulesProvider).checkDisconnect(
          account: account,
          all: current.accounts,
          bills: ref.read(billsProvider).value?.bills ?? const <Bill>[],
        );
    if (!check.allowed && !force) {
      return const Fail(AppFailure.validation('отключение уже отправлено'));
    }

    _set(current.copyWith(
      accounts: [
        for (final a in current.accounts)
          if (a.id != accountId) a,
      ],
      clearFailure: true,
    ));

    final result = await _repo.disconnect(accountId);
    return result.fold(
      (_) {
        // Начисления отключённого счёта уходят по accountId, а не по номеру.
        ref.read(billsProvider.notifier).dropByAccount(accountId);
        ref.read(billsProvider.notifier).refresh();
        return const Ok<void>(null);
      },
      (failure) {
        // Репозиторий уже решил, что стало со строкой: в офлайне он
        // помечает её «отключаем» и держит в кэше, при отказе оставляет
        // как была. Берём его версию, а не придумываем свою.
        final saved = _repo.cachedAccounts();
        _set(current.copyWith(
          accounts: saved.isEmpty ? current.accounts : saved,
          failure: failure,
        ));
        return Fail<void>(failure);
      },
    );
  }

  /// Перенос счёта на другой объект — вместо «отключить и подключить
  /// заново»: повторное подключение теряет историю и снова просит код.
  Future<Result<ConnectedAccount>> moveToObject(String accountId, String objectId) async {
    final current = state.value ?? AccountsState.empty;
    final result = await _repo.move(accountId: accountId, objectId: objectId);
    return result.fold(
      (moved) {
        _set(current.copyWith(
          accounts: [
            for (final a in current.accounts) a.id == moved.id ? moved : a,
          ],
          clearFailure: true,
        ));
        // Начисления переехали вместе со счётом — объект у них другой.
        ref.read(billsProvider.notifier).refresh();
        return Ok(moved);
      },
      (failure) {
        _set(current.copyWith(failure: failure));
        return Fail<ConnectedAccount>(failure);
      },
    );
  }

  /// Дописывает подключённый счёт, не дожидаясь перезагрузки списка.
  void applyConnected(ConnectedAccount account) {
    final current = state.value ?? AccountsState.empty;
    final known = current.accounts.any((a) => a.id == account.id);
    _set(current.copyWith(
      accounts: known
          ? [for (final a in current.accounts) a.id == account.id ? account : a]
          : [...current.accounts, account],
      clearFailure: true,
    ));
  }

  void _set(AccountsState value) => state = AsyncData(value);
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, AccountsState>(AccountsNotifier.new);

final accountsByObjectProvider = Provider.family<List<ConnectedAccount>, String>(
  (ref, objectId) =>
      ref.watch(accountsProvider).value?.byObject(objectId) ?? const <ConnectedAccount>[],
);

/// Когда начисления обновлялись в последний раз — для подписи s.syncedAt.
/// Пока список не загружен, время берём прямо из кэша: подпись нужна
/// раньше, чем ответит источник.
final lastSyncProvider = Provider<DateTime?>((ref) {
  final state = ref.watch(accountsProvider).value;
  return state?.syncedAt ?? ref.watch(accountsRepoProvider).lastSyncAt();
});

/// Подсказка «начисления давно не обновлялись». Решает [ConnectRules],
/// а не экран: то же правило проверяется юнит-тестом.
final syncHintProvider = Provider<bool>((ref) {
  final state = ref.watch(accountsProvider).value;
  if (state == null) return false;
  return ref.watch(rulesProvider).shouldSuggestSync(
        lastSyncAt: ref.watch(lastSyncProvider),
        accounts: state.accounts,
        now: ref.watch(clockProvider)(),
      );
});
