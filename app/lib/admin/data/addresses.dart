/// Справочник улиц Оша и нечёткий поиск по нему.
///
/// В выгрузках 1С улицы пишут как попало: «Курманжандатка», «К.Датка»,
/// «пр. Масалиева», «ул.Ленина». Справочник нужен, чтобы адрес абонента
/// совпал с тем, что житель увидит в приложении, а нечёткий поиск — чтобы
/// предложить «похоже на ул. Курманжан Датка», а не просто отказать.
library;

class Street {
  const Street(this.name, {this.kind = 'ул.', this.aliases = const []});

  /// «Курманжан Датка»
  final String name;

  /// «ул.», «пр.», «пер.»
  final String kind;

  /// Как ещё пишут: «К. Датка», «Курманжан-Датка».
  final List<String> aliases;

  /// «ул. Курманжан Датка»
  String get full => '$kind $name';
}

/// Улицы пилотного района. Порядок — по числу абонентов Ошводоканала.
const oshStreets = <Street>[
  Street('Курманжан Датка', aliases: ['К. Датка', 'К.Датка', 'Курманжан-Датка', 'Курманджан Датка']),
  Street('Масалиева', aliases: ['Масалиев']),
  Street('Ленина'),
  Street('Навои'),
  Street('Г. Айтиева', aliases: ['Айтиева', 'Гапара Айтиева']),
  Street('Алымбека Датки', aliases: ['Алымбек Датка']),
  Street('Абдыкадырова'),
  Street('Аматова'),
  Street('Зайнабетдинова'),
  Street('Исанова'),
  Street('Кыргызстан'),
  Street('Моминова'),
  Street('Монуева'),
  Street('Ноокатская'),
  Street('Раззакова'),
  Street('Токтогула'),
  Street('Тайгараева'),
  Street('Шакирова'),
  Street('Хамзы'),
  Street('Ю. Абдрахманова', aliases: ['Абдрахманова', 'Юсупа Абдрахманова']),
  Street('Байтик Баатыра'),
  Street('Нариманская'),
  Street('Карасуйская'),
  Street('Жапарова'),
  Street('Осмонова'),
  Street('Мырзакматова', kind: 'пер.'),
  Street('Ахунбаева'),
  Street('Борбугулова'),
  Street('Достук', kind: 'пр.'),
  Street('Анаркулова'),
];

/// Без регистра, точек, дефисов и пробелов; «ё» → «е».
String foldName(String s) =>
    s.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'[\s.\-–—_,"«»]'), '');

final _kindPrefix = RegExp(
  r'^\s*(ул(ица)?|пр(осп(ект)?)?|пер(еулок)?|мкр|м-н|б-р|бульвар|ж/м)\.?\s*',
  caseSensitive: false,
);

/// «ул.Курманжан Датка» → «Курманжан Датка»; «пр. Масалиева» → «Масалиева».
String stripKind(String raw) => raw.replaceFirst(_kindPrefix, '').trim();

/// Расстояние Левенштейна — сколько правок от одного слова до другого.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1, ins = cur[j - 1] + 1, sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}

/// Как нашлась улица.
enum StreetMatch {
  /// Совпала точно (с точностью до регистра, точек и типа улицы).
  exact,

  /// Найдена по известному написанию или с опечаткой — нужно согласие.
  suggested,

  /// Не нашлась.
  none,
}

class StreetLookup {
  const StreetLookup(this.match, [this.street, this.why = '']);
  final StreetMatch match;
  final Street? street;

  /// Почему предлагаем: «так же написано ещё в 4 строках», «пробел пропущен».
  final String why;
}

class StreetBook {
  StreetBook([List<Street> streets = oshStreets])
      : _streets = streets,
        _exact = {
          for (final s in streets) foldName(s.name): s,
        },
        _alias = {
          for (final s in streets)
            for (final a in s.aliases) foldName(a): s,
        };

  final List<Street> _streets;
  final Map<String, Street> _exact, _alias;

  List<Street> get all => _streets;

  StreetLookup find(String raw) {
    final bare = stripKind(raw);
    if (bare.isEmpty) return const StreetLookup(StreetMatch.none);
    final key = foldName(bare);
    final exact = _exact[key];
    if (exact != null) {
      // «Курманжан Датка» и «Курманжандатка» дают один ключ — но второе
      // написание не совпадает с образцом, и его стоит поправить.
      final sameSpelling = bare.toLowerCase().replaceAll('ё', 'е') == exact.name.toLowerCase();
      return sameSpelling
          ? StreetLookup(StreetMatch.exact, exact)
          : StreetLookup(StreetMatch.suggested, exact, 'пробел или точка не на месте');
    }
    final alias = _alias[key];
    if (alias != null) return StreetLookup(StreetMatch.suggested, alias, 'другое написание той же улицы');

    Street? best;
    var bestD = 1 << 30;
    for (final s in _streets) {
      final d = levenshtein(key, foldName(s.name));
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    // Допускаем одну опечатку на каждые пять букв, но не больше двух.
    final limit = (key.length / 5).floor().clamp(1, 2);
    if (best != null && bestD <= limit) {
      return StreetLookup(StreetMatch.suggested, best, 'опечатка в названии');
    }
    return const StreetLookup(StreetMatch.none);
  }

  /// Подсказки для поля «Улица» в ручном вводе: по началу слова и по вхождению.
  List<Street> suggest(String typed, {int limit = 5}) {
    final q = foldName(stripKind(typed));
    if (q.isEmpty) return const [];
    final starts = [for (final s in _streets) if (foldName(s.name).startsWith(q)) s];
    final contains = [
      for (final s in _streets)
        if (!starts.contains(s) && (foldName(s.name).contains(q) || s.aliases.any((a) => foldName(a).startsWith(q)))) s,
    ];
    return [...starts, ...contains].take(limit).toList();
  }
}

/// Разобрать адрес одной строкой, как его часто отдаёт 1С:
/// «ул. Ленина, 301, кв. 56», «Навои 18», «Масалиева д.52 кв.7».
({String street, String house, String flat}) splitAddress(String raw) {
  var s = raw.trim();
  var flat = '';
  final flatM = RegExp(r'[,\s]*(?:кв\.?|квартира)\s*([0-9]+[а-яА-Яa-zA-Z]?)\s*$', caseSensitive: false).firstMatch(s);
  if (flatM != null) {
    flat = flatM.group(1)!;
    s = s.substring(0, flatM.start);
  }
  var house = '';
  final houseM = RegExp(r'[,\s]*(?:д\.?|дом)?\s*([0-9]+(?:[/\-][0-9]+)?[а-яА-Яa-zA-Z]?)\s*$', caseSensitive: false).firstMatch(s);
  if (houseM != null) {
    house = houseM.group(1)!;
    s = s.substring(0, houseM.start);
  }
  return (street: s.replaceAll(RegExp(r'[,\s]+$'), '').trim(), house: house, flat: flat);
}

/// Номер дома с буквой «О» вместо нуля: «3О1» → «301». Частая беда ручного
/// набора в 1С: кириллическая «О» и латинская «O» рядом с нулём.
String? fixHouseNumber(String raw) {
  if (!RegExp(r'[0-9]').hasMatch(raw)) return null;
  final fixed = raw.replaceAll(RegExp(r'[ОоOo]'), '0');
  if (fixed == raw || !RegExp(r'^[0-9]+(?:[/\-][0-9]+)?[а-яА-Яa-zA-Z]?$').hasMatch(fixed)) return null;
  return fixed;
}
