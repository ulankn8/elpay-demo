import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Лента уведомлений: отключения, новые счета, прошедшие платежи.
class NoticesPage extends ConsumerWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final list = ref.watch(noticesProvider);
    final c = context.c;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.noticesTitle),
        actions: [
          if (list.any((n) => !n.read))
            IconButton(
              tooltip: s.readAll,
              onPressed: () => ref.read(noticesProvider.notifier).readAll(),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: list.isEmpty
            ? EmptyState(icon: Icons.notifications_none_rounded, title: s.noticesEmpty)
            : ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          InkWell(
                            onTap: () => ref.read(noticesProvider.notifier).read(list[i].id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CatTile(_cat(list[i].kind), _icon(list[i].kind), soft: true),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(list[i].title,
                                                  style: context.t.titleMedium),
                                            ),
                                            if (!list[i].read)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(left: 8),
                                                decoration: const BoxDecoration(
                                                    color: Brand.primary,
                                                    shape: BoxShape.circle),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(list[i].text,
                                            style: context.t.bodySmall?.copyWith(height: 1.4)),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${s.dayMonthText(list[i].date)}, ${hhmm(list[i].date)}',
                                          style: context.t.labelSmall?.copyWith(color: c.muted2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static String _cat(NoticeKind k) => switch (k) {
        NoticeKind.outage => 'water',
        NoticeKind.bill => 'power',
        NoticeKind.payment => 'paid',
        NoticeKind.market => 'market',
      };

  static IconData _icon(NoticeKind k) => switch (k) {
        NoticeKind.outage => Icons.warning_amber_rounded,
        NoticeKind.bill => Icons.receipt_long_outlined,
        NoticeKind.payment => Icons.check_circle_outline_rounded,
        NoticeKind.market => Icons.local_activity_outlined,
      };
}
