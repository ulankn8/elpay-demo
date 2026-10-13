import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/connect_rules.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'connect_args.dart';

/// Шаг предпросмотра начислений: пользователь видит, ЧТО именно будет
/// приходить, ДО подключения.
///
/// Закрывает дыру «подключил и не понял, что получишь»: суммы, периоды,
/// ближайший срок, расшифровка по тапу и отдельным блоком — счета, по
/// которым начислений нет (такому счёту начисление на 0 сом не создаётся).
///
/// Ничего не считает сам: всё уже посчитано [ConnectRules.preview]
/// синхронно и без сети.
class ChargesPreviewView extends ConsumerWidget {
  const ChargesPreviewView({
    super.key,
    required this.preview,
    required this.onBack,
    required this.onConnect,
  });

  final ChargesPreview preview;
  final VoidCallback onBack, onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final busy = ref.watch(connectProvider).connecting;
    final count = preview.count;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
            children: [
              Tip(s.previewLead),
              if (preview.nearestDue != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    AppChip(
                      '${s.dueDate} ${s.dayMonthText(preview.nearestDue!)}',
                      tone: ChipTone.warn,
                      icon: Icons.event_outlined,
                    ),
                  ],
                ),
              ],
              if (preview.lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < preview.lines.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        _ChargeRow(line: preview.lines[i]),
                      ],
                    ],
                  ),
                ),
              ],
              // Счета без выставленного начисления: подключаем, но
              // начисление на 0 сом не создаём — именно такой фальшивый
              // счёт ломал разбивку на главной.
              if (preview.withoutCharges.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle(s.noCharges),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < preview.withoutCharges.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        _PlainCandidateRow(view: preview.withoutCharges[i]),
                      ],
                    ],
                  ),
                ),
              ],
              if (preview.isEmpty && preview.withoutCharges.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: s.noCharges,
                    lead: s.previewLead,
                  ),
                ),
            ],
          ),
        ),
        AppBottomBar(
          label: s.chargedTotal,
          amount: som(preview.total),
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: busy ? null : onConnect,
                child: busy
                    ? const _ButtonSpinner()
                    : Text(count > 1 ? '${s.connectSelected} · $count' : s.connectOne),
              ),
              TextButton(onPressed: busy ? null : onBack, child: Text(s.back)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Строка предпросмотра: поставщик — период — сумма, тап открывает
/// расшифровку «как начислено».
class _ChargeRow extends ConsumerWidget {
  const _ChargeRow({required this.line});
  final ChargeLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final cat = ServiceCat.parse(line.view.candidate.cat);
    return AppRow(
      leading: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
      title: s.tr(line.view.title),
      subtitle: '${s.tr(line.period)} · ${s.shortDueText(line.due)}',
      trailing: Amount(som(line.amount), size: 15),
      chevron: line.calc.isNotEmpty,
      onTap: line.calc.isEmpty ? null : () => openChargeSheet(context, ref, line),
    );
  }
}

/// Счёт без начисления: показываем, что подключится, но суммы не обещаем.
class _PlainCandidateRow extends StatelessWidget {
  const _PlainCandidateRow({required this.view});
  final CandidateView view;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cat = ServiceCat.parse(view.candidate.cat);
    return AppRow(
      leading: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
      title: s.tr(view.title),
      subtitle: '${s.tr(view.candidate.serviceTitle)} · ${view.candidate.accountNo}',
      trailing: AppChip(s.noCharges),
    );
  }
}

/// Шторка расшифровки одного начисления: показания, тариф, итог.
///
/// Период берётся через [S.tr], чтобы в кыргызской локали месяц не
/// оставался русским — у кандидата период приходит строкой из реестра.
Future<void> openChargeSheet(BuildContext context, WidgetRef ref, ChargeLine line) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ChargeSheet(line: line),
    );

class _ChargeSheet extends StatelessWidget {
  const _ChargeSheet({required this.line});
  final ChargeLine line;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = line.view.candidate;
    final cat = ServiceCat.parse(c.cat);

    return AppSheet(
      title: s.howCharged,
      lead: '${s.tr(line.period)} · ${s.tr(c.serviceTitle)}',
      header: Row(
        children: [
          CatTile(cat.token, iconOf(cat), size: 46, radius: 13, soft: true),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tr(line.view.title), style: context.t.titleMedium),
                Text(c.accountNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall),
              ],
            ),
          ),
          Amount(som(line.amount), size: 18),
        ],
      ),
      children: [
        KeyValueBox([
          for (final f in line.calc) (s.tr(f.label), s.tr(f.value)),
          (s.dueDate, s.dayMonthText(line.due)),
          (s.total, '${som(line.amount)} ${s.som}'),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.close),
        ),
      ],
    );
  }
}

