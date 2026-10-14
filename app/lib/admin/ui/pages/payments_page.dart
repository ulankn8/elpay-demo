import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/csv.dart';
import '../../data/models.dart';
import '../../data/registry.dart';
import '../../data/text_codec.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

enum _Exp { all, pending, done }

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key, this.openExport = false});
  final bool openExport;
  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  Channel? _ch;
  _Exp _exp = _Exp.all;
  int _page = 0;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.openExport) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _openExport() : null);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _set({required Channel? ch, _Exp? exp}) => setState(() {
    _ch = ch;
    if (exp != null) _exp = exp;
    _page = 0;
  });

  Future<void> _openExport() => showSideSheet<void>(context, width: 640, builder: (_) => const _ExportSheet());

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final d = s.dashboard();
    final until = s.exportedUntil;
    final pending = s.pendingExport();
    final pendingSum = pending.fold<double>(0, (a, p) => a + p.amount);
    final q = _q.text.trim().toLowerCase();
    final subs = s.subscribers;
    final list = [
      for (final p in s.payments)
        if ((_ch == null || p.channel == _ch) &&
            (_exp == _Exp.all || (_exp == _Exp.pending) == !p.at.isBefore(until)) &&
            (q.isEmpty || p.account.contains(q) || p.receipt.toLowerCase().contains(q) || (subs[p.account]?.name.toLowerCase().contains(q) ?? false)))
          p,
    ];
    const per = 20;
    final shown = list.skip(_page * per).take(per).toList();

    Widget kpi(String l, double v, {String? note}) => Expanded(
      child: Kpi(
        label: l,
        value: Money(v, size: 22, weight: FontWeight.w700),
        note: note,
      ),
    );

    return PageBody(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kpi('Оплачено за ${monthsNom[d.period.month - 1]}', d.paid, note: '${nf(s.payments.where((p) => p.period == d.period).length)} платежей'),
              const SizedBox(width: 12),
              kpi('Через ЭлPay', d.byChannel[Channel.elpay]!, note: d.paid == 0 ? null : pct(d.byChannel[Channel.elpay]! / d.paid)),
              const SizedBox(width: 12),
              kpi('Касса службы', d.byChannel[Channel.cashier]!),
              const SizedBox(width: 12),
              kpi('Банки и терминалы', d.byChannel[Channel.bank]!),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          color: pending.isEmpty ? Colors.white : const Color(0xFFF2F7FE),
          child: Row(
            children: [
              SoftIcon(pending.isEmpty ? Icons.cloud_done_outlined : Icons.download_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending.isEmpty
                          ? 'Все платежи выгружены в 1С'
                          : 'Не выгружено в 1С: ${nf(pending.length)} ${plural(pending.length, 'платёж', 'платежа', 'платежей')} на ${som(pendingSum)} сом',
                      style: T.h3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Последняя выгрузка — ${dt(until)}${s.autoExport ? ' · автовыгрузка каждый день в 18:00 на buh@oshvodokanal.kg' : ' · автовыгрузка выключена'}',
                      style: T.sub,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(onPressed: _openExport, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Выгрузить реестр в 1С')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterPill(label: 'Все каналы', selected: _ch == null, onTap: () => _set(ch: null)),
                          for (final c in Channel.values)
                            FilterPill(
                              label: channelLabel(c),
                              count: s.payments.where((p) => p.channel == c).length,
                              selected: _ch == c,
                              onTap: () => _set(ch: c),
                            ),
                          const SizedBox(width: 10),
                          Seg<_Exp>(
                            items: const [(_Exp.all, 'Все'), (_Exp.pending, 'Ждут выгрузки'), (_Exp.done, 'Выгружены в 1С')],
                            value: _exp,
                            onChanged: (v) => _set(ch: _ch, exp: v),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _q,
                        decoration: const InputDecoration(hintText: 'Лицевой, ФИО или № квитанции', prefixIcon: Icon(Icons.search_rounded, size: 18)),
                        onChanged: (_) => setState(() => _page = 0),
                      ),
                    ),
                  ],
                ),
              ),
              Grid(
                cols: const [
                  Col('Когда', width: 120),
                  Col('Лицевой', width: 104),
                  Col('ФИО', flex: 3),
                  Col('Сумма', width: 110, right: true),
                  Col('За период', width: 110),
                  Col('Канал и способ', flex: 3),
                  Col('Квитанция', width: 150),
                  Col('В 1С', width: 130),
                ],
                rows: [
                  for (final p in shown)
                    [
                      Text(dt(p.at), style: T.td),
                      Text(p.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                      Text(subs[p.account]?.name ?? '—', style: T.td, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Money(p.amount),
                      Text(monthsNom[p.period.month - 1], style: T.td.copyWith(color: Brand.muted)),
                      Text('${channelLabel(p.channel)} · ${p.method}', style: T.td, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(p.receipt, style: T.num.copyWith(color: Brand.muted, fontSize: 12)),
                      p.at.isBefore(until) ? const Chip2('Выгружен', tone: Tone.ok, icon: Icons.check_rounded) : const Chip2('Ждёт выгрузки', tone: Tone.info),
                    ],
                ],
              ),
              Pager(page: _page, total: list.length, perPage: per, onPage: (p) => setState(() => _page = p)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Note(
          icon: Icons.shield_outlined,
          child: Text(
            '${nf(s.unmatched().where((u) => u.orgId == s.demoOrg.id && u.state == UnmatchedState.open).length)} платежа не удалось сопоставить с лицевым — их разбирает ЭлPay, деньги не потеряются. После привязки они появятся здесь и в реестре.',
          ),
        ),
      ],
    );
  }
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();
  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  RegistryFormat _format = RegistryFormat.csv1c;

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final pending = s.pendingExport();
    final sum = pending.fold<double>(0, (a, p) => a + p.amount);
    final preview = registryRows(pending.take(3).toList());
    final text = toCsv(registryRows(pending));
    final odd = nonCp1251Chars(text);
    final history = s.exports().take(6).toList();

    return SheetFrame(
      title: 'Выгрузка реестра в 1С',
      sub: 'Платежи с ${dt(s.exportedUntil)} по сейчас',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
        FilledButton.icon(
          onPressed: pending.isEmpty
              ? null
              : () async {
                  final (b, file) = await ref.read(actionsProvider).run((st) => st.exportRegistry(_format));
                  ref.read(fileGatewayProvider).download(file.name, file.bytes, file.mime);
                  if (context.mounted) {
                    toast(context, 'Реестр ${file.name}: ${nf(b.count)} платежей на ${som(b.total)} сом');
                    if (file.warning.isNotEmpty) toast(context, file.warning);
                  }
                },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(pending.isEmpty ? 'Нечего выгружать' : 'Скачать реестр · ${nf(pending.length)}'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            color: Brand.soft2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${nf(pending.length)} ${plural(pending.length, 'платёж', 'платежа', 'платежей')}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      Money(sum, size: 15),
                    ],
                  ),
                ),
                Text(
                  'reestr_${s.now().year}-${s.now().month.toString().padLeft(2, '0')}-${s.now().day.toString().padLeft(2, '0')}.${_format == RegistryFormat.xlsx ? 'xlsx' : 'csv'}',
                  style: T.sub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Формат', style: T.h3),
          const SizedBox(height: 8),
          Seg<RegistryFormat>(
            items: const [(RegistryFormat.csv1c, 'CSV для 1С — как вы загружаете'), (RegistryFormat.xlsx, 'Excel')],
            value: _format,
            onChanged: (v) => setState(() => _format = v),
          ),
          const SizedBox(height: 14),
          Text(
            'Колонки в порядке, который ждёт загрузка 1С${_format == RegistryFormat.csv1c ? ' · разделитель «;» · ${odd.isEmpty ? 'Windows-1251' : 'UTF-8'}' : ''}',
            style: T.sub,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: K.side, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(
              [for (final r in preview) r.join(';')].join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFD7EEE6), height: 1.6),
            ),
          ),
          if (odd.isNotEmpty && _format == RegistryFormat.csv1c) ...[
            const SizedBox(height: 10),
            Note(
              tone: Tone.warn,
              child: Text('В реестре есть буквы ${odd.join(' ')} — в Windows-1251 их нет. Файл будет в UTF-8: при загрузке в 1С выберите эту кодировку.'),
            ),
          ],
          const SizedBox(height: 20),
          Panel(
            child: Row(
              children: [
                const SoftIcon(Icons.schedule_send_outlined),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Выгружать автоматически', style: T.h3),
                      Text('Каждый день в 18:00 — реестр на buh@oshvodokanal.kg', style: T.sub),
                    ],
                  ),
                ),
                Switch(value: s.autoExport, onChanged: (v) => ref.read(actionsProvider).run((st) => st.setAutoExport(v))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Последние выгрузки', style: T.h3),
          const SizedBox(height: 8),
          for (final b in history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(dt(b.at), style: T.td)),
                  Expanded(child: Text('${nf(b.count)} платежей · ${som(b.total)} сом', style: T.td)),
                  Chip2(b.auto ? 'авто' : b.by, tone: b.auto ? Tone.soft : Tone.info),
                  IconButton(
                    tooltip: 'Скачать ещё раз',
                    onPressed: () {
                      final f = s.redownload(b, _format);
                      ref.read(fileGatewayProvider).download(f.name, f.bytes, f.mime);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
