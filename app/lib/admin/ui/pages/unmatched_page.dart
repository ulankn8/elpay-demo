import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/admin_store.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Деньги пришли, а лицевой не нашёлся. Разбирает админ ЭлPay.
class UnmatchedPage extends ConsumerStatefulWidget {
  const UnmatchedPage({super.key});
  @override
  ConsumerState<UnmatchedPage> createState() => _UnmatchedPageState();
}

class _UnmatchedPageState extends ConsumerState<UnmatchedPage> {
  bool _closed = false;

  Future<void> _other(Unmatched u) async {
    final c = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final s = ref.read(adminStoreProvider);
          final found = s.subscriber(c.text.trim());
          return AlertDialog(
            title: const Text('Другой лицевой', style: T.h1),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Платёж ${som(u.amount)} сом, введено «${u.entered}»', style: T.sub),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c,
                    autofocus: true,
                    decoration: InputDecoration(hintText: '31-00562', errorText: err),
                    onChanged: (_) => set(() => err = null),
                  ),
                  if (found != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Note(tone: Tone.ok, child: Text('${found.name} · ${found.address}')),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              FilledButton(
                onPressed: () async {
                  final r = await ref.read(actionsProvider).run((x) => x.bindPayment(u.id, c.text.trim()));
                  if (r.isFail) return set(() => err = r.failureOrNull!.message);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) toast(context, 'Платёж привязан к ${c.text.trim()}');
                },
                child: const Text('Привязать'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final all = s.unmatched();
    final list = [
      for (final u in all)
        if ((u.state != UnmatchedState.open) == _closed) u,
    ];
    final open = all.where((u) => u.state == UnmatchedState.open).toList();
    final now = s.now();

    return PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Kpi(
                        label: 'Ждут разбора',
                        value: Text('${open.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Expanded(
                      child: Kpi(
                        label: 'На транзитном счёте',
                        value: Money(open.fold(0, (a, u) => a + u.amount), size: 22, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Note(
                child: Text(
                  'Житель заплатил, но лицевой не нашёлся — деньги держим на транзитном счёте ЭлPay: службе они не ушли и в её кабинете не видны. Разобрать нужно за 3 рабочих дня: привязать к правильному лицевому — платёж попадёт службе в реестр — или вернуть плательщику. Житель получит push о результате.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            const Text('Сначала те, у кого срок раньше', style: T.h2),
            Seg<bool>(
              items: [(false, 'Ждут · ${open.length}'), (true, 'Разобранные · ${all.length - open.length}')],
              value: _closed,
              onChanged: (v) => setState(() => _closed = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Panel(
            child: Empty(icon: Icons.task_alt_rounded, title: 'Всё разобрано', text: 'Новые платежи без лицевого появятся здесь'),
          ),
        for (final u in list) _card(context, s, u, now),
      ],
    );
  }

  Widget _card(BuildContext context, AdminStore s, Unmatched u, DateTime now) {
    final hint = s.hintFor(u);
    final org = s.org(u.orgId);
    final daysLeft = DateTime(u.deadline.year, u.deadline.month, u.deadline.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final due = daysLeft <= 0 ? 'срок сегодня' : (daysLeft == 1 ? 'срок завтра' : 'до ${u.deadline.day} ${monthsShort[u.deadline.month - 1]}');
    final sub = hint == null ? null : s.subscriber(hint.account);
    final closed = u.state != UnmatchedState.open;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: EdgeInsets.zero,
        border: !closed && daysLeft <= 0 ? const Color(0xFFF5B3A8) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 290,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Brand.line2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Money(u.amount, size: 24, weight: FontWeight.w700),
                        if (!closed) Chip2(due, tone: daysLeft <= 0 ? Tone.bad : Tone.warn),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${dt(u.at)} · ${u.method}', style: T.sub),
                    Text('№ ${u.receipt}', style: T.sub),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CatIcon(org.cat, size: 26),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(org.name, style: T.h3, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Ввели лицевой', style: T.tiny),
                        Chip2(u.entered, tone: Tone.bad),
                        Text(
                          u.orgId == ovkId ? 'нет такого' : 'закрыт',
                          style: const TextStyle(fontSize: 11.5, color: K.badFg, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (closed)
                        Note(
                          tone: u.state == UnmatchedState.bound ? Tone.ok : Tone.soft,
                          icon: u.state == UnmatchedState.bound ? Icons.link_rounded : Icons.undo_rounded,
                          child: Text(u.state == UnmatchedState.bound ? 'Привязан к ${u.boundTo} — платёж ушёл службе в реестр' : 'Возвращён: ${u.closedNote}'),
                        )
                      else if (hint != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('ПОДСКАЗКА', style: T.th),
                            Chip2(hint.account, tone: Tone.ok),
                            Text('${sub?.name ?? ''} · ${sub?.address ?? ''}', style: T.h3),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 17, color: Brand.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(hint.why, style: T.td.copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        for (final (text, ok) in hint.checks)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(ok ? Icons.check_rounded : Icons.warning_amber_rounded, size: 16, color: ok ? Brand.primary : Brand.warning),
                                const SizedBox(width: 6),
                                Expanded(child: Text(text, style: T.td)),
                              ],
                            ),
                          ),
                      ] else ...[
                        const Text('ПОДСКАЗКИ НЕТ', style: T.th),
                        const SizedBox(height: 10),
                        Text(
                          u.orgId == ovkId
                              ? 'Похожих лицевых не нашлось — ни перестановки цифр, ни потерянного нуля.'
                              : 'Лицевой ${u.entered} закрыт у службы — служба убрала его из реестра, долга по нему нет. Других похожих лицевых не нашлось.',
                          style: T.body,
                        ),
                        const SizedBox(height: 6),
                        Text('Деньги можно вернуть на ту же карту (${u.method}) — дойдут за 1–3 рабочих дня.', style: T.sub),
                      ],
                    ],
                  ),
                ),
              ),
              if (!closed)
                Container(
                  width: 260,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Brand.line2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hint != null)
                        FilledButton.icon(
                          onPressed: () async {
                            await ref.read(actionsProvider).run((x) => x.bindPayment(u.id, hint.account));
                            if (context.mounted) toast(context, 'Платёж привязан к ${hint.account} — житель получит push');
                          },
                          icon: const Icon(Icons.link_rounded, size: 17),
                          label: Text('Привязать к ${hint.account}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      if (hint == null)
                        FilledButton.icon(
                          onPressed: () async {
                            await ref.read(actionsProvider).run((x) => x.refundPayment(u.id));
                            if (context.mounted) toast(context, 'Возврат ${som(u.amount)} сом оформлен');
                          },
                          icon: const Icon(Icons.undo_rounded, size: 17),
                          label: Text('Вернуть ${som(u.amount)} сом'),
                        ),
                      const SizedBox(height: 8),
                      if (u.orgId == ovkId)
                        OutlinedButton.icon(onPressed: () => _other(u), icon: const Icon(Icons.search_rounded, size: 17), label: const Text('Другой лицевой')),
                      if (hint != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Вернуть деньги?',
                              text: '${som(u.amount)} сом вернутся на ${u.method}. Служба этот платёж не увидит.',
                              ok: 'Вернуть',
                            );
                            if (!ok) return;
                            await ref.read(actionsProvider).run((x) => x.refundPayment(u.id));
                          },
                          style: TextButton.styleFrom(foregroundColor: Brand.danger),
                          icon: const Icon(Icons.undo_rounded, size: 17),
                          label: const Text('Вернуть плательщику'),
                        ),
                      ],
                      if (u.orgId != ovkId) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => toast(context, 'Запрос отправлен в ${org.name}'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                          label: Text('Спросить ${org.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
