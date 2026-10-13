import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/failure.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Подключённые счета: что приходит в ЭлPay, когда обновлялось,
/// и как подключить ещё или отключить лишнее.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final accounts = ref.watch(accountsProvider);
    final objects = ref.watch(billsProvider).value?.objects ?? const <PayObject>[];
    final online = ref.watch(connectivityProvider).isOnline;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.accountsTitle),
        actions: [
          IconButton(
            tooltip: s.refreshAction,
            onPressed: () => ref.read(accountsProvider.notifier).sync(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(connectProvider.notifier).reset();
          context.push('/connect');
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(s.connectAccount),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(accountsProvider.notifier).sync(),
          child: accounts.when(
            loading: () => ListView(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
              children: const [LoadingRows(count: 4)],
            ),
            error: (e, _) => ListView(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
              children: [
                ErrorView(
                  failure: e is AppFailure ? e : const AppFailure(FailureKind.unknown),
                  onRetry: () => ref.invalidate(accountsProvider),
                ),
              ],
            ),
            data: (list) => ListView(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
              children: [
                if (!online) ...[
                  OfflineBanner(onRetry: () => ref.invalidate(accountsProvider)),
                  const SizedBox(height: 14),
                ],
                Tip(s.accountsLead),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AppCard(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: s.nothingYet,
                        lead: s.connectLead,
                      ),
                    ),
                  ),
                for (final object in objects) ...[
                  if (list.any((a) => a.objectId == object.id)) ...[
                    SectionTitle(s.tr(object.name)),
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < list.where((a) => a.objectId == object.id).length;
                              i++) ...[
                            if (i > 0) const RowDivider(),
                            _AccountRow(
                              account: list.where((a) => a.objectId == object.id).toList()[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
                // Счета без объекта — чтобы ничего не потерялось.
                if (list.any((a) => objects.every((o) => o.id != a.objectId))) ...[
                  SectionTitle(s.myAccounts),
                  AppCard(
                    child: Column(
                      children: [
                        for (final a in list.where((a) => objects.every((o) => o.id != a.objectId)))
                          _AccountRow(account: a),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account});
  final ConnectedAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;

    final (statusText, tone) = switch (account.status) {
      AccountSyncStatus.syncing => (s.syncPending, ChipTone.soft),
      AccountSyncStatus.failed => (s.syncFailed, ChipTone.bad),
      AccountSyncStatus.ok => (
          account.syncedAt == null ? s.syncOk : s.syncedAt(_when(context, account.syncedAt!)),
          ChipTone.ok,
        ),
    };

    return AppRow(
      leading: CatTile(account.cat, catIcon(account.cat), soft: true),
      title: s.tr(account.title),
      subtitle: '${account.accountNo} · ${s.tr(account.subtitle)}',
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz_rounded, color: c.muted2),
        onSelected: (value) async {
          if (value != 'off') return;
          final ok = await confirmDialog(context, s.disconnectConfirm, s.disconnectAccount);
          if (ok != true) return;
          final result = await ref.read(accountsProvider.notifier).disconnect(account.id);
          if (!context.mounted) return;
          showAppSnack(
            context,
            result.isOk ? s.disconnected : s.errorUnknown,
          );
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'off', child: Text(s.disconnectAccount)),
        ],
      ),
      onTap: () => showAppSnack(context, statusText),
      subtitleColor: account.status == AccountSyncStatus.failed ? c.chipBadFg : null,
    );
  }

  String _when(BuildContext context, DateTime at) {
    final s = S.of(context);
    return '${s.dayMonthText(at)}, ${_hhmm(at)}';
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
