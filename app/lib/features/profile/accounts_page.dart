import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Счета и реквизиты: что подключено к ЭлPay.
/// Здесь счёт добавляют, меняют номер, привязывают к объекту и удаляют.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final state = ref.watch(billsProvider).value;
    final objects = state?.objects ?? const <PayObject>[];
    final bills = state?.bills ?? const <Bill>[];

    return Scaffold(
      appBar: AppBar(title: Text(s.accountsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSheet(context, ref, objects),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.addAccountTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
          children: [
            Tip(s.accountsLead),
            if (bills.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AppCard(
                  child: EmptyState(icon: Icons.receipt_long_outlined, title: s.nothingYet),
                ),
              ),
            for (final obj in objects) ...[
              SectionTitle(obj.name),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < state!.byObject(obj.id).length; i++) ...[
                      if (i > 0) const RowDivider(),
                      Builder(builder: (context) {
                        final b = state.byObject(obj.id)[i];
                        return AppRow(
                          leading: CatTile(b.cat, catIcon(b.cat), soft: true),
                          title: b.title,
                          subtitle: '${b.account} · ${b.subtitle}',
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () => _editSheet(context, ref, b, objects),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── добавление счёта из каталога ─────────────────────────────────
  void _addSheet(BuildContext context, WidgetRef ref, List<PayObject> objects) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 20),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 2),
              child: Text(s.chooseProvider, style: context.t.headlineSmall),
            ),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < Demo.providers.length; i++) ...[
                    if (i > 0) const RowDivider(),
                    AppRow(
                      leading: CatTile(Demo.providers[i].cat,
                          catIcon(Demo.providers[i].cat), soft: true),
                      title: Demo.providers[i].title,
                      subtitle: Demo.providers[i].subtitle,
                      chevron: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _formSheet(context, ref, Demo.providers[i], objects);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _formSheet(
    BuildContext context,
    WidgetRef ref,
    ProviderItem provider,
    List<PayObject> objects,
  ) {
    final s = S.of(context);
    final account = TextEditingController();
    var objectId = objects.isEmpty ? '' : objects.first.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, left: 2),
                    child: Text(provider.title, style: context.t.headlineSmall),
                  ),
                  TextField(
                    controller: account,
                    decoration: InputDecoration(
                      labelText: provider.accountLabel,
                      hintText: provider.accountHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(s.chooseObject, style: context.t.labelSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final o in objects)
                        ChoiceChip(
                          label: Text(o.name),
                          selected: objectId == o.id,
                          showCheckmark: false,
                          onSelected: (_) => setSheet(() => objectId = o.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      final acc = account.text.trim();
                      if (acc.length < 4) {
                        showAppSnack(ctx, s.accountError);
                        return;
                      }
                      final now = DateTime.now();
                      ref.read(billsProvider.notifier).addBill(Bill(
                            id: 'b-${now.millisecondsSinceEpoch}',
                            title: provider.title,
                            subtitle: provider.subtitle,
                            cat: provider.cat,
                            amount: provider.fixedAmount ?? 0,
                            objectId: objectId,
                            period: '${monthName(now.month)} ${now.year}',
                            due: DateTime(now.year, now.month, 25),
                            account: acc,
                            requisites: [
                              ...provider.requisites,
                              ...Demo.bank,
                              Field('Лицевой счёт', acc),
                            ],
                          ));
                      Navigator.pop(ctx);
                      showAppSnack(context, s.accountAdded);
                    },
                    child: Text(s.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── изменение счёта ──────────────────────────────────────────────
  void _editSheet(BuildContext context, WidgetRef ref, Bill bill, List<PayObject> objects) {
    final s = S.of(context);
    final account = TextEditingController(text: bill.account);
    var objectId = bill.objectId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, left: 2),
                    child: Text(bill.title, style: context.t.headlineSmall),
                  ),
                  TextField(
                    controller: account,
                    decoration: InputDecoration(labelText: s.accountNumber),
                  ),
                  const SizedBox(height: 16),
                  Text(s.chooseObject, style: context.t.labelSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final o in objects)
                        ChoiceChip(
                          label: Text(o.name),
                          selected: objectId == o.id,
                          showCheckmark: false,
                          onSelected: (_) => setSheet(() => objectId = o.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      ref.read(billsProvider.notifier).updateBill(
                            bill.withAccount(account.text.trim(), objectId),
                          );
                      Navigator.pop(ctx);
                      showAppSnack(context, s.saved);
                    },
                    child: Text(s.save),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(ctx, s.deleteAccountConfirm, s.removeWord);
                      if (ok != true) return;
                      ref.read(billsProvider.notifier).removeBill(bill.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(foregroundColor: Brand.danger),
                    child: Text(s.removeWord),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
