import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// Таблица из Excel не прочиталась — с понятной причиной для бухгалтера.
class SheetReadException implements Exception {
  const SheetReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Это .xlsx? ZIP начинается с «PK».
bool looksLikeXlsx(List<int> bytes) => bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

/// Старый .xls (формат Excel 97–2003)? У него подпись D0 CF 11 E0.
bool looksLikeOldXls(List<int> bytes) =>
    bytes.length > 8 && bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0;

/// Прочитать первый лист .xlsx в строки ячеек.
///
/// Без внешних библиотек Excel: .xlsx — это ZIP с XML внутри. Читаем
/// таблицу общих строк и первый лист потоком событий, а не деревом —
/// у выгрузки на 12 тысяч абонентов это сто тысяч ячеек.
List<List<String>> readXlsx(List<int> bytes) {
  if (looksLikeOldXls(bytes)) {
    throw const SheetReadException(
        'Это файл старого формата .xls. Откройте его в Excel и сохраните как .xlsx или CSV.');
  }
  if (!looksLikeXlsx(bytes)) {
    throw const SheetReadException('Файл не похож на таблицу Excel .xlsx.');
  }
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const SheetReadException('Файл .xlsx повреждён — не удалось его открыть.');
  }

  String? text(String name) {
    final f = zip.findFile(name);
    if (f == null) return null;
    return utf8.decode(f.content, allowMalformed: true);
  }

  final shared = _sharedStrings(text('xl/sharedStrings.xml'));
  final sheetPath = _firstSheetPath(text('xl/workbook.xml'), text('xl/_rels/workbook.xml.rels'));
  final sheet = text(sheetPath) ?? text('xl/worksheets/sheet1.xml');
  if (sheet == null) throw const SheetReadException('В файле нет ни одного листа.');
  return _readSheet(sheet, shared);
}

List<String> _sharedStrings(String? xml) {
  if (xml == null) return const [];
  final out = <String>[];
  StringBuffer? cur;
  var inT = false;
  for (final e in parseEvents(xml)) {
    if (e is XmlStartElementEvent) {
      if (e.localName == 'si') {
        cur = StringBuffer();
        if (e.isSelfClosing) {
          out.add('');
          cur = null;
        }
      } else if (e.localName == 't' && !e.isSelfClosing) {
        inT = true;
      } else if (e.localName == 'rPh') {
        // Фонетические подсказки (японские) в текст не входят.
        inT = false;
      }
    } else if (e is XmlEndElementEvent) {
      if (e.localName == 't') {
        inT = false;
      } else if (e.localName == 'si' && cur != null) {
        out.add(cur.toString());
        cur = null;
      }
    } else if (inT && cur != null) {
      if (e is XmlTextEvent) cur.write(e.value);
      if (e is XmlCDATAEvent) cur.write(e.value);
    }
  }
  return out;
}

String _firstSheetPath(String? workbook, String? rels) {
  if (workbook == null || rels == null) return 'xl/worksheets/sheet1.xml';
  try {
    final wb = XmlDocument.parse(workbook);
    final first = wb.findAllElements('sheet').firstOrNull;
    final rid = first?.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
    if (rid == null || rid.isEmpty) return 'xl/worksheets/sheet1.xml';
    final rs = XmlDocument.parse(rels);
    for (final r in rs.findAllElements('Relationship')) {
      if (r.getAttribute('Id') == rid) {
        var target = r.getAttribute('Target') ?? '';
        if (target.startsWith('/')) return target.substring(1);
        if (!target.startsWith('xl/')) target = 'xl/$target';
        return target;
      }
    }
  } catch (_) {
    // Нестандартная книга — пробуем путь по умолчанию.
  }
  return 'xl/worksheets/sheet1.xml';
}

/// «B12» → 1 (номер колонки с нуля).
int _colIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c >= 65 && c <= 90) {
      n = n * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      n = n * 26 + (c - 96);
    } else {
      break;
    }
  }
  return n - 1;
}

