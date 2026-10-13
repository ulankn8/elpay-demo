import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/result.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/data/payments_repository.dart';
import 'package:elpay/features/payments/pay_flow.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fixtures.dart';
import 'support/widget_harness.dart';

/// Платёжный шлюз осознанно остаётся заглушкой — но ШВЫ вокруг него
/// боевые, и правятся они один раз.
///
/// Поэтому здесь проверяется не «деньги списались», а то, что при
/// подключении настоящего шлюза не придётся переписывать экраны:
/// ключ идемпотентности защищает от двойного списания, частичная сумма
/// доезжает до репозитория, а не теряется по дороге, и остаток кошелька
/// проверяется ДО списания.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Заглушка процессинга', () {
    test('Заглушка возвращает успех и номер квитанции', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final result = await env.payments.charge(
        bills: [charge(id: 'b1', amount: 205)],
        methodId: 'visa',
        key: env.ids.key('payments.pay'),
      );

      expect(result.isOk, isTrue);
      final pay = result.valueOrNull!;
      expect(pay.status, PayStatus.success);
      expect(pay.receiptNo, isNotNull);
      expect(pay.receiptNo, isNotEmpty);
      // Экран обязан честно предупредить: шлюза ещё нет.
      expect(env.payments.isStub, isTrue);
    });

    test('Повторный вызов с тем же ключом не проводит платёж дважды',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final key = env.ids.key('payments.pay');
      final bills = [charge(id: 'b1', amount: 205)];

      final first = await env.payments.charge(bills: bills, methodId: 'visa', key: key);
      final again = await env.payments.charge(bills: bills, methodId: 'visa', key: key);

      expect(first.isOk, isTrue);
      expect(again.isOk, isTrue);
      // Тот же ключ — тот же номер квитанции: именно так боевой шлюз
      // отличает повтор по кнопке от второго платежа.
      expect(again.valueOrNull!.receiptNo, first.valueOrNull!.receiptNo);
    });

    test('Разные попытки получают разные номера квитанций', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final bills = [charge(id: 'b1', amount: 205)];

      final first = await env.payments
          .charge(bills: bills, methodId: 'visa', key: env.ids.key('payments.pay'));
      final second = await env.payments
          .charge(bills: bills, methodId: 'visa', key: env.ids.key('payments.pay'));

      expect(second.valueOrNull!.receiptNo, isNot(first.valueOrNull!.receiptNo));
    });

    test('status дочитывает исход попытки по ключу', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final key = env.ids.key('payments.pay');

      // Про незнакомый ключ шлюз ничего не знает — и это notFound,
      // а не «платежа не было».
      final unknown = await env.payments.status(key);
      expect(unknown.isFail, isTrue);
      expect(unknown.failureOrNull!.kind, FailureKind.notFound);

      final paid = await env.payments
          .charge(bills: [charge(id: 'b1')], methodId: 'visa', key: key);
      final known = await env.payments.status(key);

      expect(known.isOk, isTrue);
      // Боевой шлюз асинхронный: экран дочитывает исход после обрыва
      // связи или перезапуска — и обязан получить ТОТ ЖЕ результат.
      expect(known.valueOrNull!.receiptNo, paid.valueOrNull!.receiptNo);
    });

    test('Частичная сумма проверяется, а не принимается на веру', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final bills = [charge(id: 'b1', amount: 205)];
      IdempotencyKey key() => env.ids.key('payments.pay');

      final zero = await env.payments
          .charge(bills: bills, methodId: 'visa', key: key(), partialAmount: 0);
      expect(zero.isFail, isTrue);
      expect(zero.failureOrNull!.kind, FailureKind.validation);
      expect(zero.failureOrNull!.field, 'amount');

      final tooMuch = await env.payments
          .charge(bills: bills, methodId: 'visa', key: key(), partialAmount: 500);
      expect(tooMuch.failureOrNull!.field, 'amount');

      // По двум начислениям частичная сумма непонятно к какому относится.
      final twoBills = await env.payments.charge(
        bills: [charge(id: 'b1'), charge(id: 'b2')],
        methodId: 'visa',
        key: key(),
        partialAmount: 50,
      );
      expect(twoBills.failureOrNull!.field, 'amount');

      final ok = await env.payments
          .charge(bills: bills, methodId: 'visa', key: key(), partialAmount: 100);
      expect(ok.isOk, isTrue);
    });
  });

  group('Путь оплаты до репозитория', () {
    /// Записывает, с чем пришли, и передаёт вызов заглушке.
    ///
    /// Без этого «partialAmount доезжает до репозитория» не проверить:
    /// заглушка отвечает успехом в обоих случаях, и потерю суммы по дороге
    /// видно только по тому, ЧТО ей передали.
    late _RecordingPayments recorder;

    /// Нажать «Оплатить» ровно так, как это делает экран оплаты.
    Future<String?> pay(
      WidgetTester tester, {
      required TestEnv env,
      required List<Bill> bills,
      required double amount,
      String methodId = 'visa',
    }) async {
      String? receipt;
      final overrides = await env.overrides(
        paymentsRepo: recorder,
        session: testSession,
      );
      await pumpWidgetUnderTest(
        tester,
        Consumer(
          builder: (context, ref, _) => FilledButton(
            onPressed: () async {
              ref.read(payMethodProvider.notifier).select(methodId);
              receipt = await payAndFinish(
                context,
                ref,
                bills: bills,
                records: recordsFromBills(bills, at: env.now),
                amount: amount,
              );
            },
            child: const Text('Оплатить'),
          ),
        ),
        overrides: overrides,
      );
      await tester.tap(find.text('Оплатить'));
      await settleData(tester);
      return receipt;
    }

    setUp(() => recorder = _RecordingPayments(StubPaymentsRepository(
          clock: () => testNow,
          latency: Duration.zero,
        )));

    testWidgets('partialAmount доезжает до репозитория', (tester) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final bills = [charge(id: 'b1', amount: 205)];

      final receipt = await pay(tester, env: env, bills: bills, amount: 100);

      expect(receipt, isNotNull);
      expect(recorder.calls, hasLength(1));
      // Раньше сумма с экрана до шлюза не доезжала вообще: он получал
      // только список начислений и списывал их целиком.
      expect(recorder.calls.single.partialAmount, 100);
      expect(recorder.calls.single.bills.single.id, 'b1');
      expect(recorder.calls.single.key.value, startsWith('payments.pay'));
    });

    testWidgets('Полная сумма идёт без partialAmount', (tester) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final bills = [charge(id: 'b1', amount: 205)];

      await pay(tester, env: env, bills: bills, amount: 205);

      // Сумма равна итогу начислений — частичной оплаты нет, и шлюзу
      // не надо сообщать «заплатить столько же, сколько начислено».
      expect(recorder.calls.single.partialAmount, isNull);
    });

    testWidgets('Платёж по реквизитам без начислений несёт свою сумму',
        (tester) async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await pay(tester, env: env, bills: const [], amount: 350);

      expect(recorder.calls.single.bills, isEmpty);
      expect(recorder.calls.single.partialAmount, 350);
    });

    testWidgets('Недостаточный баланс кошелька не даёт провести оплату '
        'и не уводит баланс в ноль', (tester) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      // На кошельке 1240, начислено 5000.
      final bills = [charge(id: 'b-big', amount: 5000)];

      final receipt = await pay(
        tester,
        env: env,
        bills: bills,
        amount: 5000,
        methodId: 'wallet',
      );

      expect(receipt, isNull);
      // До шлюза дело не доходит: остаток проверяется ДО списания.
      expect(recorder.calls, isEmpty);
      expect(find.text('На кошельке недостаточно средств'), findsOneWidget);
      // И баланс остался прежним: spend() делает clamp(0, ∞), поэтому
      // без проверки остатка кошелёк просто уезжал в ноль.
      expect(_walletOf(tester), closeTo(1240, 0.001));
    });

    testWidgets('Оплата кошельком в пределах остатка списывает ровно сумму',
        (tester) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final bills = [charge(id: 'b1', amount: 205)];

      final receipt = await pay(
        tester,
        env: env,
        bills: bills,
        amount: 205,
        methodId: 'wallet',
      );

      expect(receipt, isNotNull);
      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.methodId, 'wallet');
      // «Списывает ровно сумму» — это про баланс, а не про квитанцию:
      // без этой проверки тест оставался зелёным и при выброшенном
      // списании, то есть кошельком можно было платить бесконечно.
      expect(_walletOf(tester), closeTo(1240 - 205, 0.001));
    });
  });
}

