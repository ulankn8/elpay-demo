import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics.dart';
import '../core/app_config.dart';
import '../core/cache/local_store.dart';
import '../core/failure.dart';
import '../core/net/connectivity.dart';
import '../core/net/outbox.dart';
import '../core/prefs.dart';
import '../core/result.dart';
import '../data/accounts_repository.dart';
import '../data/api/api_client.dart';
import '../data/api/elpay_api.dart';
import '../data/api/http_api.dart';
import '../data/api/mock_api.dart';
import '../data/auth_repository.dart';
import '../data/demo_data.dart';
import '../data/bills_repository.dart';
import '../data/models.dart';
import '../data/payments_repository.dart';
import '../data/stories_repository.dart';

/// Заполняется в main() — SharedPreferences читается один раз при старте.
final prefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());

/// Локальный кэш: тоже создаётся в main() поверх тех же SharedPreferences.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

/// Настройки сборки: демо или боевой API, включены ли платежи.
final configProvider = Provider<AppConfig>((ref) => AppConfig.current);

/// Состояние сети. В демо переключается вручную — так показывают офлайн.
final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ManualConnectivity();
  ref.onDispose(service.dispose);
  return service;
});

/// Поток «есть сеть / нет сети» для плашки офлайна.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final net = ref.watch(connectivityProvider);
  return net.changes;
});

final analyticsProvider = Provider<Analytics>((ref) => const DebugAnalytics());

final outboxProvider = Provider<Outbox>((ref) => Outbox(ref.watch(localStoreProvider)));

/// Бэкенд: демо-реализация или HTTP — переключается одним флагом сборки.
final apiProvider = Provider<ElPayApi>((ref) {
  final config = ref.watch(configProvider);
  if (config.useMockData) {
    return MockElPayApi(connectivity: ref.watch(connectivityProvider));
  }
  final client = ApiClient(config: config);
  ref.onDispose(client.close);
  return HttpElPayApi(client);
});

final authRepoProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
final paymentsRepoProvider = Provider<PaymentsRepository>((ref) => StubPaymentsRepository());

final billsRepoProvider = Provider<BillsRepository>((ref) => DefaultBillsRepository(
      api: ref.watch(apiProvider),
      store: ref.watch(localStoreProvider),
    ));

final accountsRepoProvider = Provider<AccountsRepository>((ref) => DefaultAccountsRepository(
      api: ref.watch(apiProvider),
      store: ref.watch(localStoreProvider),
      connectivity: ref.watch(connectivityProvider),
      outbox: ref.watch(outboxProvider),
      analytics: ref.watch(analyticsProvider),
    ));

// ───────────────────────── настройки ─────────────────────────

@immutable
class Settings {
  const Settings({required this.locale, required this.themeMode});
  final Locale locale;
  final ThemeMode themeMode;

  Settings copyWith({Locale? locale, ThemeMode? themeMode}) =>
      Settings(locale: locale ?? this.locale, themeMode: themeMode ?? this.themeMode);
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    final p = ref.read(prefsProvider);
    return Settings(
      locale: Locale(p.locale),
      themeMode: switch (p.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
    );
  }

