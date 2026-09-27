import 'package:elpay/app.dart';
import 'package:elpay/core/prefs.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Первый запуск показывает приветствие и вход', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const ElPayApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Начать'), findsOneWidget);
    expect(find.text('У меня уже есть аккаунт'), findsOneWidget);

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    // Три способа входа: телефон, почта, Telegram.
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('Почта'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
  });
}
