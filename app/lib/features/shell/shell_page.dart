import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';

/// Нижняя навигация: четыре раздела, как в утверждённом прототипе.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = dark ? const Color(0xFF6FE0BB) : Brand.p600;
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
          indicatorColor: dark ? Brand.primary.withValues(alpha: .18) : Brand.light2,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: selected),
              label: s.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: selected),
              label: s.tabPayments,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_rounded),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: selected),
              label: s.tabReports,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: selected),
              label: s.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
