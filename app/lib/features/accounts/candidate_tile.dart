import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/connect_rules.dart';

/// Найденный счёт в списке результатов: кого нашли, за какой период
/// и сколько начислено.
///
/// Решения не принимает: что показать и можно ли выбрать, уже посчитали
/// правила ([CandidateView.reason], `selectable`), поэтому одна и та же
/// логика работает в тесте правил и здесь.
class CandidateTile extends StatelessWidget {
  const CandidateTile({
    super.key,
    required this.view,
    required this.selected,
    this.onToggle,
    this.onTap,
    this.busy = false,
  });

  final CandidateView view;
  final bool selected;

  /// Галочка. null — кандидат заблокирован (закрыт у поставщика,
  /// уже подключён, неизвестный поставщик).
  final VoidCallback? onToggle;

  /// Тап по строке: предпросмотр начислений, переход на подключённый счёт
  /// или шторка кода — решает экран, а не строка.
  final VoidCallback? onTap;

  /// По этому кандидату идёт проверка кода: спиннер только здесь,
  /// остальные строки списка живые.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final candidate = view.candidate;
    final cat = ServiceCat.parse(candidate.cat);
    final reason = view.reason;
    final locked = onToggle == null;

    final (chipText, chipTone, chipIcon) = switch (reason) {
      ConnectBlock.alreadyConnected => (s.alreadyConnected, ChipTone.soft, Icons.link_rounded),
      ConnectBlock.closedByProvider => (s.accountClosed, ChipTone.bad, Icons.block_rounded),
      ConnectBlock.unknownProvider => (s.errorNotFound, ChipTone.soft, Icons.help_outline_rounded),
      ConnectBlock.needsConfirm => (
          s.confirmOwnership,
          ChipTone.warn,
          Icons.lock_outline_rounded,
        ),
      null => (null, ChipTone.soft, null),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '${s.tr(candidate.providerTitle)}, ${candidate.accountNo}',
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: locked && reason == ConnectBlock.alreadyConnected ? .65 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Минимальная область нажатия 48 dp: по галочке 26×26
                // попасть пальцем нельзя.
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : reason == ConnectBlock.alreadyConnected
                            ? Icon(Icons.check_circle_rounded, size: 26, color: c.muted2)
                            : AppCheckbox(on: selected, onTap: onToggle),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
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
                          '${s.accountHolder}: ${candidate.holder} · ${candidate.amount > 0 ? '${s.lastCharge}, ${s.tr(candidate.period)}' : s.noCharges}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.labelSmall?.copyWith(color: c.muted2),
                        ),
                        if (chipText != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Flexible — длинная подпись чипа не должна распирать строку.
                              Flexible(
                                child: AppChip(chipText, tone: chipTone, icon: chipIcon),
                              ),
                              if (onTap != null) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right_rounded, size: 18, color: c.muted2),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
