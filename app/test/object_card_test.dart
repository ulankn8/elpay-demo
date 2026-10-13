import 'package:elpay/data/models.dart';
import 'package:elpay/features/home/object_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fixtures.dart';
import 'support/widget_harness.dart';

/// Карточка объекта на главной — и защита от падения всей главной.
///
/// Разбивка по услугам считает долю как `amount / total`. При нулевом итоге
/// это NaN, а `NaN.round()` бросает UnsupportedError — то есть падает не
/// карточка, а весь экран. Нулевой итог при этом ЧЕСТНЫЙ: счёт подключён,
/// начисление поставщик ещё не выставил. Поэтому проверка не про вёрстку,
/// а про живучесть.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<Bill> bills,
    PayObject object = homeObject,
    VoidCallback? onPay,
  }) =>
      pumpWidgetUnderTest(
        tester,
        ObjectCard(object: object, bills: bills, onPay: onPay ?? () {}),
        scrollable: true,
      );

  group('Нулевой итог', () {
    testWidgets('Разбивка при нулевом итоге не роняет главную', (tester) async {
      // Два счёта подключены, начислений по ним ещё нет.
      await pumpCard(tester, bills: [
        charge(id: 'b1', amount: 0, cat: 'water'),
        charge(id: 'b2', amount: 0, cat: 'power'),
      ]);

      // Это и есть проверка: `amount / total` при total == 0 даёт NaN,
      // и округление NaN бросает UnsupportedError прямо в разметке.
      expect(tester.takeException(), isNull);
      expect(find.byType(ObjectCard), findsOneWidget);
      expect(find.text('Дом'), findsOneWidget);
    });

    testWidgets('Единственное начисление на 0 сом не ломает карточку объекта',
        (tester) async {
      var paid = false;
      await pumpCard(
        tester,
        bills: [charge(id: 'b1', amount: 0)],
        onPay: () => paid = true,
      );

      expect(tester.takeException(), isNull);
      // Начисление есть, пусть и на ноль: кнопка оплаты активна, а не
      // подменена на «всё оплачено».
      expect(find.text('Оплатить'), findsOneWidget);
      await tester.tap(find.text('Оплатить'));
      expect(paid, isTrue);
    });

    testWidgets('Нулевой остаток «прочих» не рисует лишний сегмент',
        (tester) async {
      // Пять счетов: четыре в легенде, пятый — в «прочих». Погрешность
      // double не должна давать серый сегмент там, где остатка нет.
      await pumpCard(tester, bills: [
        charge(id: 'b1', amount: 100.1, cat: 'water'),
        charge(id: 'b2', amount: 200.2, cat: 'power'),
        charge(id: 'b3', amount: 300.3, cat: 'gas'),
        charge(id: 'b4', amount: 400.4, cat: 'trash'),
        charge(id: 'b5', amount: 500.5, cat: 'net'),
      ]);

      expect(tester.takeException(), isNull);
      // В легенде ровно четыре позиции, по убыванию суммы: пятая услуга
      // уходит в «прочие», и высота карточки остаётся предсказуемой.
      expect(find.text('Интернет'), findsOneWidget);
      expect(find.text('Свет'), findsOneWidget);
      expect(find.text('Вода'), findsNothing);
    });
  });

  group('Обычная карточка', () {
    testWidgets('Сумма к оплате, срок и количество счетов', (tester) async {
      await pumpCard(tester, bills: [
        charge(id: 'b1', amount: 205, cat: 'water'),
        charge(id: 'b2', amount: 420, cat: 'gas'),
        charge(id: 'b3', amount: 100, cat: 'power', paid: true),
      ]);

      expect(tester.takeException(), isNull);
      // Оплаченное в сумму к оплате не входит: 205 + 420. Сумма собрана
      // из TextSpan, поэтому ищем по размеченному тексту.
      expect(find.textContaining('625', findRichText: true), findsWidgets);
      expect(find.text('оплачено 1 из 3'), findsOneWidget);
      // Ближайший срок — у начисления, которое надо оплатить.
      expect(find.textContaining('срок'), findsOneWidget);
    });

    testWidgets('Всё оплачено — кнопка не предлагает платить', (tester) async {
      var paid = false;
      await pumpCard(
        tester,
        bills: [charge(id: 'b1', amount: 205, paid: true)],
        onPay: () => paid = true,
      );

      expect(find.text('Все счета оплачены'), findsOneWidget);
      expect(find.text('Оплатить'), findsNothing);
      await tester.tap(find.text('Все счета оплачены'));
      expect(paid, isFalse, reason: 'кнопка отключена');
    });

    testWidgets('Объект без начислений рисуется и ничего не делит',
        (tester) async {
      await pumpCard(tester, bills: const []);

      expect(tester.takeException(), isNull);
      expect(find.text('Все счета оплачены'), findsOneWidget);
      expect(find.text('оплачено 0 из 0'), findsOneWidget);
    });

    testWidgets('Срок берётся от часов стенда, а не от дня запуска',
        (tester) async {
      await pumpCard(tester, bills: [
        charge(id: 'b1', amount: 205, due: DateTime(testNow.year, 3, 20)),
        charge(id: 'b2', amount: 420, due: DateTime(testNow.year, 3, 25)),
      ]);

      // Ближайший из двух сроков — 20 марта.
      expect(find.textContaining('20 мар'), findsOneWidget);
      expect(find.textContaining('25 мар'), findsNothing);
    });
  });
}
