import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'method_picker.dart';

/// Вкладка «Платежи»: кошелёк, быстрые действия, каталог получателей.
class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final wallet = ref.watch(walletProvider);
    final method = ref.watch(payMethodProvider);
    final autopay =
        ref.watch(billsProvider).value?.bills.where((b) => b.autopay).length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.paymentsTitle, style: context.t.displaySmall),
            const SizedBox(height: 18),
            _WalletCard(
              balance: wallet,
              onTopUp: () => _topUpSheet(context, ref),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.receipt_long_rounded,
                    cat: 'power',
                    title: s.newPayment,
                    lead: s.newPaymentLead,
                    onTap: () => context.push('/new-payment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.qr_code_scanner_rounded,
                    cat: 'kid',
                    title: s.qrPay,
                    lead: s.qrPayLead,
                    onTap: () => context.push('/qr'),
                  ),
                ),
              ],
            ),
            SectionTitle(s.sectionHistoryAuto),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('net', Icons.history_rounded, soft: true),
                    title: s.historyTitle,
                    subtitle: s.historyLead,
                    chevron: true,
                    onTap: () => context.push('/history'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('market', Icons.local_activity_outlined, soft: true),
                    title: s.marketTitle,
                    subtitle: s.marketLead,
                    chevron: true,
                    onTap: () => context.push('/market'),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('water', Icons.autorenew_rounded, soft: true),
                    title: s.autopayTitle,
                    subtitle: autopay == 0
                        ? s.autopayLead
                        : '${s.autopayOn} · ${s.billsCount(autopay)}',
                    chevron: true,
                    onTap: () => context.push('/autopay'),
                  ),
                ],
              ),
            ),
            SectionTitle(s.methodsTitle),
            AppCard(
              child: Column(
                children: [
                  for (final m in Demo.methods) ...[
                    if (m.id != Demo.methods.first.id) const RowDivider(indent: 16),
                    AppRow(
                      leading: MethodBadge(
                        item: m.isWallet
                            ? PayMethodItem(
                                id: m.id,
                                title: m.title,
                                subtitle: m.subtitle,
                                badge: m.badge,
                                isWallet: true,
                                balance: wallet)
                            : m,
                      ),
                      title: s.tr(m.title),
                      subtitle: m.isWallet
                          ? '${s.walletBalance} ${som(wallet)} ${s.som}'
                          : s.tr(m.subtitle),
                      trailing: method == m.id
                          ? const AppChip('Основной', tone: ChipTone.ok)
                          : null,
                      onTap: () {
                        ref.read(payMethodProvider.notifier).select(m.id);
                        showAppSnack(context, '${m.title} · ${s.payMethod}');
                      },
                    ),
                  ],
                  const RowDivider(indent: 16),
                  AppRow(
                    leading: CatTile('trash', Icons.add_rounded, soft: true, size: 44),
                    title: s.addCard,
                    subtitle: s.paymentsStub,
                    onTap: () => showAppSnack(context, s.paymentsStub),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
          ],
        ),
      ),
    );
  }

  void _topUpSheet(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => _TopUpSheet(title: s.topUpTitle),
    );
  }
}

class _TopUpSheet extends ConsumerStatefulWidget {
  const _TopUpSheet({required this.title});
  final String title;

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  final _ctrl = TextEditingController(text: '1000');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14, left: 2),
                child: Text(widget.title, style: context.t.headlineSmall),
              ),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.amountLabel, suffixText: s.som),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final v in [500, 1000, 2000, 5000])
                    ActionChip(
                      label: Text('$v'),
                      onPressed: () => setState(() => _ctrl.text = '$v'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(_ctrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
                  if (v == null || v <= 0) {
                    showAppSnack(context, s.amountError);
                    return;
                  }
                  ref.read(walletProvider.notifier).topUp(v);
                  Navigator.pop(context);
                  showAppSnack(context, '${s.topUpDone} · ${som(v)} ${s.som}');
                },
                child: Text(s.topUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance, required this.onTopUp});
  final double balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        color: context.c.heroBg,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        size: 16, color: Brand.primary),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(s.walletTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .7))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                      children: [
                        TextSpan(
                            text: som(balance),
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.6)),
                        TextSpan(
                            text: ' ${s.som}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .7))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTopUp,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Text(s.topUp),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.cat,
    required this.title,
    required this.lead,
    required this.onTap,
  });
  final IconData icon;
  final String cat, title, lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatTile(cat, icon, size: 40, radius: 11),
            const SizedBox(height: 10),
            Text(title, style: context.t.titleMedium),
            const SizedBox(height: 2),
            Text(lead,
                maxLines: 2,
                style: context.t.bodySmall?.copyWith(height: 1.3)),
          ],
        ),
      );
}
