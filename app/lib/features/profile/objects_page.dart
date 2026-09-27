import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

IconData objectIcon(String icon) => switch (icon) {
      'house' => Icons.home_outlined,
      'users' => Icons.people_outline_rounded,
      'flat' => Icons.apartment_rounded,
      'shop' => Icons.storefront_outlined,
      _ => Icons.place_outlined,
    };

const _iconChoices = [
  ('house', 'water'),
  ('flat', 'power'),
  ('users', 'door'),
  ('shop', 'market'),
];

/// Объекты: дом, квартира родителей, дача. Счета всегда привязаны к объекту.
class ObjectsPage extends ConsumerWidget {
  const ObjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final state = ref.watch(billsProvider).value;
    final objects = state?.objects ?? const <PayObject>[];

    return Scaffold(
      appBar: AppBar(title: Text(s.objectsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newObject),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
          children: [
            Tip(s.objectsLead),
            const SizedBox(height: 16),
            if (objects.isEmpty)
              AppCard(child: EmptyState(icon: Icons.home_outlined, title: s.nothingYet))
            else
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < objects.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      AppRow(
                        leading: CatTile(objects[i].cat, objectIcon(objects[i].icon), soft: true),
                        title: s.tr(objects[i].name),
                        subtitle:
                            '${state!.byObject(objects[i].id).length} ${s.objectBills} · ${objects[i].address}',
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _edit(context, ref, objects[i]),
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

  void _edit(BuildContext context, WidgetRef ref, PayObject? object) {
    final s = S.of(context);
    final name = TextEditingController(text: object?.name ?? '');
    final address = TextEditingController(text: object?.address ?? '');
    var icon = object?.icon ?? 'house';
    var cat = object?.cat ?? 'water';

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
                    child: Text(object == null ? s.newObject : s.editObject,
                        style: context.t.headlineSmall),
                  ),
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.objectName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    decoration: InputDecoration(labelText: s.objectAddressLabel),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final (ic, cc) in _iconChoices)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setSheet(() {
                              icon = ic;
                              cat = cc;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: icon == ic ? Brand.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CatTile(cc, objectIcon(ic), size: 44),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (name.text.trim().isEmpty) return;
                      final notifier = ref.read(billsProvider.notifier);
                      final item = PayObject(
                        id: object?.id ?? 'o-${DateTime.now().millisecondsSinceEpoch}',
                        name: name.text.trim(),
                        icon: icon,
                        cat: cat,
                        address: address.text.trim(),
                      );
                      object == null ? notifier.addObject(item) : notifier.updateObject(item);
                      Navigator.pop(ctx);
                      showAppSnack(context, s.saved);
                    },
                    child: Text(s.save),
                  ),
                  if (object != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final ok = await confirmDialog(ctx, s.deleteObjectConfirm, s.removeWord);
                        if (ok != true) return;
                        ref.read(billsProvider.notifier).removeObject(object.id);
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
      ),
    );
  }
}
