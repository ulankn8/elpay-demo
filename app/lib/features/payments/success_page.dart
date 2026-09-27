import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key, required this.amount, required this.count, this.receiptNo = ''});
  final double amount;
  final int count;
  final String receiptNo;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 40, Brand.gutter, 20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(color: c.chipOkBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 52, color: Brand.p600),
              ),
              const SizedBox(height: 22),
              Text(s.paidTitle, style: context.t.headlineMedium),
              const SizedBox(height: 10),
              Amount(som(amount), size: 34),
              const SizedBox(height: 10),
              Text(s.paidLead,
                  textAlign: TextAlign.center,
                  style: context.t.bodyMedium?.copyWith(color: c.muted)),
              if (receiptNo.isNotEmpty) ...[
                const SizedBox(height: 14),
                AppChip('№ $receiptNo', tone: ChipTone.soft),
              ],
              const Spacer(),
              Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(s.done),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => showAppSnack(context, s.soonHere),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(s.shareReceipts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
