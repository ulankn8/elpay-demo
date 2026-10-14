import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../../state/admin_state.dart';
import '../kit.dart';
import '../shell.dart';

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});
  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  String? _org;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.admin;
    final all = s.audit();
    final list = [
      for (final a in all)
        if (_org == null || a.orgId == _org) a,
    ];
    const per = 25;
    return PageBody(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterPill(
              label: 'Все службы',
              count: all.length,
              selected: _org == null,
              onTap: () => setState(() {
                _org = null;
                _page = 0;
              }),
            ),
            for (final o in s.orgs)
              if (all.any((a) => a.orgId == o.id))
                FilterPill(
                  label: o.name,
                  count: all.where((a) => a.orgId == o.id).length,
                  selected: _org == o.id,
                  onTap: () => setState(() {
                    _org = o.id;
                    _page = 0;
                  }),
                ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Grid(
                rowHeight: 46,
                cols: const [Col('Когда', width: 140), Col('Служба', flex: 2), Col('Кто', flex: 2), Col('Что', flex: 7)],
                rows: [
                  for (final a in list.skip(_page * per).take(per))
                    [
                      Text(dt(a.at), style: T.td),
                      Text(s.orgs.where((o) => o.id == a.orgId).firstOrNull?.name ?? 'ЭлPay', style: T.td.copyWith(color: Brand.muted)),
                      Text(a.who, style: T.td.copyWith(fontWeight: FontWeight.w600)),
                      Text(a.action, style: T.td, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                ],
              ),
              Pager(page: _page, total: list.length, perPage: per, onPage: (p) => setState(() => _page = p)),
            ],
          ),
        ),
      ],
    );
  }
}
