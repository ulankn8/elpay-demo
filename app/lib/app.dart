import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_theme.dart';
import 'core/l10n/s.dart';
import 'data/models.dart';
import 'features/auth/login_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/setup_page.dart';
import 'features/auth/welcome_page.dart';
import 'features/bills/bill_details_page.dart';
import 'features/home/home_page.dart';
import 'features/payments/success_page.dart';
import 'features/profile/profile_page.dart';
import 'features/shell/shell_page.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final onboarded = ref.read(prefsProvider).onboarded;
      final loc = state.matchedLocation;
      final authArea = loc == '/welcome' || loc == '/login' || loc == '/otp';
      if (!signedIn) return authArea ? null : '/welcome';
      if (signedIn && !onboarded && loc != '/setup') return '/setup';
      if (signedIn && onboarded && authArea) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final args = state.extra as (AuthMethod, String)?;
          return OtpPage(
            method: args?.$1 ?? AuthMethod.phone,
            destination: args?.$2 ?? '',
          );
        },
      ),
      GoRoute(path: '/setup', builder: (_, _) => const SetupPage()),
      GoRoute(
        path: '/bill',
        builder: (_, state) => BillDetailsPage(bill: state.extra! as Bill),
      ),
      GoRoute(
        path: '/success',
        builder: (_, state) {
          final args = state.extra as (double, int, String)?;
          return SuccessPage(
            amount: args?.$1 ?? 0,
            count: args?.$2 ?? 0,
            receiptNo: args?.$3 ?? '',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/payments',
              builder: (context, _) => SoonPage(
                title: S.of(context).tabPayments,
                icon: Icons.account_balance_wallet_outlined,
                lead: S.of(context).paymentsStub,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reports',
              builder: (context, _) => SoonPage(
                title: S.of(context).tabReports,
                icon: Icons.bar_chart_rounded,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>(buildRouter);

class ElPayApp extends ConsumerWidget {
  const ElPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ЭлPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('ru'), Locale('ky')],
      localizationsDelegates: const [
        S.delegate,
        // Кыргызского нет во flutter_localizations: системные строки
        // (кнопки диалогов, подписи полей) берём русские.
        _KyMaterial(),
        _KyWidgets(),
        _KyCupertino(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _KyMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _KyMaterial();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ky';
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ru'));
  @override
  bool shouldReload(_KyMaterial old) => false;
}

class _KyWidgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KyWidgets();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ky';
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('ru'));
  @override
  bool shouldReload(_KyWidgets old) => false;
}

class _KyCupertino extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KyCupertino();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ky';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ru'));
  @override
  bool shouldReload(_KyCupertino old) => false;
}