/// Итог подключения: успех, ЧЕСТНЫЙ частичный успех с причиной по каждому
/// счёту и очередь.
///
/// Раньше частичный успех не был виден вообще: при двух подключённых из
/// трёх ошибка затиралась, и про упавший счёт пользователь не узнавал.
class ConnectResultView extends ConsumerWidget {
  const ConnectResultView({super.key, required this.outcome, required this.onDone});

  final ConnectOutcome outcome;
  final VoidCallback onDone;

  /// Повтор только для непрошедших: выбор сводится к упавшим счетам,
  /// ключи идемпотентности переиспользуются из состояния, поэтому
  /// подключённое вторым счётом не станет.
  Future<void> _retryFailed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(connectProvider.notifier);
    notifier.selectNone();
    for (final f in outcome.failed) {
      notifier.toggle(f.candidateId);
    }
    final next = await notifier.connectChosen();
    if (!context.mounted) return;
    if (next.connected.isEmpty && next.failed.isNotEmpty) {
      showAppSnack(context, ErrorView.titleFor(context, next.failed.first.failure));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final busy = ref.watch(connectProvider).connecting;
    final partly = outcome.failed.isNotEmpty || outcome.queued.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 20),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  children: [
                    CatTile(
                      partly ? 'city' : 'paid',
                      partly ? Icons.priority_high_rounded : Icons.check_rounded,
                      size: 52,
                      radius: 15,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      partly
                          ? s.connectedPartly(outcome.connected.length, outcome.total)
                          : s.connectedCount(outcome.connected.length),
                      textAlign: TextAlign.center,
                      style: context.t.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partly ? s.connectPartlyLead : s.syncOk,
                      textAlign: TextAlign.center,
                      style: context.t.bodySmall,
                    ),
                  ],
                ),
              ),
              if (outcome.connected.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle(s.myAccounts),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < outcome.connected.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        _ConnectedRow(
                          account: outcome.connected[i],
                          charge: _chargeOf(outcome.connected[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Непрошедшие — с причиной по каждому счёту, а не одним снеком.
              if (outcome.failed.isNotEmpty) ...[
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < outcome.failed.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        AppRow(
                          leading: Icon(Icons.error_outline_rounded,
                              size: 26, color: context.c.chipBadFg),
                          title: s.connectFailedFor(s.tr(outcome.failed[i].title)),
                          subtitle: failureTitle(s, outcome.failed[i].failure),
                          subtitleColor: context.c.chipBadFg,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : () => _retryFailed(context, ref),
                  child: busy ? const _ButtonSpinner(dark: true) : Text(s.retryOnlyFailed),
                ),
              ],
              // Офлайн: операция не потеряна, уйдёт при появлении сети.
              if (outcome.queued.isNotEmpty) ...[
                const SizedBox(height: 14),
                Tip(s.pendingConnect, icon: Icons.cloud_off_rounded, tone: ChipTone.warn),
              ],
            ],
          ),
        ),
        AppBottomBar(
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(onPressed: onDone, child: Text(s.backToAccounts)),
              TextButton(
                onPressed: () => ref
                    .read(connectProvider.notifier)
                    .start(source: ConnectArgs.sourceManual),
                child: Text(s.connectAnother),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Начисление подключённого счёта, если оно пришло вместе с ним.
  double? _chargeOf(String accountId) {
    for (final b in outcome.charges) {
      if (b.accountId == accountId) return b.amount;
    }
    return null;
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({required this.account, this.charge});
  final ConnectedAccount account;
  final double? charge;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cat = ServiceCat.parse(account.cat);
    return AppRow(
      leading: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
      title: s.tr(account.title),
      subtitle: '${account.accountNo} · ${s.tr(account.subtitle)}',
      trailing: charge == null
          ? AppChip(s.noCharges)
          : Amount(som(charge!), size: 15),
    );
  }
}

/// Спиннер в кнопке — ровно той же величины, что и текст, чтобы кнопка
/// не прыгала по высоте.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: dark ? Brand.primary : Brand.onPrimary,
        ),
      );
}
