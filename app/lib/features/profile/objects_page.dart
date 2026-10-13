import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/failure_text.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(s.objectsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
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
            // Ошибка загрузки больше не выглядит как «объектов нет»:
            // AsyncSection покажет текст из S и кнопку «Повторить».
            AsyncSection<BillsState>(
              value: ref.watch(billsProvider),
              onRetry: () => ref.read(billsProvider.notifier).refresh(),
              skeleton: const LoadingRows(count: 2),
              isEmpty: (state) => state.objects.isEmpty,
              empty:
                  AppCard(child: EmptyState(icon: Icons.home_outlined, title: s.nothingYet)),
              data: (state) {
                final objects = state.objects;
                return AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < objects.length; i++) ...[
                        if (i > 0) const RowDivider(),
                        AppRow(
                          leading: CatTile(objects[i].cat, objectIcon(objects[i].icon),
                              soft: true),
                          title: s.tr(objects[i].name),
                          subtitle: '${state.byObject(objects[i].id).length} '
                              '${s.objectBills} · ${objects[i].address}',
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () => _edit(context, objects[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Шторка живёт отдельным виджетом: контроллеры полей принадлежат ему
  /// и освобождаются в dispose. Раньше они создавались на каждое открытие
  /// и не освобождались никогда.
  void _edit(BuildContext context, PayObject? object) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ObjectSheet(
        object: object,
        // Снек показывает экран, а не шторка: к этому моменту её контекст
        // уже закрыт.
        onMessage: (text) {
          if (context.mounted) showAppSnack(context, text);
        },
      ),
    );
  }
}

class _ObjectSheet extends ConsumerStatefulWidget {
  const _ObjectSheet({required this.object, required this.onMessage});

  final PayObject? object;
  final ValueChanged<String> onMessage;

  @override
  ConsumerState<_ObjectSheet> createState() => _ObjectSheetState();
}

class _ObjectSheetState extends ConsumerState<_ObjectSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.object?.name ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.object?.address ?? '');

  late String _icon = widget.object?.icon ?? 'house';
  late String _cat = widget.object?.cat ?? 'water';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);

    final object = widget.object;
    final item = PayObject(
      // Локальный id до ответа сервера: по префиксу 'loc_' видно, что он
      // ещё не серверный. Раньше здесь стоял millisecondsSinceEpoch —
      // два нажатия в одну миллисекунду давали один id.
      id: object?.id ?? ref.read(idGenProvider).local('object'),
      name: _name.text.trim(),
      icon: _icon,
      cat: _cat,
      address: _address.text.trim(),
    );

    final result = await ref.read(billsProvider.notifier).saveObject(item);
    if (!mounted) return;
    Navigator.pop(context);
    final failure = result.failureOrNull;
    widget.onMessage(
      failure == null ? s.saved : failureTitle(s, failure),
    );
  }

  Future<void> _remove(PayObject object) async {
    final s = S.of(context);
    if (_busy) return;
    final ok = await confirmDialog(context, s.deleteObjectConfirm, s.removeWord);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);

    // Счета объекта отключает BillsNotifier.removeObject: каскада на
    // сервере нет, и экран его не подменяет своим.
    final result = await ref.read(billsProvider.notifier).removeObject(object.id);
    if (!mounted) return;
    Navigator.pop(context);
    final failure = result.failureOrNull;
    if (failure != null) widget.onMessage(failureTitle(s, failure));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final object = widget.object;

    return AppSheet(
      title: object == null ? s.newObject : s.editObject,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: s.objectName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: InputDecoration(labelText: s.objectAddressLabel),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (ic, cc) in _iconChoices)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _icon = ic;
                    _cat = cc;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _icon == ic ? Brand.primary : Colors.transparent,
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
          onPressed: _busy ? null : _save,
          child: Text(s.save),
        ),
        if (object != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => _remove(object),
            style: TextButton.styleFrom(foregroundColor: Brand.danger),
            child: Text(s.removeWord),
          ),
        ],
      ],
    );
  }
}
