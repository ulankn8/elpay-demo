import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../bills/bill_row.dart';
import '../payments/method_picker.dart';

/// Квитанция об оплате: то, что показывают контролёру или бухгалтеру.
class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key, required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final method = methodById(ref, payment.methodId);

    return Scaffold(
      appBar: AppBar(title: Text(s.receiptTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                        color: Brand.light2, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Brand.p700, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(s.tr(payment.title), style: context.t.titleLarge),
                  const SizedBox(height: 4),
                  Text(s.longDateText(payment.date), style: context.t.bodySmall),
                  const SizedBox(height: 14),
                  Amount(som(payment.amount), size: 30),
                ],
              ),
            ),
            const SizedBox(height: 18),
            KeyValueBox([
              (s.receiptNo, payment.receiptNo),
              (s.paidAt, '${s.longDateText(payment.date)}, ${hhmm(payment.date)}'),
              (s.methodLabel, s.tr(method.title)),
              if (payment.account.isNotEmpty) (s.account, payment.account),
              if (payment.period.isNotEmpty) (s.period, payment.period),
            ]),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                children: [
                  AppRow(
                    leading: CatTile('net', Icons.ios_share_rounded, soft: true),
                    title: s.share,
                    onTap: () => showAppSnack(context, s.soonHere),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile('tax', Icons.picture_as_pdf_outlined, soft: true),
                    title: s.savePdf,
                    onTap: () => showAppSnack(context, s.soonHere),
                  ),
                  const RowDivider(),
                  AppRow(
                    leading: CatTile(payment.cat, catIcon(payment.cat), soft: true),
                    title: s.repeatPay,
                    onTap: () => showAppSnack(context, s.paymentsStub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
