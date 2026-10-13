import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/cache/local_store.dart';
import 'core/logger.dart';
import 'core/prefs.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Перехват падений. Своей отправки у нас нет (Sentry и Crashlytics
  // не подключены), но точка интеграции теперь ОДНА: до этого ошибки
  // в обработчиках и в дереве виджетов уходили в никуда.
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    Log.e('ошибка', details.library ?? 'flutter', details.exception, details.stack);
    flutterOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e('ошибка', 'необработанное исключение', error, stack);
    // true — приложение продолжает работать: падать из-за ошибки в фоновой
    // задаче нельзя, а видно её теперь в логе.
    return true;
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Для автотестов веб-сборки: включаем дерево семантики,
  // чтобы кнопки были видны инструментам проверки.
  if (kIsWeb && const bool.fromEnvironment('ENABLE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final prefs = await AppPrefs.open();
  final store = await PrefsLocalStore.open();
  Log.i('старт', AppConfig.current.isDemo
      ? 'демо-режим: данные из встроенного реестра'
      : 'боевой режим: ${AppConfig.current.apiBaseUrl}');
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(store),
      ],
      child: const ElPayApp(),
    ),
  );
}
