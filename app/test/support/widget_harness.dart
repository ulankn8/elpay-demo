import 'package:elpay/core/app_theme.dart';
import 'package:elpay/core/l10n/s.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Тип Override лежит в отдельной точке входа riverpod 3.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Обвязка виджет-тестов: ровно то окружение, которое даёт экрану `ElPayApp`,
/// но без маршрутизации и без настоящих SharedPreferences.
///
/// Без неё каждый виджет-тест начинался бы с двадцати строк: тема (виджеты
/// читают `context.c` — это ThemeExtension, и без темы они падают),
/// делегаты локализации (`S.of(context)` иначе null), экран телефона
/// (иначе виден только верх списка) и ProviderScope с подменами стенда.

/// Экран телефона. Без него тест видит обрезанный список, а
/// `tester.tap` по кнопке внизу карточки промахивается.
void phoneSurface(WidgetTester tester, {Size size = const Size(393, 852)}) {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Делегаты локализации приложения. Кыргызского нет во flutter_localizations,
/// поэтому в тестах берём русскую локаль — ту же, что по умолчанию в бою.
const _delegates = <LocalizationsDelegate<Object?>>[
  S.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Показать один виджет так, как его видит пользователь.
///
/// [child] оборачивается в `Scaffold`, если он не экран целиком —
/// это нужно и для `ScaffoldMessenger`, без которого `showAppSnack`
/// бросает исключение.
Future<void> pumpWidgetUnderTest(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool wrapInScaffold = true,
  bool scrollable = false,
}) async {
  phoneSurface(tester);
  final body = scrollable
      ? SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))
      : child;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: _delegates,
        theme: AppTheme.light(),
        home: wrapInScaffold ? Scaffold(body: SafeArea(child: body)) : body,
      ),
    ),
  );
  // Делегаты локализации грузятся асинхронно (`_SDelegate.load` — async),
  // и до второго кадра `Localizations` рисует SizedBox.shrink: без этой
  // прокрутки find.text не находит вообще ничего.
  await tester.pump();
}

/// Показать экран, который сам себе `Scaffold` и ходит по маршрутам
/// (`context.push('/accounts')`).
///
/// Маршруты-заглушки отвечают своим названием: тест проверяет, что экран
/// УШЁЛ куда надо, а не что там нарисовано.
Future<void> pumpRouteUnderTest(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Map<String, String> stubs = const {
    '/accounts': 'ЗАГЛУШКА: счета',
    '/accounts/:id': 'ЗАГЛУШКА: счёт',
    '/objects': 'ЗАГЛУШКА: объекты',
  },
}) async {
  phoneSurface(tester);
  final router = GoRouter(
    initialLocation: '/under-test',
    routes: [
      GoRoute(path: '/under-test', builder: (_, _) => screen),
      for (final entry in stubs.entries)
        GoRoute(
          path: entry.key,
          builder: (_, _) => Scaffold(body: Center(child: Text(entry.value))),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: _delegates,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  // См. [pumpWidgetUnderTest]: первый кадр ещё без локализации.
  await tester.pump();
}

/// Прокрутить фейковые таймеры до ответа мока.
///
/// `pumpAndSettle` в одиночку здесь НЕ работает: когда на экране нет
/// анимации, он возвращается сразу, а демо-бэкенд отвечает с задержкой
/// в несколько шагов (`Future.delayed` на каждый запрос). Поэтому сначала
/// несколько явных шагов по полсекунды, и только потом settle — он
/// докручивает анимацию появления.
Future<void> settleData(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
}
