import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'method_picker.dart';
import 'pay_flow.dart';

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

  Future<void> _pay() async {
    setState(() => _busy = true);
    final no = await payAndFinish(
      context,
      ref,
      bills: widget.bills,
      records: widget.records,
      amount: widget.amount,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (no == null) return;
    Navigator.of(context).pop();
    widget.onPaid?.call();
    goSuccess(context, widget.amount, widget.records.length, no);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final selected = ref.watch(payMethodProvider);
    final wallet = ref.watch(walletProvider);
    final stub = ref.read(paymentsRepoProvider).isStub;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Brand.gutter, 6, Brand.gutter, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 3),
              child: Text(s.payWithTitle, style: context.t.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 16),
              child: Text(s.payWithLead, style: context.t.bodySmall),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final m in Demo.methods)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MethodTile(
                          item: m.isWallet
                              ? PayMethodItem(
                                  id: m.id,
                                  title: m.title,
                                  subtitle: m.subtitle,
                                  badge: m.badge,
                                  isWallet: true,
                                  balance: wallet)
                              : m,
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
            if (stub) ...[
              const SizedBox(height: 6),
              Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Brand.onPrimary))
                  : Text('${s.pay} ${som(widget.amount)} ${s.som}'),
            ),
          ],
        ),
      ),
    );
  }
}
