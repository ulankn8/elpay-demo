import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/data/api/elpay_api.dart';
import 'package:elpay/data/models.dart';

/// Прослойка над [ElPayApi]: считает обращения и умеет уронить любой метод.
///
/// Нужна там, где демо-бэкенд не подходит именно потому, что он честный:
///
///   * «кэш истёк и репозиторий сходил в сеть» — факт обращения виден только
///     счётчиком вызовов, по данным его не отличить от ответа из кэша;
///   * «обновление не удалось» — демо-бэкенд падает только вместе с сетью,
///     а репозиторий в офлайне до источника не доходит вовсе, поэтому
///     ветка «сервер ответил отказом» иначе не исполняется;
///   * «частичный отказ» — демо-бэкенд сообщает об отказе только по
///     НЕИЗВЕСТНЫМ ему счетам, а пометить нужно известный.
///
/// Это не замена `FakeAccountsRepository`: фейк подменяет репозиторий и
/// проверяет оркестрацию выше, а эта прослойка оставляет боевой репозиторий
/// на месте и проверяет ЕГО — политику кэша, пометки статусов и очередь.
class ProbeElPayApi implements ElPayApi {
  ProbeElPayApi(this.inner);

  /// Кому передаём вызовы, когда не велено падать.
  final ElPayApi inner;

  /// Метод → сколько раз его позвали.
  final Map<String, int> calls = {};

  /// Метод → отказ, который повторяется при каждом вызове.
  final Map<String, AppFailure> _failures = {};

  /// Подмена ответа обновления начислений: так строится частичный отказ
  /// по счёту, который источник знает.
  SyncResult Function(SyncResult real)? onSyncResult;

  /// Подмена списка объектов: так проверяется пользователь, у которого
  /// объектов ещё нет, — счёт подключать некуда.
  List<PayObject> Function(List<PayObject> real)? onObjects;

  int callsOf(String method) => calls[method] ?? 0;

  /// Метод падает, пока не позвали [clearFailures].
  void failAlways(String method, AppFailure failure) => _failures[method] = failure;

  void clearFailures() => _failures.clear();

  void resetCounters() => calls.clear();

  Future<T> _call<T>(String method, Future<T> Function() body) async {
    calls[method] = callsOf(method) + 1;
    final failure = _failures[method];
    // Источник бросает AppFailure — ровно так же, как боевой ApiClient,
    // и `guard` в репозитории превращает его в Fail.
    if (failure != null) throw failure;
    return body();
  }

  @override
  Future<List<PayObject>> objects() => _call('objects', () async {
        final real = await inner.objects();
        return onObjects?.call(real) ?? real;
      });

  @override
  Future<PayObject> saveObject(PayObject object) =>
      _call('saveObject', () => inner.saveObject(object));

  @override
  Future<void> deleteObject(String objectId) =>
      _call('deleteObject', () => inner.deleteObject(objectId));

  @override
  Future<List<Bill>> bills({String? objectId, String? cursor, int limit = 100}) =>
      _call('bills', () => inner.bills(objectId: objectId, cursor: cursor, limit: limit));

  @override
  Future<List<ConnectedAccount>> accounts() => _call('accounts', inner.accounts);

  @override
  Future<List<AccountCandidate>> search(AccountQuery query) =>
      _call('search', () => inner.search(query));

  @override
  Future<AccountCandidate> confirm({required String candidateId, required String code}) =>
      _call('confirm', () => inner.confirm(candidateId: candidateId, code: code));

  @override
  Future<ConnectResult> connect({
    required String candidateId,
    required String objectId,
    required IdempotencyKey key,
  }) =>
      _call(
        'connect',
        () => inner.connect(candidateId: candidateId, objectId: objectId, key: key),
      );

  @override
  Future<void> disconnect(String accountId, {required IdempotencyKey key}) =>
      _call('disconnect', () => inner.disconnect(accountId, key: key));

  @override
  Future<ConnectedAccount> move({required String accountId, required String objectId}) =>
      _call('move', () => inner.move(accountId: accountId, objectId: objectId));

  @override
  Future<SyncResult> syncCharges({List<String> accountIds = const []}) =>
      _call('syncCharges', () async {
        final real = await inner.syncCharges(accountIds: accountIds);
        return onSyncResult?.call(real) ?? real;
      });

  @override
  Future<Catalog> catalog({required String locale}) =>
      _call('catalog', () => inner.catalog(locale: locale));

  @override
  Future<List<Payment>> history({DateTime? from, DateTime? to, String? cursor}) =>
      _call('history', () => inner.history(from: from, to: to, cursor: cursor));
}
