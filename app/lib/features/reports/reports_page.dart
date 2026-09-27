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

/// Отчёты: сколько ушло за месяц или год, на что и по каким объектам.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _year = false;
  late DateTime _anchor = DateTime.now();

  bool _inPeriod(Payment p, DateTime anchor) => _year
      ? p.date.year == anchor.year
      : p.date.year == anchor.year && p.date.month == anchor.month;

  void _shift(int delta) {
    setState(() {
      _anchor = _year
          ? DateTime(_anchor.year + delta, _anchor.month)
          : DateTime(_anchor.year, _anchor.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = ref.watch(historyProvider);
    final objects = ref.watch(billsProvider).value?.objects ?? const <PayObject>[];

    final list = all.where((p) => _inPeriod(p, _anchor)).toList();
    final prevAnchor =
        _year ? DateTime(_anchor.year - 1, _anchor.month) : DateTime(_anchor.year, _anchor.month - 1);
    final prev = all.where((p) => _inPeriod(p, prevAnchor)).toList();

    final total = list.fold<double>(0, (a, p) => a + p.amount);
    final prevTotal = prev.fold<double>(0, (a, p) => a + p.amount);
    final diff = prevTotal == 0 ? 0.0 : (total - prevTotal) / prevTotal * 100;

    final byCat = <String, double>{};
    for (final p in list) {
      byCat[p.cat] = (byCat[p.cat] ?? 0) + p.amount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final byObj = <String, double>{};
    for (final p in list) {
      byObj[p.objectId] = (byObj[p.objectId] ?? 0) + p.amount;
    }

    final title = _year ? '${_anchor.year}' : monthTitle(_anchor);
    final future = _year
        ? _anchor.year >= DateTime.now().year
        : !_anchor.isBefore(DateTime(DateTime.now().year, DateTime.now().month));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.reportsTitle, style: context.t.displaySmall),
            const SizedBox(height: 16),
            _Segmented(
              left: s.periodMonth,
              right: s.periodYear,
              rightSelected: _year,
              onChanged: (v) => setState(() {
                _year = v;
                _anchor = DateTime.now();
              }),
            ),
            const SizedBox(height: 16),
            _PeriodBar(
              title: title,
              onPrev: () => _shift(-1),
              onNext: future ? null : () => _shift(1),
            ),
            const SizedBox(height: 14),
            _TotalCard(
              total: total,
              count: list.length,
              diff: diff,
              hasPrev: prevTotal > 0 && total > 0,
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: AppCard(
                  child: EmptyState(
                      icon: Icons.bar_chart_rounded, title: s.noDataPeriod),
                ),
              )
            else ...[
              SectionTitle(s.byCategory),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  children: [
                    for (final e in cats)
                      _CatBar(
                        label: s.catName(e.key),
                        cat: e.key,
                        value: e.value,
                        share: total == 0 ? 0 : e.value / total,
                      ),
                  ],
                ),
              ),
              if (objects.isNotEmpty) ...[
                SectionTitle(s.byObject),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < objects.length; i++) ...[
                        if (i > 0) const RowDivider(),
                        AppRow(
                          leading: CatTile(objects[i].cat,
                              objects[i].icon == 'house'
                                  ? Icons.home_outlined
                                  : Icons.people_outline_rounded,
                              soft: true),
                          title: objects[i].name,
                          subtitle: objects[i].address,
                          trailing: Amount(som(byObj[objects[i].id] ?? 0), size: 15),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SectionTitle(s.historyTitle),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < list.take(5).length; i++) ...[
                      if (i > 0) const RowDivider(),
                      AppRow(
                        leading: CatTile(list[i].cat, catIcon(list[i].cat), soft: true),
                        title: list[i].title,
                        subtitle: '${dayMonth(list[i].date)} · ${list[i].account}',
                        trailing: Amount(som(list[i].amount), size: 15),
                        chevron: true,
                        onTap: () => context.push('/receipt', extra: list[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => showAppSnack(context, s.soonHere),
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(s.exportCsv),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });
  final String left, right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(String text, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: Brand.ink.withValues(alpha: .08),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Text(text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Theme.of(context).colorScheme.onSurface : c.muted,
                  )),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          item(left, !rightSelected, () => onChanged(false)),
          item(right, rightSelected, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.title, required this.onPrev, this.onNext});
  final String title;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(backgroundColor: context.c.soft),
          ),
          Expanded(
            child: Text(title, textAlign: TextAlign.center, style: context.t.titleLarge),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(backgroundColor: context.c.soft),
          ),
        ],
      );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.count,
    required this.diff,
    required this.hasPrev,
  });
  final double total, diff;
  final int count;
  final bool hasPrev;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final less = diff < 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: context.c.heroBg,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.spentTotal,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .65))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                children: [
                  TextSpan(
                      text: som(total),
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.8)),
                  TextSpan(
                      text: ' ${s.som}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .7))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(s.paymentsCount(count),
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: .65))),
              if (hasPrev && diff.abs() >= 1) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (less ? Brand.primary : Brand.warning).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${less ? '−' : '+'}${diff.abs().round()}% · ${less ? s.vsPrevLess : s.vsPrevMore}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: less ? const Color(0xFF6FE0BB) : Brand.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CatBar extends StatelessWidget {
  const _CatBar({
    required this.label,
    required this.cat,
    required this.value,
    required this.share,
  });
  final String label, cat;
  final double value, share;

  @override
  Widget build(BuildContext context) {
    final colors = Brand.category[cat] ?? Brand.category['city']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: context.t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text('${(share * 100).round()}%',
                  style: context.t.bodySmall?.copyWith(color: context.c.muted)),
              const SizedBox(width: 10),
              Amount(som(value), size: 14),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: context.c.soft2),
                FractionallySizedBox(
                  widthFactor: share.clamp(.02, 1),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
