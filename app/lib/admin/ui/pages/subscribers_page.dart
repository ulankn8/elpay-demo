import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/addresses.dart';
import '../../data/admin_store.dart';
import '../../data/models.dart';
import '../../data/registry.dart';
import '../../data/xlsx.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

const _perPage = 25;

Widget statusChip(SubscriberView v) => switch (v.status) {
  PayStatus.paid => Chip2(v.lastPayment == null ? 'Оплачено' : 'Оплачено ${dayMonth(v.lastPayment!.at)}', tone: Tone.ok, icon: Icons.check_rounded),
  PayStatus.partial => Chip2('Частично, долг ${som(v.leftToPay)}', tone: Tone.warn),
  PayStatus.unpaid =>
    v.hasDebt
        ? Chip2('Долг ${som(v.debt + v.charged)} · ${v.debt > v.charged ? '3' : '2'} мес.', tone: Tone.bad, icon: Icons.warning_amber_rounded)
        : (v.sub.createdAt != null && v.sub.createdAt!.isAfter(DateTime(2026, 9, 25))
              ? const Chip2('Новый · не оплачено', tone: Tone.info)
              : const Chip2('Не оплачено', tone: Tone.bad)),
  PayStatus.noCharge => const Chip2('Новый · без начисления', tone: Tone.info),
};

class SubscribersPage extends ConsumerStatefulWidget {
  const SubscribersPage({super.key, this.query = '', this.filter, this.open});
  final String query;
  final String? filter, open;
  @override
  ConsumerState<SubscribersPage> createState() => _SubscribersPageState();
}

