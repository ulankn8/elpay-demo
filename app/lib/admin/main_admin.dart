import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cache/local_store.dart';
import 'data/admin_store.dart';
import 'state/admin_state.dart';
import 'ui/admin_app.dart';

/// Кабинет служб ЭлPay — отдельная точка входа того же пакета:
///   flutter run -d chrome -t lib/admin/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Для проверки в браузере автотестами: дерево доступности включено сразу.
  if (kIsWeb && const bool.fromEnvironment('ENABLE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }
  // Своя приставка ключей: кабинет и мобильное приложение открываются с
  // одного адреса GitHub Pages и иначе делили бы localStorage.
  SharedPreferences.setPrefix('elpay_admin.');
  final store = AdminStore(store: await PrefsLocalStore.open());
  runApp(ProviderScope(
    overrides: [adminStoreProvider.overrideWithValue(store)],
    child: const AdminApp(),
  ));
}
