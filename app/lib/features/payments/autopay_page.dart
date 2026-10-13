import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Автоплатежи: какие счета ЭлPay оплачивает сам 25-го числа.
class AutopayPage extends ConsumerWidget {
  const AutopayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.autopayTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Tip(s.autopayLead),
            const SizedBox(height: 16),
            // Пока начисления грузятся — скелет, при отказе — текст из S
            // и «Повторить». Пустая карточка больше не выдаёт ошибку
            // загрузки за «автоплатить нечего».
            AsyncSection<BillsState>(
              value: ref.watch(billsProvider),
              onRetry: () => ref.read(billsProvider.notifier).refresh(),
              skeleton: const LoadingRows(count: 3),
              isEmpty: (state) => state.bills.isEmpty,
              empty: AppCard(
                child: EmptyState(
                  icon: Icons.autorenew_rounded,
                  title: s.nothingYet,
                  lead: s.noBillsLead,
                ),
              ),
              data: (state) => AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < state.bills.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      _AutopayRow(bill: state.bills[i]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
          ],
        ),
      ),
    );
  }
}

/// Строка счёта с тумблером автоплатежа.
///
/// Переключение идёт через [BillsNotifier.setAutopay]: тумблер встаёт
/// сразу, а при отказе Notifier возвращает его назад — экран лишь
/// показывает причину. Раньше здесь было локальное присваивание, и
/// отказ сервера оставался незамеченным.
class _AutopayRow extends ConsumerWidget {
  const _AutopayRow({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return AppRow(
      leading: CatTile(bill.cat, catIcon(bill.cat), soft: true),
      title: s.tr(bill.title),
      subtitle: '${som(bill.amount)} ${s.som} · ${bill.account}',
      trailing: Switch(
        value: bill.autopay,
        onChanged: (on) => _toggle(context, ref, on: on),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, {required bool on}) async {
    final s = S.of(context);
    final result =
        await ref.read(billsProvider.notifier).setAutopay(bill.id, on: on);
    if (!context.mounted) return;
    final failure = result.failureOrNull;
    showAppSnack(
      context,
      failure != null
          ? failureTitle(s, failure)
          : on
              ? s.autopayOn
              : s.autopayOff,
    );
  }
}