  Future<void> setLocale(String code) async {
    await ref.read(prefsProvider).setLocale(code);
    state = state.copyWith(locale: Locale(code));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(prefsProvider).setThemeMode(mode.name);
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ───────────────────────── сессия ─────────────────────────

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    final raw = ref.read(prefsProvider).sessionJson;
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn(Session s) async {
    await ref.read(prefsProvider).setSession(jsonEncode(s.toJson()));
    state = s;
  }

  Future<void> update(Session s) => signIn(s);

  Future<void> signOut() async {
    await ref.read(prefsProvider).setSession(null);
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

// ───────────────────────── счета ─────────────────────────

@immutable
class BillsState {
  const BillsState({
    required this.objects,
    required this.bills,
    this.syncedAt,
    this.fromCache = false,
    this.failure,
  });

  final List<PayObject> objects;
  final List<Bill> bills;
  final DateTime? syncedAt;

  /// Данные из кэша: сеть не ответила, но показать есть что.
  final bool fromCache;

  /// Последняя ошибка загрузки — для плашки над списком.
  final AppFailure? failure;

  List<Bill> byObject(String id) => bills.where((b) => b.objectId == id).toList();
  List<Bill> get unpaid => bills.where((b) => !b.paid).toList();
  double get dueTotal => unpaid.fold(0.0, (s, b) => s + b.amount);

  BillsState copyWith({
    List<PayObject>? objects,
    List<Bill>? bills,
    DateTime? syncedAt,
    bool? fromCache,
    AppFailure? failure,
  }) =>
      BillsState(
        objects: objects ?? this.objects,
        bills: bills ?? this.bills,
        syncedAt: syncedAt ?? this.syncedAt,
        fromCache: fromCache ?? this.fromCache,
        failure: failure,
      );
}

class BillsNotifier extends AsyncNotifier<BillsState> {
  @override
  Future<BillsState> build() async {
    final repo = ref.read(billsRepoProvider);
    // Сохранённое показываем сразу, не дожидаясь сети.
    final cached = repo.cached();
    if (cached.objects.isNotEmpty) {
      state = AsyncData(_toState(cached));
    }
    final result = await repo.load();
    return result.fold(_toState, (failure) {
      if (cached.objects.isNotEmpty) {
        return _toState(cached).copyWith(failure: failure);
      }
      throw failure;
    });
  }

  BillsState _toState(BillsSnapshot s) => BillsState(
        objects: s.objects,
        bills: s.bills,
        syncedAt: s.syncedAt,
        fromCache: s.fromCache,
      );

  /// Потянули вниз: идём в сеть, ошибку показываем плашкой, данные не теряем.
  Future<void> refresh() async {
    final repo = ref.read(billsRepoProvider);
    final current = state.value;
    final result = await repo.load(refresh: true);
    state = AsyncData(result.fold(
      _toState,
      (failure) => (current ?? const BillsState(objects: [], bills: []))
          .copyWith(failure: failure, fromCache: true),
    ));
  }

  void markPaid(Iterable<String> ids) {
    final cur = state.value;
    if (cur == null) return;
    final set = ids.toSet();
    state = AsyncData(BillsState(
      objects: cur.objects,
      bills: [
        for (final b in cur.bills) set.contains(b.id) ? b.copyWith(paid: true) : b,
      ],
    ));
  }

  void _set(BillsState v) => state = AsyncData(v);

  void addObject(PayObject o) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(objects: [...cur.objects, o], bills: cur.bills));
  }

  void updateObject(PayObject o) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(
      objects: [for (final x in cur.objects) x.id == o.id ? o : x],
      bills: cur.bills,
    ));
  }

  /// Удаляет объект вместе с его счетами — иначе счета осиротеют.
  void removeObject(String id) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(
      objects: cur.objects.where((o) => o.id != id).toList(),
      bills: cur.bills.where((b) => b.objectId != id).toList(),
    ));
  }

  void addBill(Bill b) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(objects: cur.objects, bills: [...cur.bills, b]));
  }

  void updateBill(Bill b) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(
      objects: cur.objects,
      bills: [for (final x in cur.bills) x.id == b.id ? b : x],
    ));
  }

  void removeBill(String id) {
    final cur = state.value;
    if (cur == null) return;
    _set(BillsState(
      objects: cur.objects,
      bills: cur.bills.where((b) => b.id != id).toList(),
    ));
  }

  void toggleAutopay(String id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(BillsState(
      objects: cur.objects,
      bills: [
        for (final b in cur.bills) b.id == id ? b.copyWith(autopay: !b.autopay) : b,
      ],
    ));
  }
}

final billsProvider = AsyncNotifierProvider<BillsNotifier, BillsState>(BillsNotifier.new);

/// Выбранный способ оплаты (общий для всех экранов оплаты).
class PayMethodNotifier extends Notifier<String> {
  @override
  String build() => 'visa';
  void select(String id) => state = id;
}

final payMethodProvider = NotifierProvider<PayMethodNotifier, String>(PayMethodNotifier.new);

// ───────────────────────── кошелёк ─────────────────────────

/// Баланс кошелька ЭлPay. Настоящие списания появятся вместе со шлюзом,
/// сейчас — локальное состояние демо.
class WalletNotifier extends Notifier<double> {
  @override
  double build() => 1240;

  void topUp(double v) => state = state + v;
  void spend(double v) => state = (state - v).clamp(0, double.infinity);
}

final walletProvider = NotifierProvider<WalletNotifier, double>(WalletNotifier.new);

