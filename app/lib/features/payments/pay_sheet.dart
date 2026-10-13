import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/ids.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'method_picker.dart';
import 'pay_flow.dart';

/// Платежи от этой суммы подтверждаются отдельно, если включена защита
/// крупных платежей. Число то же, что в строке s.confirmBig
/// («Подтверждать платежи от 20 000 сом») — менять их нужно вместе.
const bigPaymentFrom = 20000.0;

/// Последний шаг любой оплаты: чем платим. Способ подставлен из профиля,
/// меняется здесь же. Само списание — через заглушку платежей.
Future<void> openPaySheet(
  BuildContext context,
  WidgetRef ref, {
  required double amount,
  required List<Bill> bills,
  required List<Payment> records,
  VoidCallback? onPaid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _PaySheet(
      amount: amount,
      bills: bills,
      records: records,
      onPaid: onPaid,
    ),
  );
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({
    required this.amount,
    required this.bills,
    required this.records,
    this.onPaid,
  });
  final double amount;
  final List<Bill> bills;
  final List<Payment> records;
  final VoidCallback? onPaid;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  bool _busy = false;

  /// Ключ идемпотентности этой шторки: повтор по кнопке после отказа —
  /// та же попытка оплаты, и шлюз не проведёт её дважды.
  IdempotencyKey? _attempt;

  Future<void> _pay() async {
    final s = S.of(context);
    // Защита крупных платежей: флаг существовал в настройках, но его никто
    // не читал — обещанная в интерфейсе проверка фактически отсутствовала.
    if (widget.amount >= bigPaymentFrom && ref.read(securityProvider).confirmBig) {
      final agreed = await _confirmBig(s);
      if (!mounted || !agreed) return;
    }

    setState(() => _busy = true);
    final key = _attempt ??= ref.read(idGenProvider).key('payments.pay');
    final no = await payAndFinish(
      context,
      ref,
      bills: widget.bills,
      records: widget.records,
      amount: widget.amount,
      key: key,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (no == null) return;
    Navigator.of(context).pop();
    widget.onPaid?.call();
    goSuccess(context, widget.amount, widget.records.length, no);
  }

  /// Подтверждение крупной суммы. Настоящего подтверждения (PIN или Face ID)
  /// здесь нет: PIN живёт в профиле и к оплате не подключён — это осознанное
  /// согласие на сумму, а не проверка личности. Закрывается вместе с боевым
  /// входом и шлюзом.
  Future<bool> _confirmBig(S s) async {
    final agreed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(s.confirmTitle),
        content: Text('${s.confirmBigLead}\n${som(widget.amount)} ${s.som}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.pay)),
        ],
      ),
    );
    return agreed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final selected = ref.watch(payMethodProvider);
    final wallet = ref.watch(walletProvider);
    final methods = ref.watch(catalogNowProvider).methods;
    final stub = ref.watch(paymentsRepoProvider).isStub;

    // Кошельком платить нечем: раньше кнопка была активна, платёж
    // «проходил», а баланс уезжал в ноль через clamp в spend().
    final chosen = methods.where((m) => m.id == selected).firstOrNull;
    final notEnough =
        (chosen?.isWallet ?? selected == 'wallet') && wallet + 0.01 < widget.amount;

    return AppSheet(
      title: s.payWithTitle,
      lead: s.payWithLead,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (methods.isEmpty)
                  // Каталог не доехал: честнее сказать это, чем показать
                  // шторку оплаты без единого способа.
                  EmptyState(
                    icon: Icons.credit_card_off_rounded,
                    title: s.nothingFound,
                    lead: s.loadingData,
                  ),
                for (final m in methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MethodTile(
                      item: withWalletBalance(m, wallet),
                      selected: selected == m.id,
                      subtitleOverride:
                          selected == m.id && !m.isWallet ? s.mainFromProfile : null,
                      onTap: () => ref.read(payMethodProvider.notifier).select(m.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (notEnough) ...[
          const SizedBox(height: 6),
          Tip(s.walletNotEnough,
              icon: Icons.account_balance_wallet_outlined, tone: ChipTone.bad),
        ],
        if (stub) ...[
          const SizedBox(height: 6),
          Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy || notEnough || methods.isEmpty ? null : _pay,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Brand.onPrimary))
              : Text('${s.pay} ${som(widget.amount)} ${s.som}'),
        ),
      ],
    );
  }
}
