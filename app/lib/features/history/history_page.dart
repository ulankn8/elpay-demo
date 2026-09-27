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

/// История платежей: поиск, фильтр по категории, группировка по месяцам.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _search = TextEditingController();
  String _cat = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = ref.watch(historyProvider);
    final q = _search.text.trim().toLowerCase();
    final list = all.where((p) {
      if (_cat != 'all' && p.cat != _cat) return false;
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          p.account.toLowerCase().contains(q) ||
          p.receiptNo.toLowerCase().contains(q);
    }).toList();

    final cats = <String>{for (final p in all) p.cat}.toList();
    final groups = <String, List<Payment>>{};
    for (final p in list) {
      groups.putIfAbsent(s.monthTitleText(p.date), () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.historyTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
                children: [
                  _FilterChip(
                    label: s.filterAll,
                    selected: _cat == 'all',
                    onTap: () => setState(() => _cat = 'all'),
                  ),
                  for (final c in cats)
                    _FilterChip(
                      label: s.catName(c),
                      selected: _cat == c,
                      onTap: () => setState(() => _cat = c),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: q.isEmpty ? s.historyEmpty : s.nothingFound,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.key, style: context.t.titleLarge)),
                                Amount(
                                  som(entry.value.fold<double>(0, (a, p) => a + p.amount)),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                          AppCard(
                            child: Column(
                              children: [
                                for (var i = 0; i < entry.value.length; i++) ...[
                                  if (i > 0) const RowDivider(),
                                  _PaymentRow(payment: entry.value[i]),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
        ),
      );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) => AppRow(
        leading: CatTile(payment.cat, catIcon(payment.cat), soft: true),
        title: S.of(context).tr(payment.title),
        subtitle: '${S.of(context).dayMonthText(payment.date)}, ${hhmm(payment.date)} · ${payment.account}',
        trailing: Amount(som(payment.amount), size: 15),
        chevron: true,
        onTap: () => context.push('/receipt', extra: payment),
      );
}
