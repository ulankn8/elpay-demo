import 'dart:convert';

import 'package:elpay/admin/data/csv.dart';
import 'package:elpay/admin/data/text_codec.dart';
import 'package:elpay/admin/data/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

/// Файлы, которые реально приходят из 1С и Excel: Windows-1251 с «;»,
/// UTF-8 с меткой, «Юникод-текст» UTF-16 с табуляцией и .xlsx.
void main() {
  const header = 'Лиц_счет;Абонент;Улица;Дом;Кв;Кол_прож';
  const row = '31-00562;Токтогулова Айгерим;ул. Курманжан Датка;212;14;5';

  group('Кодировки', () {
    test('Windows-1251 узнаётся и раскодируется без потерь', () {
      final bytes = encodeCp1251('$header\r\n$row\r\n');
      final d = decodeText(bytes);
      expect(d.encoding, TextEncoding.cp1251);
      expect(d.text, contains('Токтогулова Айгерим'));
      expect(d.text, contains('Лиц_счет'));
    });

    test('UTF-8 без метки — UTF-8', () {
      final d = decodeText(utf8.encode('$header\n$row\n'));
      expect(d.encoding, TextEncoding.utf8);
      expect(d.text, contains('Курманжан'));
    });

    test('UTF-8 с меткой BOM — метка не попадает в первую колонку', () {
      final d = decodeText([0xEF, 0xBB, 0xBF, ...utf8.encode('$header\n')]);
      expect(d.encoding, TextEncoding.utf8Bom);
      expect(d.text.startsWith('Лиц_счет'), isTrue);
    });

    test('UTF-16 («Юникод-текст» из Excel) читается', () {
      final s = 'Лиц_счет\tАбонент\n31-00562\tТоктогулова\n';
      final bytes = <int>[0xFF, 0xFE];
      for (final u in s.codeUnits) {
        bytes..add(u & 0xFF)..add(u >> 8);
      }
      final d = decodeText(bytes);
      expect(d.encoding, TextEncoding.utf16le);
      expect(parseCsv(d.text).last, ['31-00562', 'Токтогулова']);
    });

    test('Ё, №, «кавычки» и тире проходят туда и обратно через 1251', () {
      const s = 'Ёлкин № 5 «Дом» — 2';
      expect(decodeCp1251(encodeCp1251(s)), s);
    });

    test('Кыргызские ң ө ү в 1251 не помещаются — это видно заранее', () {
      expect(fitsCp1251('Токтогулова Айгерим'), isTrue);
      expect(fitsCp1251('Өмүрбек Жээнбеков'), isFalse);
      expect(nonCp1251Chars('Өмүрбек Мөңкө'), containsAll(['Ө', 'ү', 'ө', 'ң']));
    });
  });

  group('CSV', () {
    test('разделитель угадывается: «;», «,», табуляция', () {
      expect(detectDelimiter('$header\n$row\n'), ';');
      expect(detectDelimiter('a,b,c\n1,2,3\n'), ',');
      expect(detectDelimiter('a\tb\tc\n1\t2\t3\n'), '\t');
    });

    test('«;» выигрывает у запятых внутри адресов', () {
      const text = 'Лиц;Адрес;Сумма\n'
          '31-1;"ул. Ленина, 301, кв. 56";123\n'
          '31-2;"ул. Навои, 18";164\n';
      expect(detectDelimiter(text), ';');
      expect(parseCsv(text)[1], ['31-1', 'ул. Ленина, 301, кв. 56', '123']);
    });

    test('кавычки внутри кавычек и перевод строки внутри ячейки', () {
      const text = 'a;b\n"ТСЖ ""Береке""";"строка 1\nстрока 2"\n';
      final rows = parseCsv(text);
      expect(rows[1][0], 'ТСЖ "Береке"');
      expect(rows[1][1], 'строка 1\nстрока 2');
    });

    test('CRLF и пустые строки в конце не дают лишних строк', () {
      final rows = parseCsv('$header\r\n$row\r\n\r\n;;;;;\r\n');
      expect(rows, hasLength(2));
    });

    test('запись и чтение обратно дают то же самое', () {
      final data = [
        ['Лицевой', 'Сумма', 'Назначение'],
        ['31-00562', '205,00', 'Вода; сентябрь "2026"'],
      ];
      expect(parseCsv(toCsv(data)), data);
    });
  });

  group('Excel .xlsx', () {
    test('записанный файл читается обратно с теми же ячейками', () {
      final data = [
        ['Лиц_счет', 'Абонент', 'Кол_прож'],
        ['31-00562', 'Токтогулова Айгерим', '5'],
        ['31-00218', 'Абдыкадыров Нурлан', '3'],
      ];
      expect(readXlsx(writeXlsx(data)), data);
    });

    test('пустые ячейки посередине не сдвигают колонки', () {
      final data = [
        ['a', '', 'c'],
        ['', 'b', ''],
      ];
      expect(readXlsx(writeXlsx(data)), [
        ['a', '', 'c'],
        ['', 'b', ''],
      ]);
    });

    test('общие строки и числа, как их пишет сам Excel', () {
      // Файл в том виде, в каком его сохраняет Excel: тексты в sharedStrings,
      // числа — в <v> без типа, «205» хранится как 205.0.
      const sheet = '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
          '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
          '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="C2"><v>205.0</v></c></row>'
          '</sheetData></worksheet>';
      const strings = '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<si><t>Лиц_счет</t></si><si><r><t>Сум</t></r><r><t>ма</t></r></si><si><t>31-00562</t></si></sst>';
      final bytes = _zip({'xl/worksheets/sheet1.xml': sheet, 'xl/sharedStrings.xml': strings});
      expect(readXlsx(bytes), [
        ['Лиц_счет', 'Сумма', ''],
        ['31-00562', '', '205'],
      ]);
    });

    test('старый .xls — понятная причина, а не падение', () {
      expect(
        () => readXlsx([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0, 0]),
        throwsA(isA<SheetReadException>().having((e) => e.message, 'message', contains('.xls'))),
      );
    });

    test('не таблица — понятная причина', () {
      expect(() => readXlsx(utf8.encode('просто текст')), throwsA(isA<SheetReadException>()));
    });
  });
}

/// Собрать ZIP с заданными XML — как это делает Excel, без нашего writeXlsx.
List<int> _zip(Map<String, String> files) {
  final rows = <List<String>>[];
  // writeXlsx даёт обвязку книги; подменяем в ней лист и общие строки.
  final base = writeXlsx(rows);
  return replaceInZip(base, files);
}
