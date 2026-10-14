/// Сопоставление колонок файла с полями ЭлPay.
///
/// Бухгалтер не настраивает выгрузку под нас: мастер сам узнаёт, что
/// «Лиц_счет», «ЛС» и «Номер лицевого» — это лицевой счёт, а «Кол_прож» —
/// жильцы. Если заголовков нет, угадывает по содержимому и честно
/// помечает такие колонки «Проверьте».
library;

import 'addresses.dart' show foldName;
import 'models.dart';

enum Field { account, name, street, house, flat, address, residents, phone, amount, period, calc, skip }

extension FieldInfo on Field {
  String get label => switch (this) {
        Field.account => 'Лицевой счёт',
        Field.name => 'ФИО',
        Field.street => 'Улица',
        Field.house => 'Дом',
        Field.flat => 'Квартира',
        Field.address => 'Адрес одной строкой',
        Field.residents => 'Жильцов',
        Field.phone => 'Телефон',
        Field.amount => 'Сумма начисления',
        Field.period => 'Период',
        Field.calc => 'Как посчитано',
        Field.skip => 'Не загружать',
      };
}

/// Какие поля бывают у каждого вида загрузки и какие из них обязательны.
List<Field> fieldsFor(ImportKind kind) => switch (kind) {
      ImportKind.subscribers => const [
          Field.account, Field.name, Field.street, Field.house, Field.flat,
          Field.address, Field.residents, Field.phone, Field.skip,
        ],
      ImportKind.charges => const [
          Field.account, Field.amount, Field.period, Field.calc, Field.name, Field.residents, Field.skip,
        ],
    };

/// Названия колонок, под которыми поле встречается в выгрузках 1С.
/// Сравниваются после foldName: без регистра, пробелов, точек и подчёркиваний.
const _synonyms = <Field, List<String>>{
  Field.account: [
    'лицсчет', 'лицевойсчет', 'лицевой', 'лс', 'лсчет', 'лицсч', 'номерлс', 'номерлицевого',
    'номерлицевогосчета', 'nls', 'account', 'кодабонента', 'абонентскийномер', 'лицевойномер',
  ],
  Field.name: [
    'абонент', 'фио', 'потребитель', 'плательщик', 'фамилияимяотчество', 'владелец', 'name',
    'наименованиеабонента', 'фиоабонента', 'собственник',
  ],
  Field.street: ['улица', 'ул', 'street', 'наименованиеулицы', 'улицаабонента'],
  Field.house: ['дом', 'д', 'номердома', 'house', 'домномер'],
  Field.flat: ['кв', 'квартира', 'flat', 'номерквартиры', 'квномер'],
  Field.address: ['адрес', 'адресабонента', 'address', 'адресобъекта', 'полныйадрес'],
  Field.residents: [
    'колпрож', 'количествопроживающих', 'проживающих', 'жильцов', 'колвочел', 'колчел', 'человек',
    'residents', 'числопрописанных', 'прописано', 'колвопроживающих', 'жильцы',
  ],
  Field.phone: ['телефон', 'тел', 'моб', 'мобильный', 'phone', 'контактныйтелефон', 'телабонента'],
  Field.amount: [
    'сумма', 'начислено', 'кначислению', 'коплате', 'сумманачисления', 'amount', 'итого',
    'начисл', 'суммакоплате', 'начисленозапериод',
  ],
  Field.period: ['период', 'месяц', 'расчетныйпериод', 'period', 'периодначисления'],
  Field.calc: ['расчет', 'основание', 'тариф', 'какпосчитано', 'формула'],
};

/// Насколько уверены в сопоставлении колонки.
enum MapConfidence {
  /// Узнали по названию колонки.
  header,

  /// Угадали по содержимому — пусть человек глянет.
  guess,

  /// Узнали, но значения требуют внимания (например, телефон без кода страны).
  check,

  /// Колонка не загружается.
  none,
}

class ColumnMap {
  const ColumnMap(this.field, this.confidence, [this.note = '']);
  final Field field;
  final MapConfidence confidence;
  final String note;

