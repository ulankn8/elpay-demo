import 'dart:convert';
import 'dart:typed_data';

/// Кодировки, в которых 1С и Excel отдают выгрузки.
enum TextEncoding { utf8, utf8Bom, cp1251, utf16le }

extension TextEncodingLabel on TextEncoding {
  String get label => switch (this) {
        TextEncoding.utf8 => 'UTF-8',
        TextEncoding.utf8Bom => 'UTF-8',
        TextEncoding.cp1251 => 'Windows-1251',
        TextEncoding.utf16le => 'UTF-16',
      };
}

/// Windows-1251, байты 0x80–0xBF. С 0xC0 по 0xFF — подряд «А»…«я».
/// 0x98 в кодировке не определён.
const _cp1251High = <int>[
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
];

final Map<int, int> _cp1251Back = {
  for (var i = 0; i < _cp1251High.length; i++)
    if (_cp1251High[i] != 0xFFFD) _cp1251High[i]: 0x80 + i,
};

String decodeCp1251(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      out.writeCharCode(b);
    } else if (b >= 0xC0) {
      out.writeCharCode(0x0410 + (b - 0xC0));
    } else {
      out.writeCharCode(_cp1251High[b - 0x80]);
    }
  }
  return out.toString();
}

/// Можно ли записать строку в Windows-1251 без потерь.
///
/// Кыргызских «ң», «ө», «ү» в этой кодировке НЕТ — реестр с такими именами
/// надо выгружать в UTF-8, иначе 1С получит знаки вопроса.
bool fitsCp1251(String s) {
  for (final r in s.runes) {
    if (r < 0x80) continue;
    if (r >= 0x0410 && r <= 0x044F) continue;
    if (_cp1251Back.containsKey(r)) continue;
    return false;
  }
  return true;
}

/// Символы, которые в Windows-1251 не помещаются (для предупреждения).
Set<String> nonCp1251Chars(String s) => {
      for (final r in s.runes)
        if (!(r < 0x80 || (r >= 0x0410 && r <= 0x044F) || _cp1251Back.containsKey(r)))
          String.fromCharCode(r),
    };

Uint8List encodeCp1251(String s) {
  final out = BytesBuilder(copy: false);
  for (final r in s.runes) {
    if (r < 0x80) {
      out.addByte(r);
    } else if (r >= 0x0410 && r <= 0x044F) {
      out.addByte(0xC0 + (r - 0x0410));
    } else {
      out.addByte(_cp1251Back[r] ?? 0x3F); // «?» вместо того, чего нет
    }
  }
  return out.toBytes();
}

/// Текст файла и кодировка, в которой он оказался.
class DecodedText {
  const DecodedText(this.text, this.encoding);
  final String text;
  final TextEncoding encoding;
}

/// Угадать кодировку и раскодировать.
///
/// Порядок: метка BOM (UTF-8, UTF-16 — так сохраняет Excel «Юникод-текст»),
/// затем строгий UTF-8, и только если он не сошёлся — Windows-1251.
/// Строгий UTF-8 на русском тексте в 1251 почти никогда не сходится:
/// байты 0xC0–0xFF подряд не образуют правильных последовательностей.
DecodedText decodeText(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return DecodedText(utf8.decode(bytes.sublist(3), allowMalformed: true), TextEncoding.utf8Bom);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    final units = <int>[];
    for (var i = 2; i + 1 < bytes.length; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return DecodedText(String.fromCharCodes(units), TextEncoding.utf16le);
  }
  try {
    return DecodedText(utf8.decode(bytes), TextEncoding.utf8);
  } on FormatException {
    return DecodedText(decodeCp1251(bytes), TextEncoding.cp1251);
  }
}
