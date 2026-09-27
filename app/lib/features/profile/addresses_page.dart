import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Адреса уведомлений: куда присылать предупреждения об отключениях.
class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final list = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.addressesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newAddress),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
          children: [
            Tip(s.addressesLead),
            const SizedBox(height: 16),
            if (list.isEmpty)
              AppCard(child: EmptyState(icon: Icons.place_outlined, title: s.nothingYet))
            else
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      AppRow(
                        leading: CatTile('water', Icons.place_outlined, soft: true),
                        title: list[i].title,
                        subtitle: list[i].address,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _edit(context, ref, list[i]),
                        ),
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

  void _edit(BuildContext context, WidgetRef ref, AddressItem? item) {
    final s = S.of(context);
    final title = TextEditingController(text: item?.title ?? '');
    final address = TextEditingController(text: item?.address ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
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
                  child: Text(item == null ? s.newAddress : s.editWord,
                      style: context.t.headlineSmall),
                ),
                TextField(
                  controller: title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: s.addressTitleLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  decoration: InputDecoration(labelText: s.addressLabel),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty || address.text.trim().isEmpty) return;
                    final notifier = ref.read(addressesProvider.notifier);
                    final value = AddressItem(
                      id: item?.id ?? 'a-${DateTime.now().millisecondsSinceEpoch}',
                      title: title.text.trim(),
                      address: address.text.trim(),
                    );
                    item == null ? notifier.add(value) : notifier.update(value);
                    Navigator.pop(ctx);
                    showAppSnack(context, s.saved);
                  },
                  child: Text(s.save),
                ),
                if (item != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(ctx, s.deleteAddressConfirm, s.removeWord);
                      if (ok != true) return;
                      ref.read(addressesProvider.notifier).remove(item.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(foregroundColor: Brand.danger),
                    child: Text(s.removeWord),
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
