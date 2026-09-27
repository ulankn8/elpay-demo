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
import '../bills/bill_row.dart';

Future<void> openCheckout(BuildContext context, WidgetRef ref, List<Bill> bills) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CheckoutSheet(bills: bills),
  );
}

/// Лист оплаты: выбор счетов, способ оплаты, итог.
/// Само списание — через [PaymentsRepository], сейчас это заглушка.
class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key, required this.bills});
  final List<Bill> bills;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  late Set<String> _selected = widget.bills.where((b) => !b.autopay).map((b) => b.id).toSet();
  bool _busy = false;

  List<Bill> get _chosen => widget.bills.where((b) => _selected.contains(b.id)).toList();
  double get _sum => _chosen.fold(0.0, (a, b) => a + b.amount);

  Future<void> _pay() async {
    final s = S.of(context);
    setState(() => _busy = true);
    final result = await ref.read(paymentsRepoProvider).pay(
          bills: _chosen,
          methodId: ref.read(payMethodProvider),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      ref.read(billsProvider.notifier).markPaid(_chosen.map((b) => b.id));
      final ids = _chosen.map((b) => b.id).toList();
      Navigator.of(context).pop();
      context.push('/success', extra: (_sum, ids.length, result.receiptNo ?? ''));
    } else {
      showAppSnack(context, result.reason ?? s.paymentsStub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final multi = widget.bills.length > 1;
    final method = ref.watch(payMethodProvider);
    final stub = ref.read(paymentsRepoProvider).isStub;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(multi ? s.checkoutTitle : s.checkoutOne,
                      style: context.t.headlineSmall),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 6, Brand.gutter, 8),
              children: [
                if (multi)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${s.selected} ${_selected.length} из ${widget.bills.length}',
                              style: context.t.labelSmall),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selected = _selected.length == widget.bills.length
                                ? <String>{}
                                : widget.bills.map((b) => b.id).toSet();
                          }),
                          child: Text(_selected.length == widget.bills.length
                              ? s.unselectAll
                              : s.selectAll),
                        ),
                      ],
                    ),
                  ),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.bills.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        _CheckoutRow(
                          bill: widget.bills[i],
                          selected: _selected.contains(widget.bills[i].id),
                          selectable: multi,
                          onToggle: () => setState(() {
                            final id = widget.bills[i].id;
                            _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!multi) ...[
                  SectionTitle(s.whatFor),
                  KeyValueBox([
                    for (final f in widget.bills.first.requisites.take(2)) (f.label, f.value),
                    (s.period, widget.bills.first.period),
                  ]),
                ],
                SectionTitle(s.payMethod),
                for (final m in Demo.methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MethodTile(
                      item: m,
                      selected: method == m.id,
                      onTap: () => ref.read(payMethodProvider.notifier).select(m.id),
                    ),
                  ),
                if (stub) ...[
                  const SizedBox(height: 10),
                  Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                Brand.gutter, 12, Brand.gutter, MediaQuery.of(context).padding.bottom + 12),
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
                    Amount(som(_sum), size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _selected.isEmpty || _busy ? null : _pay,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Brand.onPrimary))
                      : Text('${s.pay} ${som(_sum)} ${s.som}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({
    required this.bill,
    required this.selected,
    required this.selectable,
    required this.onToggle,
  });
  final Bill bill;
  final bool selected, selectable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final due = dueLabel(context, bill);
    return InkWell(
      onTap: selectable ? onToggle : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Opacity(
          opacity: selected || !selectable ? 1 : .45,
          child: Row(
            children: [
              if (selectable) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected ? Brand.primary : Colors.transparent,
                    border: Border.all(
                        color: selected ? Brand.primary : c.muted2, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 16, color: Brand.onPrimary)
                      : null,
                ),
                const SizedBox(width: 12),
              ],
              CatTile(bill.cat, catIcon(bill.cat), size: 36, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.titleMedium),
                    Text(due.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.t.bodySmall?.copyWith(
                            color: due.overdue ? c.chipBadFg : c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Amount(som(bill.amount), size: 16),
                  if (selectable)
                    Text(s.details,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.item, required this.selected, required this.onTap});
  final PayMethodItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(Brand.radiusRow),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Brand.light2.withValues(alpha: .6) : Colors.transparent,
          border: Border.all(color: selected ? Brand.primary : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(Brand.radiusRow),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: item.isWallet ? Brand.p700 : context.c.heroBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(item.badge,
                  style: const TextStyle(
                      fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.t.titleMedium),
                  Text(
                    item.isWallet
                        ? '${s.walletBalance} ${som(item.balance ?? 0)} ${s.som}'
                        : item.subtitle,
                    style: context.t.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? Brand.primary : c.muted2,
                    width: selected ? 7 : 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
