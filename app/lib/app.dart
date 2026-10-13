import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics.dart';
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
import 'features/accounts/account_page.dart';
import 'features/accounts/accounts_page.dart';
import 'features/accounts/connect_args.dart';
import 'features/accounts/connect_page.dart';
import 'features/profile/addresses_page.dart';
import 'features/profile/family_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/objects_page.dart';
import 'features/profile/personal_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/security_page.dart';
import 'features/reports/reports_page.dart';
import 'features/shell/not_found_page.dart';
import 'features/shell/shell_page.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(Ref ref) {
  // Смена сессии меняет набор доступных экранов: без refreshListenable
  // выход из аккаунта не вызывал redirect, и это приходилось
  // компенсировать ручными context.go в экранах.
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/welcome',
    refreshListenable: refresh,
    // События экрана уже были описаны в Analytics, но не отправлялись
    // ниоткуда: один наблюдатель закрывает это для всех переходов сразу.
    observers: [_ScreenObserver(ref.read(analyticsProvider))],
    // Нераспознанная и устаревшая ссылка открывает понятную страницу,
    // а не роняет приложение.
    errorBuilder: (_, state) => NotFoundPage(location: state.uri.toString()),
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
        // Прямой вход по ссылке приходит без extra — раньше это было
        // падение на force-unwrap прямо в сборке экрана.
        builder: (_, state) => switch (state.extra) {
          final Bill bill => BillDetailsPage(bill: bill),
          _ => NotFoundPage(location: state.uri.toString()),
        },
      ),
      GoRoute(
        path: '/new-payment',
        builder: (_, state) => NewPaymentPage(args: state.extra as NewPaymentArgs?),
      ),
      GoRoute(path: '/qr', builder: (_, _) => const QrPage()),
      GoRoute(
        path: '/object',
        builder: (_, state) => switch (state.extra) {
          final String id when id.isNotEmpty => ObjectPage(objectId: id),
          _ => NotFoundPage(location: state.uri.toString()),
        },
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
        builder: (_, state) => switch (state.extra) {
          final EventItem event => EventPage(event: event),
          _ => NotFoundPage(location: state.uri.toString()),
        },
      ),
      GoRoute(path: '/personal', builder: (_, _) => const PersonalPage()),
      GoRoute(path: '/objects', builder: (_, _) => const ObjectsPage()),
      GoRoute(path: '/accounts', builder: (_, _) => const AccountsPage()),
      GoRoute(
        // Экран подключённого счёта открывается по path-параметру, а не
        // через extra: прямой вход и ссылка работают, а не падают.
        path: '/accounts/:id',
        builder: (_, state) => AccountPage(accountId: state.pathParameters['id'] ?? ''),
      ),
      // Короткая форма той же ссылки: /account/o-1 ведёт туда же.
      GoRoute(
        path: '/account/:id',
        redirect: (_, state) => '/accounts/${state.pathParameters['id'] ?? ''}',
      ),
      GoRoute(
        // ЕДИНСТВЕННЫЙ вход в мастер подключения. Аргументы берутся из
        // ссылки, поэтому /connect?provider=p-water&source=story работает
        // и при прямом переходе.
        path: '/connect',
        builder: (_, state) {
          final args = ConnectArgs.fromQuery(state.uri.queryParameters);
          final extra = state.extra;
          // СОВМЕСТИМОСТЬ: значок услуги пока передаёт providerId через
          // extra. Когда он перейдёт на ConnectArgs.location, ветка уйдёт.
          if (extra is String && extra.isNotEmpty) {
            return ConnectAccountPage(
              args: ConnectArgs(
                providerId: extra,
                objectId: args.objectId,
                source: args.source == ConnectArgs.sourceManual
                    ? ConnectArgs.sourceService
                    : args.source,
              ),
            );
          }
          return ConnectAccountPage(args: args);
        },
      ),
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
        builder: (_, state) => switch (state.extra) {
          final Payment payment => ReceiptPage(payment: payment),
          _ => NotFoundPage(location: state.uri.toString()),
        },
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
    // ЕДИНСТВЕННЫЙ слушатель сети на всё приложение: он разгружает очередь
    // отложенных операций. Без этой строки подключение, сделанное без
    // сети, лежало бы в очереди и не отправлялось никогда.
    ref.watch(syncWatcherProvider);
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

/// Пересчёт маршрутов при входе и выходе.
///
/// `redirect` читает сессию через `ref.read`, поэтому сам об изменении не
/// узнаёт: об этом ему сообщает этот слушатель.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    _sub = ref.listen<Session?>(sessionProvider, (previous, next) {
      // Правка профиля меняет сессию, но не меняет доступные экраны:
      // перестраиваем маршруты только на вход и выход.
      if ((previous == null) != (next == null)) notifyListeners();
    });
  }

  late final ProviderSubscription<Session?> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Отправляет `screen_view` на каждый переход.
class _ScreenObserver extends NavigatorObserver {
  _ScreenObserver(this._analytics);

  final Analytics _analytics;

  void _track(Route<dynamic>? route) {
    // go_router подставляет в settings.name путь маршрута; у системных
    // маршрутов (шторки, диалоги) имени нет — такие события не нужны.
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.track(AnalyticsEvent.screen(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _track(newRoute);
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
