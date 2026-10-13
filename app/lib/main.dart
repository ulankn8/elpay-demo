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
  final store = await LocalStore.open();
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
