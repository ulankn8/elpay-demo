import 'package:elpay/admin/data/admin_store.dart';
import 'package:elpay/admin/data/seed.dart';
import 'package:elpay/admin/state/admin_state.dart';
import 'package:elpay/admin/ui/admin_app.dart';
import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final seed = generateSeed();

/// Каждый экран кабинета на ноутбуке и в узком окне — без переполнений.
/// В релизной веб-сборке Flutter их не рисует, и обрезанный текст молча
/// пропадает; ловим это здесь.
void main() {
  const service = [
    '/svc/overview', '/svc/subscribers', '/svc/subscribers?open=31-00562', '/svc/subscribers?open=new',
    '/svc/subscribers?f=debt', '/svc/charges', '/svc/import', '/svc/import?kind=charges', '/svc/import/journal',
    '/svc/payments', '/svc/payments?export=1', '/svc/notify', '/svc/staff', '/svc/api', '/svc/settings',
  ];
  const admin = ['/adm/orgs', '/adm/orgs/sch5', '/adm/unmatched', '/adm/audit'];

  for (final width in const [1440.0, 1100.0]) {
    for (final (email, routes) in [('jypar@oshvodokanal.kg', service), ('a.kadyrov@elpay.kg', admin)]) {
      for (final route in routes) {
        testWidgets('${width.toInt()} px · $route', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final store = AdminStore(store: MemoryLocalStore(), clock: MovableClock(DateTime(2026, 11, 1)).clock, seed: seed);
          await store.signIn(email, '4815');
          await tester.pumpWidget(ProviderScope(
            overrides: [adminStoreProvider.overrideWithValue(store)],
            child: const AdminApp(),
          ));
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(tester.element(find.byType(AdminApp)));
          container.read(routerProvider).go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Страница не найдена'), findsNothing);
        });
      }
    }
  }
}
