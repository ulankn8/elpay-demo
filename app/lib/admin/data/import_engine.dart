/// Проверка файла ДО записи в реестр.
///
/// Главное правило мастера: ничего не меняется, пока служба не увидела,
/// что именно изменится. План раскладывает строки файла на новые,
/// обновления, без изменений и ошибки — с причиной и, где можно,
/// готовой правкой «Исправить на это».
library;

import 'addresses.dart';
import 'mapping.dart';
import 'models.dart';

enum IssueKind {
  badAccount,
  duplicate,
  emptyName,
  addressNotFound,
  badResidents,
  accountNotFound,
  badAmount,
  periodMismatch,
}

extension IssueLabel on IssueKind {
  String get label => switch (this) {
        IssueKind.badAccount => 'Лицевой не по формату',
        IssueKind.duplicate => 'Дубль лицевого',
        IssueKind.emptyName => 'Пустое ФИО',
        IssueKind.addressNotFound => 'Адрес не найден',
        IssueKind.badResidents => 'Жильцов не число',
        IssueKind.accountNotFound => 'Нет такого абонента',
        IssueKind.badAmount => 'Сумма не разобрана',
        IssueKind.periodMismatch => 'Другой период',
      };
}

/// Строка файла, которая не загрузится, и как её поправить.
class RowIssue {
  const RowIssue({
    required this.index,
    required this.line,
    required this.kind,
    required this.message,
    this.account = '',
    this.name = '',
    this.address = '',
    this.fixLabel,
    this.fix,
  });

  /// Номер строки данных (с нуля) и строки файла (как в Excel).
  final int index, line;
  final IssueKind kind;

  /// Что не так: «Похоже на ул. Курманжан Датка».
  final String message;
  final String account, name, address;

  /// Готовая правка: подпись кнопки и новые значения полей.
  final String? fixLabel;
  final Map<Field, String>? fix;
}

class SubscriberChange {
  const SubscriberChange(this.before, this.after, this.fields);
  final Subscriber before, after;

  /// Что поменялось: «жильцов 4 → 5».
  final List<String> fields;
}

class SubscriberPlan {
  const SubscriberPlan({
    required this.rows,
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.issues,
  });

  final int rows;
  final List<Subscriber> created;
  final List<SubscriberChange> updated;
  final int unchanged;
  final List<RowIssue> issues;

  int get willLoad => rows - issues.length;
  Map<IssueKind, int> get issueCounts {
    final m = <IssueKind, int>{};
    for (final i in issues) {
      m[i.kind] = (m[i.kind] ?? 0) + 1;
    }
    return m;
  }
}

class ChargesPlan {
  const ChargesPlan({
    required this.rows,
    required this.period,
    required this.charges,
    required this.issues,
    required this.replaces,
    required this.withoutCharge,
  });

  final int rows;
  final Period period;
  final List<Charge> charges;
  final List<RowIssue> issues;

  /// Сколько начислений за этот период уже было (загрузка их заменит).
  final int replaces;

  /// Активные абоненты, которым в файле нет начисления.
  final int withoutCharge;

  double get total => charges.fold<double>(0, (s, c) => s + c.amount);
  int get willLoad => charges.length;
}

/// Правила лицевого счёта службы: «31-00562» — две цифры, дефис, пять цифр.
class AccountRule {
  const AccountRule({required this.pattern, required this.example, this.prefixDigits = 2, this.bodyDigits = 5});
  final RegExp pattern;
  final String example;
  final int prefixDigits, bodyDigits;

  static final water = AccountRule(pattern: RegExp(r'^\d{2}-\d{5}$'), example: '31-00562');

  /// Привести к виду службы: пробелы, длинные тире, «31 00562».
  String normalize(String raw) {
    var s = raw.trim().toUpperCase().replaceAll(RegExp(r'[–—‐−]'), '-').replaceAll(RegExp(r'\s+'), '');
    final m = RegExp(r'^(\d{2})(\d{5})$').firstMatch(s);
    if (m != null) s = '${m.group(1)}-${m.group(2)}';
    return s;
  }

  /// Можно ли исправить: «31-0562» → «31-00562» (потерян ведущий ноль).
  String? suggest(String normalized) {
    final m = RegExp(r'^(\d{2})-(\d{1,4})$').firstMatch(normalized);
    if (m == null) return null;
    return '${m.group(1)}-${m.group(2)!.padLeft(bodyDigits, '0')}';
  }
}

String _cell(List<String> row, int col) => col >= 0 && col < row.length ? row[col].trim() : '';

