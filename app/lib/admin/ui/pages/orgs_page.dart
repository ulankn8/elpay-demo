import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Службы пилота. У Ошводоканала цифры живые — из его реестра.
class OrgsPage extends ConsumerWidget {
  const OrgsPage({super.key});

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final service = TextEditingController();
    var cat = 'school';
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Подключить службу', style: T.h1),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Название, как увидят жители'),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: service,
                  decoration: const InputDecoration(labelText: 'Услуга: «Вода», «Садик», «Вывоз мусора»…'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in const ['water', 'power', 'trash', 'gas', 'net', 'kid', 'school'])
                      InkWell(
                        onTap: () => set(() => cat = c),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cat == c ? Brand.primary : Colors.transparent, width: 2),
                          ),
                          child: CatIcon(c),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final st = ref.read(adminStoreProvider);
                final o = Org(
                  id: 'org-${st.now().microsecondsSinceEpoch}',
                  name: name.text.trim(),
                  service: service.text.trim().isEmpty ? 'Услуга' : service.text.trim(),
                  cat: cat,
                  status: OrgStatus.onboarding,
                  onboardingStep: 0,
                );
                await ref.read(actionsProvider).run((s) => s.saveOrg(o, logAction: 'Заведена служба «${o.name}»'));
                if (ctx.mounted) Navigator.pop(ctx, o.id);
              },
              child: const Text('Завести и продолжить'),
            ),
          ],
        ),
      ),
    );
    if (id != null && context.mounted) context.go('/adm/orgs/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.admin;
    final d = s.dashboard();
    final orgs = s.orgs;
    final active = orgs.where((o) => o.status == OrgStatus.active).toList();
    int subsOf(Org o) => o.id == ovkId ? d.subscribers : o.subscribers;
    double appOf(Org o) => o.id == ovkId ? (d.subscribers == 0 ? 0 : d.inApp / d.subscribers) : o.inAppShare;
    double paidOf(Org o) => o.id == ovkId ? (d.charged == 0 ? 0 : d.paid / d.charged) : o.paidShare;
    final totalSubs = active.fold<int>(0, (a, o) => a + subsOf(o));
    final totalApp = active.fold<double>(0, (a, o) => a + subsOf(o) * appOf(o));
    final weightedPaid = totalSubs == 0 ? 0.0 : active.fold<double>(0, (a, o) => a + subsOf(o) * paidOf(o)) / totalSubs;
    final open = s.unmatched().where((u) => u.state == UnmatchedState.open).toList();
    final openSum = open.fold<double>(0, (a, u) => a + u.amount);
    final lagging = active.where((o) => o.id != ovkId).fold<Org?>(null, (m, o) => m == null || paidOf(o) < paidOf(m) ? o : m);

    return PageBody(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Kpi(
                  label: 'Работают в пилоте',
                  value: Text('${active.length} служб', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  note: '${orgs.length - active.length} на подключении',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Kpi(
                  label: 'Абонентов у служб',
                  value: Text(nf(totalSubs), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  meter: totalSubs == 0 ? 0 : totalApp / totalSubs,
                  meterColor: Brand.info,
                  note: '${nf(totalApp.round())} в ЭлPay · ${pct(totalSubs == 0 ? 0 : totalApp / totalSubs)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Kpi(
                  label: 'Оплачено за сентябрь',
                  value: Text(pct(weightedPaid), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  meter: weightedPaid,
                  note: 'в среднем, с весом по абонентам',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Kpi(
                  label: 'Платежи без сопоставления',
                  value: Text(
                    '${open.length}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: open.isEmpty ? Brand.ink : Brand.danger),
                  ),
                  note: open.isEmpty ? 'всё разобрано' : '${som(openSum)} сом ждут разбора',
                  noteColor: open.isEmpty ? null : Brand.danger,
                  accent: open.isEmpty ? null : const Color(0xFFF5B3A8),
                  onTap: () => context.go('/adm/unmatched'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: PanelHead(
                  'Службы пилота',
                  sub: 'У каждой службы свой кабинет: она видит только своих абонентов и платежи',
                  trailing: FilledButton.icon(
                    onPressed: () => _new(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Подключить службу'),
                  ),
                ),
              ),
              Grid(
                rowHeight: 60,
                cols: const [
                  Col('Служба и услуга', flex: 4),
                  Col('Абонентов', width: 100, right: true),
                  Col('Доля в ЭлPay', width: 160),
                  Col('Оплачено', width: 90, right: true),
                  Col('Последний импорт', flex: 3),
                  Col('Доступ', width: 80),
                  Col('Статус', width: 200),
                ],
                onTap: (i) {
                  final o = orgs[i];
                  context.go(o.id == ovkId ? '/svc/overview' : '/adm/orgs/${o.id}');
                },
                rowColor: (i) => orgs[i].status == OrgStatus.onboarding ? const Color(0xFFFFFBF2) : null,
                rows: [
                  for (final o in orgs)
                    [
                      Row(
                        children: [
                          CatIcon(o.cat, size: 32),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  o.name,
                                  style: T.td.copyWith(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(o.service, style: T.tiny),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(o.status == OrgStatus.active ? nf(subsOf(o)) : '—', style: T.num.copyWith(fontWeight: FontWeight.w700)),
                      o.status == OrgStatus.active
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(value: appOf(o), minHeight: 6, color: Brand.info, backgroundColor: Brand.line2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(pct(appOf(o)), style: T.num),
                              ],
                            )
                          : const Text('—', style: T.sub),
                      Text(
                        o.status == OrgStatus.active ? pct(paidOf(o)) : '—',
                        style: T.num.copyWith(fontWeight: FontWeight.w700, color: paidOf(o) < .5 && o.status == OrgStatus.active ? K.warnFg : Brand.ink),
                      ),
                      Text(
                        o.id == ovkId
                            ? () {
                                final j = s.imports().firstWhere((x) => x.status == ImportStatus.applied);
                                return '${dt(j.at)} · ${j.kind == ImportKind.charges ? 'начисления' : 'абоненты'}';
                              }()
                            : (o.lastImport.isEmpty ? 'ждём первый файл' : o.lastImport),
                        style: T.td.copyWith(color: o.lastImport.isEmpty && o.id != ovkId ? K.warnFg : Brand.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('${s.staffOf(o.id).length} сотр.', style: T.td),
                      o.status == OrgStatus.active
                          ? const Chip2('Работает', tone: Tone.ok)
                          : Chip2('Подключение · ${o.onboardingStep} из 5', tone: Tone.warn, icon: Icons.schedule_rounded),
                    ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (open.isNotEmpty)
              Expanded(
                child: Note(
                  tone: Tone.bad,
                  action: LinkAction('Разобрать платежи', onTap: () => context.go('/adm/unmatched')),
                  child: Text(
                    '${open.length} ${plural(open.length, 'платёж', 'платежа', 'платежей')} без сопоставления на ${som(openSum)} сом. Деньги на транзитном счёте ЭлPay, срок разбора — 3 рабочих дня.',
                  ),
                ),
              ),
            if (open.isNotEmpty && lagging != null) const SizedBox(width: 12),
            if (lagging != null)
              Expanded(
                child: Note(
                  tone: Tone.warn,
                  icon: Icons.trending_down_rounded,
                  child: Text(
                    '${lagging.name} отстаёт: оплачено ${pct(paidOf(lagging))} — ниже всех в пилоте. Предложите службе напомнить должникам из кабинета.',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
