import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';
import '../payments/pay_flow.dart';
import '../payments/pay_sheet.dart';

/// Экран объекта: все его счета с галочками. У каждой услуги своя кнопка,
/// внизу — оплата всех выбранных одной суммой.
class ObjectPage extends ConsumerStatefulWidget {
  const ObjectPage({super.key, required this.objectId});
  final String objectId;

  @override
  ConsumerState<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends ConsumerState<ObjectPage> {
  Set<String>? _selected;

  Set<String> _initial(List<Bill> bills) =>
      bills.where((b) => !b.paid && !b.autopay).map((b) => b.id).toSet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final state = ref.watch(billsProvider).value;
    final object = state?.objects.where((o) => o.id == widget.objectId).firstOrNull;
    final bills = (state?.byObject(widget.objectId) ?? const <Bill>[])
        .where((b) => !b.paid)
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));

    final selected = _selected ??= _initial(bills);
    final chosen = bills.where((b) => selected.contains(b.id)).toList();
    final sum = chosen.fold<double>(0, (a, b) => a + b.amount);
    final total = bills.fold<double>(0, (a, b) => a + b.amount);
    final deadline = bills.isEmpty
        ? null
        : bills.map((b) => b.due).reduce((a, b) => a.isBefore(b) ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(object == null ? '' : s.tr(object.name))),
      body: SafeArea(
        top: false,
        child: bills.isEmpty
            ? EmptyState(icon: Icons.check_rounded, title: s.allPaid, lead: s.noBillsLead)
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
                      children: [
                        if (object != null)
                          AppCard(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CatTile(
                                      object.cat,
                                      object.icon == 'users'
                                          ? Icons.people_outline_rounded
                                          : Icons.home_outlined,
                                      size: 40,
                                      radius: 12,
                                      soft: true,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(object.address,
                                          maxLines: 2,
                                          style: context.t.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600, height: 1.35)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.toPayShort,
                                              style: context.t.labelSmall
                                                  ?.copyWith(color: c.muted)),
                                          const SizedBox(height: 2),
                                          Amount(som(total), size: 26),
                                        ],
                                      ),
                                    ),
                                    if (deadline != null)
                                      AppChip('${s.dueBy} ${s.dayMonthText(deadline)}',
                                          tone: ChipTone.warn),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                          child: Row(
                            children: [
                              _Check(
                                on: selected.length == bills.length,
                                onTap: () => setState(() {
                                  _selected = selected.length == bills.length
                                      ? <String>{}
                                      : bills.map((b) => b.id).toSet();
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selected.length == bills.length
                                      ? '${s.selectedAll} ${s.billsCount(bills.length)}'
                                      : s.selectedOf(selected.length, bills.length),
                                  style: context.t.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _selected = selected.isEmpty
                                      ? bills.map((b) => b.id).toSet()
                                      : <String>{};
                                }),
                                child: Text(selected.isEmpty ? s.selectAll : s.selectNone),
                              ),
                            ],
                          ),
                        ),
                        AppCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < bills.length; i++) ...[
                                if (i > 0) const RowDivider(indent: 16),
                                _ObjectBillRow(
                                  bill: bills[i],
                                  selected: selected.contains(bills[i].id),
                                  onToggle: () => setState(() {
                                    final id = bills[i].id;
                                    selected.contains(id)
                                        ? selected.remove(id)
                                        : selected.add(id);
                                    _selected = {...selected};
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            Expanded(child: Text(s.total, style: context.t.titleMedium)),
                            Amount(som(sum), size: 22),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: chosen.isEmpty
                              ? null
                              : () => openPaySheet(
                                    context,
                                    ref,
                                    amount: sum,
                                    bills: chosen,
                                    records: recordsFromBills(chosen),
                                  ),
                          child: Text('${s.payAllSum} · ${som(sum)} ${s.som}'),
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

/// Строка услуги: галочка, сумма справа, срок и своя кнопка «Оплатить».
class _ObjectBillRow extends StatelessWidget {
  const _ObjectBillRow({
    required this.bill,
    required this.selected,
    required this.onToggle,
  });
  final Bill bill;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final due = dueLabel(context, bill);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _Check(on: selected, onTap: onToggle),
          ),
          const SizedBox(width: 12),
          CatTile(bill.cat, catIcon(bill.cat), size: 42, radius: 12, soft: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(s.tr(bill.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.titleMedium),
                    ),
                    const SizedBox(width: 10),
                    Amount(som(bill.amount), size: 15),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${s.tr(bill.subtitle)} · ${bill.account}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: AppChip(
                        // в списке — короткая форма, подробности на карточке счёта
                        due.overdue ? s.overdue : due.text,
                        tone: due.overdue
                            ? ChipTone.bad
                            : due.soon
                                ? ChipTone.warn
                                : ChipTone.soft,
                      ),
                    ),
                    if (bill.autopay) ...[
                      const SizedBox(width: 6),
                      Flexible(child: AppChip(S.of(context).autopayTitle, tone: ChipTone.ok)),
                    ],
                    const SizedBox(width: 10),
                    _PayPill(onTap: () => context.push('/bill', extra: bill)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: on ? Brand.primary : Colors.transparent,
            border: Border.all(color: on ? Brand.primary : context.c.muted2, width: 1.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: on
              ? const Icon(Icons.check_rounded, size: 16, color: Brand.onPrimary)
              : null,
        ),
      );
}

class _PayPill extends StatelessWidget {
  const _PayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFF6FE0BB) : Brand.p700;
    return Material(
      color: dark ? Brand.primary.withValues(alpha: .16) : Brand.light2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Brand.primary.withValues(alpha: .32), width: 1),
          ),
          child: Text(s.pay,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}
