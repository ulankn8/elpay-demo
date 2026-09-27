import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';

/// Нижняя навигация: четыре раздела, как в утверждённом прототипе.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: c.line2)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) =>
              navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 66,
          indicatorColor: Brand.light2,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded, color: Brand.p600),
              label: s.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet_rounded, color: Brand.p600),
              label: s.tabPayments,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_rounded),
              selectedIcon: const Icon(Icons.bar_chart_rounded, color: Brand.p600),
              label: s.tabReports,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded, color: Brand.p600),
              label: s.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// Временная страница для разделов, которые ещё разрабатываются.
class SoonPage extends StatelessWidget {
  const SoonPage({super.key, required this.title, required this.icon, this.lead});
  final String title;
  final IconData icon;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(title, style: context.t.displaySmall),
            const SizedBox(height: 28),
            AppCard(
              child: EmptyState(icon: icon, title: s.soonHere, lead: lead),
            ),
          ],
        ),
      ),
    );
  }
}
