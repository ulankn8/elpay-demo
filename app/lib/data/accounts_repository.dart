import '../core/analytics.dart';
import '../core/cache/local_store.dart';
import '../core/failure.dart';
import '../core/logger.dart';
import '../core/net/connectivity.dart';
import '../core/net/outbox.dart';
import '../core/result.dart';
import 'api/elpay_api.dart';
import 'models.dart';

/// Подключение счетов: поиск, подтверждение, подключение, отключение,
/// обновление начислений.
///
/// Репозиторий — единственное место, которое знает про сеть, кэш и очередь.
/// Экраны получают [Result] и больше ничего.
abstract class AccountsRepository {
  /// Подключённые счета. Сначала из кэша, потом из сети.
  Future<Result<List<ConnectedAccount>>> accounts({bool refresh = false});

  /// Что лежит в кэше прямо сейчас — для мгновенной отрисовки.
  List<ConnectedAccount> cachedAccounts();

  Future<Result<List<AccountCandidate>>> search(AccountQuery query);

  Future<Result<AccountCandidate>> confirm({required String candidateId, required String code});

  Future<Result<ConnectResult>> connect({required String candidateId, required String objectId});

  Future<Result<void>> disconnect(String accountId);

  Future<Result<SyncResult>> sync();

  /// Когда начисления обновлялись в последний раз.
  DateTime? lastSyncAt();
}

class DefaultAccountsRepository implements AccountsRepository {
  DefaultAccountsRepository({
    required this.api,
    required this.store,
    required this.connectivity,
    required this.outbox,
    this.analytics = const NoopAnalytics(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ElPayApi api;
  final LocalStore store;
  final ConnectivityService connectivity;
  final Outbox outbox;
  final Analytics analytics;
  final DateTime Function() _clock;

  static const _tag = 'accounts';

  @override
  List<ConnectedAccount> cachedAccounts() =>
      (store.readList(CacheKeys.accounts) ?? const []).map(ConnectedAccount.fromJson).toList();

  @override
  DateTime? lastSyncAt() => store.updatedAt(CacheKeys.accounts);

  @override
  Future<Result<List<ConnectedAccount>>> accounts({bool refresh = false}) async {
    final cached = cachedAccounts();
    if (!refresh && cached.isNotEmpty) {
      // Отдаём кэш сразу, обновление пойдёт отдельным вызовом.
      return Ok(cached);
    }
    final result = await guard(() => api.accounts());
    return result.fold(
      (list) async {
        await _write(list);
        return Ok(list);
      },
      (failure) async {
        Log.w(_tag, 'не удалось получить счета: ${failure.message}');
        // Сеть отвалилась — показываем сохранённое, но честно говорим об ошибке.
        return cached.isEmpty ? Fail<List<ConnectedAccount>>(failure) : Ok(cached);
      },
    );
  }

  @override
  Future<Result<List<AccountCandidate>>> search(AccountQuery query) async {
    analytics.track(AnalyticsEvent.connectStarted(query.method));
    if (!connectivity.isOnline) {
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
  }) async {
    if (!connectivity.isOnline) {
      // Без сети подключение не теряется: уйдёт из очереди, когда связь появится.
      await outbox.add(OutboxItem(
        id: 'connect-$candidateId',
        kind: 'connect_account',
        payload: {'candidateId': candidateId, 'objectId': objectId},
        createdAt: _clock(),
      ));
      return const Fail(AppFailure.network('подключим, когда появится сеть'));
    }

    final result = await guard(() => api.connect(candidateId: candidateId, objectId: objectId));
    return result.fold(
      (value) async {
        await _write([...cachedAccounts(), value.account]);
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
  Future<Result<void>> disconnect(String accountId) async {
    final account = cachedAccounts().where((a) => a.id == accountId).firstOrNull;
    final result = await guard(() => api.disconnect(accountId));
    if (result.isOk) {
      await _write(cachedAccounts().where((a) => a.id != accountId).toList());
      if (account != null) {
        analytics.track(AnalyticsEvent.accountDisconnected(account.providerId));
      }
    }
    return result;
  }

  @override
  Future<Result<SyncResult>> sync() async {
    if (!connectivity.isOnline) return const Fail(AppFailure.network());
    final result = await guard(() => api.syncCharges());
    return result.fold(
      (value) async {
        await _write(value.accounts);
        return Ok(value);
      },
      (failure) {
        analytics.track(AnalyticsEvent.syncFailed(failure.kind.name));
        // Помечаем счета как «не обновились» — статус виден в списке.
        final marked = [
          for (final a in cachedAccounts())
            a.copyWith(status: AccountSyncStatus.failed, lastError: failure.message),
        ];
        if (marked.isNotEmpty) _write(marked);
        return Fail<SyncResult>(failure);
      },
    );
  }

  /// Отправляет отложенные подключения, когда сеть вернулась.
  Future<int> flushOutbox() => outbox.flush((item) async {
        if (item.kind != 'connect_account') return false;
        final r = await connect(
          candidateId: '${item.payload['candidateId']}',
          objectId: '${item.payload['objectId']}',
        );
        return r.isOk;
      });

  Future<void> _write(List<ConnectedAccount> list) => store.writeJson(
        CacheKeys.accounts,
        [for (final a in list) a.toJson()],
        now: _clock(),
      );
}
