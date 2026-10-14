import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens.dart';
import '../../data/models.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

/// Журнал загрузок: кто, когда, каким файлом и с каким итогом.
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});
  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  ImportKind? _kind;

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final all = s.imports();
    final list = [
      for (final j in all)
        if (_kind == null || j.kind == _kind) j,
    ];
    final now = s.now();
    return PageBody(
      children: [
        Row(
          children: [
            FilterPill(label: 'Все', count: all.length, selected: _kind == null, onTap: () => setState(() => _kind = null)),
            const SizedBox(width: 8),
            FilterPill(
              label: 'Абоненты',
              count: all.where((j) => j.kind == ImportKind.subscribers).length,
              selected: _kind == ImportKind.subscribers,
              onTap: () => setState(() => _kind = ImportKind.subscribers),
            ),
            const SizedBox(width: 8),
            FilterPill(
              label: 'Начисления',
              count: all.where((j) => j.kind == ImportKind.charges).length,
              selected: _kind == ImportKind.charges,
              onTap: () => setState(() => _kind = ImportKind.charges),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => context.go('/svc/import'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Новая загрузка'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: Grid(
            rowHeight: 60,
            cols: const [
              Col('Когда', width: 130),
              Col('Что', width: 150),
              Col('Файл', flex: 4),
              Col('Кто', flex: 2),
              Col('Итог', flex: 5),
              Col('Статус', width: 230),
            ],
            rows: [
              for (final j in list)
                [
                  Text(dt(j.at), style: T.td),
                  Chip2(
                    j.kind == ImportKind.subscribers ? 'Абоненты' : 'Начисления · ${j.period == null ? '' : monthsLabel(j.period!)}',
                    tone: j.kind == ImportKind.subscribers ? Tone.info : Tone.ok,
                  ),
                  Text(
                    j.fileName,
                    style: T.td.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(j.by, style: T.td, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (j.kind == ImportKind.subscribers) ...[
                        if (j.created > 0) Chip2('+${nf(j.created)}', tone: Tone.ok),
                        if (j.updated > 0) Chip2('${nf(j.updated)} обновлено', tone: Tone.info),
                        if (j.unchanged > 0) Chip2('${nf(j.unchanged)} без изм.'),
                      ] else ...[
                        Chip2('${nf(j.created)} строк'),
                        Chip2('${nf(j.total)} сом', tone: Tone.info),
                      ],
                      if (j.errors > 0) Chip2('${nf(j.errors)} ошибок', tone: Tone.bad),
                    ],
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      j.status == ImportStatus.rolledBack
                          ? const Chip2('Отменён', icon: Icons.undo_rounded)
                          : Chip2(j.errors > 0 ? 'Применён, с ошибками' : 'Применён', tone: j.errors > 0 ? Tone.warn : Tone.ok, icon: Icons.check_rounded),
                      const SizedBox(width: 6),
                      if (j.canRollback(now))
                        TextButton(
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Отменить импорт ${j.fileName}?',
                              text: 'Реестр вернётся к состоянию до загрузки.',
                              ok: 'Отменить',
                              danger: true,
                            );
                            if (!ok) return;
                            final r = await ref.read(actionsProvider).run((st) => st.rollback(j.id));
                            if (context.mounted) toast(context, r.isOk ? 'Импорт отменён' : r.failureOrNull!.message, bad: r.isFail);
                          },
                          style: TextButton.styleFrom(foregroundColor: Brand.danger),
                          child: const Text('Отменить'),
                        ),
                    ],
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('Отменить загрузку можно в течение суток — после этого она остаётся в журнале навсегда.', style: T.sub),
      ],
    );
  }
}

String monthsLabel(Period p) => periodTitle(p.year, p.month).toLowerCase();