int _col(List<ColumnMap> map, Field f) => map.indexWhere((m) => m.field == f);

/// Телефон к виду +996 XXX XX XX XX. Пустое и непонятное — пусто.
String normalizePhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  String? nine;
  if (d.length == 9) nine = d;
  if (d.length == 10 && d.startsWith('0')) nine = d.substring(1);
  if (d.length == 12 && d.startsWith('996')) nine = d.substring(3);
  if (nine == null) return '';
  return '+996 ${nine.substring(0, 3)} ${nine.substring(3, 5)} ${nine.substring(5, 7)} ${nine.substring(7)}';
}

/// «Токтогулова  айгерим» → «Токтогулова Айгерим».
String normalizeName(String raw) => raw
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .map((p) => p.length == 1 ? p.toUpperCase() : p[0].toUpperCase() + p.substring(1))
    .join(' ');

/// Сумма из «1 234,56», «205.00», «205».
double? parseAmount(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.').replaceAll(RegExp(r'(сом|сомов|kgs)$', caseSensitive: false), '');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

const _monthsRu = {
  'январ': 1, 'феврал': 2, 'март': 3, 'апрел': 4, 'ма': 5, 'июн': 6,
  'июл': 7, 'август': 8, 'сентябр': 9, 'октябр': 10, 'ноябр': 11, 'декабр': 12,
};

/// Период из «2026-09», «09.2026», «сентябрь 2026», «01.09.2026» или числа даты Excel.
Period? parsePeriod(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  var m = RegExp(r'^(\d{4})[-./](\d{1,2})$').firstMatch(s);
  if (m != null) return Period(int.parse(m.group(1)!), int.parse(m.group(2)!));
  m = RegExp(r'^(\d{1,2})[-./](\d{4})$').firstMatch(s);
  if (m != null) return Period(int.parse(m.group(2)!), int.parse(m.group(1)!));
  m = RegExp(r'^\d{1,2}[-./](\d{1,2})[-./](\d{4})$').firstMatch(s);
  if (m != null) return Period(int.parse(m.group(2)!), int.parse(m.group(1)!));
  m = RegExp(r'^([а-я]+)\s+(\d{4})').firstMatch(s);
  if (m != null) {
    final word = m.group(1)!;
    // «май» короче остальных, поэтому сначала длинные основы.
    final keys = _monthsRu.keys.toList()..sort((a, b) => b.length - a.length);
    for (final k in keys) {
      if (word.startsWith(k)) return Period(int.parse(m.group(2)!), _monthsRu[k]!);
    }
  }
  final serial = double.tryParse(s);
  if (serial != null && serial > 30000 && serial < 80000) {
    final d = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    return Period(d.year, d.month);
  }
  return null;
}

/// Значения строки по полям с учётом правок, которые служба уже приняла.
Map<Field, String> _values(List<String> row, List<ColumnMap> map, Map<Field, String>? overrides) {
  final v = <Field, String>{};
  for (var i = 0; i < map.length; i++) {
    final f = map[i].field;
    if (f == Field.skip) continue;
    v[f] = _cell(row, i);
  }
  if (overrides != null) v.addAll(overrides);
  return v;
}

/// Разложить файл абонентов на план.
///
/// [existing] — реестр службы по лицевому. [overrides] — правки строк,
/// принятые в мастере («Исправить на это», вписанное ФИО).
/// [updateExisting] = false — уже известные лицевые пропускаются как есть.
SubscriberPlan planSubscribers({
  required ParsedTable table,
  required List<ColumnMap> map,
  required Map<String, Subscriber> existing,
  required DateTime now,
  StreetBook? streets,
  AccountRule? rule,
  Map<int, Map<Field, String>> overrides = const {},
  bool updateExisting = true,
}) {
  final book = streets ?? StreetBook();
  final acc = rule ?? AccountRule.water;
  final created = <Subscriber>[];
  final updated = <SubscriberChange>[];
  final issues = <RowIssue>[];
  var unchanged = 0;
  final seen = <String, int>{};

  // Как часто то же неверное написание улицы встречается в файле —
  // чтобы сказать «так же написано ещё в 4 строках». Ключ — написание
  // как есть: foldName склеил бы «Курманжандатка» с правильным
  // «Курманжан Датка» и посчитал бы верные строки ошибочными.
  final streetCol = _col(map, Field.street);
  String spelling(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final spellCount = <String, int>{};
  if (streetCol >= 0) {
    for (final r in table.rows) {
      final k = spelling(_cell(r, streetCol));
      spellCount[k] = (spellCount[k] ?? 0) + 1;
    }
  }

  for (var i = 0; i < table.rows.length; i++) {
    final row = table.rows[i];
    final line = table.fileLine(i);
    final v = _values(row, map, overrides[i]);

    var street = v[Field.street] ?? '';
    var house = v[Field.house] ?? '';
    var flat = v[Field.flat] ?? '';
    if (street.isEmpty && (v[Field.address] ?? '').isNotEmpty) {
      final parts = splitAddress(v[Field.address]!);
      street = parts.street;
      if (house.isEmpty) house = parts.house;
      if (flat.isEmpty) flat = parts.flat;
    }
    final rawAccount = v[Field.account] ?? '';
    final account = acc.normalize(rawAccount);
    final name = normalizeName(v[Field.name] ?? '');
    final addressText = [street, house, if (flat.isNotEmpty) 'кв. $flat'].where((p) => p.isNotEmpty).join(', ');

    RowIssue issue(IssueKind k, String msg, {String? fixLabel, Map<Field, String>? fix}) => RowIssue(
          index: i,
          line: line,
          kind: k,
          message: msg,
          account: account.isEmpty ? rawAccount : account,
          name: name,
          address: addressText,
          fixLabel: fixLabel,
          fix: fix,
        );

    // 1. Лицевой.
    if (!acc.pattern.hasMatch(account)) {
      final s = acc.suggest(account);
      final owner = s == null ? null : existing[s];
      if (s == null) {
        issues.add(issue(IssueKind.badAccount, account.isEmpty ? 'Лицевой не указан' : 'Ожидается вид ${acc.example}'));
      } else if (owner != null && normalizeName(owner.name) != name) {
        // Подсказанный лицевой уже у другого человека: автоправка переписала
        // бы чужую карточку. Только предупреждаем — решает человек.
        issues.add(issue(IssueKind.badAccount,
            'Похоже, потерян ноль, но $s уже у ${owner.name} — проверьте лицевой в 1С'));
      } else {
        issues.add(issue(IssueKind.badAccount, 'Похоже, потерян ноль: $s', fixLabel: 'Исправить на $s', fix: {Field.account: s}));
      }
      continue;
    }
    // 2. Дубль в самом файле: первая строка загружается, остальные — нет.
    final first = seen[account];
    if (first != null) {
      final firstName = normalizeName(_values(table.rows[first], map, overrides[first])[Field.name] ?? '');
      issues.add(issue(IssueKind.duplicate,
          'Уже есть в строке ${table.fileLine(first)}${firstName.isNotEmpty ? ' — $firstName' : ''}. Загрузим ту строку'));
      continue;
    }
    seen[account] = i;

    // 3. ФИО.
    if (name.isEmpty) {
      issues.add(issue(IssueKind.emptyName, 'Впишите ФИО здесь или в 1С'));
      continue;
    }
    // 4. Адрес по справочнику.
    final found = book.find(street);
    if (found.match == StreetMatch.none) {
      issues.add(issue(IssueKind.addressNotFound,
          street.isEmpty ? 'Улица не указана' : 'Улицы «${stripKind(street)}» нет в справочнике Оша'));
      continue;
    }
    if (found.match == StreetMatch.suggested) {
      final n = (spellCount[spelling(v[Field.street] ?? '')] ?? 1) - 1;
      final why = n > 0 ? 'так же написано ещё в $n ${n % 10 == 1 && n % 100 != 11 ? 'строке' : 'строках'}' : found.why;
      issues.add(issue(IssueKind.addressNotFound, 'Похоже на ${found.street!.full} · $why',
          fixLabel: 'Исправить на это', fix: {Field.street: found.street!.full, Field.address: ''}));
      continue;
    }
    if (house.isEmpty) {
      issues.add(issue(IssueKind.addressNotFound, 'Не указан номер дома'));
      continue;
    }
    final fixedHouse = fixHouseNumber(house);
    if (fixedHouse != null) {
      issues.add(issue(IssueKind.addressNotFound, '«О» вместо нуля → дом $fixedHouse',
          fixLabel: 'Исправить на это', fix: {Field.house: fixedHouse}));
      continue;
    }
    // 5. Жильцы.
    final residentsRaw = v[Field.residents] ?? '';
    int? residents;
    if (residentsRaw.isNotEmpty) {
      residents = int.tryParse(residentsRaw.replaceAll(RegExp(r'[.,]0+$'), ''));
      if (residents == null || residents < 0 || residents > 40) {
        issues.add(issue(IssueKind.badResidents, '«$residentsRaw» — укажите число от 0 до 40'));
        continue;
      }
    }

    final before = existing[account];
    final phone = (v[Field.phone] ?? '').isEmpty ? (before?.phone ?? '') : normalizePhone(v[Field.phone]!);
    final next = Subscriber(
      account: account,
      name: name,
      street: found.street!.full,
      house: house,
      flat: flat,
      residents: residents ?? before?.residents ?? 1,
      phone: phone,
      inAppSince: before?.inAppSince,
      meter: before?.meter ?? false,
      active: true,
      note: before?.note ?? '',
      createdAt: before?.createdAt ?? now,
    );
    if (before == null) {
      created.add(next);
    } else if (!updateExisting || next.sameDataAs(before) && before.active) {
      unchanged++;
    } else {
      updated.add(SubscriberChange(before, next, _diff(before, next)));
    }
  }
  return SubscriberPlan(
    rows: table.rows.length,
    created: created,
    updated: updated,
    unchanged: unchanged,
    issues: issues,
  );
}

List<String> _diff(Subscriber a, Subscriber b) => [
      if (a.name != b.name) 'ФИО: ${a.name} → ${b.name}',
      if (a.street != b.street || a.house != b.house || a.flat != b.flat) 'адрес: ${a.address} → ${b.address}',
      if (a.residents != b.residents) 'жильцов ${a.residents} → ${b.residents}',
      if (a.phone != b.phone) a.phone.isEmpty ? 'добавлен телефон' : 'телефон изменён',
      if (!a.active) 'снова активен',
    ];

/// Разложить файл начислений за [period] на план.
ChargesPlan planCharges({
  required ParsedTable table,
  required List<ColumnMap> map,
  required Map<String, Subscriber> subscribers,
  required Period period,
  required int alreadyLoaded,
  AccountRule? rule,
  Map<int, Map<Field, String>> overrides = const {},
}) {
  final acc = rule ?? AccountRule.water;
  final charges = <Charge>[];
  final issues = <RowIssue>[];
  final seen = <String, int>{};

  for (var i = 0; i < table.rows.length; i++) {
    final v = _values(table.rows[i], map, overrides[i]);
    final line = table.fileLine(i);
    final account = acc.normalize(v[Field.account] ?? '');
    final sub = subscribers[account];
    RowIssue issue(IssueKind k, String msg, {String? fixLabel, Map<Field, String>? fix}) => RowIssue(
          index: i,
          line: line,
          kind: k,
          message: msg,
          account: account,
          name: sub?.name ?? normalizeName(v[Field.name] ?? ''),
          address: sub?.address ?? '',
          fixLabel: fixLabel,
          fix: fix,
        );

    if (!acc.pattern.hasMatch(account)) {
      final s = acc.suggest(account);
      issues.add(s != null
          ? issue(IssueKind.badAccount, 'Похоже, потерян ноль: $s', fixLabel: 'Исправить на $s', fix: {Field.account: s})
          : issue(IssueKind.badAccount, 'Ожидается вид ${acc.example}'));
      continue;
    }
    if (sub == null) {
      issues.add(issue(IssueKind.accountNotFound, 'Такого лицевого нет в реестре — сначала загрузите абонентов'));
      continue;
    }
    final first = seen[account];
    if (first != null) {
      issues.add(issue(IssueKind.duplicate, 'Начисление уже есть в строке ${table.fileLine(first)}'));
      continue;
    }
    seen[account] = i;
    final amount = parseAmount(v[Field.amount] ?? '');
    if (amount == null || amount < 0) {
      issues.add(issue(IssueKind.badAmount, '«${v[Field.amount] ?? ''}» — нужна сумма в сомах, например 205,00'));
      continue;
    }
    final p = (v[Field.period] ?? '').isEmpty ? period : parsePeriod(v[Field.period]!);
    if (p == null || p != period) {
      issues.add(issue(IssueKind.periodMismatch, 'В строке период «${v[Field.period]}», а загружаем ${period.key}'));
      continue;
    }
    final calc = (v[Field.calc] ?? '').isNotEmpty
        ? v[Field.calc]!
        : sub.meter
            ? 'по счётчику'
            : '${sub.residents} чел × 41 сом';
    charges.add(Charge(account: account, period: period, amount: (amount * 100).round() / 100, calc: calc));
  }
  final withCharge = {for (final c in charges) c.account};
  final without = subscribers.values.where((s) => s.active && !withCharge.contains(s.account)).length;
  return ChargesPlan(
    rows: table.rows.length,
    period: period,
    charges: charges,
    issues: issues,
    replaces: alreadyLoaded,
    withoutCharge: without,
  );
}
