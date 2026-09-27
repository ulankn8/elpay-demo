import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Безопасность: код-пароль, вход по биометрии, подтверждение крупных сумм.
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final sec = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.securityTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('power', Icons.lock_outline_rounded, soft: true),
                    title: s.pinTitle,
                    subtitle: s.pinLead,
                    trailing: Switch(
                      value: sec.pinOn,
                      onChanged: (v) => v ? _setPin(context, ref) : _clearPin(context, ref),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('kid', Icons.face_rounded, soft: true),
                    title: s.faceId,
                    subtitle: sec.pinOn ? null : s.pinFirst,
                    trailing: Switch(
                      value: sec.biometrics && sec.pinOn,
                      onChanged: sec.pinOn
                          ? (v) => ref.read(securityProvider.notifier).setBiometrics(v)
                          : null,
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('tax', Icons.verified_user_outlined, soft: true),
                    title: s.confirmBigShort,
                    subtitle: s.confirmBigLead,
                    trailing: Switch(
                      value: sec.confirmBig,
                      onChanged: (v) => ref.read(securityProvider.notifier).setConfirmBig(v),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('net', Icons.devices_rounded, soft: true),
                    title: s.devicesTitle,
                    subtitle: s.devicesLead,
                    chevron: true,
                    onTap: () => context.push('/devices'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearPin(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    await ref.read(securityProvider.notifier).setPin(null);
    if (context.mounted) showAppSnack(context, s.pinOffMsg);
  }

  void _setPin(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final first = TextEditingController();
    final second = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 2),
                  child: Text(s.pinTitle, style: context.t.headlineSmall),
                ),
                TextField(
                  controller: first,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.pinEnter, counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: second,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.pinRepeat, counterText: ''),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final a = first.text.trim(), b = second.text.trim();
                    if (a.length != 4) {
                      showAppSnack(ctx, s.pinEnter);
                      return;
                    }
                    if (a != b) {
                      showAppSnack(ctx, s.pinMismatch);
                      return;
                    }
                    await ref.read(securityProvider.notifier).setPin(a);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) showAppSnack(context, s.pinOnMsg);
                  },
                  child: Text(s.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Устройства и входы: список сессий и выход на чужих устройствах.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final list = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.devicesTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Tip(s.devicesLead),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    AppRow(
                      leading: CatTile(
                        list[i].current ? 'water' : 'trash',
                        list[i].title.contains('Браузер')
                            ? Icons.laptop_mac_rounded
                            : Icons.smartphone_rounded,
                        soft: true,
                      ),
                      title: list[i].title,
                      subtitle: '${list[i].place} · ${list[i].lastSeen}',
                      trailing: list[i].current
                          ? AppChip(s.thisDevice, tone: ChipTone.ok)
                          : TextButton(
                              onPressed: () {
                                ref.read(devicesProvider.notifier).revoke(list[i].id);
                                showAppSnack(context, s.revokeDevice);
                              },
                              child: Text(s.revokeDevice),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(context, s.logoutAll, s.logoutAll);
                if (ok != true) return;
                ref.read(devicesProvider.notifier).revokeOthers();
                if (context.mounted) showAppSnack(context, s.logoutAllDone);
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(s.logoutAll),
            ),
          ],
        ),
      ),
    );
  }
}
