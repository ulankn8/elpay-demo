import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../payments/checkout_sheet.dart';
import 'bill_row.dart';

/// Карточка счёта: за что платим, как начислено и полные реквизиты.
class BillDetailsPage extends ConsumerWidget {
  const BillDetailsPage({super.key, required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;
    final state = ref.watch(billsProvider).value;
    final b = state?.bills.firstWhere((x) => x.id == bill.id, orElse: () => bill) ?? bill;
    final due = dueLabel(context, b);
    final object = state?.objects.where((o) => o.id == b.objectId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(s.tr(b.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 28),
        children: [
          Row(
            children: [
              CatTile(b.cat, catIcon(b.cat)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.tr(b.subtitle), style: context.t.titleMedium),
                    if (b.account.isNotEmpty && b.account != '—')
                      Text('${s.account} ${b.account}', style: context.t.bodySmall),
                  ],
                ),
              ),
              AppChip(
                b.paid ? s.paidTitle : due.text,
                tone: b.paid
                    ? ChipTone.ok
                    : due.overdue
                        ? ChipTone.bad
                        : due.soon
                            ? ChipTone.warn
                            : ChipTone.soft,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Amount(som(b.amount), size: 34),
          const SizedBox(height: 16),
          KeyValueBox([
            (s.period, b.period),
            (s.dueDate, s.longDateText(b.due)),
            if (object != null) (s.object, s.tr(object.name)),
          ]),
          const SizedBox(height: 14),
          _AutopayRow(bill: b),
          SectionTitle(s.howCharged),
          KeyValueBox([for (final f in b.calc) (s.tr(f.label), s.tr(f.value))]),
          SectionTitle(s.requisites),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < b.requisites.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 16),
                  CopyRow(s.tr(b.requisites[i].label), s.tr(b.requisites[i].value),
                      copiedText: s.copied),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(s.requisitesHint, style: context.t.labelSmall?.copyWith(color: c.muted, height: 1.45)),
          const SizedBox(height: 22),
          if (!b.paid)
            FilledButton(
              onPressed: () => openCheckout(context, ref, [b]),
              child: Text('${s.pay} ${som(b.amount)} ${s.som}'),
            ),
        ],
      ),
    );
  }
}

class _AutopayRow extends ConsumerWidget {
  const _AutopayRow({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Brand.radiusRow)),
      child: Row(
        children: [
          Expanded(
            child: Text(S.of(context).autopayDay(bill.due.day),
                style: context.t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: bill.autopay,
            onChanged: (_) => ref.read(billsProvider.notifier).toggleAutopay(bill.id),
          ),
        ],
      ),
    );
  }
}
