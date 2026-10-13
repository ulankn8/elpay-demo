import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart';
import '../../core/failure.dart';
import '../../core/ids.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

const _tag = 'pay-flow';

/// Деньги здесь double, поэтому «та же сумма» — это разница в копейку.
/// Долг записан в плане: переход на int тыйын делается перед шлюзом.
const _epsilon = 0.01;

/// Проводит платёж и возвращает номер квитанции (null — не прошло).
/// Один путь для всех оплат: счёт из ленты, платёж по реквизитам, QR, билет.
///
/// ОПЛАТА ОСТАЁТСЯ ЗАГЛУШКОЙ: списание делает [StubPaymentsRepository],
/// который всегда отвечает успехом, поэтому ветки «отказ» и «нет сети» ниже
/// против живого шлюза не проверены — это известная дыра, и закрывается она
/// вместе с боевой реализацией. Экраны об этом честно предупреждают плашкой
/// по `paymentsRepoProvider.isStub`.
///
/// [key] передаёт экран, который умеет повторить попытку: повтор по кнопке
/// идёт с тем же ключом идемпотентности, и шлюз не спишет деньги дважды.
/// Не передали — ключ выдаётся на эту попытку.
Future<String?> payAndFinish(
  BuildContext context,
  WidgetRef ref, {
  required List<Bill> bills,
  required List<Payment> records,
  required double amount,
  IdempotencyKey? key,
}) async {
  final s = S.of(context);
  final methodId = ref.read(payMethodProvider);
  // Каталог мог ещё не доехать — тогда кошелёк опознаётся по id, как раньше.
  final isWallet = ref.read(catalogNowProvider).methodById(methodId)?.isWallet ??
      methodId == 'wallet';

  // Остаток кошелька проверяется ДО списания. Раньше проверки не было, а
  // `spend()` делает clamp(0, ∞): платёж «проходил», а баланс просто уезжал
  // в ноль — и пользователь узнавал об этом по балансу, а не по сообщению.
  if (isWallet && ref.read(walletProvider) + _epsilon < amount) {
    showAppSnack(context, s.walletNotEnough);
    return null;
  }

  final analytics = ref.read(analyticsProvider);
  analytics.track(AnalyticsEvent.payStarted(amount, bills.length));

  // ОДИН ключ идемпотентности на попытку оплаты.
  final attempt = key ?? ref.read(idGenProvider).key('payments.pay');

  final result = await ref.read(paymentsRepoProvider).charge(
        bills: bills,
        methodId: methodId,
        key: attempt,
        partialAmount: _partialOf(bills, amount),
      );
  if (!context.mounted) return null;

  final PayResult pay;
  switch (result) {
    case Fail(:final failure):
      // Раньше здесь было `result.reason ?? ''`, а reason всегда null —
      // при отказе пользователь получал пустой снек.
      Log.w(_tag, 'платёж ${attempt.value} не прошёл: ${failure.message}');
      showAppSnack(context, failureTitle(s, failure));
      return null;
    case Ok(:final value):
      pay = value;
  }

  final no = pay.receiptNo ?? '';
  if (pay.status == PayStatus.declined) {
    // Причину отказа называет процессинг; молчит — показываем текст из S,
    // а не пустую строку.
    final reason = pay.reason ?? '';
    showAppSnack(
      context,
      reason.isEmpty
          ? failureTitle(s, const AppFailure(FailureKind.unknown, message: 'отказ шлюза'))
          : reason,
    );
    return null;
  }
  if (pay.status == PayStatus.offline) {
    showAppSnack(context, failureTitle(s, const AppFailure.network()));
    return null;
  }
  if (no.isEmpty) {
    // «Платёж принят, подтверждаем»: боевой шлюз асинхронный — отвечает
    // «принято», а исход приходит позже (и его дочитывает
    // `PaymentsRepository.status(key)`). Значения PayStatus.pending в модели
    // пока нет (его добавляет лана моделей), поэтому случай опознаётся по
    // отсутствию номера квитанции: списание принято, квитанции ещё нет.
    // Счёт оплаченным НЕ помечаем и на экран успеха не уходим.
    showAppSnack(context, s.payPending);
    return null;
  }

  if (bills.isNotEmpty) {
    // Номер квитанции приходит от процессинга — клиент его не выдумывает.
    final marked = await ref.read(billsProvider.notifier).markPaid(
          [for (final b in bills) b.id],
          receiptNo: no,
        );
    // Деньги уже списаны: из-за неудачной отметки терять квитанцию нельзя.
    // Состояние вернётся на следующем обновлении начислений.
    if (marked case Fail(:final failure)) {
      Log.w(_tag, 'оплата прошла, отметка не сохранилась: ${failure.message}');
    }
  }
  if (isWallet) ref.read(walletProvider.notifier).spend(amount);
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
  analytics.track(AnalyticsEvent.payDone(amount, methodId));
  return no;
}

/// Сумма для шлюза, когда она не равна итогу начислений: платёж по
/// реквизитам, QR и билет (начислений нет) или частичная оплата счёта.
///
/// `partialAmount` объявлен в контракте платежей, но pay_flow его не
/// передавал: шлюз всегда получал только список начислений, а сумма с экрана
/// до него не доезжала.
double? _partialOf(List<Bill> bills, double amount) {
  if (bills.isEmpty) return amount;
  final total = bills.fold<double>(0, (sum, b) => sum + b.amount);
  if ((total - amount).abs() <= _epsilon) return null;
  return amount;
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
