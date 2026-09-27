import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Уведомления: что присылать и когда молчать.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final n = ref.watch(notifyProvider);
    final notifier = ref.read(notifyProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s.notifyTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('power', Icons.receipt_long_outlined, soft: true),
                    title: s.notifyBills,
                    trailing: Switch(
                      value: n.bills,
                      onChanged: (v) => notifier.set(n.copyWith(bills: v)),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('water', Icons.water_damage_outlined, soft: true),
                    title: s.notifyOutages,
                    trailing: Switch(
                      value: n.outages,
                      onChanged: (v) => notifier.set(n.copyWith(outages: v)),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('market', Icons.local_activity_outlined, soft: true),
                    title: s.notifyMarket,
                    trailing: Switch(
                      value: n.market,
                      onChanged: (v) => notifier.set(n.copyWith(market: v)),
                    ),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('kid', Icons.bedtime_outlined, soft: true),
                    title: s.quietHours,
                    trailing: Switch(
                      value: n.quietHours,
                      onChanged: (v) => notifier.set(n.copyWith(quietHours: v)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Tip(s.notifyLead),
          ],
        ),
      ),
    );
  }
}

/// Тарифы и комиссии: на чём зарабатывает продукт.
class TariffsPage extends StatelessWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tariffsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.tariffsLead2, style: context.t.bodyMedium),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < s.tariffRows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: context.c.line2),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.tariffRows[i].$1, style: context.t.titleMedium),
                                const SizedBox(height: 2),
                                Text(s.tariffRows[i].$2, style: context.t.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(s.tariffRows[i].$3,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Brand.p700)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Tip(s.tariffsNote),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showAppSnack(context, s.soonHere),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(s.offer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Поддержка: чат и телефон.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.supportTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Tip(s.supportHours),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('water', Icons.chat_bubble_outline_rounded, soft: true),
                    title: s.supportChat,
                    chevron: true,
                    onTap: () => showAppSnack(context, s.soonHere),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('power', Icons.call_outlined, soft: true),
                    title: s.supportCall,
                    chevron: true,
                    onTap: () => showAppSnack(context, s.soonHere),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
