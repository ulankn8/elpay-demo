import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../bills/bill_row.dart';

/// Найденный счёт в списке результатов: кого нашли, за какой период
/// и сколько начислено. Уже подключённые показываем тускло.
class CandidateTile extends StatelessWidget {
  const CandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onToggle,
  });

  final AccountCandidate candidate;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final locked = candidate.alreadyConnected;

    return InkWell(
      onTap: locked ? null : onToggle,
      child: Opacity(
        opacity: locked ? .55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: locked
                    ? Icon(Icons.check_circle_rounded, size: 26, color: c.muted2)
                    : _Check(on: selected),
              ),
              const SizedBox(width: 12),
              CatTile(candidate.cat, catIcon(candidate.cat), size: 42, radius: 12, soft: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(s.tr(candidate.providerTitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.t.titleMedium),
                        ),
                        if (candidate.amount > 0) ...[
                          const SizedBox(width: 10),
                          Amount(som(candidate.amount), size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${s.tr(candidate.serviceTitle)} · ${candidate.accountNo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.t.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      candidate.amount > 0
                          ? '${s.accountHolder}: ${candidate.holder} · ${candidate.period}'
                          : '${s.accountHolder}: ${candidate.holder} · ${s.noCharges}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.labelSmall?.copyWith(color: c.muted2),
                    ),
                    if (locked || candidate.needsConfirm) ...[
                      const SizedBox(height: 8),
                      AppChip(
                        locked ? s.alreadyConnected : s.confirmOwnership,
                        tone: locked ? ChipTone.soft : ChipTone.warn,
                        icon: locked ? Icons.link_rounded : Icons.lock_outline_rounded,
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

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: on ? Brand.primary : Colors.transparent,
          border: Border.all(color: on ? Brand.primary : context.c.muted2, width: 1.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: on ? const Icon(Icons.check_rounded, size: 16, color: Brand.onPrimary) : null,
      );
}