// ───────────────────────── история платежей ─────────────────────────

class HistoryNotifier extends Notifier<List<Payment>> {
  @override
  List<Payment> build() => Demo.history(DateTime.now());

  void add(Iterable<Payment> items) {
    state = [...items, ...state]..sort((a, b) => b.date.compareTo(a.date));
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<Payment>>(HistoryNotifier.new);

// ───────────────────────── семья и устройства ─────────────────────────

class FamilyNotifier extends Notifier<List<FamilyMember>> {
  @override
  List<FamilyMember> build() => Demo.familyDemo;

  void add(FamilyMember m) => state = [...state, m];
  void remove(String id) => state = state.where((m) => m.id != id).toList();
  void update(FamilyMember m) =>
      state = [for (final x in state) x.id == m.id ? m : x];
}

final familyProvider =
    NotifierProvider<FamilyNotifier, List<FamilyMember>>(FamilyNotifier.new);

class DevicesNotifier extends Notifier<List<DeviceItem>> {
  @override
  List<DeviceItem> build() => Demo.devicesDemo;

  void revoke(String id) => state = state.where((d) => d.id != id).toList();
  void revokeOthers() => state = state.where((d) => d.current).toList();
}

final devicesProvider =
    NotifierProvider<DevicesNotifier, List<DeviceItem>>(DevicesNotifier.new);

// ───────────────────────── безопасность и уведомления ─────────────────────────

@immutable
class SecurityState {
  const SecurityState({
    required this.pinOn,
    required this.biometrics,
    required this.confirmBig,
  });
  final bool pinOn, biometrics, confirmBig;

  SecurityState copyWith({bool? pinOn, bool? biometrics, bool? confirmBig}) =>
      SecurityState(
        pinOn: pinOn ?? this.pinOn,
        biometrics: biometrics ?? this.biometrics,
        confirmBig: confirmBig ?? this.confirmBig,
      );
}

class SecurityNotifier extends Notifier<SecurityState> {
  @override
  SecurityState build() {
    final p = ref.read(prefsProvider);
    return SecurityState(pinOn: p.pin != null, biometrics: p.biometrics, confirmBig: true);
  }

  Future<void> setPin(String? pin) async {
    await ref.read(prefsProvider).setPin(pin);
    state = state.copyWith(pinOn: pin != null);
  }

  Future<void> setBiometrics(bool v) async {
    await ref.read(prefsProvider).setBiometrics(v);
    state = state.copyWith(biometrics: v);
  }

  void setConfirmBig(bool v) => state = state.copyWith(confirmBig: v);
}

final securityProvider =
    NotifierProvider<SecurityNotifier, SecurityState>(SecurityNotifier.new);

@immutable
class NotifyState {
  const NotifyState({
    required this.bills,
    required this.outages,
    required this.market,
    required this.quietHours,
  });
  final bool bills, outages, market, quietHours;

  NotifyState copyWith({bool? bills, bool? outages, bool? market, bool? quietHours}) =>
      NotifyState(
        bills: bills ?? this.bills,
        outages: outages ?? this.outages,
        market: market ?? this.market,
        quietHours: quietHours ?? this.quietHours,
      );
}

class NotifyNotifier extends Notifier<NotifyState> {
  @override
  NotifyState build() =>
      const NotifyState(bills: true, outages: true, market: false, quietHours: true);

  void set(NotifyState v) => state = v;
}

final notifyProvider = NotifierProvider<NotifyNotifier, NotifyState>(NotifyNotifier.new);

// ───────────────────────── адреса уведомлений ─────────────────────────

@immutable
class AddressItem {
  const AddressItem({required this.id, required this.title, required this.address});
  final String id, title, address;
}

class AddressesNotifier extends Notifier<List<AddressItem>> {
  @override
  List<AddressItem> build() {
    final session = ref.watch(sessionProvider);
    return [
      AddressItem(
        id: 'a1',
        title: 'Дом',
        address: session?.address.isNotEmpty == true
            ? '${session!.city}, ${session.address}'
            : 'Ош, ул. Курманжан Датка, 212',
      ),
      const AddressItem(id: 'a2', title: 'Родители', address: 'Ош, ул. Масалиева, 44'),
    ];
  }

  void add(AddressItem a) => state = [...state, a];
  void update(AddressItem a) => state = [for (final x in state) x.id == a.id ? a : x];
  void remove(String id) => state = state.where((a) => a.id != id).toList();
}

final addressesProvider =
    NotifierProvider<AddressesNotifier, List<AddressItem>>(AddressesNotifier.new);

// ───────────────────────── уведомления в ленте ─────────────────────────

class NoticesNotifier extends Notifier<List<NoticeItem>> {
  @override
  List<NoticeItem> build() => Demo.notices(DateTime.now());

  void readAll() => state = [for (final n in state) n.copyWith(read: true)];
  void read(String id) =>
      state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  void add(NoticeItem n) => state = [n, ...state];
}

final noticesProvider =
    NotifierProvider<NoticesNotifier, List<NoticeItem>>(NoticesNotifier.new);

final unreadNoticesProvider =
    Provider<int>((ref) => ref.watch(noticesProvider).where((n) => !n.read).length);

// ───────────────────────── маркет и билеты ─────────────────────────

final eventsProvider = Provider<List<EventItem>>((ref) => Demo.events(DateTime.now()));

class TicketsNotifier extends Notifier<List<TicketItem>> {
  @override
  List<TicketItem> build() => const [];

  void add(TicketItem t) => state = [t, ...state];
  void markUsed(String id) =>
      state = [for (final t in state) t.id == id ? t.copyWith(used: true) : t];
  void remove(String id) => state = state.where((t) => t.id != id).toList();
}

final ticketsProvider =
    NotifierProvider<TicketsNotifier, List<TicketItem>>(TicketsNotifier.new);

// ───────────────────────── сторисы ─────────────────────────

final storiesRepoProvider = Provider<StoriesRepository>((ref) => MockStoriesRepository());

/// Сторисы главной. Просмотренные помечаются локально — на бэкенде
/// это станет отметкой прочтения.
class StoriesNotifier extends AsyncNotifier<List<StoryItem>> {
  @override
  Future<List<StoryItem>> build() => ref.read(storiesRepoProvider).stories();

  void markSeen(String id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData([
      for (final s in cur) s.id == id ? s.copyWith(seen: true) : s,
    ]);
  }
}

final storiesProvider =
    AsyncNotifierProvider<StoriesNotifier, List<StoryItem>>(StoriesNotifier.new);

// ───────────────────────── подключённые счета ─────────────────────────

/// Список подключённых лицевых счетов. Сначала из кэша, потом из сети.
class AccountsNotifier extends AsyncNotifier<List<ConnectedAccount>> {
  @override
  Future<List<ConnectedAccount>> build() async {
    final repo = ref.read(accountsRepoProvider);
    final cached = repo.cachedAccounts();
    if (cached.isNotEmpty) state = AsyncData(cached);
    final result = await repo.accounts();
    return result.fold((list) => list, (failure) {
      if (cached.isNotEmpty) return cached;
      throw failure;
    });
  }

  /// Обновить начисления по всем счетам.
  Future<Result<SyncResult>> sync() async {
    final repo = ref.read(accountsRepoProvider);
    state = AsyncData([
      for (final a in state.value ?? const <ConnectedAccount>[])
        a.copyWith(status: AccountSyncStatus.syncing),
    ]);
    final result = await repo.sync();
    result.fold(
      (value) {
        state = AsyncData(value.accounts);
        // Начисления изменились — перечитываем их из источника, а не из кэша.
        ref.read(billsProvider.notifier).refresh();
      },
      (failure) => state = AsyncData([
        for (final a in state.value ?? const <ConnectedAccount>[])
          a.copyWith(status: AccountSyncStatus.failed, lastError: failure.message),
      ]),
    );
    return result;
  }

  Future<Result<void>> disconnect(String accountId) async {
    final result = await ref.read(accountsRepoProvider).disconnect(accountId);
    if (result.isOk) {
      state = AsyncData([
        for (final a in state.value ?? const <ConnectedAccount>[])
          if (a.id != accountId) a,
      ]);
      ref.read(billsProvider.notifier).refresh();
    }
    return result;
  }

  void add(ConnectedAccount account) =>
      state = AsyncData([...?state.value, account]);
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<ConnectedAccount>>(AccountsNotifier.new);

// ───────────────────────── мастер подключения ─────────────────────────

/// Шаг мастера: сначала форма поиска, потом найденные счета.
enum ConnectStep { form, results, done }

@immutable
class ConnectState {
  const ConnectState({
    this.step = ConnectStep.form,
    this.byAddress = false,
    this.searching = false,
    this.connecting = false,
    this.found = const [],
    this.selected = const {},
    this.connected = const [],
    this.failure,
  });

  final ConnectStep step;

  /// Выбран поиск по адресу, а не по лицевому счёту.
  final bool byAddress;
  final bool searching, connecting;
  final List<AccountCandidate> found;
  final Set<String> selected;
  final List<ConnectedAccount> connected;
  final AppFailure? failure;

  List<AccountCandidate> get selectable =>
      found.where((c) => !c.alreadyConnected).toList();

  double get selectedSum => found
      .where((c) => selected.contains(c.id))
      .fold(0.0, (sum, c) => sum + c.amount);

  ConnectState copyWith({
    ConnectStep? step,
    bool? byAddress,
    bool? searching,
    bool? connecting,
    List<AccountCandidate>? found,
    Set<String>? selected,
    List<ConnectedAccount>? connected,
    AppFailure? failure,
  }) =>
      ConnectState(
        step: step ?? this.step,
        byAddress: byAddress ?? this.byAddress,
        searching: searching ?? this.searching,
        connecting: connecting ?? this.connecting,
        found: found ?? this.found,
        selected: selected ?? this.selected,
        connected: connected ?? this.connected,
        failure: failure,
      );
}

/// Состояние мастера подключения счёта: поиск → выбор → подключение.
class ConnectNotifier extends Notifier<ConnectState> {
  @override
  ConnectState build() => const ConnectState();

  void setMode({required bool byAddress}) =>
      state = const ConnectState().copyWith(byAddress: byAddress);

  void reset() => state = const ConnectState();

  void toggle(String candidateId) {
    final next = {...state.selected};
    next.contains(candidateId) ? next.remove(candidateId) : next.add(candidateId);
    state = state.copyWith(selected: next);
  }

  void selectAll() => state = state.copyWith(
        selected: {for (final c in state.selectable) c.id},
      );

  void selectNone() => state = state.copyWith(selected: const {});

  Future<void> search(AccountQuery query) async {
    state = state.copyWith(searching: true, failure: null);
    final result = await ref.read(accountsRepoProvider).search(query);
    state = result.fold(
      (list) => state.copyWith(
        searching: false,
        step: ConnectStep.results,
        found: list,
        selected: {for (final c in list.where((c) => !c.alreadyConnected)) c.id},
      ),
      (failure) => state.copyWith(searching: false, failure: failure),
    );
  }

  /// Подтверждение владения счётом кодом из квитанции.
  Future<Result<AccountCandidate>> confirm(String candidateId, String code) async {
    final result = await ref.read(accountsRepoProvider)
        .confirm(candidateId: candidateId, code: code);
    result.fold(
      (updated) => state = state.copyWith(
        found: [
          for (final c in state.found) c.id == updated.id ? updated : c,
        ],
      ),
      (_) {},
    );
    return result;
  }

  /// Подключает выбранные счета к объекту. Возвращает, сколько подключилось.
  Future<int> connectSelected(String objectId) async {
    final repo = ref.read(accountsRepoProvider);
    final chosen = state.found.where((c) => state.selected.contains(c.id)).toList();
    if (chosen.isEmpty) return 0;

    state = state.copyWith(connecting: true, failure: null);
    final connected = <ConnectedAccount>[];
    AppFailure? failure;

    for (final candidate in chosen) {
      final result = await repo.connect(candidateId: candidate.id, objectId: objectId);
      result.fold((value) => connected.add(value.account), (f) => failure = f);
    }

    if (connected.isNotEmpty) {
      ref.invalidate(accountsProvider);
      // Появились новые начисления — обновляем ленту счетов из источника.
      await ref.read(billsProvider.notifier).refresh();
    }
    state = state.copyWith(
      connecting: false,
      connected: connected,
      step: connected.isEmpty ? ConnectStep.results : ConnectStep.done,
      failure: connected.isEmpty ? failure : null,
    );
    return connected.length;
  }
}

final connectProvider = NotifierProvider<ConnectNotifier, ConnectState>(ConnectNotifier.new);
