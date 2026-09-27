import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';
import '../data/auth_repository.dart';
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
