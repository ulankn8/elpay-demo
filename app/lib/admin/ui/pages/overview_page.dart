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

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.admin;
    final d = s.dashboard();
    final now = s.now();
    final due = d.period.due;
    final daysLeft = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final pending = s.pendingExport();
    final pendingSum = pending.fold<double>(0, (a, p) => a + p.amount);
    final lastSub = s.imports().where((j) => j.kind == ImportKind.subscribers && j.status == ImportStatus.applied).firstOrNull;
    final lastCharge = s.imports().where((j) => j.kind == ImportKind.charges && j.status == ImportStatus.applied).firstOrNull;
    final lastCamp = s.campaigns().firstOrNull;
    final unpaid = s.segment(Segment.unpaid);
    final pushable = unpaid.where((v) => v.sub.inApp).length;

    final kpis = [
      Kpi(
        label: 'Начислено за ${monthsNom[d.period.month - 1]}',
        value: Money(d.charged, size: 26, weight: FontWeight.w700),
        note:
            '${nf(d.subscribers)} ${plural(d.subscribers, 'абонент', 'абонента', 'абонентов')}${lastCharge != null ? ' · загружено ${dayMonth(lastCharge.at)}' : ''}',
        onTap: () => context.go('/svc/charges'),
      ),
      Kpi(
        label: 'Оплачено на сегодня',
        value: Money(d.paid, size: 26, weight: FontWeight.w700),
        meter: d.charged == 0 ? 0 : d.paid / d.charged,
        note:
            '${pct(d.charged == 0 ? 0 : d.paid / d.charged)} · ${daysLeft >= 0 ? 'до срока ${nf(daysLeft)} ${plural(daysLeft, 'день', 'дня', 'дней')}' : 'срок прошёл'}',
        noteColor: Brand.p700,
        onTap: () => context.go('/svc/payments'),
      ),
      Kpi(
        label: 'Не оплатили ${monthsNom[d.period.month - 1]}',
        value: Text(nf(d.unpaid), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
        note: 'ещё ${nf(d.partial)} оплатили частично',
        onTap: () => context.go('/svc/subscribers?f=unpaid'),
      ),
      Kpi(
        label: 'Подключили счёт в ЭлPay',
        value: Text(nf(d.inApp), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8)),
        meter: d.subscribers == 0 ? 0 : d.inApp / d.subscribers,
        meterColor: Brand.info,
        note: '${pct(d.subscribers == 0 ? 0 : d.inApp / d.subscribers)} абонентов · видят начисления в телефоне',
        onTap: () => context.go('/svc/subscribers?f=inApp'),
      ),
    ];

    final attention = <Widget>[
      if (lastSub != null && lastSub.errors > 0)
        Note(
          tone: Tone.warn,
          action: LinkAction('Загрузить исправленный файл', onTap: () => context.go('/svc/import')),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${nf(lastSub.errors)} ${plural(lastSub.errors, 'строка не загрузилась', 'строки не загрузились', 'строк не загрузились')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' в импорте ${dayMonth(lastSub.at)}: адрес не найден, дубль лицевого, пустое ФИО.'),
              ],
            ),
          ),
        ),
      if (pending.isNotEmpty)
        Note(
          icon: Icons.download_rounded,
          action: LinkAction('Выгрузить реестр', onTap: () => context.go('/svc/payments?export=1')),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${nf(pending.length)} ${plural(pending.length, 'платёж', 'платежа', 'платежей')} не выгружены в 1С',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' — на ${som(pendingSum)} сом.'),
              ],
            ),
          ),
        ),
      if (unpaid.isNotEmpty && daysLeft >= 0)
        Note(
          icon: Icons.notifications_none_rounded,
          action: LinkAction('Напомнить', onTap: () => context.go('/svc/notify?s=unpaid')),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'До срока ${nf(daysLeft)} ${plural(daysLeft, 'день', 'дня', 'дней')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ', не оплатили ${nf(unpaid.length)}. Push бесплатно дойдёт до ${nf(pushable)}.'),
              ],
            ),
          ),
        ),
      if (d.debtors > 0)
        Note(
          tone: Tone.bad,
          icon: Icons.account_balance_wallet_outlined,
          action: LinkAction('Список должников', onTap: () => context.go('/svc/subscribers?f=debt')),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Долг прошлых периодов',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' — ${som(d.debt)} сом у ${nf(d.debtors)} ${plural(d.debtors, 'абонента', 'абонентов', 'абонентов')}.'),
              ],
            ),
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 4 : 2;
        return PageBody(
          children: [
            _GridOf(cols: cols, children: kpis),
            const SizedBox(height: 16),
            Flex(
              direction: c.maxWidth > 1100 ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Wrap(
                  horizontal: c.maxWidth > 1100,
                  flex: 2,
                  child: Panel(
                    child: _Chart(d: d, now: now),
                  ),
                ),
                const SizedBox(width: 16, height: 16),
                _Wrap(
                  horizontal: c.maxWidth > 1100,
                  flex: 1,
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PanelHead('Требует внимания', trailing: attention.isEmpty ? null : Chip2('${attention.length}', tone: Tone.bad)),
                        if (attention.isEmpty)
                          const Note(tone: Tone.ok, icon: Icons.check_circle_outline, child: Text('Всё в порядке: ошибок импорта нет, реестр выгружен.')),
                        for (final a in attention) Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GridOf(
              cols: cols > 2 ? 3 : 1,
              children: [
                _MiniCard(
                  icon: Icons.upload_rounded,
                  title: 'Последний импорт абонентов',
                  sub: lastSub == null ? 'ещё не было' : '${lastSub.fileName} · ${dt(lastSub.at)} · ${lastSub.by}',
                  chips: lastSub == null
                      ? const []
                      : [
                          Chip2('+${nf(lastSub.created)} новых', tone: Tone.ok),
                          Chip2('${nf(lastSub.updated)} обновлено', tone: Tone.info),
                          Chip2('${nf(lastSub.unchanged)} без изменений'),
                          if (lastSub.errors > 0) Chip2('${nf(lastSub.errors)} с ошибкой', tone: Tone.bad),
                        ],
                  onTap: () => context.go('/svc/import/journal'),
                ),
                _MiniCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Начисления за ${monthsNom[d.period.month - 1]}',
                  sub: lastCharge == null ? 'не загружены' : '${lastCharge.fileName} · ${dt(lastCharge.at)} · ${lastCharge.by}',
                  chips: [
                    if (lastCharge != null) Chip2('${nf(lastCharge.created)} строк', tone: Tone.ok, icon: Icons.check_rounded),
                    Chip2('срок до ${due.day} ${monthsShort[due.month - 1]}'),
                  ],
                  onTap: () => context.go('/svc/charges'),
                ),
                _MiniCard(
                  icon: Icons.send_rounded,
                  title: 'Последняя рассылка',
                  sub: lastCamp == null ? 'ещё не было' : '${dt(lastCamp.sendAt)} · «${lastCamp.template}» · ${nf(lastCamp.recipients)} получателей',
                  chips: [
                    if (lastCamp?.paidAfter != null)
                      Chip2('после неё оплатили ${nf(lastCamp!.paidAfter!)} · ${pct(lastCamp.paidAfter! / lastCamp.recipients)}', tone: Tone.ok),
                    if (lastCamp != null && lastCamp.paidAfter == null) const Chip2('результат через 3 дня', tone: Tone.info),
                  ],
                  onTap: () => context.go('/svc/notify'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.horizontal, required this.flex, required this.child});
  final bool horizontal;
  final int flex;
  final Widget child;
  @override
  Widget build(BuildContext context) => horizontal ? Expanded(flex: flex, child: child) : child;
}

class _GridOf extends StatelessWidget {
  const _GridOf({required this.cols, required this.children});
  final int cols;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final part = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[if (j > 0) const SizedBox(width: 16), Expanded(child: j < part.length ? part[j] : const SizedBox())],
            ],
          ),
        ),
      );
      if (i + cols < children.length) rows.add(const SizedBox(height: 16));
    }
    return Column(children: rows);
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, required this.sub, required this.chips, this.onTap});
  final IconData icon;
  final String title, sub;
  final List<Widget> chips;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftIcon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: T.h3),
                      const SizedBox(height: 2),
                      Text(sub, style: T.sub),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      ),
    ),
  );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.d, required this.now});
  final Dashboard d;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final byDay = d.byDay;
    final days = byDay.keys.toList()..sort();
    final maxV = byDay.values.fold<double>(1, (m, v) => v > m ? v : m);
    final today = DateTime(now.year, now.month, now.day);
    final todaySum = byDay[today] ?? 0;
    final ch = d.byChannel;
    final paid = d.paid;
    String share(double v) => paid == 0 ? '' : ' · ${pct(v / paid)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelHead('Поступления по дням'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Money(todaySum, size: 22, weight: FontWeight.w700),
            const SizedBox(width: 10),
            Flexible(child: Text('сегодня, ${now.day} ${monthsGen[now.month - 1]}', style: T.sub)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Tooltip(
                    message: '${day.day} ${monthsShort[day.month - 1]}: ${som(byDay[day]!)} сом',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: (byDay[day]! / maxV).clamp(.03, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: day == today ? const [Color(0xFF7BDDB9), Brand.primary] : const [Color(0xFF3FCB9A), Brand.primary],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                                  border: day == today ? Border.all(color: Brand.p700, width: 1.5) : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.day}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Brand.muted2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Legend(color: Brand.primary, text: 'ЭлPay — ${som(ch[Channel.elpay]!)} сом${share(ch[Channel.elpay]!)}'),
            _Legend(color: Brand.ink3, text: 'Касса службы — ${som(ch[Channel.cashier]!)} сом'),
            _Legend(color: Brand.warning, text: 'Банки и терминалы — ${som(ch[Channel.bank]!)} сом'),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        const Text('Кто подключил счёт в приложении, платит чаще', style: T.h3),
        const SizedBox(height: 12),
        _Rate(label: 'Подключены в ЭлPay', value: d.inAppPaidRate, color: Brand.primary),
        const SizedBox(height: 8),
        _Rate(label: 'Остальные абоненты', value: d.otherPaidRate, color: Brand.muted2),
        const SizedBox(height: 10),
        Text(
          'Доля оплативших ${monthsNom[d.period.month - 1]} хотя бы частично. Каждый новый подключённый — это напоминание о сроке в телефоне и оплата в два касания.',
          style: T.sub,
        ),
      ],
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 170,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Brand.ink3),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: value, minHeight: 10, color: color, backgroundColor: Brand.line2),
        ),
      ),
      SizedBox(
        width: 64,
        child: Text(
          pct(value),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Brand.ink3),
      ),
    ],
  );
}
