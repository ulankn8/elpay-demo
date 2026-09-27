import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Проводит платёж и возвращает номер квитанции (null — не прошло).
/// Один путь для всех оплат: счёт из ленты, платёж по реквизитам, QR.
///
/// Сейчас списание делает заглушка [StubPaymentsRepository]; когда появится
/// боевой шлюз, меняется только репозиторий — этот код останется прежним.
Future<String?> payAndFinish(
  BuildContext context,
  WidgetRef ref, {
  required List<Bill> bills,
  required List<Payment> records,
  required double amount,
}) async {
  final methodId = ref.read(payMethodProvider);
  final result = await ref.read(paymentsRepoProvider).pay(
        bills: bills,
        methodId: methodId,
      );
  if (!context.mounted) return null;

  if (!result.ok) {
    showAppSnack(context, result.reason ?? '');
    return null;
  }

  final no = result.receiptNo ?? '';
  if (bills.isNotEmpty) {
    ref.read(billsProvider.notifier).markPaid(bills.map((b) => b.id));
  }
  if (methodId == 'wallet') ref.read(walletProvider.notifier).spend(amount);
  ref.read(historyProvider.notifier).add([
    for (final p in records)
      Payment(
        id: p.id,
        title: p.title,
        cat: p.cat,
        amount: p.amount,
        date: p.date,
        methodId: methodId,
        receiptNo: no,
        objectId: p.objectId,
        account: p.account,
        period: p.period,
      ),
  ]);
  return no;
}

/// Записи истории из оплаченных счетов.
List<Payment> recordsFromBills(List<Bill> bills, {DateTime? at}) {
  final now = at ?? DateTime.now();
  return [
    for (final b in bills)
      Payment(
        id: 'p-${b.id}-${now.millisecondsSinceEpoch}',
        title: b.title,
        cat: b.cat,
        amount: b.amount,
        date: now,
        methodId: '',
        receiptNo: '',
        objectId: b.objectId,
        account: b.account,
        period: b.period,
      ),
  ];
}

/// Переход на экран успеха с итогом платежа.
void goSuccess(BuildContext context, double amount, int count, String receiptNo) =>
    context.push('/success', extra: (amount, count, receiptNo));
