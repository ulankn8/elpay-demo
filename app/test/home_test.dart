import 'dart:convert';

import 'package:elpay/app.dart';
import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/prefs.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = Session(
  id: 'u-test',
  name: 'Токтогулова Айгерим',
  phone: '+996 555 12 34 56',
  method: AuthMethod.phone,
  address: 'ул. Курманжан Датка, 212',
);

/// Мок-API отвечает с задержкой и несколькими шагами подряд:
/// прокручиваем таймеры, пока экран не получит данные.
Future<void> _loadData(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
}

/// Экран телефона: иначе в тесте виден только верх списка.
void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('После входа главная показывает сторисы, объекты и «Новую оплату»',
      (tester) async {
    _phoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'flutter.session': jsonEncode(_session.toJson()),
      'flutter.onboarded': true,
    });
    final prefs = await AppPrefs.open();
    final store = await LocalStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          localStoreProvider.overrideWithValue(store),
        ],
        child: const ElPayApp(),
      ),
    );
    await _loadData(tester);

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

  testWidgets('Вкладка «Платежи» открывает кошелёк и разделы', (tester) async {
    _phoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'flutter.session': jsonEncode(_session.toJson()),
      'flutter.onboarded': true,
    });
    final prefs = await AppPrefs.open();
    final store = await LocalStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          localStoreProvider.overrideWithValue(store),
        ],
        child: const ElPayApp(),
      ),
    );
    await _loadData(tester);

    await tester.tap(find.text('Платежи'));
    await _loadData(tester);

    expect(find.text('Кошелёк ЭлPay'), findsWidgets);
    expect(find.text('История платежей'), findsWidgets);
    expect(find.text('Способы оплаты'), findsOneWidget);
  });
}
