import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../state/admin_state.dart';
import 'kit.dart';
import 'login_page.dart';
import 'pages/api_page.dart';
import 'pages/audit_page.dart';
import 'pages/charges_page.dart';
import 'pages/import_page.dart';
import 'pages/journal_page.dart';
import 'pages/notify_page.dart';
import 'pages/org_page.dart';
import 'pages/orgs_page.dart';
import 'pages/overview_page.dart';
import 'pages/payments_page.dart';
import 'pages/settings_page.dart';
import 'pages/staff_page.dart';
import 'pages/subscribers_page.dart';
import 'pages/unmatched_page.dart';
import 'shell.dart';

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/svc/overview',
    refreshListenable: refresh,
    redirect: (context, state) {
      final me = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (me == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/') return me.role == Role.admin ? '/adm/orgs' : '/svc/overview';
      if (loc.startsWith('/adm') && me.role != Role.admin) return '/svc/overview';
      return null;
    },
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Страница не найдена', style: T.h1)),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/login'),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/svc/overview',
            pageBuilder: (_, _) => const NoTransitionPage(child: OverviewPage()),
          ),
          GoRoute(
            path: '/svc/subscribers',
            pageBuilder: (_, s) => NoTransitionPage(
              child: SubscribersPage(
                key: ValueKey(s.uri.toString()),
                query: s.uri.queryParameters['q'] ?? '',
                filter: s.uri.queryParameters['f'],
                open: s.uri.queryParameters['open'],
              ),
            ),
          ),
          GoRoute(
            path: '/svc/charges',
            pageBuilder: (_, _) => const NoTransitionPage(child: ChargesPage()),
          ),
          GoRoute(
            path: '/svc/import',
            pageBuilder: (_, s) => NoTransitionPage(child: ImportPage(kind: s.uri.queryParameters['kind'])),
          ),
          GoRoute(
            path: '/svc/import/journal',
            pageBuilder: (_, _) => const NoTransitionPage(child: JournalPage()),
          ),
          GoRoute(
            path: '/svc/payments',
            pageBuilder: (_, s) => NoTransitionPage(child: PaymentsPage(openExport: s.uri.queryParameters['export'] == '1')),
          ),
          GoRoute(
            path: '/svc/notify',
            pageBuilder: (_, s) => NoTransitionPage(child: NotifyPage(segment: s.uri.queryParameters['s'])),
          ),
          GoRoute(
            path: '/svc/staff',
            pageBuilder: (_, _) => const NoTransitionPage(child: StaffPage()),
          ),
          GoRoute(
            path: '/svc/api',
            pageBuilder: (_, _) => const NoTransitionPage(child: ApiPage()),
          ),
          GoRoute(
            path: '/svc/settings',
            pageBuilder: (_, _) => const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: '/adm/orgs',
            pageBuilder: (_, _) => const NoTransitionPage(child: OrgsPage()),
          ),
          GoRoute(
            path: '/adm/orgs/:id',
            pageBuilder: (_, s) => NoTransitionPage(child: OrgPage(id: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/adm/unmatched',
            pageBuilder: (_, _) => const NoTransitionPage(child: UnmatchedPage()),
          ),
          GoRoute(
            path: '/adm/audit',
            pageBuilder: (_, _) => const NoTransitionPage(child: AuditPage()),
          ),
        ],
      ),
    ],
  );
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Кабинет служб ЭлPay',
    debugShowCheckedModeBanner: false,
    theme: adminTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    routerConfig: ref.watch(routerProvider),
  );
}