/// Баланс кошелька в контейнере, который поднял виджет-тест.
///
/// Берётся из того же ProviderScope, что видит экран оплаты: отдельный
/// контейнер показал бы начальное значение, а не состояние после оплаты.
double _walletOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.text('Оплатить'))).read(walletProvider);

/// Что передали шлюзу на одной попытке.
class _PayCall {
  const _PayCall({
    required this.bills,
    required this.methodId,
    required this.key,
    required this.partialAmount,
  });

  final List<Bill> bills;
  final String methodId;
  final IdempotencyKey key;
  final double? partialAmount;
}

/// Прослойка над заглушкой: записывает вызовы, поведение не меняет.
class _RecordingPayments extends PaymentsRepository {
  _RecordingPayments(this.inner);

  final PaymentsRepository inner;
  final List<_PayCall> calls = [];

  @override
  bool get isStub => inner.isStub;

  @override
  Future<Result<PayResult>> charge({
    required List<Bill> bills,
    required String methodId,
    required IdempotencyKey key,
    double? partialAmount,
  }) {
    calls.add(_PayCall(
      bills: bills,
      methodId: methodId,
      key: key,
      partialAmount: partialAmount,
    ));
    return inner.charge(
      bills: bills,
      methodId: methodId,
      key: key,
      partialAmount: partialAmount,
    );
  }

  @override
  Future<Result<PayResult>> status(IdempotencyKey key) => inner.status(key);
}
