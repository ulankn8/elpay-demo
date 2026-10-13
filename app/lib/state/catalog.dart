import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import 'providers.dart';

/// Каталог платежей: категории, поставщики, значки услуг, способы оплаты,
/// реквизиты банка.
///
/// Экраны платежей больше не импортируют demo_data: источник подменяется
/// в одной строке apiProvider, и это наконец правда, а не комментарий.
class CatalogNotifier extends AsyncNotifier<Catalog> {
  static const _tag = 'catalog-state';

  CatalogRepository get _repo => ref.read(catalogRepoProvider);

  @override
  Future<Catalog> build() async {
    final cached = _repo.cached();
    // Сохранённый каталог показываем сразу: он меняется раз в месяцы,
    // и ждать сеть, чтобы нарисовать список услуг, незачем.
    if (!cached.isEmpty) state = AsyncData(cached);

    final result = await _repo.load();
    return result.fold((value) => value, (failure) {
      if (cached.isEmpty) throw failure;
      Log.w(_tag, 'каталог не обновился (${failure.message}), работаем с сохранённым');
      return cached;
    });
  }

  Future<void> refresh() async {
    final current = state.value;
    final result = await _repo.load(refresh: true);
    state = AsyncData(result.fold(
      (value) => value,
      // Каталог устаревает годами — падать из-за него экранам нельзя.
      (failure) => current ?? _repo.cached(),
    ));
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogNotifier, Catalog>(CatalogNotifier.new);

/// Загруженный каталог, иначе сохранённый, иначе пустой — СИНХРОННО.
///
/// Нужен, чтобы шторки (pay_sheet, method_picker, service_row) не
/// переписывались на async: замена `Demo.methods` на
/// `ref.watch(catalogNowProvider).methods` остаётся механической.
final catalogNowProvider = Provider<Catalog>((ref) {
  final loaded = ref.watch(catalogProvider).value;
  if (loaded != null && !loaded.isEmpty) return loaded;
  final cached = ref.watch(catalogRepoProvider).cached();
  return cached.isEmpty ? Catalog.empty : cached;
});

/// Поиск поставщика для шторки выбора. Пустой запрос — весь список,
/// чтобы шторка не начиналась с пустого экрана.
final providerSearchProvider = Provider.family<List<ProviderItem>, String>(
  (ref, query) => ref.watch(catalogNowProvider).searchProviders(query),
);

/// Способы оплаты — их читают четыре экрана, и остальной каталог им не нужен.
final payMethodsProvider = Provider<List<PayMethodItem>>(
  (ref) => ref.watch(catalogNowProvider).methods,
);