  ColumnMap withField(Field f) => ColumnMap(f, f == Field.skip ? MapConfidence.none : MapConfidence.header);
}

/// Таблица файла: заголовки (настоящие или «Колонка 1…») и строки данных.
class ParsedTable {
  const ParsedTable({
    required this.headers,
    required this.rows,
    required this.hasHeader,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final bool hasHeader;

  /// Номер строки в файле — так, как его увидит бухгалтер в Excel.
  int fileLine(int dataIndex) => dataIndex + (hasHeader ? 2 : 1);

  int get width => headers.length;

  /// Первые непустые значения колонки — для предпросмотра.
  List<String> samples(int col, {int take = 3}) => [
        for (final r in rows)
          if (col < r.length && r[col].trim().isNotEmpty) r[col].trim(),
      ].take(take).toList();
}

final _accountLike = RegExp(r'^\s*[0-9A-Za-zА-Яа-я]{1,6}[-–—][0-9]{3,7}\s*$');
final _moneyLike = RegExp(r'^\s*-?[0-9  ]+([.,][0-9]{1,2})?\s*$');
final _phoneLike = RegExp(r'^\s*\+?[0-9][0-9 ()\-]{8,16}\s*$');

Field? _bySynonym(String header) {
  final key = foldName(header);
  if (key.isEmpty) return null;
  for (final e in _synonyms.entries) {
    if (e.value.contains(key)) return e.key;
  }
  return null;
}

/// Первая строка — заголовки? Да, если в ней узнаётся хотя бы два названия
/// колонок или если в ней нет ни одного лицевого, а ниже они есть.
bool looksLikeHeader(List<List<String>> rows) {
  if (rows.isEmpty) return false;
  final first = rows.first;
  final known = first.where((c) => _bySynonym(c) != null).length;
  if (known >= 2) return true;
  final firstHasAccount = first.any((c) => _accountLike.hasMatch(c));
  final secondHasAccount = rows.length > 1 && rows[1].any((c) => _accountLike.hasMatch(c));
  final firstHasNumbers = first.any((c) => RegExp(r'^\s*[0-9]+([.,][0-9]+)?\s*$').hasMatch(c));
  return !firstHasAccount && secondHasAccount && !firstHasNumbers;
}

ParsedTable toTable(List<List<String>> raw) {
  if (raw.isEmpty) return const ParsedTable(headers: [], rows: [], hasHeader: false);
  final header = looksLikeHeader(raw);
  final width = raw.fold<int>(0, (w, r) => r.length > w ? r.length : w);
  final headers = header
      ? [for (var i = 0; i < width; i++) i < raw.first.length && raw.first[i].trim().isNotEmpty ? raw.first[i].trim() : 'Колонка ${i + 1}']
      : [for (var i = 0; i < width; i++) 'Колонка ${i + 1}'];
  final rows = [
    for (final r in header ? raw.skip(1) : raw) [...r, for (var i = r.length; i < width; i++) ''],
  ];
  return ParsedTable(headers: headers, rows: rows, hasHeader: header);
}

/// Угадать поле по содержимому колонки.
Field? _byContent(List<String> values) {
  final v = [for (final x in values) x.trim()].where((x) => x.isNotEmpty).take(30).toList();
  if (v.isEmpty) return null;
  double share(bool Function(String) test) => v.where(test).length / v.length;

  if (share(_accountLike.hasMatch) > .8) return Field.account;
  if (share(_phoneLike.hasMatch) > .8 && v.any((x) => x.replaceAll(RegExp(r'\D'), '').length >= 9)) return Field.phone;
  if (share((x) => RegExp(r'^[0-9]{1,2}$').hasMatch(x) && int.parse(x) <= 20) > .9) return Field.residents;
  if (share(_moneyLike.hasMatch) > .9 && v.any((x) => x.contains(',') || x.contains('.'))) return Field.amount;
  if (share((x) => RegExp(r'^[А-ЯЁӨҮҢ][а-яёөүң]+(\s+[А-ЯЁӨҮҢ][а-яёөүң.]*){1,3}$').hasMatch(x)) > .7) return Field.name;
  if (share((x) => RegExp(r'(ул\.?|пр\.?|пер\.?)\s', caseSensitive: false).hasMatch(x) && RegExp(r'[0-9]').hasMatch(x)) > .7) {
    return Field.address;
  }
  return null;
}

/// Сопоставить колонки: сначала шаблон прошлой загрузки, потом названия,
/// потом содержимое. Одно поле не назначается двум колонкам.
List<ColumnMap> autoMap(ParsedTable t, ImportKind kind, {Map<String, Field>? template}) {
  final allowed = fieldsFor(kind).toSet();
  final used = <Field>{};
  final out = List<ColumnMap>.filled(t.width, const ColumnMap(Field.skip, MapConfidence.none));

  void take(int i, Field f, MapConfidence c, [String note = '']) {
    if (f != Field.skip && (used.contains(f) || !allowed.contains(f))) return;
    used.add(f);
    out[i] = ColumnMap(f, f == Field.skip ? MapConfidence.none : c, note);
  }

  // 1. Шаблон: колонка с тем же названием, что в прошлый раз.
  if (template != null && t.hasHeader) {
    for (var i = 0; i < t.width; i++) {
      final f = template[t.headers[i]];
      if (f != null) take(i, f, MapConfidence.header);
    }
  }
  // 2. Названия колонок.
  for (var i = 0; i < t.width; i++) {
    if (out[i].confidence != MapConfidence.none || !t.hasHeader) continue;
    if (template != null && template[t.headers[i]] == Field.skip) continue;
    final f = _bySynonym(t.headers[i]);
    if (f != null) take(i, f, MapConfidence.header);
  }
  // 3. Содержимое.
  for (var i = 0; i < t.width; i++) {
    if (out[i].confidence != MapConfidence.none) continue;
    if (template != null && template[t.headers[i]] == Field.skip) continue;
    final f = _byContent([for (final r in t.rows.take(50)) r[i]]);
    if (f != null) take(i, f, MapConfidence.guess, 'угадали по значениям');
  }
  // Если есть и улица/дом, и «адрес одной строкой» — берём раздельные поля.
  final addr = out.indexWhere((m) => m.field == Field.address);
  if (addr >= 0 && used.contains(Field.street) && used.contains(Field.house)) {
    out[addr] = const ColumnMap(Field.skip, MapConfidence.none);
  }
  // Телефоны без кода страны — узнали, но попросим взглянуть.
  final ph = out.indexWhere((m) => m.field == Field.phone);
  if (ph >= 0) {
    final s = t.samples(ph, take: 20);
    if (s.isNotEmpty && s.every((x) => !x.trim().startsWith('+'))) {
      out[ph] = ColumnMap(Field.phone, MapConfidence.check, 'номера без кода страны — допишем +996 сами');
    }
  }
  return out;
}

/// Чего не хватает, чтобы загрузить: обязательные поля без колонки.
List<Field> missingRequired(List<ColumnMap> map, ImportKind kind) {
  final have = map.map((m) => m.field).toSet();
  return switch (kind) {
    ImportKind.subscribers => [
        if (!have.contains(Field.account)) Field.account,
        if (!have.contains(Field.name)) Field.name,
        if (!have.contains(Field.address) && !have.contains(Field.street)) Field.street,
        if (!have.contains(Field.address) && !have.contains(Field.house)) Field.house,
      ],
    ImportKind.charges => [
        if (!have.contains(Field.account)) Field.account,
        if (!have.contains(Field.amount)) Field.amount,
      ],
  };
}

/// Шаблон для следующей загрузки: название колонки → поле.
Map<String, Field> templateOf(ParsedTable t, List<ColumnMap> map) => {
      for (var i = 0; i < t.width && i < map.length; i++) t.headers[i]: map[i].field,
    };