/// Число из Excel без хвоста «.0»: 205.0 → «205», 4.5E1 → «45».
String _number(String raw) {
  final v = double.tryParse(raw);
  if (v == null) return raw;
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  var s = v.toString();
  if (s.contains('e') || s.contains('E')) s = v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
  return s;
}

List<List<String>> _readSheet(String xml, List<String> shared) {
  final rows = <List<String>>[];
  List<String>? row;
  var col = -1;
  String? type;
  final value = StringBuffer();
  var inV = false, inIs = false, inT = false;

  for (final e in parseEvents(xml)) {
    if (e is XmlStartElementEvent) {
      switch (e.localName) {
        case 'row':
          row = <String>[];
          if (e.isSelfClosing) {
            rows.add(row);
            row = null;
          }
        case 'c':
          final r = e.attributes.where((a) => a.localName == 'r').firstOrNull?.value;
          col = r == null ? (row?.length ?? 0) : _colIndex(r);
          type = e.attributes.where((a) => a.localName == 't').firstOrNull?.value;
          value.clear();
          if (e.isSelfClosing) _put(row, col, '');
        case 'v':
          inV = !e.isSelfClosing;
        case 'is':
          inIs = true;
        case 't':
          inT = inIs && !e.isSelfClosing;
      }
    } else if (e is XmlEndElementEvent) {
      switch (e.localName) {
        case 'v':
          inV = false;
        case 't':
          inT = false;
        case 'is':
          inIs = false;
        case 'c':
          final raw = value.toString();
          final cell = switch (type) {
            's' => (int.tryParse(raw) ?? -1) >= 0 && int.parse(raw) < shared.length ? shared[int.parse(raw)] : '',
            'b' => raw == '1' ? 'ИСТИНА' : 'ЛОЖЬ',
            'str' || 'inlineStr' || 'e' => raw,
            _ => _number(raw),
          };
          _put(row, col, cell);
        case 'row':
          if (row != null && row.any((c) => c.trim().isNotEmpty)) rows.add(row);
          row = null;
      }
    } else if (e is XmlTextEvent && (inV || inT)) {
      value.write(e.value);
    } else if (e is XmlCDATAEvent && (inV || inT)) {
      value.write(e.value);
    }
  }
  // Выравниваем строки по ширине — пустые хвостовые ячейки Excel не пишет.
  final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
  return [for (final r in rows) [...r, for (var i = r.length; i < width; i++) '']];
}

void _put(List<String>? row, int col, String v) {
  if (row == null || col < 0) return;
  while (row.length < col) {
    row.add('');
  }
  if (row.length == col) {
    row.add(v);
  } else {
    row[col] = v;
  }
}

/// Собрать простой .xlsx из строк — для «Скачать ошибки в Excel» и тестов.
List<int> writeXlsx(List<List<String>> rows, {String sheetName = 'Лист1'}) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String ref(int c, int r) {
    var n = c + 1;
    var s = '';
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return '$s$r';
  }

  final sheet = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v.isEmpty) continue;
      sheet.write('<c r="${ref(c, r + 1)}" t="inlineStr"><is><t xml:space="preserve">${esc(v)}</t></is></c>');
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  final files = <String, String>{
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '</Relationships>',
    'xl/worksheets/sheet1.xml': sheet.toString(),
  };
  final archive = Archive();
  for (final e in files.entries) {
    final data = utf8.encode(e.value);
    archive.addFile(ArchiveFile(e.key, data.length, data));
  }
  return ZipEncoder().encode(archive);
}

/// Подменить файлы внутри ZIP — для тестов, которые собирают .xlsx
/// «как сохраняет Excel», с общими строками и числами без типа.
List<int> replaceInZip(List<int> zipBytes, Map<String, String> files) {
  final src = ZipDecoder().decodeBytes(zipBytes);
  final out = Archive();
  for (final f in src.files) {
    if (files.containsKey(f.name)) continue;
    out.addFile(ArchiveFile(f.name, f.content.length, f.content));
  }
  for (final e in files.entries) {
    final data = utf8.encode(e.value);
    out.addFile(ArchiveFile(e.key, data.length, data));
  }
  return ZipEncoder().encode(out);
}
