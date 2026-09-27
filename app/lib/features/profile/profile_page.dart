import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.profileTitle, style: context.t.displaySmall),
            const SizedBox(height: 16),
            AppCard(
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
                    leading: CatTile('net', Icons.language_rounded, soft: true),
                    title: s.language,
                    subtitle: s.langName,
                    chevron: true,
                    onTap: () => _langSheet(context, ref),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('tax', Icons.info_outline_rounded, soft: true),
                    title: s.version,
                    subtitle: 'ЭлPay 0.1 · ${s.byElbagar}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: AppRow(
                leading: CatTile('trash', Icons.logout_rounded, soft: true),
                title: s.logout,
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(s.logoutConfirm),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true), child: Text(s.logout)),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(sessionProvider.notifier).signOut();
                    if (context.mounted) context.go('/welcome');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _themeSheet(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
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
