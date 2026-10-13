import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/net/connectivity.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Мост до [signOutEverywhere]: функция принимает `Ref`, а экран держит
/// `WidgetRef` — это разные типы, и напрямую вызов не компилируется.
///
/// РАСХОЖДЕНИЕ С ПЛАНОМ: по-хорошему такой провайдер живёт в
/// state/app_state.dart рядом с самим выходом (там же лежит
/// `resetOnSignOut`). Как только он появится там, этот уедет.
final _signOutProvider =
    Provider<Future<void> Function()>((ref) => () => signOutEverywhere(ref));

/// Профиль: личные данные, объекты и счета, семья, безопасность, настройки.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final sec = ref.watch(securityProvider);
    final billsAsync = ref.watch(billsProvider);
    final family = ref.watch(familyProvider);
    final accounts = ref.watch(accountsProvider);
    final config = ref.watch(configProvider);
    // Состояние сети: демо-переключатель ниже показывает офлайн-режим.
    ref.watch(isOnlineProvider);
    final online = ref.watch(connectivityProvider).isOnline;
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.profileTitle, style: context.t.displaySmall),
            const SizedBox(height: 16),
            AppCard(
              onTap: () => context.push('/personal'),
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Brand.primary, Brand.p600]),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(session?.initials ?? 'ЭП',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700, color: Brand.onPrimary)),
                  ),
                  const SizedBox(height: 12),
                  Text(session?.name ?? '', style: context.t.headlineSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (session?.phone != null)
                        AppChip(session!.phone!, tone: ChipTone.ok, icon: Icons.smartphone_rounded),
                      if (session?.email != null)
                        AppChip(session!.email!, tone: ChipTone.ok, icon: Icons.mail_outline_rounded),
                      if (session?.telegram != null)
                        AppChip(session!.telegram!, tone: ChipTone.ok, icon: Icons.send_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => context.push('/personal'),
                    child: Text(s.personalData),
                  ),
                ],
              ),
            ),
            SectionTitle(s.myAccounts),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('water', Icons.home_work_outlined, soft: true),
                    title: s.objectsTitle,
                    // Загрузка и ошибка подписаны честно: раньше любой
                    // отказ выглядел как «объектов нет».
                    subtitle: billsAsync.when(
                      data: (state) => state.objects.isEmpty
                          ? s.objectsLead
                          : state.objects.map((o) => s.tr(o.name)).join(', '),
                      loading: () => s.loadingData,
                      error: (e, _) => failureTitle(s, failureOf(e)),
                    ),
                    chevron: true,
                    onTap: () => context.push('/objects'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('power', Icons.receipt_long_outlined, soft: true),
                    title: s.accountsTitle,
                    subtitle: accounts.when(
                      data: (list) => s.billsCount(list.length),
                      loading: () => s.loadingData,
                      error: (e, _) => failureTitle(s, failureOf(e)),
                    ),
                    chevron: true,
                    onTap: () => context.push('/accounts'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('trash', Icons.place_outlined, soft: true),
                    title: s.addressesTitle,
                    subtitle: s.addressCount(addresses.length),
                    chevron: true,
                    onTap: () => context.push('/addresses'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('kid', Icons.people_outline_rounded, soft: true),
                    title: s.familyTitle,
                    subtitle: s.membersCount(family.length),
                    chevron: true,
                    onTap: () => context.push('/family'),
                  ),
                ],
              ),
            ),
            SectionTitle(s.sectionAccess),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('tax', Icons.lock_outline_rounded, soft: true),
                    title: s.securityTitle,
                    subtitle: sec.pinOn ? '${s.pinTitle} · ${s.faceId}' : s.securityLead,
                    chevron: true,
                    onTap: () => context.push('/security'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('net', Icons.notifications_none_rounded, soft: true),
                    title: s.notifyTitle,
                    subtitle: s.notifyLead,
                    chevron: true,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
            SectionTitle(s.appSection),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('market', Icons.dark_mode_outlined, soft: true),
                    title: s.theme,
                    subtitle: switch (settings.themeMode) {
                      ThemeMode.light => s.themeLight,
                      ThemeMode.dark => s.themeDark,
                      ThemeMode.system => s.themeSystem,
                    },
                    chevron: true,
                    onTap: () => _themeSheet(context, ref),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('door', Icons.language_rounded, soft: true),
                    title: s.language,
                    subtitle: s.langName,
                    chevron: true,
                    onTap: () => _langSheet(context, ref),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('power', Icons.percent_rounded, soft: true),
                    title: s.tariffsTitle,
                    subtitle: s.tariffsLead,
                    chevron: true,
                    onTap: () => context.push('/tariffs'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('water', Icons.support_agent_rounded, soft: true),
                    title: s.supportTitle,
                    subtitle: s.supportLead,
                    chevron: true,
                    onTap: () => context.push('/support'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('tax', Icons.info_outline_rounded, soft: true),
                    title: s.version,
                    subtitle: 'ЭлPay 0.2 · ${s.byElbagar}',
                  ),
                ],
              ),
            ),
            SectionTitle(s.demoSection),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('net', Icons.wifi_rounded, soft: true),
                    title: s.demoOffline,
                    subtitle: s.demoOfflineLead,
                    onTap: () => _toggleNetwork(context, ref, online),
                    trailing: Switch(
                      value: !online,
                      onChanged: (_) => _toggleNetwork(context, ref, online),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('tax', Icons.cloud_outlined, soft: true),
                    title: s.demoDataSource,
                    subtitle: config.isDemo ? s.demoDataMock : config.apiBaseUrl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('trash', Icons.logout_rounded, soft: true),
                    title: s.logout,
                    onTap: () => _logout(context, ref),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('trash', Icons.delete_outline_rounded, soft: true),
                    title: s.deleteAccount,
                    subtitle: s.deleteAccountLead,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Демо-переключатель сети: показывает, как приложение ведёт себя офлайн.
  void _toggleNetwork(BuildContext context, WidgetRef ref, bool online) {
    final s = S.of(context);
    final net = ref.read(connectivityProvider);
    if (net is! ManualConnectivity) return;
    net.setOnline(!online);
    showAppSnack(context, online ? s.offlineBanner : s.syncOk);
  }

  /// Выход чистит ОБА хранилища и сбрасывает состояние: у AppPrefs и
  /// LocalStore разные префиксы, и выход «только из сессии» оставлял на
  /// устройстве счета, историю, кошелёк и билеты прошлого пользователя —
  /// следующий вход показывал чужие данные.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await confirmDialog(context, s.logoutConfirm, s.logout);
    if (ok != true) return;
    await ref.read(_signOutProvider)();
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await confirmDialog(context, s.deleteAccountLead, s.deleteAccount);
    if (ok != true) return;
    // Онбординг снимается до выхода: сам выход чистит хранилища целиком.
    await ref.read(prefsProvider).setOnboarded(false);
    await ref.read(_signOutProvider)();
    if (!context.mounted) return;
    showAppSnack(context, s.deleteAccountDone);
    context.go('/welcome');
  }

  void _themeSheet(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, label) in [
              (ThemeMode.system, s.themeSystem),
              (ThemeMode.light, s.themeLight),
              (ThemeMode.dark, s.themeDark),
            ])
              _PickTile(
                label: label,
                selected: ref.read(settingsProvider).themeMode == mode,
                onTap: () {
                  ref.read(settingsProvider.notifier).setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _langSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in [('ru', 'Русский'), ('ky', 'Кыргызча')])
              _PickTile(
                label: label,
                selected: ref.read(settingsProvider).locale.languageCode == code,
                onTap: () {
                  ref.read(settingsProvider.notifier).setLocale(code);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label, style: context.t.titleMedium),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: Brand.primary)
            : Icon(Icons.circle_outlined, color: context.c.muted2),
        onTap: onTap,
      );
}
