import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Автоплатежи: какие счета ЭлPay оплачивает сам 25-го числа.
class AutopayPage extends ConsumerWidget {
  const AutopayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final state = ref.watch(billsProvider).value;
    final bills = state?.bills ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(s.autopayTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Tip(s.autopayLead),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < bills.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    AppRow(
                      leading: CatTile(bills[i].cat, catIcon(bills[i].cat), soft: true),
                      title: bills[i].title,
                      subtitle: '${som(bills[i].amount)} ${s.som} · ${bills[i].account}',
                      trailing: Switch(
                        value: bills[i].autopay,
                        onChanged: (v) {
                          ref.read(billsProvider.notifier).toggleAutopay(bills[i].id);
                          showAppSnack(context, v ? s.autopayOn : s.autopayOff);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
          ],
        ),
      ),
    );
  }
}
