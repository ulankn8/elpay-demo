import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Сотрудники службы. Ролей внутри службы нет: права у всех одинаковые.
class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final org = ref.read(adminStoreProvider).demoOrg;
    final name = TextEditingController();
    final email = TextEditingController();
    String? err, errField;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Пригласить сотрудника', style: T.h1),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Приглашение придёт на рабочую почту @${org.emailDomain}. Войти можно сразу — по коду из письма.', style: T.sub),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: 'Имя и фамилия', errorText: errField == 'name' ? err : null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  decoration: InputDecoration(labelText: 'Рабочая почта', hintText: 'имя@${org.emailDomain}', errorText: errField == 'email' ? err : null),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                final r = await ref.read(actionsProvider).run((s) => s.invite(orgId: org.id, name: name.text, email: email.text));
                if (r.isFail) {
                  return set(() {
                    err = r.failureOrNull!.message;
                    errField = r.failureOrNull!.field;
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) toast(context, 'Приглашение отправлено на ${r.valueOrNull!.email}');
              },
              child: const Text('Пригласить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.admin;
    final org = s.demoOrg;
    final staff = s.staffOf(org.id);
    final me = s.session;
    final log = s.audit(orgId: org.id).take(14).toList();

    return PageBody(
      children: [
        const Note(
          icon: Icons.groups_2_outlined,
          child: Text('Все сотрудники службы видят абонентов и платежи, загружают файлы и делают рассылки. Пригласить и закрыть доступ может любой из вас.'),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: PanelHead(
                        'Сотрудники · ${staff.length}',
                        trailing: FilledButton.icon(
                          onPressed: () => _invite(context, ref),
                          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                          label: const Text('Пригласить'),
                        ),
                      ),
                    ),
                    Grid(
                      rowHeight: 62,
                      cols: const [Col('Сотрудник', flex: 4), Col('Почта', flex: 4), Col('Последний вход', flex: 4), Col('', width: 140)],
                      rows: [
                        for (final st in staff)
                          [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: Brand.light2,
                                  child: Text(
                                    st.initials,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.p700),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    '${st.name}${st.id == me?.id ? ' (вы)' : ''}',
                                    style: T.td.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Text(st.email, style: T.td, overflow: TextOverflow.ellipsis),
                            st.pending
                                ? Tooltip(
                                    message: 'Приглашение — ${dt(st.invitedAt)}',
                                    child: const Chip2('Ждёт первого входа', tone: Tone.warn),
                                  )
                                : Text(
                                    '${dt(st.lastLoginAt!)} · ${st.device}',
                                    style: T.td.copyWith(color: Brand.muted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            st.id == me?.id
                                ? const SizedBox()
                                : TextButton(
                                    onPressed: () async {
                                      final ok = await confirm(
                                        context,
                                        title: 'Закрыть доступ?',
                                        text: '${st.name} больше не сможет войти в кабинет. Его действия останутся в журнале.',
                                        ok: 'Закрыть доступ',
                                        danger: true,
                                      );
                                      if (!ok) return;
                                      final r = await ref.read(actionsProvider).run((x) => x.removeStaff(st.id));
                                      if (context.mounted) toast(context, r.isOk ? 'Доступ закрыт' : r.failureOrNull!.message, bad: r.isFail);
                                    },
                                    style: TextButton.styleFrom(foregroundColor: Brand.danger),
                                    child: const Text('Закрыть доступ'),
                                  ),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              flex: 2,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelHead('Безопасность'),
                    Kv([
                      ('Вход', 'Код на рабочую почту, без паролей'),
                      ('Сессия', '12 часов, потом снова код'),
                      ('Почта', 'Только рабочий домен службы'),
                      ('Доступ', 'Выдаёт менеджер ЭлPay — Азамат Кадыров'),
                    ], labelWidth: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: PanelHead('Журнал действий службы', sub: 'Кто, когда и что сделал в кабинете'),
              ),
              Grid(
                rowHeight: 44,
                cols: const [Col('Когда', width: 140), Col('Кто', flex: 2), Col('Что', flex: 7)],
                rows: [
                  for (final a in log)
                    [
                      Text(dt(a.at), style: T.td),
                      Text(a.who, style: T.td.copyWith(fontWeight: FontWeight.w600)),
                      Text(a.action, style: T.td, maxLines: 2, overflow: TextOverflow.ellipsis),
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