class _SubscribersPageState extends ConsumerState<SubscribersPage> {
  late final _q = TextEditingController(text: widget.query);
  late SubFilter _filter = SubFilter.values.where((f) => f.name == widget.filter).firstOrNull ?? SubFilter.all;
  int _page = 0;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    if (widget.open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.open == 'new') {
          openSubscriberForm(context);
        } else {
          openSubscriberCard(context, widget.open!);
        }
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _exportExcel(List<SubscriberView> list) {
    final s = ref.read(adminStoreProvider);
    final rows = <List<String>>[
      ['Лицевой', 'ФИО', 'Адрес', 'Жильцов', 'Телефон', 'Начислено', 'Оплачено', 'Долг прошлых периодов', 'В ЭлPay'],
      for (final v in list)
        [
          v.sub.account,
          v.sub.name,
          v.sub.address,
          '${v.sub.residents}',
          v.sub.phone,
          v.charged.toStringAsFixed(2).replaceAll('.', ','),
          v.paid.toStringAsFixed(2).replaceAll('.', ','),
          v.debt.toStringAsFixed(2).replaceAll('.', ','),
          v.sub.inApp ? 'да' : 'нет',
        ],
    ];
    final now = s.now();
    ref
        .read(fileGatewayProvider)
        .download(
          'abonenty_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.xlsx',
          writeXlsx(rows, sheetName: 'Абоненты'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
    toast(context, 'Выгрузили ${nf(list.length)} ${plural(list.length, 'абонента', 'абонентов', 'абонентов')} в Excel');
  }

  Future<void> _remind(List<SubscriberView> list) async {
    final inApp = list.where((v) => v.sub.inApp).length;
    final ok = await confirm(
      context,
      title: 'Напомнить об оплате',
      text:
          'Push в приложении ЭлPay получат ${nf(inApp)} из ${nf(list.length)} выбранных — бесплатно. '
          '${list.length - inApp > 0 ? 'Остальным ${nf(list.length - inApp)} отправить SMS можно в разделе «Уведомления».' : ''}',
      ok: 'Отправить push',
    );
    if (!ok || !mounted) return;
    final store = ref.read(adminStoreProvider);
    await ref
        .read(actionsProvider)
        .run(
          (s) => s.scheduleCampaign(
            segment: Segment.unpaid,
            template: 'Напоминание выбранным',
            text: '{имя}, за воду {сумма}. Оплатите до {срок} — без пени.',
            sms: false,
            sendAt: store.now(),
            onlyAccounts: {for (final v in list) v.sub.account},
          ),
        );
    if (!mounted) return;
    setState(_selected.clear);
    toast(context, 'Напоминание ушло: ${nf(inApp)} push');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final counts = s.counts();
    final list = s.search(filter: _filter, query: _q.text);
    final pages = (list.length / _perPage).ceil();
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final shown = list.skip(page * _perPage).take(_perPage).toList();
    final p = s.openPeriod;
    final due = p.due;
    final allShownSelected = shown.isNotEmpty && shown.every((v) => _selected.contains(v.sub.account));
    final selectedViews = [for (final a in _selected) ?s.view(a)];
    // Канал оплаты помещается только на широком экране — на ноутбуке он
    // съедал ФИО и адрес; канал всё равно виден в карточке абонента.
    final screen = MediaQuery.sizeOf(context).width;
    final wide = screen >= 1600;
    // Узкое окно: ФИО и адрес в одной ячейке, без «Жильцов» и «В ЭлPay» —
    // чтобы статус оплаты оставался на экране без прокрутки вбок.
    final compact = screen < 1300;

    Widget pill(SubFilter f, String label, [Color? dot]) => FilterPill(
      label: label,
      count: counts[f],
      dot: dot,
      selected: _filter == f,
      onTap: () => setState(() {
        _filter = f;
        _page = 0;
      }),
    );

    return PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Реестр абонентов', style: T.h2),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      style: T.sub,
                      children: [
                        TextSpan(text: 'Оплата за ${monthsNom[p.month - 1]} '),
                        TextSpan(
                          text: 'до ${due.day} ${monthsGen[due.month - 1]}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink),
                        ),
                        const TextSpan(text: ' · поиск по лицевому, ФИО, адресу или телефону'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/svc/import'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Импорт из 1С'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => openSubscriberForm(context),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Добавить абонента'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              pill(SubFilter.all, 'Все'),
                              pill(SubFilter.paid, 'Оплатили', Brand.primary),
                              pill(SubFilter.partial, 'Частично', Brand.warning),
                              pill(SubFilter.unpaid, 'Не оплатили', Brand.danger),
                              pill(SubFilter.debt, 'С долгом', const Color(0xFFB03A28)),
                              pill(SubFilter.inApp, 'Подключены в ЭлPay', Brand.info),
                              pill(SubFilter.fresh, 'Новые за месяц'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _q,
                            decoration: InputDecoration(
                              hintText: 'Найти в реестре',
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              suffixIcon: _q.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () => setState(() {
                                        _q.clear();
                                        _page = 0;
                                      }),
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                    ),
                            ),
                            onChanged: (_) => setState(() => _page = 0),
                          ),
                        ),
                      ],
                    ),
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        decoration: BoxDecoration(color: Brand.light2, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Text(
                              'Выбрано ${nf(_selected.length)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.p700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${nf(selectedViews.where((v) => v.sub.inApp).length)} подключены в ЭлPay — push дойдёт бесплатно',
                                style: const TextStyle(fontSize: 12.5, color: Brand.p700),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _remind(selectedViews),
                              icon: const Icon(Icons.notifications_active_outlined, size: 17),
                              label: const Text('Напомнить об оплате'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _exportExcel(selectedViews),
                              icon: const Icon(Icons.download_rounded, size: 17),
                              label: const Text('Выгрузить'),
                            ),
                            IconButton(onPressed: () => setState(_selected.clear), icon: const Icon(Icons.close_rounded), tooltip: 'Снять выделение'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Grid(
                cols: [
                  const Col('', width: 40),
                  const Col('Лицевой', width: 100),
                  if (compact) const Col('ФИО и адрес', flex: 5) else ...const [Col('ФИО', flex: 3), Col('Адрес', flex: 4)],
                  if (!compact) const Col('Жильцов', width: 70, right: true),
                  const Col('Начислено', width: 90, right: true),
                  const Col('Оплачено', width: 86, right: true),
                  const Col('Статус оплаты', width: 180),
                  if (wide) const Col('Канал', flex: 2),
                  if (!compact) const Col('В ЭлPay', width: 76),
                ],
                selected: (i) => _selected.contains(shown[i].sub.account),
                onTap: (i) => openSubscriberCard(context, shown[i].sub.account),
                empty: Empty(
                  icon: Icons.search_off_rounded,
                  title: 'Никого не нашли',
                  text: _q.text.isEmpty ? 'В этом фильтре пока пусто' : 'Проверьте лицевой или попробуйте часть фамилии',
                ),
                rows: [
                  for (final v in shown)
                    [
                      Checkbox(
                        value: _selected.contains(v.sub.account),
                        onChanged: (on) => setState(() => on == true ? _selected.add(v.sub.account) : _selected.remove(v.sub.account)),
                      ),
                      Text(v.sub.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                      if (compact)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.sub.name,
                              style: T.td.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              v.sub.address,
                              style: T.td.copyWith(color: Brand.muted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          v.sub.name,
                          style: T.td.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          v.sub.address,
                          style: T.td.copyWith(color: Brand.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!compact) Text('${v.sub.residents}', style: T.num),
                      Text(v.charged > 0 ? som(v.charged) : '—', style: T.num),
                      Text(v.charged > 0 ? som(v.paid) : '—', style: T.num.copyWith(color: v.paid > 0 ? Brand.ink : Brand.muted)),
                      statusChip(v),
                      if (wide)
                        Text(
                          v.lastPayment == null
                              ? '—'
                              : '${channelLabel(v.lastPayment!.channel)}${v.lastPayment!.channel == Channel.elpay ? ' · ${v.lastPayment!.method}' : ''}',
                          style: T.td.copyWith(color: v.lastPayment == null ? Brand.muted2 : Brand.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (!compact)
                        v.sub.inApp
                            ? const Chip2('Да', tone: Tone.info, icon: Icons.check_rounded)
                            : const Text('Нет', style: TextStyle(fontSize: 13, color: Brand.muted)),
                    ],
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 20),
                  Flexible(
                    child: Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: shown.isEmpty
                              ? null
                              : () => setState(() {
                                  if (allShownSelected) {
                                    _selected.removeAll(shown.map((v) => v.sub.account));
                                  } else {
                                    _selected.addAll(shown.map((v) => v.sub.account));
                                  }
                                }),
                          icon: Icon(allShownSelected ? Icons.deselect : Icons.select_all, size: 17),
                          label: Text(allShownSelected ? 'Снять со страницы' : 'Выбрать страницу'),
                        ),
                        TextButton.icon(
                          onPressed: list.isEmpty ? null : () => _exportExcel(list),
                          icon: const Icon(Icons.table_view_outlined, size: 17),
                          label: Text('Весь список в Excel · ${nf(list.length)}'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Pager(page: page, total: list.length, perPage: _perPage, onPage: (p) => setState(() => _page = p)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── карточка абонента ─────────────────────────

Future<void> openSubscriberCard(BuildContext context, String account) =>
    showSideSheet<void>(context, width: 600, builder: (_) => _SubscriberCard(account: account));

class _SubscriberCard extends ConsumerWidget {
  const _SubscriberCard({required this.account});
  final String account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.admin;
    final v = s.view(account);
    if (v == null) return const SheetFrame(title: 'Абонент не найден', body: SizedBox());
    final sub = v.sub;
    final p = s.openPeriod;
    final history = s.history(account);
    final log = s.subscriberLog(account);
    final calc = sub.meter
        ? 'по счётчику'
        : '${sub.residents} ${plural(sub.residents, 'человек', 'человека', 'человек')} × 41 сом = ${som(sub.residents * 41.0)} сом';

    return SheetFrame(
      title: sub.name,
      sub: '${sub.account} · ${sub.address}',
      leading: const CatIcon('water', size: 44),
      actions: [
        if (sub.active)
          TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: 'Отключить абонента?',
                text: '${sub.name} останется в истории, но новых начислений не получит. Включить обратно можно в любой момент.',
                ok: 'Отключить',
                danger: true,
              );
              if (!ok) return;
              await ref.read(actionsProvider).run((st) => st.saveSubscriber(sub.copyWith(active: false), isNew: false));
              if (context.mounted) toast(context, 'Абонент ${sub.account} отключён');
            },
            style: TextButton.styleFrom(foregroundColor: Brand.danger),
            child: const Text('Отключить'),
          )
        else
          TextButton(
            onPressed: () => ref.read(actionsProvider).run((st) => st.saveSubscriber(sub.copyWith(active: true), isNew: false)),
            child: const Text('Включить снова'),
          ),
        OutlinedButton.icon(
          onPressed: () => _adjust(context, ref, sub, p, v.charged),
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('Корректировка'),
        ),
        OutlinedButton.icon(
          onPressed: () => openSubscriberForm(context, edit: sub),
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Изменить'),
        ),
        if (v.status != PayStatus.paid && v.charged > 0)
          FilledButton.icon(
            onPressed: !sub.inApp
                ? null
                : () async {
                    await ref
                        .read(actionsProvider)
                        .run(
                          (st) => st.scheduleCampaign(
                            segment: Segment.unpaid,
                            template: 'Напоминание абоненту',
                            text: '{имя}, за воду {сумма}. Оплатите до {срок} — без пени.',
                            sms: false,
                            sendAt: st.now(),
                            onlyAccounts: {sub.account},
                          ),
                        );
                    if (context.mounted) toast(context, 'Push отправлен: ${sub.name}');
                  },
            icon: const Icon(Icons.notifications_active_outlined, size: 17),
            label: Text(sub.inApp ? 'Напомнить об оплате' : 'Нет в ЭлPay — только SMS'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusChip(v),
              if (!sub.active) const Chip2('Отключён', tone: Tone.soft, icon: Icons.block),
              sub.inApp
                  ? Chip2('В ЭлPay с ${dayMonth(sub.inAppSince!)}', tone: Tone.info, icon: Icons.smartphone_rounded)
                  : const Chip2('Не подключён в ЭлPay', icon: Icons.smartphone_rounded),
              if (v.hasDebt) Chip2('Долг прошлых периодов ${som(v.debt)} сом', tone: Tone.bad),
            ],
          ),
          const SizedBox(height: 18),
          Panel(
            color: Brand.soft2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('К оплате за ${monthsNom[p.month - 1]}', style: T.sub),
                      const SizedBox(height: 4),
                      Money(v.leftToPay, size: 28, weight: FontWeight.w700),
                      const SizedBox(height: 4),
                      Text('Начислено ${som(v.charged)} · оплачено ${som(v.paid)} · срок до ${p.due.day} ${monthsShort[p.due.month - 1]}', style: T.sub),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Kv([
            ('Лицевой счёт', sub.account),
            ('Адрес', sub.address),
            ('Жильцов', '${sub.residents}'),
            ('Как считается', calc),
            ('Телефон', sub.phone.isEmpty ? '' : '${sub.phone.substring(0, sub.phone.length - 5)}•• ${sub.phone.substring(sub.phone.length - 2)}'),
            ('Заведён', sub.createdAt == null ? '' : longDate(sub.createdAt!)),
          ]),
          const SizedBox(height: 20),
          const Text('История за полгода', style: T.h2),
          const SizedBox(height: 10),
          Panel(
            padding: EdgeInsets.zero,
            child: Grid(
              rowHeight: 44,
              cols: const [
                Col('Период', width: 130),
                Col('Начислено', width: 90, right: true),
                Col('Оплачено', width: 90, right: true),
                Col('Когда и как', flex: 4),
              ],
              rows: [
                for (final h in history)
                  [
                    Text(periodTitle(h.period.year, h.period.month), style: T.td.copyWith(fontWeight: FontWeight.w600)),
                    Text(som(h.charged), style: T.num),
                    Text(
                      som(h.paid),
                      style: T.num.copyWith(color: h.paid >= h.charged ? Brand.p700 : Brand.danger, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      h.paidAt == null
                          ? (h.period == p ? 'ждём до ${p.due.day} ${monthsShort[p.due.month - 1]}' : 'не оплачено')
                          : '${dayMonth(h.paidAt!)} · ${h.how}',
                      style: T.td.copyWith(color: h.paidAt == null ? Brand.danger : Brand.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
              ],
            ),
          ),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Журнал изменений', style: T.h2),
            const SizedBox(height: 8),
            for (final a in log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 120, child: Text(dt(a.at), style: T.sub)),
                    Expanded(child: Text('${a.action} · ${a.who}', style: T.td)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Subscriber sub, Period p, double current) async {
    final amount = TextEditingController(text: current.toStringAsFixed(2).replaceAll('.', ','));
    final reason = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Корректировка за ${monthsNom[p.month - 1]}', style: T.h1),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${sub.name}, ${sub.account}. Сейчас начислено ${som(current)} сом.', style: T.sub),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  decoration: InputDecoration(labelText: 'Новая сумма, сом', errorText: err),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Причина: перерасчёт, ошибка в 1С…'),
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
                final r = await ref.read(actionsProvider).run((s) => s.adjustCharge(sub.account, p, v, reason.text));
                if (r.isFail) return set(() => err = r.failureOrNull!.message);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) toast(context, 'Начисление изменено, жилец увидит новую сумму в приложении');
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── форма абонента ─────────────────────────

Future<void> openSubscriberForm(BuildContext context, {Subscriber? edit}) =>
    showSideSheet<void>(context, width: 560, builder: (_) => _SubscriberForm(edit: edit));

class _SubscriberForm extends ConsumerStatefulWidget {
  const _SubscriberForm({this.edit});
  final Subscriber? edit;
  @override
  ConsumerState<_SubscriberForm> createState() => _SubscriberFormState();
}

class _SubscriberFormState extends ConsumerState<_SubscriberForm> {
  final _book = StreetBook();
  late final _account = TextEditingController(text: widget.edit?.account ?? ref.read(adminStoreProvider).nextFreeAccount());
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _street = TextEditingController(text: widget.edit?.street ?? '');
  late final _house = TextEditingController(text: widget.edit?.house ?? '');
  late final _flat = TextEditingController(text: widget.edit?.flat ?? '');
  late final _phone = TextEditingController(text: widget.edit?.phone ?? '');
  late int _residents = widget.edit?.residents ?? 1;
  String? _error, _errorField;
  bool get _isNew => widget.edit == null;

  @override
  void dispose() {
    for (final c in [_account, _name, _street, _house, _flat, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetForNext() {
    setState(() {
      _account.text = ref.read(adminStoreProvider).nextFreeAccount(_account.text.split('-').first);
      _name.clear();
      _flat.clear();
      _phone.clear();
      _residents = 1;
      _error = null;
    });
  }

  Future<void> _save({bool more = false}) async {
    final street = _book.find(_street.text);
    final r = await ref
        .read(actionsProvider)
        .run(
          (s) => s.saveSubscriber(
            Subscriber(
              account: _account.text,
              name: _name.text,
              street: street.street?.full ?? _street.text,
              house: _house.text,
              flat: _flat.text,
              residents: _residents,
              phone: _phone.text,
              active: widget.edit?.active ?? true,
            ),
            isNew: _isNew,
          ),
        );
    if (!mounted) return;
    if (r.isFail) {
      setState(() {
        _error = r.failureOrNull!.message;
        _errorField = r.failureOrNull!.field;
      });
      return;
    }
    toast(context, _isNew ? 'Абонент ${r.valueOrNull!.account} добавлен' : 'Изменения сохранены');
    if (more) {
      _resetForNext();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final acc = _account.text.trim();
    final taken = _isNew ? s.subscriber(acc) : null;
    final validAcc = RegExp(r'^\d{2}-\d{5}$').hasMatch(acc);
    final found = _book.find(_street.text);
    final suggestions = _street.text.length >= 2 && found.match != StreetMatch.exact ? _book.suggest(_street.text) : const <Street>[];
    final next = Period.of(s.now());

    String? err(String f) => _errorField == f ? _error : null;

    return SheetFrame(
      title: _isNew ? 'Новый абонент' : 'Изменить абонента',
      sub: _isNew ? 'Вручную — для одного-двух. Больше 20 удобнее файлом из 1С' : widget.edit!.account,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        if (_isNew) OutlinedButton(onPressed: () => _save(more: true), child: const Text('Сохранить и добавить ещё')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field2(
            label: 'Лицевой счёт',
            hint: !_isNew
                ? 'Лицевой не меняется — он связывает абонента с 1С и приложением'
                : !validAcc
                ? 'Вид 31-00562: участок, дефис, пять цифр'
                : taken != null
                ? null
                : 'Свободен · подставили следующий свободный номер',
            child: TextField(
              controller: _account,
              enabled: _isNew,
              decoration: InputDecoration(
                errorText: taken != null ? 'Уже есть: ${taken.name}, ${taken.address}' : err('account'),
                suffixIcon: _isNew && validAcc && taken == null ? const Icon(Icons.check_circle_rounded, color: Brand.primary, size: 20) : null,
              ),
              onChanged: (_) => setState(() => _errorField = null),
            ),
          ),
          const SizedBox(height: 14),
          Field2(
            label: 'ФИО',
            child: TextField(
              controller: _name,
              decoration: InputDecoration(hintText: 'Фамилия Имя Отчество', errorText: err('name')),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 14),
          Field2(
            label: 'Улица',
            hint: found.match == StreetMatch.exact
                ? 'Есть в справочнике Оша'
                : (found.match == StreetMatch.suggested ? 'Похоже на ${found.street!.full}' : null),
            child: TextField(
              controller: _street,
              decoration: InputDecoration(
                hintText: 'Начните вводить — подскажем из справочника',
                errorText: err('street'),
                prefixIcon: const Icon(Icons.place_outlined, size: 18),
              ),
              onChanged: (_) => setState(() => _errorField = null),
            ),
          ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Brand.line),
              ),
              child: Column(
                children: [
                  for (final st in suggestions)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18),
                      title: Text(st.full, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${nf(s.subscribers.values.where((x) => x.street == st.full).length)} абонентов на улице', style: T.tiny),
                      onTap: () => setState(() => _street.text = st.full),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Field2(
                  label: 'Дом',
                  child: TextField(controller: _house),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Field2(
                  label: 'Квартира',
                  hint: 'Частный дом — оставьте пустой',
                  child: TextField(controller: _flat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Field2(
            label: 'Жильцов',
            hint: 'Начисление по норме: $_residents × 41 сом = ${som(_residents * 41.0)} сом в месяц',
            child: Row(
              children: [
                IconButton.outlined(onPressed: _residents > 0 ? () => setState(() => _residents--) : null, icon: const Icon(Icons.remove)),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$_residents',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.outlined(onPressed: _residents < 40 ? () => setState(() => _residents++) : null, icon: const Icon(Icons.add)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Field2(
            label: 'Телефон для уведомлений — необязательно',
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
              decoration: const InputDecoration(hintText: '0555 12 34 56'),
            ),
          ),
          if (_isNew) ...[
            const SizedBox(height: 18),
            Note(
              tone: Tone.ok,
              icon: Icons.smartphone_rounded,
              child: Text(
                'Житель найдёт свой счёт в приложении ЭлPay по лицевому ${validAcc ? acc : ''} сразу, '
                'а начисление за ${monthsNom[next.month - 1]} — со следующей загрузкой начислений.',
              ),
            ),
          ],
          if (_error != null && _errorField == null) ...[const SizedBox(height: 12), Note(tone: Tone.bad, child: Text(_error!))],
        ],
      ),
    );
  }
}
