import '../../core/failure.dart';
import '../../core/logger.dart';
import '../../core/net/connectivity.dart';
import '../demo_data.dart';
import '../models.dart';
import '../registry_data.dart';
import 'elpay_api.dart';

/// Демо-бэкенд: отвечает из демо-данных и реестра счетов, имитируя сеть.
///
/// Он же проверяет офлайн: если [connectivity] говорит «сети нет»,
/// запрос падает с [AppFailure.network] — ровно как в бою.
class MockElPayApi implements ElPayApi {
  MockElPayApi({
    ConnectivityService? connectivity,
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 420),
  })  : _net = connectivity ?? const AlwaysOnline(),
        _clock = clock ?? DateTime.now;

  final ConnectivityService _net;
  final DateTime Function() _clock;
  final Duration latency;

  /// Счета, подключённые в этой сессии поверх демо-набора.
  final List<ConnectedAccount> _connected = [];
  final List<Bill> _extraBills = [];
  final Set<String> _confirmed = {};
  bool _seeded = false;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (!_net.isOnline) {
      Log.w('mock-api', 'запрос отклонён: нет сети');
      throw const AppFailure.network();
    }
  }

  /// Подключённые счета для демо-набора начислений — чтобы список
  /// «Мои счета» не был пустым при первом запуске.
  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = _clock();
    for (final b in Demo.bills(now)) {
      final reg = Registry.accounts
          .where((r) => r.accountNo == b.account)
          .map((r) => r)
          .firstOrNull;
      _connected.add(ConnectedAccount(
        id: 'acc-${b.id}',
        providerId: reg?.providerId ?? 'p-${b.cat}',
        title: b.title,
        subtitle: b.subtitle,
        cat: b.cat,
        accountNo: b.account,
        objectId: b.objectId,
        holder: reg?.holder ?? 'Токтогулова А.',
        address: reg?.address ?? '',
        connectedAt: now.subtract(Duration(days: 40 + _connected.length)),
        syncedAt: now.subtract(const Duration(hours: 3)),
      ));
    }
  }

  @override
  Future<List<PayObject>> objects() async {
    await _wait();
    return Demo.objects;
  }

  @override
  Future<List<Bill>> bills() async {
    await _wait();
    return [...Demo.bills(_clock()), ..._extraBills];
  }

  @override
  Future<List<ConnectedAccount>> accounts() async {
    await _wait();
    _seed();
    return List.unmodifiable(_connected);
  }

  @override
  Future<List<AccountCandidate>> search(AccountQuery query) async {
    await _wait();
    _seed();

    final found = query.isByAccount
        ? Registry.byAccount(query.accountNo, providerId: query.providerId)
        : Registry.byAddress(query.city, query.street, query.house, query.flat);

    Log.i('mock-api', 'поиск ${query.method}: найдено ${found.length}');

    final connectedNos = _connected.map((a) => a.accountNo).toSet();
    return [
      for (final r in found)
        AccountCandidate(
          id: r.id,
          providerId: r.providerId,
          providerTitle: Demo.providerById(r.providerId)?.title ?? r.providerId,
          serviceTitle: Demo.providerById(r.providerId)?.subtitle ?? '',
          cat: Demo.providerById(r.providerId)?.cat ?? 'city',
          accountNo: r.accountNo,
          holder: r.holder,
          address: r.address,
          amount: r.amount,
          period: r.period,
          dueDay: r.dueDay,
          calc: r.calc,
          // Счёт на другого человека подключаем только с подтверждением.
          needsConfirm: !r.holder.startsWith('Токтогулова А.') && !_confirmed.contains(r.id),
          alreadyConnected: connectedNos.contains(r.accountNo),
        ),
    ];
  }

  @override
  Future<AccountCandidate> confirm({required String candidateId, required String code}) async {
    await _wait();
    final reg = Registry.byId(candidateId);
    if (reg == null) throw const AppFailure.notFound('счёт не найден');
    if (code.trim() != reg.confirmCode) {
      throw const AppFailure.validation('код не подошёл', field: 'code');
    }
    _confirmed.add(candidateId);
    final list = await search(AccountQuery.byAccount(reg.accountNo, providerId: reg.providerId));
    return list.firstWhere((c) => c.id == candidateId);
  }

  @override
  Future<ConnectResult> connect({required String candidateId, required String objectId}) async {
    await _wait();
    _seed();

    final reg = Registry.byId(candidateId);
    if (reg == null) throw const AppFailure.notFound('счёт не найден');
    if (_connected.any((a) => a.accountNo == reg.accountNo)) {
      throw const AppFailure.validation('счёт уже подключён');
    }

    final provider = Demo.providerById(reg.providerId);
    final now = _clock();
    final account = ConnectedAccount(
      id: 'acc-${reg.id}-${now.microsecondsSinceEpoch}',
      providerId: reg.providerId,
      title: provider?.title ?? reg.providerId,
      subtitle: provider?.subtitle ?? '',
      cat: provider?.cat ?? 'city',
      accountNo: reg.accountNo,
      objectId: objectId,
      holder: reg.holder,
      address: reg.address,
      connectedAt: now,
      syncedAt: now,
    );
    _connected.add(account);

    Bill? bill;
    if (reg.amount > 0) {
      bill = Bill(
        id: 'bill-${reg.id}-${now.microsecondsSinceEpoch}',
        title: account.title,
        subtitle: account.subtitle,
        cat: account.cat,
        amount: reg.amount,
        objectId: objectId,
        period: reg.period,
        due: DateTime(now.year, now.month, reg.dueDay),
        account: reg.accountNo,
        calc: reg.calc,
        requisites: [
          ...?provider?.requisites,
          ...Demo.bank,
          Field('Лицевой счёт', reg.accountNo),
          Field('Назначение', '${provider?.subtitle ?? ''}, ${reg.period}'),
        ],
      );
      _extraBills.add(bill);
    }
    Log.i('mock-api', 'подключён счёт ${reg.accountNo}');
    return ConnectResult(account: account, bill: bill);
  }

  @override
  Future<void> disconnect(String accountId) async {
    await _wait();
    final account = _connected.where((a) => a.id == accountId).firstOrNull;
    if (account == null) throw const AppFailure.notFound('счёт не подключён');
    _connected.removeWhere((a) => a.id == accountId);
    _extraBills.removeWhere((b) => b.account == account.accountNo);
    Log.i('mock-api', 'отключён счёт ${account.accountNo}');
  }

  @override
  Future<SyncResult> syncCharges() async {
    await _wait();
    _seed();
    final now = _clock();
    final synced = [
      for (final a in _connected) a.copyWith(status: AccountSyncStatus.ok, syncedAt: now),
    ];
    _connected
      ..clear()
      ..addAll(synced);
    return SyncResult(
      bills: [...Demo.bills(now), ..._extraBills],
      accounts: List.unmodifiable(synced),
      syncedAt: now,
    );
  }

  @override
  Future<List<Payment>> history() async {
    await _wait();
    return Demo.history(_clock());
  }
}
