import 'package:elpay/core/logger.dart';
import 'package:elpay/core/service_cat.dart';
import 'package:elpay/data/demo_data.dart';
import 'package:elpay/data/registry_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Согласованность демо-данных и реестра.
///
/// Демо-набор — это и есть «ответ бэкенда» на месяц эксплуатации: поиск
/// счёта, подключение и начисления работают по нему. Любое расхождение
/// между реестром, каталогом и начислениями выглядит на демонстрации как
/// баг приложения, и найти его надо здесь, а не на экране.
void main() {
  Log.enabled = false;

  final catalog = Demo.catalog;
  final bills = Demo.bills(testNow);

  test('У каждой записи реестра есть поставщик в каталоге', () {
    final known = {for (final p in catalog.providers) p.id};

    for (final r in Registry.accounts) {
      expect(known, contains(r.providerId), reason: 'запись ${r.id}');
    }
  });

  test('У каждого начисления демо-данных существующий objectId', () {
    final objects = {for (final o in Demo.objects) o.id};

    expect(bills, isNotEmpty);
    for (final b in bills) {
      expect(objects, contains(b.objectId), reason: 'начисление ${b.id}');
    }
  });

  test('У каждого поставщика задана маска лицевого счёта', () {
    // РАСХОЖДЕНИЕ С ПЛАНОМ, зафиксированное честно: у «Школы №29» маски
    // нет осознанно — формата у «класс и фамилия» не существует, и маска
    // отбросила бы правильный ввод. Поэтому правило такое: маска либо
    // задана и согласована со своим образцом, либо отсутствует явно,
    // и список таких поставщиков не растёт молча.
    for (final p in catalog.providers) {
      expect(p.accountHint, isNotEmpty, reason: '${p.id}: нечего показать в поле');

      if (p.mask.isAny) {
        expect(p.mask.hint, isEmpty, reason: '${p.id}: образец без маски');
        continue;
      }
      expect(p.mask.hint, isNotEmpty, reason: '${p.id}: маска без образца');
      // Образец обязан проходить свою же маску, иначе подсказка врёт.
      expect(
        p.mask.matches(p.mask.hint),
        isTrue,
        reason: '${p.id}: образец ${p.mask.hint} не проходит ${p.mask.pattern}',
      );
      // И приводиться к себе же: иначе normalize испортит верный номер.
      expect(p.mask.normalize(p.mask.hint), p.mask.hint, reason: p.id);
    }

    expect(
      {
        for (final p in catalog.providers)
          if (p.mask.isAny) p.id,
      },
      {'p-school'},
      reason: 'поставщики без маски названы явно',
    );
  });

  test('Маска поставщика приводит номер реестра к каноническому виду', () {
    for (final r in Registry.accounts) {
      final mask = catalog.maskOf(r.providerId);

      expect(mask.matches(r.accountNo), isTrue,
          reason: '${r.id}: ${r.accountNo} не проходит маску ${r.providerId}');
      // Проверка до сети не должна отбрасывать номер из самого реестра.
      expect(mask.normalize(r.accountNo), r.accountNo, reason: r.id);
    }

    // '3101187' без разделителей — тот же счёт, что '31-01187'.
    expect(catalog.maskOf('p-water').normalize('3101187'), '31-01187');
  });

  test('Каждая категория из данных известна ServiceCat или честно падает в other', () {
    void check(String? raw, String where) {
      final cat = ServiceCat.parse(raw);
      expect(cat.isKnown, isTrue, reason: '$where: категория «$raw» неизвестна');
      expect(cat.wire, raw, reason: where);
    }

    for (final p in catalog.providers) {
      check(p.cat, 'поставщик ${p.id}');
    }
    for (final c in catalog.categories) {
      check(c.cat, 'категория ${c.id}');
    }
    for (final q in catalog.quickServices) {
      check(q.cat, 'значок ${q.label}');
    }
    for (final b in bills) {
      check(b.cat, 'начисление ${b.id}');
    }
    for (final o in Demo.objects) {
      check(o.cat, 'объект ${o.id}');
    }

    // А незнакомое с бэкенда падает в other и ничего не роняет.
    expect(ServiceCat.parse('совершенно новая услуга'), ServiceCat.other);
    expect(ServiceCat.parse(''), ServiceCat.other);
    expect(iconOf(ServiceCat.other), isNotNull);
  });

  test('Значок услуги ведёт на существующего поставщика', () {
    for (final q in catalog.quickServices) {
      expect(catalog.providerById(q.providerId), isNotNull, reason: 'значок ${q.label}');
    }
  });

  test('Категория поставщика есть в каталоге категорий', () {
    final known = {for (final c in catalog.categories) c.id};

    for (final p in catalog.providers) {
      expect(known, contains(p.categoryId), reason: p.id);
      // И обратная сторона: категория поставщика действительно его находит.
      expect(catalog.byCategory(p.categoryId).map((x) => x.id), contains(p.id));
    }
  });

  test('Начисление демо-набора указывает на запись реестра и на свой счёт', () {
    for (final b in bills) {
      expect(Registry.byAccount(b.account), isNotEmpty,
          reason: 'начисление ${b.id}: номера ${b.account} нет в реестре');
      // Договорённость 'acc-<billId>', на которую опирается засев
      // демо-бэкенда: без неё начисление не привязано к счёту, и
      // отключение снесёт не то.
      expect(b.accountId, 'acc-${b.id}', reason: b.id);
    }
  });

  test('Поиск по адресу семьи находит счета, по чужому адресу — нет', () {
    final (city, street, house, flat) = Registry.homeAddress;

    final mine = Registry.byAddress(city, street, house, flat);
    expect(mine.length, greaterThanOrEqualTo(5));
    // Фильтр по поставщику оставляет только его счета — это путь
    // от значка услуги на главной.
    expect(
      Registry.byAddress(city, street, house, flat)
          .where((r) => r.providerId == 'p-gas'),
      hasLength(1),
    );

    expect(Registry.byAddress('Ош', 'ул. Несуществующая', '1', ''), isEmpty);
  });

  test('Способы оплаты: кошелёк один и у него есть баланс', () {
    final wallets = catalog.methods.where((m) => m.isWallet);

    expect(wallets, hasLength(1));
    expect(wallets.single.balance, isNotNull);
    for (final m in catalog.methods) {
      expect(m.title, isNotEmpty, reason: m.id);
    }
  });

  test('Каталог демо-набора не пустой и находится поиском', () {
    expect(catalog.isEmpty, isFalse);
    expect(catalog.searchProviders('ошводоканал'), isNotEmpty);
    // Поиск по услуге, а не только по названию.
    expect(catalog.searchProviders('холодная вода').map((p) => p.id), contains('p-water'));
    // Пустой запрос — весь список, чтобы шторка не начиналась с пустоты.
    expect(catalog.searchProviders('').length, catalog.providers.length);
  });
}
