import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Выбор поставщика с поиском по названию, услуге и номеру-образцу.
///
/// Каталог берётся из состояния ([catalogNowProvider]), а не из `Demo.*`:
/// шторкой пользуются и мастер подключения, и оплата по реквизитам, и обе
/// получают один список — тот, что пришёл из CatalogRepository.
///
/// До этой шторки выбор поставщика выглядел двумя разными способами: весь
/// список без поиска в accounts_page и плоская сетка из девяти значков в
/// new_payment_page. Поиска не было ни там, ни там.
///
/// Возвращает выбранного поставщика или null, если шторку закрыли.
Future<ProviderItem?> openProviderPicker(
  BuildContext context,
  WidgetRef ref, {
  String? categoryId,
  String? selectedId,
}) {
  // Каталога нет совсем (холодный старт без кэша) — просим обновить, иначе
  // шторка откроется пустой и пустой же останется.
  if (ref.read(catalogNowProvider).providers.isEmpty) {
    ref.read(catalogProvider.notifier).refresh();
  }
  return showModalBottomSheet<ProviderItem>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ProviderPicker(categoryId: categoryId, selectedId: selectedId),
  );
}

class _ProviderPicker extends ConsumerStatefulWidget {
  const _ProviderPicker({this.categoryId, this.selectedId});

  /// Показывать только поставщиков этой категории (пришли со значка услуги).
  final String? categoryId;
  final String? selectedId;

  @override
  ConsumerState<_ProviderPicker> createState() => _ProviderPickerState();
}

class _ProviderPickerState extends ConsumerState<_ProviderPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    // Контроллер шторки освобождается — образец «создать внутри builder и
    // забыть» в этом файле не повторяется.
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final catalog = ref.watch(catalogNowProvider);
    final found = catalog.searchProviders(_query.text, categoryId: widget.categoryId);

    return AppSheet(
      title: s.chooseProvider,
      children: [
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.providerSearchHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(_query.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Flexible(
          child: found.isEmpty
              ? SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: s.nothingFound,
                    lead: s.foundNothingLead,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 12),
                  itemCount: found.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => ProviderRow(
                    provider: found[i],
                    selected: found[i].id == widget.selectedId,
                    onTap: () => Navigator.pop(context, found[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Строка поставщика в списке: значок категории, название, образец номера.
class ProviderRow extends StatelessWidget {
  const ProviderRow({
    super.key,
    required this.provider,
    this.selected = false,
    this.onTap,
  });

  final ProviderItem provider;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final p = provider;
    // Образец номера показываем рядом с услугой: по нему пользователь
    // узнаёт своего поставщика быстрее, чем по названию конторы.
    final hint = p.accountHint.isEmpty ? '' : ' · ${p.accountHint}';
    return InkWell(
      borderRadius: BorderRadius.circular(Brand.radiusRow),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Brand.light2.withValues(alpha: .6) : Colors.transparent,
          border: Border.all(color: selected ? Brand.primary : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(Brand.radiusRow),
        ),
        child: Row(
          children: [
            CatTile(p.cat, iconOfRaw(p.cat), soft: true),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tr(p.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.titleMedium),
                  Text('${s.tr(p.subtitle)}$hint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.bodySmall),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              size: selected ? 22 : 20,
              color: selected ? Brand.primary : c.muted2,
            ),
          ],
        ),
      ),
    );
  }
}
