import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'account_page.dart';
import 'connect_args.dart';

/// Подключённые счета: что приходит в ЭлPay, когда обновлялось,
/// и как подключить ещё или отключить лишнее.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final accounts = ref.watch(accountsProvider);
    final objects = ref.watch(objectsProvider);
    final online = ref.watch(onlineNowProvider);
    final pending = ref.watch(pendingOpsProvider);
    final lastSync = ref.watch(lastSyncProvider);
    final hint = ref.watch(syncHintProvider);

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
        onPressed: () =>
            context.push(const ConnectArgs(source: ConnectArgs.sourceAccounts).location),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.connectAccount),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(accountsProvider.notifier).sync(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
            children: [
              if (!online) ...[
                OfflineBanner(onRetry: () => ref.invalidate(accountsProvider)),
                const SizedBox(height: 12),
              ],
              // В очереди что-то есть: операция не потеряна, но и не ушла.
              if (pending > 0) ...[
                Tip(s.offlineQueued, icon: Icons.schedule_rounded, tone: ChipTone.warn),
                const SizedBox(height: 12),
              ],
              Tip(s.accountsLead),
              if (lastSync != null) ...[
                const SizedBox(height: 10),
                Text(
                  s.syncedAt('${s.dayMonthText(lastSync)}, ${_hhmm(lastSync)}'),
                  style: context.t.labelSmall?.copyWith(color: context.c.muted2),
                ),
              ],
              if (hint) ...[
                const SizedBox(height: 12),
                Tip(s.syncHint, icon: Icons.sync_rounded, tone: ChipTone.warn),
              ],
              const SizedBox(height: 4),
              // Триада «загрузка → ошибка → данные» одна на всё приложение:
              // '.value ?? const []' превращал ошибку сервера в «счетов нет».
              AsyncSection<AccountsState>(
                value: accounts,
                stale: accounts.value?.fromCache ?? false,
                onRetry: () => ref.invalidate(accountsProvider),
                isEmpty: (state) => state.accounts.isEmpty,
                empty: AppCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: s.nothingYet,
                    lead: s.connectLead,
                  ),
                ),
                data: (state) => _Groups(state: state, objects: objects),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Счета, сгруппированные по объектам.
///
/// Группы считаются ОДИН раз: раньше `byObject(obj.id)` вызывался и в
/// условии цикла, и в его теле на каждой итерации — O(n²) на каждый кадр.
class _Groups extends ConsumerWidget {
  const _Groups({required this.state, required this.objects});

  final AccountsState state;
  final List<PayObject> objects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    final byObject = <String, List<ConnectedAccount>>{};
    final loose = <ConnectedAccount>[];
    final known = {for (final o in objects) o.id};
    for (final a in state.accounts) {
      if (known.contains(a.objectId)) {
        byObject.putIfAbsent(a.objectId, () => []).add(a);
      } else {
        // Счёт без объекта — чтобы ничего не потерялось.
        loose.add(a);
      }
    }

    final failed = state.failedToSync;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(accountsProvider.notifier)
                .sync(accountIds: [for (final a in failed) a.id]),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(s.retryOnlyFailed),
          ),
        ],
        for (final object in objects)
          if (byObject[object.id] != null) ...[
            SectionTitle(s.tr(object.name)),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < byObject[object.id]!.length; i++) ...[
                    if (i > 0) const RowDivider(indent: 16),
                    _AccountRow(account: byObject[object.id]![i]),
                  ],
                ],
              ),
            ),
          ],
        if (loose.isNotEmpty) ...[
          SectionTitle(s.myAccounts),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < loose.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 16),
                  _AccountRow(account: loose[i]),
                ],
              ],
            ),
          ),
        ],
      ],
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
    final cat = ServiceCat.parse(account.cat);

    return InkWell(
      onTap: () => context.push('/accounts/${account.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 6, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatTile(cat.token, iconOf(cat), soft: true),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tr(account.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.titleMedium),
                  const SizedBox(height: 2),
                  Text('${account.accountNo} · ${s.tr(account.subtitle)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.bodySmall),
                  const SizedBox(height: 8),
                  SyncStatusChip(account: account),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: c.muted2),
              onSelected: (value) async {
                switch (value) {
                  case 'open':
                    context.push('/accounts/${account.id}');
                  case 'move':
                    await openMoveSheet(context, ref, account);
                  case 'off':
                    await openDisconnectSheet(context, ref, account);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'open', child: Text(s.details)),
                PopupMenuItem(value: 'move', child: Text(s.moveToObject)),
                PopupMenuItem(value: 'off', child: Text(s.disconnectAccount)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
