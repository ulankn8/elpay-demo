import 'package:elpay/admin/data/addresses.dart';
import 'package:elpay/admin/data/csv.dart';
import 'package:elpay/admin/data/import_engine.dart';
import 'package:elpay/admin/data/mapping.dart';
import 'package:elpay/admin/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 1, 9, 42);

/// Выгрузка «как из 1С»: свои названия колонок, улица отдельно.
const csv1c = 'Лиц_счет;Абонент;Улица;Дом;Кв;Кол_прож;Телефон;Примечание\n'
    '31-00562;Токтогулова Айгерим;ул. Курманжан Датка;212;14;5;0555 31 82 47;\n'
    '31-00218;Абдыкадыров Нурлан;ул. Ленина;301;56;3;;\n'
    '31-02288;Жээнбекова Нуриза;ул. Курманжандатка;212;31;2;;\n'
    '31-02289;Сапаров Эрмек;ул. Курманжандатка;214;;4;;\n'
    '31-00873;Абдулаев Улукбек;ул. Ленина;3О1;12;1;;\n'
    '31-0562;Иманова Чолпон;ул. Навои;20;;2;;\n'
    '31-00218;Абдыкадыров Н.;ул. Ленина;301;56;3;;дубль\n'
    '31-02350;;ул. Навои;31;;1;;\n'
    '31-00655;Ниязов Эркин;ж/м Ак-Тилек;7;;3;;\n'
    '31-02290;Осмонов Бекжан;пр. Масалиева;52;18;x;;\n';

ParsedTable table(String text) => toTable(parseCsv(text));

