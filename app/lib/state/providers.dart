import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';
import '../data/auth_repository.dart';
import '../data/demo_data.dart';
import '../data/bills_repository.dart';
import '../data/models.dart';
import '../data/payments_repository.dart';

/// Заполняется в main() — SharedPreferences читается один раз при старте.
final prefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());

final authRepoProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
final billsRepoProvider = Provider<BillsRepository>((ref) => MockBillsRepository());
final paymentsRepoProvider = Provider<PaymentsRepository>((ref) => StubPaymentsRepository());

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
  const BillsState({required this.objects, required this.bills});
  final List<PayObject> objects;
  final List<Bill> bills;

  List<Bill> byObject(String id) => bills.where((b) => b.objectId == id).toList();
  List<Bill> get unpaid => bills.where((b) => !b.paid).toList();
  double get dueTotal => unpaid.fold(0.0, (s, b) => s + b.amount);
}

class BillsNotifier extends AsyncNotifier<BillsState> {
  @override
  Future<BillsState> build() async {
    final repo = ref.read(billsRepoProvider);
    final objects = await repo.objects();
    final bills = await repo.bills();
    return BillsState(objects: objects, bills: bills);
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
