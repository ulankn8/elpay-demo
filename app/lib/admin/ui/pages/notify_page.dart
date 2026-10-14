import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/models.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

const _templates = {
  'Напоминание о сроке': '{имя}, за воду за {месяц} {сумма}. Оплатите до {срок} — без пени.',
  'Долг за 2 месяца': '{имя}, по лицевому {лицевой} долг {сумма}. Оплатите, чтобы не начислялась пеня.',
  'Пеня с 26-го': '{имя}, с 26-го начнётся пеня 0,1% в день. К оплате {сумма} — оплатите до {срок}.',
};

enum _When { now, tomorrow, auto }

class NotifyPage extends ConsumerStatefulWidget {
  const NotifyPage({super.key, this.segment});
  final String? segment;
  @override
  ConsumerState<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends ConsumerState<NotifyPage> {
  late Segment _seg = Segment.values.where((s) => s.name == widget.segment).firstOrNull ?? Segment.unpaid;
  bool _sms = false;
  String _tpl = _templates.keys.first;
  late final _text = TextEditingController(text: _templates[_tpl]);
  _When _when = _When.tomorrow;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _render(String t, {required String name, required String sum, required String account}) {
    final s = ref.read(adminStoreProvider);
    final p = s.openPeriod;
    return t
        .replaceAll('{имя}', name.split(' ').length > 1 ? name.split(' ')[1] : name)
        .replaceAll('{сумма}', '$sum сом')
        .replaceAll('{срок}', '${p.due.day} ${monthsGen[p.due.month - 1]}')
        .replaceAll('{месяц}', monthsNom[p.month - 1])
        .replaceAll('{лицевой}', account);
  }

  DateTime _sendAt() {
    final now = ref.read(adminStoreProvider).now();
    return switch (_when) {
      _When.now => now,
      _When.tomorrow => DateTime(now.year, now.month, now.day + 1, 10),
      _When.auto => ref.read(adminStoreProvider).openPeriod.due.subtract(const Duration(days: 3)).add(const Duration(hours: 10)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final recent = s.recentlyNotified();
    final seg = s.segment(_seg);
    final reach = [
      for (final v in seg)
        if (!recent.contains(v.sub.account)) v,
    ];
    final push = reach.where((v) => v.sub.inApp).length;
    final smsable = reach.where((v) => !v.sub.inApp && v.sub.phone.isNotEmpty).length;
    final noContact = reach.length - push - smsable;
    final cost = smsable * Campaign.smsPrice;
    final sample = s.view('31-00562')!;
    final previewText = _render(_text.text, name: sample.sub.name, sum: som(sample.leftToPay + sample.debt), account: sample.sub.account);
    final campaigns = s.campaigns();

    Widget segCard(Segment g, String label) {
      final n = s.segment(g).length;
      final on = _seg == g;
      return Expanded(
        child: Material(
          color: on ? Brand.light2 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: on ? Brand.primary : Brand.line, width: on ? 1.6 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _seg = g),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(nf(n), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
                      Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: on ? Brand.primary : Brand.muted2),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: T.sub),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final form = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHead(
            'Новая рассылка',
            trailing: Chip2('${monthsNom[s.openPeriod.month - 1]} · срок ${s.openPeriod.due.day} ${monthsShort[s.openPeriod.due.month - 1]}'),
          ),
          const Text('1 · Кому', style: T.h3),
          const SizedBox(height: 8),
          Row(
            children: [
              segCard(Segment.unpaid, 'Не оплатили ${monthsNom[s.openPeriod.month - 1]}'),
              const SizedBox(width: 10),
              segCard(Segment.debt, 'С долгом за прошлые месяцы'),
              const SizedBox(width: 10),
              segCard(Segment.partial, 'Оплатили частично'),
            ],
          ),
          if (seg.length != reach.length) ...[
            const SizedBox(height: 8),
            Note(
              tone: Tone.soft,
              icon: Icons.do_not_disturb_on_outlined,
              child: Text('${nf(seg.length - reach.length)} получили напоминание меньше трёх дней назад — их пропустим, чтобы не надоедать.'),
            ),
          ],
          const SizedBox(height: 18),
          const Text('2 · Как доставить', style: T.h3),
          const SizedBox(height: 8),
          _Channel(
            icon: Icons.notifications_active_outlined,
            title: 'Push в приложении ЭлPay — ${nf(push)} получат бесплатно',
            sub: 'у них подключён счёт службы; кнопка «Оплатить» откроет начисление',
            value: true,
            locked: true,
          ),
          const SizedBox(height: 8),
          _Channel(
            icon: Icons.sms_outlined,
            title: 'SMS остальным — ${nf(smsable)}',
            sub: '${nf(smsable)} × 1,2 сом = ${som(cost)} сом · спишется с баланса службы${noContact > 0 ? ' · у ${nf(noContact)} нет телефона' : ''}',
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              const Text('3 · Текст', style: T.h3),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _templates.keys)
                    FilterPill(
                      label: t,
                      selected: _tpl == t,
                      onTap: () => setState(() {
                        _tpl = t;
                        _text.text = _templates[t]!;
                      }),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _text, maxLines: 3, onChanged: (_) => setState(() {})),
          const SizedBox(height: 6),
          const Text('Подставится своё у каждого: {имя} {сумма} {срок} {месяц} {лицевой}', style: T.tiny),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              const Text('4 · Когда', style: T.h3),
              Seg<_When>(
                items: const [(_When.now, 'Сейчас'), (_When.tomorrow, 'Завтра в 10:00'), (_When.auto, 'За 3 дня до срока')],
                value: _when,
                onChanged: (v) => setState(() => _when = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Уйдёт ${nf(push)} push${_sms ? ' и ${nf(smsable)} SMS' : ''}', style: T.h3),
                    Text(_sms ? 'стоимость ${som(cost)} сом' : 'бесплатно · ${nf(smsable)} без приложения в этот раз не получат', style: T.sub),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: reach.isEmpty
                    ? null
                    : () async {
                        final at = _sendAt();
                        final c = await ref
                            .read(actionsProvider)
                            .run((st) => st.scheduleCampaign(segment: _seg, template: _tpl, text: _text.text, sms: _sms, sendAt: at));
                        if (context.mounted) toast(context, 'Рассылка «${c.template}» запланирована на ${dt(at)}: ${nf(c.recipients)} получателей');
                      },
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(_when == _When.now ? 'Отправить сейчас' : 'Запланировать на ${dt(_sendAt())}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );

    final phone = Column(
      children: [
        Row(
          children: [
            const Icon(Icons.visibility_outlined, size: 16, color: Brand.muted),
            const SizedBox(width: 6),
            Expanded(child: Text('Так увидит ${sample.sub.name}, ${sample.sub.account}', style: T.sub)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 270,
          height: 520,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(36)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 44, 12, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3E6C88), Color(0xFF25455E), Color(0xFF162B3D)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  hhmm(_sendAt()),
                  style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w600),
                ),
                Text(
                  longDate(_sendAt()),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .88), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(5)),
                            child: const Text(
                              'Эл',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Brand.onPrimary),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'ЭлPay',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF53605B)),
                          ),
                          const Spacer(),
                          const Text('сейчас', style: TextStyle(fontSize: 10.5, color: Color(0xFF53605B))),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.demoOrg.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(previewText, style: const TextStyle(fontSize: 11.5, color: Color(0xFF222222), height: 1.4)),
                      const SizedBox(height: 8),
                      const Text(
                        'Оплатить в ЭлPay →',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.p700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 290,
          child: Note(
            icon: Icons.shield_outlined,
            child: Text('Не чаще 1 раза в 3 дня одному абоненту. ${campaigns.isEmpty ? '' : 'Последняя рассылка — ${dt(campaigns.first.sendAt)}.'}'),
          ),
        ),
      ],
    );

    return PageBody(
      children: [
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 20),
                    SizedBox(width: 290, child: phone),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    form,
                    const SizedBox(height: 16),
                    Center(child: SizedBox(width: 290, child: phone)),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: PanelHead('Рассылки')),
              Grid(
                cols: const [
                  Col('Когда', width: 130),
                  Col('Шаблон', flex: 3),
                  Col('Кому', flex: 3),
                  Col('Получили', width: 140, right: true),
                  Col('Оплатили после неё', flex: 3),
                ],
                rows: [
                  for (final c in campaigns)
                    [
                      Text(dt(c.sendAt), style: T.td.copyWith(fontWeight: FontWeight.w700)),
                      Text(c.template, style: T.td),
                      Text(
                        c.accounts.isNotEmpty
                            ? 'Выбранные в таблице'
                            : switch (c.segment) {
                                Segment.unpaid => 'Не оплатили',
                                Segment.debt => 'С долгом',
                                Segment.partial => 'Частично',
                              },
                        style: T.td.copyWith(color: Brand.muted),
                      ),
                      Text('${nf(c.push)} push${c.sms > 0 ? ' · ${nf(c.sms)} SMS' : ''}', style: T.num),
                      c.paidAfter != null
                          ? Chip2('${nf(c.paidAfter!)} · ${pct(c.paidAfter! / c.recipients)}', tone: Tone.ok)
                          : (c.sendAt.isAfter(s.now()) ? const Chip2('запланирована', tone: Tone.info) : const Chip2('результат через 3 дня')),
                    ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Channel extends StatelessWidget {
  const _Channel({required this.icon, required this.title, required this.sub, required this.value, this.onChanged, this.locked = false});
  final IconData icon;
  final String title, sub;
  final bool value, locked;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Brand.line),
    ),
    child: Row(
      children: [
        SoftIcon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.h3),
              Text(sub, style: T.sub),
            ],
          ),
        ),
        locked ? const Chip2('всегда', tone: Tone.ok, icon: Icons.check_rounded) : Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}