void main() {
  group('Сопоставление колонок', () {
    test('названия колонок 1С узнаются сами', () {
      final t = table(csv1c);
      expect(t.hasHeader, isTrue);
      final m = autoMap(t, ImportKind.subscribers);
      expect([for (final c in m) c.field], [
        Field.account, Field.name, Field.street, Field.house, Field.flat, Field.residents, Field.phone, Field.skip,
      ]);
      expect(m[0].confidence, MapConfidence.header);
      expect(missingRequired(m, ImportKind.subscribers), isEmpty);
    });

    test('телефоны без кода страны помечены «Проверьте»', () {
      final m = autoMap(table(csv1c), ImportKind.subscribers);
      expect(m[6].confidence, MapConfidence.check);
      expect(m[6].note, contains('+996'));
    });

    test('файл без заголовков: колонки угадываются по значениям', () {
      const raw = '31-00562;Токтогулова Айгерим;ул. Курманжан Датка, 212, кв. 14;5\n'
          '31-00218;Абдыкадыров Нурлан;ул. Ленина, 301, кв. 56;3\n'
          '31-00944;Маматова Гулзат;ул. Навои, 18;4\n';
      final t = table(raw);
      expect(t.hasHeader, isFalse);
      final m = autoMap(t, ImportKind.subscribers);
      expect(m.map((c) => c.field), [Field.account, Field.name, Field.address, Field.residents]);
      expect(m.every((c) => c.confidence == MapConfidence.guess), isTrue);
    });

    test('шаблон прошлой загрузки побеждает угадывание', () {
      final t = table(csv1c);
      final tpl = templateOf(t, autoMap(t, ImportKind.subscribers))..['Примечание'] = Field.skip;
      tpl['Телефон'] = Field.skip; // в прошлый раз телефоны не грузили
      final m = autoMap(t, ImportKind.subscribers, template: tpl);
      expect(m[6].field, Field.skip);
    });

    test('без лицевого загрузить нельзя — мастер говорит, чего не хватает', () {
      final t = table('Абонент;Улица;Дом\nТоктогулова;Навои;18\n');
      final m = autoMap(t, ImportKind.subscribers);
      expect(missingRequired(m, ImportKind.subscribers), contains(Field.account));
    });

    test('начисления: сумма и период узнаются', () {
      final t = table('ЛС;Сумма к оплате;Период\n31-00562;205,00;сентябрь 2026\n');
      final m = autoMap(t, ImportKind.charges);
      expect(m.map((c) => c.field), [Field.account, Field.amount, Field.period]);
    });
  });

  group('Справочник улиц', () {
    final book = StreetBook();
    test('точное совпадение — с типом улицы и без', () {
      expect(book.find('ул. Курманжан Датка').match, StreetMatch.exact);
      expect(book.find('Курманжан Датка').match, StreetMatch.exact);
    });
    test('слитное написание, другое написание и опечатка — предлагаем', () {
      expect(book.find('ул. Курманжандатка').street!.name, 'Курманжан Датка');
      expect(book.find('К. Датка').street!.name, 'Курманжан Датка');
      expect(book.find('Масалиев').street!.name, 'Масалиева');
      expect(book.find('Ноокатская').match, StreetMatch.exact);
      expect(book.find('Нооктская').match, StreetMatch.suggested);
    });
    test('незнакомое не притягиваем за уши', () {
      expect(book.find('ж/м Ак-Тилек').match, StreetMatch.none);
      expect(book.find('Ленинградская').match, StreetMatch.none);
    });
    test('адрес одной строкой разбирается', () {
      final a = splitAddress('ул. Ленина, 301, кв. 56');
      expect((a.street, a.house, a.flat), ('ул. Ленина', '301', '56'));
      final b = splitAddress('Навои 18');
      expect((b.street, b.house, b.flat), ('Навои', '18', ''));
      final c = splitAddress('Масалиева д.52 кв.7');
      expect((c.street, c.house, c.flat), ('Масалиева', '52', '7'));
    });
  });

  group('План загрузки абонентов', () {
    final existing = {
      '31-00562': const Subscriber(
          account: '31-00562', name: 'Токтогулова Айгерим', street: 'ул. Курманжан Датка',
          house: '212', flat: '14', residents: 4, phone: '+996 555 31 82 47'),
      '31-00218': const Subscriber(
          account: '31-00218', name: 'Абдыкадыров Нурлан', street: 'ул. Ленина', house: '301', flat: '56', residents: 3),
    };

    SubscriberPlan plan({Map<int, Map<Field, String>> overrides = const {}}) {
      final t = table(csv1c);
      return planSubscribers(
          table: t, map: autoMap(t, ImportKind.subscribers), existing: existing, now: now, overrides: overrides);
    }

    test('строки раскладываются: новые, обновления, без изменений, ошибки', () {
      final p = plan();
      expect(p.rows, 10);
      expect(p.updated.map((c) => c.after.account), ['31-00562']);
      expect(p.updated.single.fields, ['жильцов 4 → 5']);
      expect(p.unchanged, 1); // 31-00218 тот же
      expect(p.created, isEmpty);
      expect(p.issues, hasLength(8));
      expect(p.willLoad, 2);
      // Ничего не загружено — это только план.
      expect(existing['31-00562']!.residents, 4);
    });

    test('у каждой ошибки — строка файла, причина и, где можно, правка', () {
      final byLine = {for (final i in plan().issues) i.line: i};
      expect(byLine[4]!.kind, IssueKind.addressNotFound);
      expect(byLine[4]!.message, contains('Похоже на ул. Курманжан Датка'));
      expect(byLine[4]!.message, contains('ещё в 1 строке'));
      expect(byLine[4]!.fix, {Field.street: 'ул. Курманжан Датка', Field.address: ''});
      expect(byLine[6]!.message, contains('дом 301'));
      expect(byLine[7]!.kind, IssueKind.badAccount);
      expect(byLine[7]!.fix, isNull, reason: '31-00562 занят другим человеком');
      expect(byLine[8]!.kind, IssueKind.duplicate);
      expect(byLine[8]!.message, contains('строке 3'));
      expect(byLine[9]!.kind, IssueKind.emptyName);
      expect(byLine[10]!.kind, IssueKind.addressNotFound);
      expect(byLine[10]!.fix, isNull, reason: 'жилмассива нет в справочнике — подсказать нечего');
      expect(byLine[11]!.kind, IssueKind.badResidents);
    });

    test('принятая правка «Исправить на это» превращает ошибку в новую строку', () {
      final first = plan();
      final fixes = {
        for (final i in first.issues)
          if (i.fix != null && i.kind == IssueKind.addressNotFound) i.index: i.fix!,
      };
      final p = plan(overrides: fixes);
      expect(p.created.map((s) => s.account), containsAll(['31-02288', '31-02289', '31-00873']));
      final z = p.created.firstWhere((s) => s.account == '31-02288');
      expect(z.street, 'ул. Курманжан Датка');
      expect(z.address, 'ул. Курманжан Датка, 212, кв. 31');
    });

    test('подсказка лицевого не переписывает чужую карточку', () {
      // «31-0562» → 31-00562, но этот лицевой у Токтогуловой, а в строке — Иманова.
      final p = plan();
      final i = p.issues.firstWhere((x) => x.line == 7);
      expect(i.fix, isNull, reason: 'автоправка переписала бы карточку Токтогуловой');
      expect(i.message, contains('уже у Токтогулова Айгерим'));
    });

    test('подсказка лицевого есть, если номер свободен или это тот же человек', () {
      final t = table('Лиц_счет;Абонент;Улица;Дом\n31-0562;Токтогулова Айгерим;ул. Курманжан Датка;212\n31-999;Новый Абонент;ул. Навои;1\n');
      final p = planSubscribers(table: t, map: autoMap(t, ImportKind.subscribers), existing: existing, now: now);
      expect(p.issues[0].fix, {Field.account: '31-00562'}, reason: 'тот же человек');
      expect(p.issues[1].fix, {Field.account: '31-00999'}, reason: 'номер свободен');
    });

    test('исправленный лицевой «31-0562» совпал с существующим — это дубль-обновление', () {
      final p = plan(overrides: {5: {Field.account: '31-00562'}});
      // Такой лицевой уже встречался в строке 2 — значит, дубль в файле.
      final i = p.issues.firstWhere((x) => x.index == 5);
      expect(i.kind, IssueKind.duplicate);
    });

    test('«не обновлять известных»: существующие лицевые пропускаются', () {
      final t = table(csv1c);
      final p = planSubscribers(
          table: t, map: autoMap(t, ImportKind.subscribers), existing: existing, now: now, updateExisting: false);
      expect(p.updated, isEmpty);
      expect(p.unchanged, 2);
    });

    test('телефон приводится к +996, имя — к заглавным', () {
      final t = table('ЛС;ФИО;Улица;Дом;Тел\n31-04000;сыдыкова  жамиля;Масалиева;52;0700 12 64 09\n');
      final p = planSubscribers(table: t, map: autoMap(t, ImportKind.subscribers), existing: const {}, now: now);
      final s = p.created.single;
      expect(s.name, 'Сыдыкова Жамиля');
      expect(s.phone, '+996 700 12 64 09');
      expect(s.street, 'ул. Масалиева');
      expect(s.residents, 1, reason: 'без колонки жильцов — один по умолчанию');
    });
  });

  group('План загрузки начислений', () {
    final subs = {
      for (final s in const [
        Subscriber(account: '31-00562', name: 'Токтогулова Айгерим', street: 'ул. Курманжан Датка', house: '212', residents: 5),
        Subscriber(account: '31-00218', name: 'Абдыкадыров Нурлан', street: 'ул. Ленина', house: '301', residents: 3),
        Subscriber(account: '31-00944', name: 'Маматова Гулзат', street: 'ул. Навои', house: '18', residents: 4),
      ])
        s.account: s,
    };

    test('суммы по лицевым, ошибки по строкам, кто остался без начисления', () {
      final t = table('ЛС;Сумма;Период\n'
          '31-00562;205,00;сентябрь 2026\n'
          '31-00218;123;09.2026\n'
          '31-09999;41;сентябрь 2026\n'
          '31-00218;123;сентябрь 2026\n'
          '31-00944;сто;сентябрь 2026\n');
      final p = planCharges(
          table: t, map: autoMap(t, ImportKind.charges), subscribers: subs, period: const Period(2026, 9), alreadyLoaded: 0);
      expect(p.charges.map((c) => c.account), ['31-00562', '31-00218']);
      expect(p.total, 328);
      expect(p.charges.first.calc, '5 чел × 41 сом');
      expect(p.issues.map((i) => i.kind), [IssueKind.accountNotFound, IssueKind.duplicate, IssueKind.badAmount]);
      expect(p.withoutCharge, 1); // Маматова
    });

    test('строка за другой месяц не попадает в загружаемый период', () {
      final t = table('ЛС;Сумма;Период\n31-00562;205;август 2026\n');
      final p = planCharges(
          table: t, map: autoMap(t, ImportKind.charges), subscribers: subs, period: const Period(2026, 9), alreadyLoaded: 3);
      expect(p.issues.single.kind, IssueKind.periodMismatch);
      expect(p.replaces, 3);
    });

    test('периоды и суммы во всех видах, как их пишут бухгалтеры', () {
      expect(parsePeriod('2026-09'), const Period(2026, 9));
      expect(parsePeriod('09.2026'), const Period(2026, 9));
      expect(parsePeriod('01.09.2026'), const Period(2026, 9));
      expect(parsePeriod('Сентябрь 2026 г.'), const Period(2026, 9));
      expect(parsePeriod('май 2026'), const Period(2026, 5));
      expect(parsePeriod('46266'), const Period(2026, 9), reason: 'число даты Excel');
      expect(parseAmount('1 234,56'), 1234.56);
      expect(parseAmount('205.00'), 205);
      expect(parseAmount('205 сом'), 205);
      expect(parseAmount('сто'), isNull);
    });
  });
}
