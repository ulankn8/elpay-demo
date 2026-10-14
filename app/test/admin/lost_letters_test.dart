import 'dart:convert';

import 'package:elpay/admin/data/mapping.dart';
import 'package:elpay/admin/data/text_codec.dart';
import 'package:elpay/admin/platform/file_io.dart';
import 'package:elpay/admin/state/import_wizard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Кыргызские ң, ө, ү в Windows-1251 не помещаются: 1С пишет вместо них «?».
/// Мастер не может вернуть буквы, но обязан сказать об этом до загрузки.
void main() {
  ParsedTable table(List<List<String>> rows) => ParsedTable(headers: const ['Лиц', 'ФИО'], rows: rows, hasHeader: true);

  test('«?» внутри слова — предупреждение с примером и числом ячеек', () {
    final w = lostLettersWarning(
      table([
        ['31-00562', 'Т?л?бердиева Айгерим'],
        ['31-00563', 'Ж?н?шалиев Бакыт'],
        ['31-00564', 'Иванов Пётр'],
      ]),
    );
    expect(w, contains('В 2 ячейках'));
    expect(w, contains('«Т?л?бердиева Айгерим»'));
    expect(w, contains('UTF-8'));
  });

  test('Одна ячейка — «ячейке», а не «ячейках»', () {
    expect(
      lostLettersWarning(
        table([
          ['31-1', 'Ж?н?шалиев'],
        ]),
      ),
      contains('В 1 ячейке'),
    );
  });

  test('Обычный вопрос в примечании и чистые имена — без предупреждения', () {
    expect(
      lostLettersWarning(
        table([
          ['31-00562', 'Токтогулова Айгерим', 'Переехали?'],
          ['31-00563', 'Үмөтова Нургүл', '?'],
        ]),
      ),
      isEmpty,
    );
  });

  test('Файл из 1С в Windows-1251 с потерянными буквами — мастер предупреждает', () {
    // encodeCp1251 сам заменяет ү и ө на «?» — ровно как 1С.
    final bytes = encodeCp1251('Лиц_счет;Абонент\r\n31-00562;Түлөбердиева Айгерим\r\n');
    final loaded = readImportFile(PickedFile('abon.csv', bytes));
    expect(loaded.table.rows.single[1], 'Т?л?бердиева Айгерим');
    expect(loaded.warning, contains('ячейке'));
  });

  test('Тот же файл в UTF-8 — буквы на месте, предупреждения нет', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Лиц_счет;Абонент\r\n31-00562;Түлөбердиева Айгерим\r\n')];
    final loaded = readImportFile(PickedFile('abon.csv', bytes));
    expect(loaded.table.rows.single[1], 'Түлөбердиева Айгерим');
    expect(loaded.warning, isEmpty);
  });
}
