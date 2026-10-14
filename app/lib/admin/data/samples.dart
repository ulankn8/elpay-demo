/// Файлы-примеры для мастера импорта: «как выгружает 1С», с типовыми
/// ошибками внутри — чтобы мастер можно было попробовать сразу, без
/// настоящей выгрузки.
library;

import 'csv.dart';
import 'models.dart';
import 'text_codec.dart';
import 'xlsx.dart';

/// Абоненты из 1С: Windows-1251, разделитель «;», колонки как в шаблоне
/// «1С: Абоненты ОВК». Внутри: без изменений, обновления, новые и восемь
/// строк с ошибками, которые мастер поймает и предложит исправить.
List<int> sampleSubscribersCsv(Map<String, Subscriber> existing) {
  final rows = <List<String>>[
    ['Лиц_счет', 'Абонент', 'Улица', 'Дом', 'Кв', 'Кол_прож', 'Телефон', 'Примечание'],
  ];
  String local(String phone) {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length < 9) return '';
    final n = d.substring(d.length - 9);
    return '0${n.substring(0, 3)} ${n.substring(3, 5)} ${n.substring(5, 7)} ${n.substring(7)}';
  }

  List<String> row(Subscriber s, {int? residents, String note = ''}) => [
        s.account, s.name, s.street, s.house, s.flat, '${residents ?? s.residents}', local(s.phone), note,
      ];

  // Без изменений и обновления — из настоящего реестра. Только те, чьи
  // имена помещаются в Windows-1251: в такой базе 1С кыргызских ң, ө, ү нет.
  final known = existing.values.where((s) => s.account.startsWith('31-0') && fitsCp1251(s.name)).take(24).toList();
  for (var i = 0; i < known.length; i++) {
    final s = known[i];
    rows.add(i % 6 == 2 ? row(s, residents: s.residents + 1, note: 'прописан ребёнок') : row(s));
  }
  // Новые абоненты нового дома.
  const fresh = [
    ['Жумабаева Асель', '218', '9', '3'],
    ['Мамытов Кубаныч', '218', '10', '4'],
    ['Исакова Бермет', '218', '11', '2'],
    ['Рахимов Фарход', '218', '12', '5'],
    ['Касымова Нургуль', '218', '13', '1'],
  ];
  var n = 9100;
  for (final f in fresh) {
    rows.add(['31-${(n++).toString().padLeft(5, '0')}', f[0], 'ул. Курманжан Датка', f[1], f[2], f[3], '', 'новый дом']);
  }
  // Ошибки — ровно те, что видны на экране проверки концепта.
  rows.addAll([
    ['31-09110', 'Жээнбекова Нуриза', 'ул. Курманжандатка', '212', '31', '2', '', ''],
    ['31-09111', 'Сапаров Эрмек', 'ул. Курманжандатка', '214', '', '4', '', ''],
    ['31-09112', 'Абдулаев Улукбек', 'ул. Ленина', '3О1', '12', '1', '', 'О вместо нуля'],
    ['31-0912', 'Иманова Чолпон', 'ул. Навои', '20', '', '2', '', 'потерян ноль'],
    [known.first.account, known.first.name, known.first.street, known.first.house, known.first.flat, '${known.first.residents}', '', 'дубль'],
    ['31-09113', '', 'ул. Навои', '31', '', '1', '', 'пустое ФИО'],
    ['31-09114', 'Ниязов Эркин', 'ж/м Ак-Тилек', '7', '', '3', '', 'новый жилмассив'],
    ['31-09115', 'Осмонов Бекжан', 'пр. Масалиева', '52', '18', 'двое', '', ''],
  ]);
  return encodeCp1251(toCsv(rows));
}

/// Начисления за [period] по всем активным абонентам, как их отдаёт 1С
/// в Excel. Две строки с ошибками: чужой лицевой и сумма словами.
List<int> sampleChargesXlsx(Map<String, Subscriber> subscribers, Period period, double Function(String) lastCharge) {
  const months = ['январь', 'февраль', 'март', 'апрель', 'май', 'июнь', 'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'];
  final label = '${months[period.month - 1]} ${period.year}';
  final rows = <List<String>>[
    ['ЛС', 'ФИО', 'Кол_прож', 'Сумма к оплате', 'Период'],
  ];
  for (final s in subscribers.values) {
    if (!s.active) continue;
    final amount = s.meter ? lastCharge(s.account) : s.residents * 41.0;
    if (amount <= 0) continue;
    // Одна сумма словами — так бывает, когда ведомость правили руками.
    final text = s.account == '31-00731' ? 'сорок один' : amount.toStringAsFixed(2).replaceAll('.', ',');
    rows.add([s.account, s.name, '${s.residents}', text, label]);
  }
  rows.add(['31-99999', 'Неизвестный Абонент', '2', '82,00', label]);
  return writeXlsx(rows, sheetName: 'Начисления');
}
