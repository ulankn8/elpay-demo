import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/admin_store.dart';
import '../../data/models.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Начисления по месяцам: что загружено, сколько оплачено, корректировки.
class ChargesPage extends ConsumerStatefulWidget {
  const ChargesPage({super.key});
  @override
  ConsumerState<ChargesPage> createState() => _ChargesPageState();
}

class _ChargesPageState extends ConsumerState<ChargesPage> {
  Period? _sel;
  int _page = 0;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final periods = s.periods();
    final sel = periods.firstWhere((p) => p.period == (_sel ?? s.openPeriod), orElse: () => periods.first);
    final next = s.openPeriod.next;
    final q = _q.text.trim().toLowerCase();
    final rows = [
      for (final sub in s.subscribers.values)
        if (s.chargeOf(sub.account, sel.period) > 0 && (q.isEmpty || sub.account.contains(q) || sub.name.toLowerCase().contains(q))) sub,
    ]..sort((a, b) => a.account.compareTo(b.account));
    const per = 15;
    final shown = rows.skip(_page * per).take(per).toList();

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/svc/import?kind=charges'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: Text('Начисления за ${monthsNom[next.month - 1]}'),
        ),
        const SizedBox(height: 14),
        for (final p in periods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: p.period == sel.period ? Brand.light2 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.period == sel.period ? Brand.primary : Brand.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  _sel = p.period;
                  _page = 0;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(periodTitle(p.period.year, p.period.month), style: T.h3)),
                          p.open ? const Chip2('открыт', tone: Tone.ok) : const Chip2('закрыт'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Money(p.charged, size: 16, weight: FontWeight.w700),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(value: p.share, minHeight: 6, color: Brand.primary, backgroundColor: Brand.line2),
                      ),
                      const SizedBox(height: 5),
                      Text('оплачено ${pct(p.share)}${p.open ? ' · срок до ${p.period.due.day} ${monthsShort[p.period.due.month - 1]}' : ''}', style: T.tiny),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Kpi(
                label: 'Начислено',
                value: Money(sel.charged, size: 22, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Kpi(
                label: 'Абонентов с начислением',
                value: Text(nf(sel.count), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Kpi(
                label: 'Средний счёт',
                value: Money(sel.count == 0 ? 0 : (sel.charged / sel.count).roundToDouble(), size: 22, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Kpi(
                label: 'Оплачено',
                value: Money(sel.paid, size: 22, weight: FontWeight.w700),
                meter: sel.share,
                note: pct(sel.share),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Note(
          icon: Icons.upload_file_rounded,
          child: Text(
            sel.job == null
                ? 'Начисления этого месяца загружены до подключения кабинета.'
                : 'Загружено ${dt(sel.job!.at)} · ${sel.job!.fileName} · ${sel.job!.by}. Жители видят суммы в приложении с момента загрузки, с push «Пришло начисление».',
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Начисления за ${monthsNom[sel.period.month - 1]}', style: T.h2)),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _q,
                        decoration: const InputDecoration(hintText: 'Лицевой или ФИО', prefixIcon: Icon(Icons.search_rounded, size: 18)),
                        onChanged: (_) => setState(() => _page = 0),
                      ),
                    ),
                  ],
                ),
              ),
              Grid(
                cols: const [
                  Col('Лицевой', width: 110),
                  Col('ФИО', flex: 3),
                  Col('Как посчитано', flex: 3),
                  Col('Сумма', width: 120, right: true),
                  Col('', width: 180),
                ],
                rows: [
                  for (final sub in shown)
                    [
                      Text(sub.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                      Text(sub.name, style: T.td, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(sub.meter ? 'по счётчику' : '${sub.residents} чел × 41 сом', style: T.td.copyWith(color: Brand.muted)),
                      Money(s.chargeOf(sub.account, sel.period)),
                      if (sel.open)
                        TextButton.icon(
                          onPressed: () => _adjust(context, sub.account, sub.name, sel.period, s.chargeOf(sub.account, sel.period)),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Корректировка'),
                        )
                      else
                        const SizedBox(),
                    ],
                ],
              ),
              Pager(page: _page, total: rows.length, perPage: per, onPage: (p) => setState(() => _page = p)),
            ],
          ),
        ),
      ],
    );

    return PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 300, child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
      ],
    );
  }

  Future<void> _adjust(BuildContext context, String account, String name, Period p, double current) async {
    final amount = TextEditingController(text: current.toStringAsFixed(2).replaceAll('.', ','));
    final reason = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Корректировка: $account', style: T.h1),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$name. Сейчас за ${monthsNom[p.month - 1]} начислено ${som(current)} сом.', style: T.sub),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  decoration: InputDecoration(labelText: 'Новая сумма, сом', errorText: err),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Причина'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                final v = double.tryParse(amount.text.replaceAll(',', '.').replaceAll(' ', ''));
                if (v == null) return set(() => err = 'Нужна сумма числом');
                final r = await ref.read(actionsProvider).run((s) => s.adjustCharge(account, p, v, reason.text));
                if (r.isFail) return set(() => err = r.failureOrNull!.message);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Нужен экранам импорта для подписи периода.
extension PeriodSummaryX on PeriodSummary {
  String get title => periodTitle(period.year, period.month);
}
