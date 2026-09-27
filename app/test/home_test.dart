import 'dart:convert';

import 'package:elpay/app.dart';
import 'package:elpay/core/prefs.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
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

void main() {
  testWidgets('После входа главная показывает счета и кнопку «Оплатить всё»',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.session': jsonEncode(_session.toJson()),
      'flutter.onboarded': true,
    });
    final prefs = await AppPrefs.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const ElPayApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Салам'), findsOneWidget);
    expect(find.text('Счета'), findsOneWidget);
    expect(find.text('Ош-Тазалык'), findsWidgets);
    expect(find.textContaining('Оплатить всё'), findsWidgets);

    // Нижняя навигация — четыре раздела.
    for (final tab in ['Главная', 'Платежи', 'Отчёты', 'Профиль']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('Вкладка «Платежи» открывает кошелёк и каталог', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.session': jsonEncode(_session.toJson()),
      'flutter.onboarded': true,
    });
    final prefs = await AppPrefs.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const ElPayApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Платежи'));
    await tester.pumpAndSettle();

    expect(find.text('Кошелёк ЭлPay'), findsWidgets);
    expect(find.text('Куда платить'), findsOneWidget);
    expect(find.text('Коммунальные услуги'), findsOneWidget);
  });
}
