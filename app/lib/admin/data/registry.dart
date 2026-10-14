/// Реестр платежей для 1С и подсказки для платежей без сопоставления.
library;

import 'dart:convert';

import 'addresses.dart' show levenshtein;
import 'csv.dart';
import 'models.dart';
import 'text_codec.dart';
import 'xlsx.dart';

enum RegistryFormat { csv1c, xlsx }

class RegistryFile {
  const RegistryFile({required this.name, required this.bytes, required this.mime, required this.encoding, this.warning = ''});
  final String name, mime, encoding, warning;
  final List<int> bytes;
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _money(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

String channelLabel(Channel c) => switch (c) {
      Channel.elpay => 'ЭлPay',
      Channel.cashier => 'Касса службы',
      Channel.bank => 'Банк',
    };

/// Колонки реестра в том порядке, в каком их ждёт типовая загрузка 1С.
const registryHeader = ['ЛицевойСчет', 'ДатаОплаты', 'Сумма', 'НомерКвитанции', 'Канал', 'Период'];

List<List<String>> registryRows(List<Payment> payments) => [
      registryHeader,
      for (final p in payments)
        [p.account, _date(p.at), _money(p.amount), p.receipt, '${channelLabel(p.channel)} · ${p.method}', p.period.key],
    ];

/// Собрать файл реестра. CSV — в Windows-1251, как его ждёт 1С; если в
/// реестре есть буквы, которых в 1251 нет (ң, ө, ү), — UTF-8 с меткой,
/// и об этом надо сказать бухгалтеру заранее.
RegistryFile buildRegistry(List<Payment> payments, {required RegistryFormat format, required DateTime at}) {
  final stamp = '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  final rows = registryRows(payments);
  if (format == RegistryFormat.xlsx) {
    return RegistryFile(
      name: 'reestr_$stamp.xlsx',
      bytes: writeXlsx(rows, sheetName: 'Реестр'),
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      encoding: 'Excel',
    );
  }
  final text = toCsv(rows);
  if (fitsCp1251(text)) {
    return RegistryFile(name: 'reestr_$stamp.csv', bytes: encodeCp1251(text), mime: 'text/csv', encoding: 'Windows-1251');
  }
  final odd = nonCp1251Chars(text).join(' ');
  return RegistryFile(
    name: 'reestr_$stamp.csv',
    bytes: [0xEF, 0xBB, 0xBF, ...utf8.encode(text)],
    mime: 'text/csv',
    encoding: 'UTF-8',
    warning: 'В реестре есть буквы $odd — в Windows-1251 их нет, поэтому файл в UTF-8. '
        'В 1С при загрузке выберите кодировку UTF-8.',
  );
}

/// Подсказка, к какому лицевому отнести платёж, и почему.
class MatchHint {
  const MatchHint({required this.account, required this.why, required this.checks});
  final String account;

  /// «Не хватает нуля: 31-0562 → 31-00562»
  final String why;

  /// Проверки: текст и сошлось ли.
  final List<(String, bool)> checks;
}

/// Найти, куда скорее всего хотели заплатить.
///
/// Типовые ошибки ввода: потерян ведущий ноль, переставлены две соседние
/// цифры, одна цифра набрана неверно. Подсказку подтверждают сумма
/// начисления и телефон плательщика.
MatchHint? suggestAccount({
  required String entered,
  required double amount,
  required String payerPhone,
  required Map<String, Subscriber> subscribers,
  required double Function(String account) chargeOf,
  required bool Function(String account) paidOpenPeriod,
}) {
  final e = entered.trim();
  // Все правдоподобные лицевые: потерянный ноль, перестановка соседних
  // цифр, одна неверная цифра. Кандидатов бывает несколько — «31-01854»
  // перестановкой даёт и 31-01584, и 31-01845, — поэтому выбираем по уликам.
  final candidates = <String, String>{};

  final pad = RegExp(r'^(\d{2})-(\d{1,4})$').firstMatch(e);
  if (pad != null) {
    final acc = '${pad.group(1)}-${pad.group(2)!.padLeft(5, '0')}';
    if (subscribers.containsKey(acc)) candidates[acc] = 'Не хватает нуля: $e → $acc';
  }
  final digits = e.split('');
  for (var i = 0; i + 1 < digits.length; i++) {
    if (!RegExp(r'\d').hasMatch(digits[i]) || !RegExp(r'\d').hasMatch(digits[i + 1]) || digits[i] == digits[i + 1]) continue;
    final sw = [...digits];
    final t = sw[i];
    sw[i] = sw[i + 1];
    sw[i + 1] = t;
    final acc = sw.join();
    if (subscribers.containsKey(acc)) candidates.putIfAbsent(acc, () => 'Переставлены две цифры: $e → $acc');
  }
  if (RegExp(r'^\d{2}-\d{5}$').hasMatch(e)) {
    for (final acc in subscribers.keys) {
      if (acc.length == e.length && levenshtein(acc, e) == 1) {
        candidates.putIfAbsent(acc, () => 'Одна цифра набрана неверно: $e → $acc');
      }
    }
  }
  if (candidates.isEmpty) return null;

  final phoneDigits = payerPhone.replaceAll(RegExp(r'\D'), '');
  bool phoneMatches(String acc) {
    final d = subscribers[acc]!.phone.replaceAll(RegExp(r'\D'), '');
    return d.length >= 9 && phoneDigits.length >= 9 && phoneDigits.endsWith(d.substring(d.length - 9));
  }

  int score(String acc) => (phoneMatches(acc) ? 2 : 0) + (chargeOf(acc) == amount ? 1 : 0);

  final ranked = candidates.keys.toList()..sort((a, b) => score(b) - score(a));
  final best = ranked.first;
  // Несколько кандидатов и улики их не различают — это лотерея, а не подсказка.
  if (ranked.length > 1 && score(ranked[1]) == score(best)) return null;

  final charge = chargeOf(best);
  final checks = <(String, bool)>[
    if (charge > 0)
      (
        amount == charge
            ? 'Сумма совпадает с начислением — ${charge.toStringAsFixed(0)} сом'
            : 'Сумма не совпадает: начислено ${charge.toStringAsFixed(0)}, заплачено ${amount.toStringAsFixed(0)}',
        amount == charge,
      ),
    if (phoneDigits.isNotEmpty && subscribers[best]!.phone.isNotEmpty)
      (phoneMatches(best) ? 'Телефон плательщика совпадает с карточкой абонента' : 'Телефон плательщика другой', phoneMatches(best)),
    if (paidOpenPeriod(best))
      ('Период у абонента уже оплачен — платёж станет авансом', false)
    else
      ('Период у абонента ещё не оплачен', true),
    if (ranked.length > 1) ('Ещё ${ranked.length - 1} похожих лицевых отброшены по телефону и сумме', true),
  ];
  return MatchHint(account: best, why: candidates[best]!, checks: checks);
}
