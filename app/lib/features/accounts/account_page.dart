import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/failure.dart';
import '../../core/format.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Экран подключённого счёта: владелец, адрес, объект, статус
/// синхронизации, когда обновляли, перенос на другой объект и отключение.
///
/// Открывается по path-параметру (`/accounts/:id`), а НЕ через
/// `state.extra`, поэтому прямой вход и ссылка работают, а не падают на
/// force-unwrap: если счёта с таким id нет, экран честно говорит об этом.
///
/// Отключение — не удаление: история платежей остаётся, и экран прямо
/// это говорит.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final accounts = ref.watch(accountsProvider);
    final account = accounts.value?.byId(accountId);

    return Scaffold(
      appBar: AppBar(
        title: Text(account == null ? s.accountsTitle : s.tr(account.title)),
        actions: [
          if (account != null)
            IconButton(
              tooltip: s.refreshAction,
              onPressed: () =>
                  ref.read(accountsProvider.notifier).sync(accountIds: [account.id]),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            AsyncSection<AccountsState>(
              value: accounts,
              stale: accounts.value?.fromCache ?? false,
              onRetry: () => ref.invalidate(accountsProvider),
              data: (state) {
                final found = state.byId(accountId);
                if (found == null) {
                  // Счёт отключили в другом месте или ссылка устарела.
                  return AppCard(
                    child: EmptyState(
                      icon: Icons.link_off_rounded,
                      title: s.errorNotFound,
                      lead: s.pageNotFoundLead,
                    ),
                  );
                }
                return _AccountBody(account: found);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account});
  final ConnectedAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final cat = ServiceCat.parse(account.cat);
    final objects = ref.watch(objectsProvider);
    final object = _objectOf(objects, account.objectId);
    final bills = ref.watch(billsProvider).value?.byAccount(account.id) ?? const <Bill>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CatTile(cat.token, iconOf(cat), size: 52, radius: 15, soft: true),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.tr(account.title), style: context.t.titleLarge),
                        const SizedBox(height: 2),
                        Text('${account.accountNo} · ${s.tr(account.subtitle)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [SyncStatusChip(account: account)]),
              // Технический текст поставщика пользователь не видит: ошибка
              // переводится через failureTitle.
              if (account.status == AccountSyncStatus.failed && account.lastError != null) ...[
                const SizedBox(height: 12),
                Tip(
                  failureTitle(s, failureOf(account.lastError)),
                  icon: Icons.sync_problem_rounded,
                  tone: ChipTone.bad,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyValueBox([
          (s.accountHolder, account.holder.isEmpty ? '—' : account.holder),
          if (account.address.isNotEmpty) (s.address, account.address),
          (s.object, object == null ? '—' : s.tr(object.name)),
        ]),
        if (bills.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle(s.billsTitle),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < bills.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 16),
                  AppRow(
                    leading: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
                    title: s.tr(bills[i].title),
                    subtitle: '${s.tr(bills[i].period)} · ${s.shortDueText(bills[i].due)}',
                    trailing: bills[i].paid
                        ? AppChip(s.paidTitle, tone: ChipTone.ok)
                        : Amount(som(bills[i].amount), size: 15),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            children: [
              AppRow(
                leading: Icon(Icons.swap_horiz_rounded, size: 26, color: context.c.muted),
                title: s.moveToObject,
                subtitle: object == null ? null : s.tr(object.name),
                chevron: true,
                onTap: () => openMoveSheet(context, ref, account),
              ),
              const RowDivider(indent: 16),
              AppRow(
                leading: Icon(Icons.link_off_rounded, size: 26, color: Brand.danger),
                title: s.disconnectAccount,
                onTap: () async {
                  final done = await openDisconnectSheet(context, ref, account);
                  if (!context.mounted || !done) return;
                  // Счёта больше нет — оставаться на его экране незачем.
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/accounts');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Отключение — НЕ удаление: история платежей остаётся, и экран
        // говорит это до нажатия, а не после.
        Tip(s.disconnectConfirm),
      ],
    );
  }

  PayObject? _objectOf(List<PayObject> objects, String id) {
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }
}

/// Чип статуса синхронизации.
///
/// Операция в очереди важнее статуса обновления: пользователю нужно знать,
/// что счёт ещё подключается (или отключается) без сети, а не что
/// начисления по нему «актуальны».
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.account});

  final ConnectedAccount account;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    if (account.isPendingConnect) {
      return AppChip(s.pendingConnect, tone: ChipTone.warn, icon: Icons.cloud_off_rounded);
    }
    if (account.isPendingDisconnect) {
      return AppChip(s.pendingDisconnect, tone: ChipTone.warn, icon: Icons.cloud_off_rounded);
    }

    final (text, tone, icon) = switch (account.status) {
      AccountSyncStatus.syncing => (s.syncPending, ChipTone.soft, Icons.sync_rounded),
      AccountSyncStatus.failed => (s.syncFailed, ChipTone.bad, Icons.sync_problem_rounded),
      AccountSyncStatus.ok => (
          account.syncedAt == null
              ? s.syncOk
              : s.syncedAt('${s.dayMonthText(account.syncedAt!)}, ${hhmm(account.syncedAt!)}'),
          ChipTone.ok,
          Icons.check_rounded,
        ),
    };
    return AppChip(text, tone: tone, icon: icon);
  }
}

/// Отключение счёта с предупреждениями из [ConnectRules.checkDisconnect]:
/// неоплаченное начисление и «это последний счёт объекта».
///
/// Возвращает true, если счёт отключён (или отключение ушло в очередь).
/// Рядом с опасным действием стоит безопасная альтернатива: счёт чаще
/// хотят перенести на другой объект, а не отключить.
Future<bool> openDisconnectSheet(
  BuildContext context,
  WidgetRef ref,
  ConnectedAccount account,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DisconnectSheet(account: account),
  );
  return result ?? false;
}

class _DisconnectSheet extends ConsumerStatefulWidget {
  const _DisconnectSheet({required this.account});
  final ConnectedAccount account;

  @override
  ConsumerState<_DisconnectSheet> createState() => _DisconnectSheetState();
}

class _DisconnectSheetState extends ConsumerState<_DisconnectSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _busy = true);
    final result = await ref
        .read(accountsProvider.notifier)
        .disconnect(widget.account.id, force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    final ok = result.isOk;
    final text = ok
        ? s.disconnected
        : ErrorView.titleFor(
            context, result.failureOrNull ?? const AppFailure(FailureKind.unknown));
    // Сообщение берём у ScaffoldMessenger ДО закрытия шторки: после pop
    // её контекст уже нельзя использовать для поиска предков.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, ok);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final account = widget.account;
    final state = ref.watch(accountsProvider).value ?? AccountsState.empty;
    final check = ref.watch(rulesProvider).checkDisconnect(
          account: account,
          all: state.accounts,
          bills: ref.watch(billsProvider).value?.bills ?? const <Bill>[],
        );
    final cat = ServiceCat.parse(account.cat);

    return AppSheet(
      title: s.disconnectAccount,
      lead: s.disconnectConfirm,
      header: Row(
        children: [
          CatTile(cat.token, iconOf(cat), size: 46, radius: 13, soft: true),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tr(account.title), style: context.t.titleMedium),
                Text(account.accountNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall),
              ],
            ),
          ),
        ],
      ),
      children: [
        if (check.unpaidAmount > 0) ...[
          Tip(s.disconnectUnpaid(som(check.unpaidAmount)),
              icon: Icons.account_balance_wallet_outlined, tone: ChipTone.warn),
          const SizedBox(height: 10),
        ],
        if (check.lastForObject) ...[
          Tip(s.disconnectLastForObject, tone: ChipTone.warn),
          const SizedBox(height: 10),
        ],
        if (!check.allowed) ...[
          Tip(s.pendingDisconnect, icon: Icons.cloud_off_rounded),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: Brand.danger),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.onPrimary))
              : Text(s.disconnectAccount),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  Navigator.pop(context, false);
                  openMoveSheet(context, ref, account);
                },
          child: Text(s.moveToObject),
        ),
      ],
    );
  }
}

