/// Разбор CSV из 1С и Excel: разделитель угадываем, кавычки по RFC 4180.
library;

/// Разделители, которые встречаются в выгрузках: русский Excel и 1С
/// ставят «;», английский — «,», «Текст с разделителями табуляции» — таб.
const csvDelimiters = [';', ',', '\t', '|'];

String delimiterLabel(String d) => switch (d) {
      ';' => '«;»',
      ',' => '«,»',
      '\t' => 'табуляция',
      '|' => '«|»',
      _ => '«$d»',
    };

/// Угадать разделитель по первым строкам: выигрывает тот, что даёт
/// одинаковое (и больше одного) число колонок в большинстве строк.
String detectDelimiter(String text) {
  final sample = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(20).toList();
  if (sample.isEmpty) return ';';
  var best = ';';
  var bestScore = -1.0;
  for (final d in csvDelimiters) {
    final counts = [for (final l in sample) _countOutsideQuotes(l, d)];
    if (counts.every((c) => c == 0)) continue;
    final freq = <int, int>{};
    for (final c in counts) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    final common = freq.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (common.key == 0) continue;
    // Согласованность важнее количества: «;» в каждой строке по 7 раз
    // лучше «,», которая встречается то 2, то 9 раз (запятые в адресах).
    final score = common.value / sample.length * 1000 + common.key;
    if (score > bestScore) {
      bestScore = score;
      best = d;
    }
  }
  return best;
}

int _countOutsideQuotes(String line, String d) {
  var n = 0;
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      q = !q;
    } else if (!q && ch == d) {
      n++;
    }
  }
  return n;
}

/// Разобрать CSV в строки ячеек. Кавычки, «""» внутри кавычек, переводы
/// строк внутри кавычек, CRLF и LF. Полностью пустые строки пропускаются.
List<List<String>> parseCsv(String text, {String? delimiter}) {
  final d = delimiter ?? detectDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        cell.write(ch);
      }
      i++;
      continue;
    }
    if (ch == '"' && cell.isEmpty) {
      inQuotes = true;
    } else if (ch == d) {
      endCell();
    } else if (ch == '\r') {
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else if (ch == '\n') {
      endRow();
    } else {
      cell.write(ch);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Записать CSV: ячейку с разделителем, кавычкой или переводом строки
/// берём в кавычки, кавычку удваиваем.
String toCsv(List<List<String>> rows, {String delimiter = ';', String newline = '\r\n'}) {
  String esc(String v) {
    if (v.contains(delimiter) || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  return rows.map((r) => r.map(esc).join(delimiter)).join(newline) + newline;
}
