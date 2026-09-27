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
import 'features/history/history_page.dart';
import 'features/history/receipt_page.dart';
import 'features/home/home_page.dart';
import 'features/market/event_page.dart';
import 'features/market/market_page.dart';
import 'features/market/tickets_page.dart';
import 'features/notices/notices_page.dart';
import 'features/objects/object_page.dart';
import 'features/stories/story_viewer_page.dart';
import 'features/payments/autopay_page.dart';
import 'features/payments/new_payment_page.dart';
import 'features/payments/payments_page.dart';
import 'features/payments/qr_page.dart';
import 'features/payments/success_page.dart';
import 'features/profile/accounts_page.dart';
import 'features/profile/addresses_page.dart';
import 'features/profile/family_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/objects_page.dart';
import 'features/profile/personal_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/security_page.dart';
import 'features/reports/reports_page.dart';
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
        path: '/new-payment',
        builder: (_, state) => NewPaymentPage(args: state.extra as NewPaymentArgs?),
      ),
      GoRoute(path: '/qr', builder: (_, _) => const QrPage()),
      GoRoute(
        path: '/object',
        builder: (_, state) => ObjectPage(objectId: state.extra! as String),
      ),
      GoRoute(
        path: '/story',
        builder: (_, state) => StoryViewerPage(initialIndex: (state.extra as int?) ?? 0),
      ),
      GoRoute(path: '/notices', builder: (_, _) => const NoticesPage()),
      GoRoute(path: '/market', builder: (_, _) => const MarketPage()),
      GoRoute(path: '/tickets', builder: (_, _) => const TicketsPage()),
      GoRoute(
        path: '/event',
        builder: (_, state) => EventPage(event: state.extra! as EventItem),
      ),
      GoRoute(path: '/personal', builder: (_, _) => const PersonalPage()),
      GoRoute(path: '/objects', builder: (_, _) => const ObjectsPage()),
      GoRoute(path: '/accounts', builder: (_, _) => const AccountsPage()),
      GoRoute(path: '/addresses', builder: (_, _) => const AddressesPage()),
      GoRoute(path: '/family', builder: (_, _) => const FamilyPage()),
      GoRoute(path: '/security', builder: (_, _) => const SecurityPage()),
      GoRoute(path: '/devices', builder: (_, _) => const DevicesPage()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
      GoRoute(path: '/tariffs', builder: (_, _) => const TariffsPage()),
      GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
      GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
      GoRoute(path: '/autopay', builder: (_, _) => const AutopayPage()),
      GoRoute(
        path: '/receipt',
        builder: (_, state) => ReceiptPage(payment: state.extra! as Payment),
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
            GoRoute(path: '/payments', builder: (_, _) => const PaymentsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
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
