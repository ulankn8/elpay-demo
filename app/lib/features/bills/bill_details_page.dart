import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../payments/pay_flow.dart';
import '../payments/pay_sheet.dart';
import 'bill_row.dart';

/// Разбор счёта: за что платим, как начислено и полные реквизиты.
/// Оплата — только кнопкой внизу, способ спрашиваем следующим шагом.
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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      children: [
                        CatTile(b.cat, catIcon(b.cat), size: 56, radius: 16),
                        const SizedBox(height: 10),
                        Text(s.tr(b.title),
                            textAlign: TextAlign.center, style: context.t.titleLarge),
                        const SizedBox(height: 3),
                        Text('${s.tr(b.subtitle)} · ${b.period}',
                            textAlign: TextAlign.center, style: context.t.bodySmall),
                        const SizedBox(height: 12),
                        Amount(som(b.amount), size: 30),
                        const SizedBox(height: 10),
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
                  ),
                  SectionTitle(s.whatForTitle),
                  KeyValueBox([
                    if (object != null && object.address.isNotEmpty)
                      (s.address, object.address),
                    if (b.account.isNotEmpty) (s.tr('Лицевой счёт'), b.account),
                    (s.payBy, s.longDateText(b.due)),
                    if (object != null) (s.object, s.tr(object.name)),
                  ]),
                  if (b.calc.isNotEmpty) ...[
                    SectionTitle(s.howCharged),
                    KeyValueBox([for (final f in b.calc) (s.tr(f.label), s.tr(f.value))]),
                  ],
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
                  Text(s.requisitesHint,
                      style: context.t.labelSmall?.copyWith(color: c.muted, height: 1.45)),
                  const SizedBox(height: 16),
                  _AutopayRow(bill: b),
                ],
              ),
            ),
            if (!b.paid)
              Container(
                padding: EdgeInsets.fromLTRB(Brand.gutter, 12, Brand.gutter,
                    MediaQuery.of(context).padding.bottom + 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: c.line2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.toPayShort, style: context.t.titleMedium)),
                        Amount(som(b.amount), size: 22),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => openPaySheet(
                        context,
                        ref,
                        amount: b.amount,
                        bills: [b],
                        records: recordsFromBills([b]),
                      ),
                      child: Text('${s.pay} ${som(b.amount)} ${s.som}'),
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

class _AutopayRow extends ConsumerWidget {
  const _AutopayRow({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      decoration:
          BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Brand.radiusRow)),
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
