import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/data/catalog_repository.dart';
import 'package:elpay/state/providers.dart';
import 'package:elpay/core/l10n/s.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Каталог платежей за слоем данных.
///
/// Каталог — единственное, что экраны платежей читают СИНХРОННО: шторки
/// (pay_sheet, method_picker, service_row) не переписываются на async,
/// поэтому замена `Demo.methods` на `ref.watch(catalogNowProvider).methods`
/// остаётся механической. Ровно это здесь и проверяется, плюс то, что
/// пустой или не загрузившийся каталог экраны не роняет.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Репозиторий поверх заданного источника. [source] = null — демо-каталог.
  DefaultCatalogRepository repoOver(
    MemoryLocalStore store, {
    Future<Catalog> Function()? source,
    TestEnv? env,
  }) =>
      DefaultCatalogRepository(
        api: (env ?? makeEnv(store: store)).api,
        store: store,
        clock: () => testNow,
        source: source,
      );

  group('Синхронное чтение', () {
    test('Каталог читается синхронно из кэша и доступен шторкам без await',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      // До первой загрузки кэша нет — и это не исключение, а пустой каталог.
      expect(env.catalog.cached().isEmpty, isTrue);
      expect((await env.catalog.load()).isOk, isTrue);

      // Новый репозиторий поверх того же хранилища: так его видит
      // следующий запуск приложения.
      final fresh = repoOver(env.store, env: env);
      final cached = fresh.cached();

      expect(cached.isEmpty, isFalse);
      expect(cached.providers, isNotEmpty);
      expect(cached.methods, isNotEmpty);
      expect(fresh.updatedAt(), testNow);
    });

    test('Шторки видят каталог, не дожидаясь catalogProvider', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      // Каталог уже лежит в хранилище с прошлого запуска.
      await env.catalog.load();
      final container = await env.container();

      // Ни одного await: сеть ещё не отвечала, а способы оплаты шторке
      // нужны сейчас. Сохранённый каталог состояние публикует синхронно,
      // до первого await в build() — поэтому он уже здесь.
      expect(container.read(catalogNowProvider).isEmpty, isFalse);
      expect(container.read(payMethodsProvider), isNotEmpty);
      expect(container.read(providerSearchProvider('вода')), isNotEmpty);
    });

    test('Битый кэш каталога читается как пустой, а не роняет экран', () {
      final store = MemoryLocalStore();
      store.corrupt(DefaultCatalogRepository.cacheKey, now: testNow);
      final env = makeEnv(store: store);
      addTearDown(env.dispose);

      expect(repoOver(store, env: env).cached().isEmpty, isTrue);
    });
  });

  group('Поиск и маски', () {
    late Catalog catalog;

    setUp(() async {
      final env = makeEnv();
      addTearDown(env.dispose);
      catalog = (await env.catalog.load()).valueOrNull!;
    });

    test('Поиск поставщика находит по названию и по услуге', () {
      // По названию.
      expect(
        catalog.searchProviders('ошводоканал').map((p) => p.id),
        contains('p-water'),
      );
      // По услуге — пользователь ищет «мусор», а не имя предприятия.
      expect(
        catalog.searchProviders('вывоз мусора').map((p) => p.id),
        contains('p-trash'),
      );
      // Регистр и «ё» мешать не должны.
      expect(
        catalog.searchProviders('ОШВОДОКАНАЛ').map((p) => p.id),
        contains('p-water'),
      );
      // Пустой запрос — весь список: шторка не начинается с пустого экрана.
      expect(catalog.searchProviders(''), hasLength(catalog.providers.length));
      expect(catalog.searchProviders('такого поставщика нет'), isEmpty);

      // Кыргызский: пользователь видит перевод и ищет по нему. Без tr
      // поиск сравнивал запрос с русским ключом и не находил ничего.
      final ky = SKy();
      expect(
        catalog.searchProviders('суу', tr: ky.tr).map((p) => p.id),
        contains('p-water'),
        reason: 'поиск должен идти по тому, что на экране',
      );
    });

    test('Поиск по номеру-образцу находит поставщика', () {
      // Номер из квитанции вставили в поиск — поставщик обязан найтись
      // по образцу своего лицевого счёта.
      expect(
        catalog.searchProviders('31-01187').map((p) => p.id),
        contains('p-water'),
      );
    });

    test('Маска поставщика приводит 3101187 к 31-01187', () {
      final mask = catalog.maskOf('p-water');

      expect(mask.normalize('3101187'), '31-01187');
      expect(mask.normalize('31 01187'), '31-01187');
      expect(mask.matches('3101187'), isTrue);
      // Семь цифр — не восемь: лишняя цифра должна отсекаться до сети.
      expect(mask.matches('31011878'), isFalse);
    });

    test('Неизвестный поставщик даёт маску «любая», а не отказ', () {
      final mask = catalog.maskOf('p-такого-нет');

      expect(mask.isAny, isTrue);
      expect(mask.matches('12345'), isTrue);
      expect(catalog.providerById('p-такого-нет'), isNull);
    });

    test('Значки услуг фильтруются по категории поставщика', () {
      expect(catalog.quickFor(null), hasLength(catalog.quickServices.length));
      final util = catalog.quickFor('util');
      expect(util, isNotEmpty);
      expect(
        util.every((q) => catalog.providerById(q.providerId)?.categoryId == 'util'),
        isTrue,
      );
    });
  });

  group('Пустой и недоступный каталог', () {
    test('Пустой каталог не роняет экраны оплаты', () async {
      final store = MemoryLocalStore();
      final env = makeEnv(store: store);
      addTearDown(env.dispose);
      // Источник отвечает пустым каталогом: так ведёт себя недонастроенный
      // бэкенд, и экраны платежей обязаны это пережить.
      final empty = repoOver(store, env: env, source: () async => Catalog.empty);
      expect((await empty.load()).valueOrNull!.isEmpty, isTrue);

      final container = await env.container(catalogRepo: empty);

      expect(container.read(catalogNowProvider).isEmpty, isTrue);
      expect(container.read(payMethodsProvider), isEmpty);
      expect(container.read(providerSearchProvider('вода')), isEmpty);
      final catalog = container.read(catalogNowProvider);
      expect(catalog.providerById('p-water'), isNull);
      expect(catalog.methodById('wallet'), isNull);
      expect(catalog.byCategory('util'), isEmpty);
      expect(catalog.quickFor('util'), isEmpty);
      expect(catalog.maskOf('p-water').isAny, isTrue);
    });

    test('Пустой ответ источника не затирает сохранённый каталог', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await env.catalog.load();
      final broken = repoOver(env.store, env: env, source: () async => Catalog.empty);

      final result = await broken.load(refresh: true);

      // Пустой каталог почти всегда ошибка на той стороне: затирать им
      // сохранённый нельзя, иначе экраны платежей станут пустыми.
      expect(result.valueOrNull!.isEmpty, isFalse);
      expect(broken.cached().isEmpty, isFalse);
    });

    test('Отказ источника при сохранённом каталоге отдаёт сохранённый',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await env.catalog.load();
      final failing = repoOver(
        env.store,
        env: env,
        source: () async => throw const AppFailure.server(),
      );

      final result = await failing.load(refresh: true);

      // Каталог устаревает годами — падать из-за него экранам нельзя.
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.providers, isNotEmpty);
    });

    test('Отказ источника без кэша — честный Fail', () async {
      final store = MemoryLocalStore();
      final env = makeEnv(store: store);
      addTearDown(env.dispose);
      final failing = repoOver(
        store,
        env: env,
        source: () async => throw const AppFailure.network(),
      );

      final result = await failing.load();

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
    });
  });

  group('Состояние каталога', () {
    test('catalogProvider загружает каталог и refresh его обновляет',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();

      final loaded = await container.read(catalogProvider.future);

      expect(loaded.providers, isNotEmpty);
      expect(container.read(catalogNowProvider).providers, loaded.providers);

      await container.read(catalogProvider.notifier).refresh();
      expect(container.read(catalogProvider).value!.providers, isNotEmpty);
    });

    test('Свежий каталог отдаётся без похода в источник', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      var calls = 0;
      final repo = repoOver(
        env.store,
        env: env,
        source: () async {
          calls++;
          return (await env.api.catalog(locale: 'ru'));
        },
      );

      await repo.load();
      await repo.load();

      expect(calls, 1, reason: 'каталог меняется раз в месяцы');

      // refresh спрашивает всё равно: пользователь потянул список вниз.
      await repo.load(refresh: true);
      expect(calls, 2);
    });
  });
}
