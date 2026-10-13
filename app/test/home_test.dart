import 'package:elpay/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fixtures.dart';
import 'support/widget_harness.dart';

/// Главная и вкладка «Платежи» — приложение целиком, после входа.
///
/// Стенд (`makeEnv`) даёт фиксированные часы, хранилище в памяти и
/// демо-бэкенд без задержки: прогон перестал ждать по 420 мс на каждый
/// запрос, а даты в начислениях не зависят от дня запуска.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Запустить приложение вошедшим пользователем.
  Future<TestEnv> openApp(WidgetTester tester) async {
    final env = makeEnv();
    addTearDown(env.dispose);
    phoneSurface(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: await env.overrides(session: testSession),
        child: const ElPayApp(),
      ),
    );
    await settleData(tester);
    return env;
  }

  testWidgets('После входа главная показывает сторисы, объекты и «Новую оплату»',
      (tester) async {
    await openApp(tester);

    expect(find.textContaining('Салам'), findsOneWidget);
    // сторисы: первая карточка ленты
    expect(find.textContaining('Завтра'), findsWidgets);
    // карточка объекта с кнопкой «Оплатить»
    expect(find.text('Дом'), findsOneWidget);
    expect(find.text('Оплатить'), findsWidgets);
    expect(find.text('Новая оплата'), findsOneWidget);

    // Нижняя навигация — четыре раздела.
    for (final tab in ['Главная', 'Платежи', 'Отчёты', 'Профиль']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('Главная не печатает сырые исключения вместо данных',
      (tester) async {
    await openApp(tester);

    // Единственным показом ошибки на главной когда-то был Text('$e') —
    // пользователь читал «AppFailure(network): нет связи».
    expect(find.textContaining('AppFailure'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Вкладка «Платежи» открывает кошелёк и разделы', (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Платежи'));
    await settleData(tester);

    expect(find.text('Кошелёк ЭлPay'), findsWidgets);
    expect(find.text('История платежей'), findsWidgets);
    expect(find.text('Способы оплаты'), findsOneWidget);
  });
}
