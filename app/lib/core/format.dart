import 'package:intl/intl.dart';

/// Формат сумм как в прототипе: 4 449,44 · 3 500 · 180
String som(num v) {
  final f = NumberFormat.decimalPatternDigits(
    locale: 'ru',
    decimalDigits: v % 1 == 0 ? 0 : 2,
  );
  return f.format(v).replaceAll(' ', ' ');
}

/// Русская плюрализация: 1 счёт, 2 счёта, 5 счетов
String plural(int n, String one, String few, String many) {
  final d = n % 10, h = n % 100;
  if (d == 1 && h != 11) return one;
  if (d >= 2 && d <= 4 && (h < 10 || h >= 20)) return few;
  return many;
}

/// +996 555 12 34 56 из цифр
String phoneMask(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  final take = d.length > 9 ? d.substring(d.length - 9) : d;
  final parts = <String>[];
  if (take.isNotEmpty) parts.add(take.substring(0, take.length.clamp(0, 3)));
  if (take.length > 3) parts.add(take.substring(3, take.length.clamp(3, 5)));
  if (take.length > 5) parts.add(take.substring(5, take.length.clamp(5, 7)));
  if (take.length > 7) parts.add(take.substring(7, take.length.clamp(7, 9)));
  return parts.join(' ');
}

const monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
];
const monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сент', 'окт', 'ноя', 'дек'
];

const monthsNom = [
  'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
  'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'
];

/// «сентябрь» — для периода начисления
String monthName(int m) => monthsNom[m - 1];

/// «Сентябрь 2026» — заголовок месяца в истории и отчётах
String monthTitle(DateTime d) {
  final n = monthsNom[d.month - 1];
  return '${n[0].toUpperCase()}${n.substring(1)} ${d.year}';
}

/// «4 сент» — короткая дата строки истории
String dayMonth(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';

/// «10:15»
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// «20 сентября 2026»
String longDate(DateTime d) => '${d.day} ${monthsGen[d.month - 1]} ${d.year}';

/// «до 25 сент»
String shortDue(DateTime d) => 'до ${d.day} ${monthsShort[d.month - 1]}';

bool isValidEmail(String v) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