/// Перенос счёта на другой объект — вместо «отключить и подключить
/// заново»: повторное подключение теряет историю и снова просит код.
Future<void> openMoveSheet(
  BuildContext context,
  WidgetRef ref,
  ConnectedAccount account,
) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MoveSheet(account: account),
    );

class _MoveSheet extends ConsumerStatefulWidget {
  const _MoveSheet({required this.account});
  final ConnectedAccount account;

  @override
  ConsumerState<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<_MoveSheet> {
  String? _busyId;

  Future<void> _move(PayObject object) async {
    final s = S.of(context);
    setState(() => _busyId = object.id);
    final result =
        await ref.read(accountsProvider.notifier).moveToObject(widget.account.id, object.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    final text = result.isOk
        ? s.movedOk
        : ErrorView.titleFor(
            context, result.failureOrNull ?? const AppFailure(FailureKind.unknown));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final objects = ref.watch(objectsProvider);

    return AppSheet(
      title: s.moveToObject,
      lead: s.chooseObject,
      children: [
        if (objects.isEmpty)
          EmptyState(
            icon: Icons.home_work_outlined,
            title: s.noObjectsTitle,
            lead: s.noObjectsLead,
          )
        else
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < objects.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 16),
                  AppRow(
                    leading: CatTile(objects[i].cat, iconOfRaw(objects[i].cat),
                        size: 42, radius: 12, soft: true),
                    title: s.tr(objects[i].name),
                    subtitle: objects[i].address,
                    trailing: _busyId == objects[i].id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2))
                        : objects[i].id == widget.account.objectId
                            ? Icon(Icons.check_rounded, size: 20, color: Brand.primary)
                            : null,
                    onTap: _busyId != null || objects[i].id == widget.account.objectId
                        ? null
                        : () => _move(objects[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
      ],
    );
  }
}
