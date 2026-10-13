import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderOrFamily объявлен в misc.dart, а не в основном экспорте пакета.
import 'package:flutter_riverpod/misc.dart';

import '../core/cache/local_store.dart';
import '../core/failure.dart';
import '../core/logger.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import 'providers.dart';

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

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

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

  /// Выход только из сессии. Данные предыдущего пользователя чистит
  /// [signOutEverywhere] — звать надо его, а не этот метод.
  Future<void> signOut() async {
    await ref.read(prefsProvider).setSession(null);
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

// ───────────────────────── способ оплаты ─────────────────────────

/// Выбранный способ оплаты, общий для всех экранов оплаты.
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

/// История платежей. Хранится локально: квитанция открывается ТОЛЬКО
/// отсюда (`/receipt` зовут history_page и reports_page), поэтому без
/// записи в хранилище начисление оставалось «оплачено», а квитанции
/// по нему после перезапуска не было нигде.
class HistoryNotifier extends Notifier<List<Payment>> {
  static const _tag = 'history';

  @override
  List<Payment> build() {
    final saved = ref.read(localStoreProvider).readList(CacheKeys.history);
    if (saved == null || saved.isEmpty) return _demo();
    try {
      return [for (final row in saved) Payment.fromJson(row)];
    } catch (e, st) {
      // Битую запись не роняем на пользователя: показываем демо-набор,
      // как при первом запуске.
      Log.e(_tag, 'битая история платежей, читаем демо-набор', e, st);
      return _demo();
    }
  }

  List<Payment> _demo() => Demo.history(ref.read(clockProvider)());

  void add(Iterable<Payment> items) {
    state = [...items, ...state]..sort((a, b) => b.date.compareTo(a.date));
    _save();
  }

  /// Записываем БЕЗ await: экраны оплаты зовут [add] синхронно, а список
  /// уже на экране — ждать хранилище им незачем.
  void _save() {
    ref.read(localStoreProvider).writeJson(
      CacheKeys.history,
      [for (final p in state) p.toJson()],
      now: ref.read(clockProvider)(),
    );
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<Payment>>(HistoryNotifier.new);

// ───────────────────────── семья и устройства ─────────────────────────

class FamilyNotifier extends Notifier<List<FamilyMember>> {
  @override
  List<FamilyMember> build() => Demo.familyDemo;

  void add(FamilyMember m) => state = [...state, m];
  void remove(String id) => state = [
        for (final m in state)
          if (m.id != id) m,
      ];
  void update(FamilyMember m) => state = [for (final x in state) x.id == m.id ? m : x];
}

final familyProvider =
    NotifierProvider<FamilyNotifier, List<FamilyMember>>(FamilyNotifier.new);

class DevicesNotifier extends Notifier<List<DeviceItem>> {
  @override
  List<DeviceItem> build() => Demo.devicesDemo;

  void revoke(String id) => state = [
        for (final d in state)
          if (d.id != id) d,
      ];
  void revokeOthers() => state = [
        for (final d in state)
          if (d.current) d,
      ];
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

  SecurityState copyWith({bool? pinOn, bool? biometrics, bool? confirmBig}) => SecurityState(
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

/// Адреса, по которым приходят уведомления об отключениях.
///
/// БАГ, который здесь закрыт: `build()` делал `ref.watch(sessionProvider)`,
/// поэтому любая правка профиля пересоздавала нотифаер и стирала всё
/// добавленное. Теперь сессия читается через `ref.read`, а список целиком
/// пересобирает только явный [reload].
///
/// Правка профиля при этом НЕ теряется: на сессию подписка есть, но она
/// обновляет ровно строку «Дом» ([_syncHome]). До этого новый адрес из
/// /personal не доходил до экрана «Адреса уведомлений» вообще — [reload]
/// не звал никто, а звать его оттуда нельзя: он стирает добавленное.
class AddressesNotifier extends Notifier<List<AddressItem>> {
  @override
  List<AddressItem> build() {
    ref.listen(sessionProvider, (_, _) => _syncHome());
    return _fromSession();
  }

  /// Подтянуть из профиля ТОЛЬКО адрес «Дом»: остальные строки
  /// пользовательские, профиль про них ничего не знает.
  void _syncHome() {
    final home = _fromSession().first;
    state = [
      for (final a in state) a.id == home.id ? home : a,
    ];
  }

  List<AddressItem> _fromSession() {
    final session = ref.read(sessionProvider);
    return [
      AddressItem(
        id: 'a1',
        title: 'Дом',
        address: session != null && session.address.isNotEmpty
            ? '${session.city}, ${session.address}'
            : 'Ош, ул. Курманжан Датка, 212',
      ),
      const AddressItem(id: 'a2', title: 'Родители', address: 'Ош, ул. Масалиева, 44'),
    ];
  }

  /// Пересобрать список из профиля — по явной просьбе экрана.
  void reload() => state = _fromSession();

  void add(AddressItem a) => state = [...state, a];
  void update(AddressItem a) => state = [for (final x in state) x.id == a.id ? a : x];
  void remove(String id) => state = [
        for (final a in state)
          if (a.id != id) a,
      ];
}

final addressesProvider =
    NotifierProvider<AddressesNotifier, List<AddressItem>>(AddressesNotifier.new);

// ───────────────────────── уведомления в ленте ─────────────────────────

class NoticesNotifier extends Notifier<List<NoticeItem>> {
  @override
  List<NoticeItem> build() => Demo.notices(ref.read(clockProvider)());

  void readAll() => state = [for (final n in state) n.copyWith(read: true)];
  void read(String id) =>
      state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  void add(NoticeItem n) => state = [n, ...state];
}

final noticesProvider =
    NotifierProvider<NoticesNotifier, List<NoticeItem>>(NoticesNotifier.new);

final unreadNoticesProvider = Provider<int>((ref) {
  var count = 0;
  for (final n in ref.watch(noticesProvider)) {
    if (!n.read) count++;
  }
  return count;
});

// ───────────────────────── маркет и билеты ─────────────────────────

final eventsProvider =
    Provider<List<EventItem>>((ref) => Demo.events(ref.watch(clockProvider)()));

/// Ключ кэша билетов. В [CacheKeys] его нет: core правит другая лана,
/// и тащить общий файл за одной строкой дороже, чем держать ключ рядом
/// с владельцем (так же сделано в DefaultCatalogRepository).
/// Купленные билеты. Как и история, живут в хранилище: иначе билет,
/// за который заплатили, исчезал при следующем запуске.
class TicketsNotifier extends Notifier<List<TicketItem>> {
  static const _tag = 'tickets';

  @override
  List<TicketItem> build() {
    final saved = ref.read(localStoreProvider).readList(CacheKeys.tickets);
    if (saved == null) return const [];
    try {
      return [for (final row in saved) TicketItem.fromJson(row)];
    } catch (e, st) {
      Log.e(_tag, 'битый список билетов, начинаем с пустого', e, st);
      return const [];
    }
  }

  void add(TicketItem t) => _save([t, ...state]);
  void markUsed(String id) =>
      _save([for (final t in state) t.id == id ? t.copyWith(used: true) : t]);
  void remove(String id) => _save([
        for (final t in state)
          if (t.id != id) t,
      ]);

  void _save(List<TicketItem> value) {
    state = value;
    ref.read(localStoreProvider).writeJson(
      CacheKeys.tickets,
      [for (final t in value) t.toJson()],
      now: ref.read(clockProvider)(),
    );
  }
}


final ticketsProvider =
    NotifierProvider<TicketsNotifier, List<TicketItem>>(TicketsNotifier.new);

// ───────────────────────── сторисы ─────────────────────────

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

// ───────────────────────── выход из аккаунта ─────────────────────────

/// Что сбрасывается при выходе. Список объявлен явно, чтобы новый провайдер
/// с данными пользователя не забыли в него добавить.
///
/// Не `const`: провайдеры — обычные `final`-значения, в константу их
/// не положить.
final resetOnSignOut = <ProviderOrFamily>[
  sessionProvider,
  billsProvider,
  accountsProvider,
  connectProvider,
  catalogProvider,
  historyProvider,
  walletProvider,
  familyProvider,
  devicesProvider,
  ticketsProvider,
  noticesProvider,
  addressesProvider,
  securityProvider,
  notifyProvider,
  storiesProvider,
  payMethodProvider,
];

/// Выход из аккаунта: чистит ОБА хранилища и сбрасывает состояние.
///
/// У AppPrefs и LocalStore разные префиксы ключей, и чистка одной сессии
/// оставляла на устройстве счета, историю, кошелёк и билеты предыдущего
/// пользователя — следующий вход показывал чужие данные.
/// Источник ответил «вы не вошли» (401/403): токен протух или отозван.
///
/// Чинить это повтором нельзя — нужен новый вход. Сбрасываем сессию, и
/// `redirect` роутера (app.dart) сам уводит на /welcome. Возвращает true,
/// если ошибка была именно про вход: вызывающий тогда не показывает
/// обычную плашку «повторить».
Future<bool> handleAuthFailure(Ref ref, AppFailure? failure) async {
  if (failure?.kind != FailureKind.auth) return false;
  Log.w('auth', 'источник не признал вход: ${failure!.message} — выходим');
  await signOutEverywhere(ref);
  return true;
}

Future<void> signOutEverywhere(Ref ref) async {
  final prefs = ref.read(prefsProvider);
  await prefs.setSession(null);
  await prefs.setPin(null);
  // Онбординг тоже принадлежит пользователю: без сброса следующий вход
  // проскакивает /setup (otp_page и redirect в app.dart смотрят
  // prefs.onboarded), а город и адрес задать уже негде.
  await prefs.setOnboarded(false);

  // Кэш данных и очередь отложенных операций: иначе чужое подключение
  // уйдёт на сервер уже под новым пользователем.
  await ref.read(outboxProvider).clear();
  await ref.read(localStoreProvider).clear();

  for (final provider in resetOnSignOut) {
    ref.invalidate(provider);
  }
  Log.i('auth', 'выход: сессия, кэш и очередь очищены');
}
