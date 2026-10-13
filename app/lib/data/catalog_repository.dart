import '../core/cache/local_store.dart';
import '../core/clock.dart';
import '../core/logger.dart';
import '../core/result.dart';
import 'api/elpay_api.dart';
import 'models.dart';

// Тип каталога объявлен в моделях (иначе demo_data и репозиторий импортировали
// бы друг друга), но по плану его ищут здесь — реэкспортируем.
export 'models.dart' show Catalog;

/// Каталог платежей за слоем данных.
///
/// Снимает последний блокер подмены реализации «одной строкой»: до этого
/// `Demo.*` импортировали напрямую пять экранов в features/payments, и никакая
/// замена источника на них не влияла. Теперь каталог приходит оттуда же,
/// откуда начисления и счета, — из репозитория поверх [ElPayApi].
abstract class CatalogRepository {
  /// Каталог почти не меняется, поэтому кэш читается СИНХРОННО — это
  /// позволяет шторкам (pay_sheet, method_picker) не переписываться на async.
  /// Кэша нет или он битый — [Catalog.empty], а не исключение.
  Catalog cached();

  /// Свежий кэш отдаётся сразу; иначе идём в источник и пишем результат.
  /// Источник упал, а кэш есть — `Ok(кэш)`: каталог устаревает годами,
  /// и падать из-за него экраны не должны. Нет ни того, ни другого —
  /// `Fail(failure)`.
  Future<Result<Catalog>> load({bool refresh = false});

  /// Когда каталог обновляли в последний раз (null — ни разу).
  DateTime? updatedAt();
}

class DefaultCatalogRepository implements CatalogRepository {
  DefaultCatalogRepository({
    required this.api,
    required this.store,
    Clock? clock,
    this.ttl = const Duration(hours: 12),
    this.locale = 'ru',
    Future<Catalog> Function()? source,
  }) : _clock = clock ?? systemClock {
    // Присваивание в теле, а не в списке инициализации: там `api` и `locale`
    // ещё не проинициализированы. Раньше из-за этого источником по умолчанию
    // стоял демо-набор, и в боевой сборке `GET /catalog` не вызывался
    // НИКОГДА — поставщики, маски лицевых счетов и способы оплаты оставались
    // демонстрационными поверх живого бэкенда, а обещанная «подмена одной
    // строкой в apiProvider» каталога не касалась.
    _source = source ?? () => api.catalog(locale: locale);
  }

  /// Источник данных: [ElPayApi.catalog] — в бою `GET /catalog?locale=`,
  /// в демо тот же `Demo.catalog` из [MockElPayApi]. Параметр `source`
  /// конструктора остаётся швом для тестов.
  final ElPayApi api;

  final LocalStore store;

  /// Насколько кэш каталога считается свежим.
  final Duration ttl;

  /// Язык каталога: названия услуг приходят с сервера уже переведёнными.
  final String locale;

  final Clock _clock;
  late final Future<Catalog> Function() _source;

  static const _tag = 'catalog';

  /// Ключ кэша. В `CacheKeys` его нет: core правит другая лана, и тащить
  /// общий файл за одной строкой дороже, чем держать ключ рядом с владельцем.
  static const cacheKey = 'catalog';

  @override
  Catalog cached() {
    final saved = store.readMap(cacheKey);
    if (saved == null) return Catalog.empty;
    try {
      return Catalog.fromJson(saved);
    } catch (e, st) {
      Log.e(_tag, 'битый кэш каталога, читаем как пустой', e, st);
      return Catalog.empty;
    }
  }

  @override
  DateTime? updatedAt() => store.updatedAt(cacheKey);

  @override
  Future<Result<Catalog>> load({bool refresh = false}) async {
    final now = _clock();
    final saved = cached();
    final fresh = !store.isStale(cacheKey, ttl, now: now);
    if (!refresh && !saved.isEmpty && fresh) return Ok(saved);

    final result = await guard(_source);
    switch (result) {
      case Ok(:final value):
        if (value.isEmpty) {
          // Пустой каталог — почти всегда ошибка на той стороне; затирать
          // им сохранённый нельзя, иначе экраны платежей станут пустыми.
          Log.w(_tag, 'источник вернул пустой каталог, оставляем сохранённый');
          return saved.isEmpty ? result : Ok(saved);
        }
        await store.writeJson(cacheKey, value.toJson(), now: now);
        Log.i(_tag, 'каталог обновлён: поставщиков ${value.providers.length}');
        return Ok(value);
      case Fail(:final failure):
        if (!saved.isEmpty) {
          Log.w(_tag, 'каталог не обновился (${failure.message}), отдаём сохранённый');
          return Ok(saved);
        }
        return result;
    }
  }
}
