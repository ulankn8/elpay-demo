/// Демо-данные кабинета: реестр Ошводоканала на 14 октября 2026.
///
/// Генератор детерминированный (своё ГСЧ, одинаковое в браузере и в
/// тестах), а главные итоги сходятся с концептом ТОЧНО, до сома:
/// 12 480 абонентов, начислено 2 368 940, оплачено 1 487 310,
/// 7 806 / 642 / 4 032, ЭлPay 912 450 · касса 341 280 · банки 233 580,
/// 3 914 подключили счёт в приложении, долг прошлых периодов 418 270
/// у 1 905 абонентов. Первые десять абонентов — те же, что в концепте
/// и в мобильном приложении.
library;

import 'addresses.dart';
import 'models.dart';

/// «Сейчас» демо-реестра. Дальше время в кабинете идёт от этой точки.
final seedNow = DateTime(2026, 10, 14, 12, 0);
const openPeriod = Period(2026, 9);
const ovkId = 'ovk';
const tariff = 41.0;

/// Итоги, которые генератор обязан выдержать.
abstract final class SeedTotals {
  static const subscribers = 12480;
  static const charged = 2368940.0;
  static const paid = 1487310.0;
  static const paidFull = 7806;
  static const partial = 642;
  static const unpaid = 4032;
  static const inApp = 3914;
  static const viaElpay = 912450.0;
  static const viaCashier = 341280.0;
  static const viaBank = 233580.0;
  static const debtors = 1905;
  static const debt = 418270.0;
}

/// ГСЧ Парка — Миллера: произведение < 2^53, поэтому в JavaScript
/// (числа с плавающей точкой) даёт ту же последовательность, что в Dart VM.
class Rng {
  Rng(int seed) : _s = (seed % 2147483646) + 1;
  int _s;
  int next() => _s = (_s * 48271) % 2147483647;
  int nextInt(int n) => next() % n;
  double nextDouble() => next() / 2147483647;
  T pick<T>(List<T> l) => l[nextInt(l.length)];
  int weighted(List<int> w) {
    final total = w.fold<int>(0, (a, b) => a + b);
    var r = nextInt(total);
    for (var i = 0; i < w.length; i++) {
      if ((r -= w[i]) < 0) return i;
    }
    return w.length - 1;
  }
}

/// Хеш строки, одинаковый в браузере и в Dart VM. У String.hashCode это
/// не так: на вебе он другой, и демо-данные разошлись бы с тестами.
///
/// Произведение остаётся меньше 2^53, поэтому в JavaScript точность не теряется.
int stableHash(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 131 + c) % 2147483647;
  }
  return h;
}

/// Неоплаченные прошлые периоды абонента.
class PriorDebt {
  const PriorDebt(this.periods, this.paidOnOldest);

  /// Неоплаченные месяцы, от старого к новому (август, июль…).
  final List<Period> periods;

  /// Сколько уже внесено в счёт самого старого из них.
  final double paidOnOldest;
}

class SeedData {
  SeedData({
    required this.subscribers,
    required this.septCharges,
    required this.priorCharge,
    required this.payments,
    required this.debts,
  });

  final List<Subscriber> subscribers;

  /// Начисления за сентябрь — открытый период.
  final Map<String, double> septCharges;

  /// Начисление за прошлый месяц (апрель–август) — по норме или счётчику.
  final double Function(String account, Period p) priorCharge;

  /// Платежи за сентябрь, пришедшие 1–14 октября.
  final List<Payment> payments;

  final Map<String, PriorDebt> debts;
}

const _surnames = [
  'Абдыкадыров', 'Асанов', 'Токтогулов', 'Мамытов', 'Сыдыков', 'Эргешов', 'Юсупов', 'Кадыров',
  'Осмонов', 'Ташиев', 'Жээнбеков', 'Абдулаев', 'Ниязов', 'Сапаров', 'Бекматов', 'Турсунов',
  'Абдыраимов', 'Маматов', 'Жумабаев', 'Иманов', 'Каримов', 'Алиев', 'Рахимов', 'Султанов',
  'Темиров', 'Усенов', 'Шаршенов', 'Эшматов', 'Арзыматов', 'Бакиров', 'Мырзаев', 'Нурматов',
  'Орозбаев', 'Калыков', 'Зулпуев', 'Таджибаев', 'Хамидов', 'Юлдашев', 'Рахманов', 'Мирзаев',
  'Дүйшөнов', 'Өмүрбеков', 'Түлөбердиев', 'Касымов', 'Анарбаев', 'Байматов', 'Жолдошев', 'Исаков',
];
const _female = [
  'Айгерим', 'Гулзат', 'Жамиля', 'Айнура', 'Динара', 'Чолпон', 'Нуриза', 'Асель', 'Бермет',
  'Жылдыз', 'Нургуль', 'Айпери', 'Мээрим', 'Сайкал', 'Гульнара', 'Зарина', 'Камила', 'Малика',
  'Наргиза', 'Дилноза', 'Гулмира', 'Назгуль',
];
const _male = [
  'Нурлан', 'Бакыт', 'Рустам', 'Талант', 'Мирлан', 'Улукбек', 'Эркин', 'Эрмек', 'Бекжан',
  'Азамат', 'Адилет', 'Нурбек', 'Тимур', 'Данияр', 'Кубаныч', 'Жыргал', 'Алмаз', 'Фарход',
  'Шерзод', 'Бахтияр', 'Медер', 'Улан',
];

/// Десять абонентов концепта — их видно на всех экранах.
final _named = <Subscriber>[
  Subscriber(account: '31-00562', name: 'Токтогулова Айгерим', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      residents: 5, phone: '+996 555 31 82 47', inAppSince: DateTime(2026, 9, 3, 19, 12), createdAt: DateTime(2019, 4, 2)),
  Subscriber(account: '31-01187', name: 'Токтогулов Бакыт', street: 'ул. Масалиева', house: '44', flat: '3',
      residents: 3, phone: '+996 770 18 22 05', inAppSince: DateTime(2026, 9, 3, 19, 20), createdAt: DateTime(2016, 1, 11)),
  Subscriber(account: '31-00218', name: 'Абдыкадыров Нурлан', street: 'ул. Ленина', house: '301', flat: '56',
      residents: 3, phone: '+996 700 41 10 92', inAppSince: DateTime(2026, 6, 14), createdAt: DateTime(2014, 3, 5)),
  Subscriber(account: '31-00944', name: 'Маматова Гулзат', street: 'ул. Навои', house: '18',
      residents: 4, phone: '+996 555 70 33 18', inAppSince: DateTime(2026, 7, 2), createdAt: DateTime(2017, 8, 22)),
  Subscriber(account: '31-01502', name: 'Юсупов Рустам', street: 'ул. Курманжан Датка', house: '230',
      residents: 2, createdAt: DateTime(2018, 5, 30)),
  Subscriber(account: '31-02071', name: 'Сыдыкова Жамиля', street: 'ул. Масалиева', house: '52', flat: '7',
      residents: 6, phone: '+996 700 12 64 09', createdAt: DateTime(2021, 2, 9)),
  Subscriber(account: '31-00731', name: 'Эргешов Талант', street: 'ул. Ленина', house: '285',
      residents: 1, createdAt: DateTime(2015, 10, 1)),
  Subscriber(account: '31-01845', name: 'Ташиева Айнура', street: 'ул. Навои', house: '24', flat: '11',
      residents: 4, phone: '+996 505 88 14 37', inAppSince: DateTime(2026, 5, 19), createdAt: DateTime(2019, 12, 3)),
  Subscriber(account: '31-00390', name: 'Кадыров Мирлан', street: 'ул. Г. Айтиева', house: '7',
      residents: 5, createdAt: DateTime(2013, 6, 17)),
  Subscriber(account: '31-02260', name: 'Осмонова Динара', street: 'ул. Курманжан Датка', house: '205', flat: '2',
      residents: 3, createdAt: DateTime(2026, 10, 1, 9, 42)),
];

/// Платежи именованных абонентов — как на экранах концепта.
final _namedPayments = <String, ({double amount, DateTime at, Channel ch, String method})>{
  '31-00218': (amount: 123, at: DateTime(2026, 10, 12, 20, 41), ch: Channel.elpay, method: 'Элкарт'),
  '31-00944': (amount: 100, at: DateTime(2026, 10, 14, 11, 54), ch: Channel.elpay, method: 'Элкарт'),
  '31-01502': (amount: 82, at: DateTime(2026, 10, 9, 10, 15), ch: Channel.cashier, method: 'Касса службы'),
  '31-00731': (amount: 41, at: DateTime(2026, 10, 3, 14, 2), ch: Channel.bank, method: 'MBANK'),
  '31-01845': (amount: 164, at: DateTime(2026, 10, 11, 9, 27), ch: Channel.elpay, method: 'кошелёк ЭлPay'),
};
const _namedUnpaid = {'31-00562', '31-01187', '31-02071', '31-00390', '31-02260'};

/// Вес дней октября — та же форма, что у графика концепта: пик перед сроком.
const _dayWeights = [382, 619, 845, 723, 411, 964, 1188, 1319, 1093, 881, 797, 1428, 2055, 2168];

const _districts = {'31': 2260, '32': 2610, '33': 2540, '34': 2590, '35': 2504};

SeedData generateSeed() {
  final rng = Rng(20261014);
  final streets = StreetBook().all;
  final streetWeights = [for (var i = 0; i < streets.length; i++) i < 4 ? 9 : (i < 10 ? 4 : 2)];

  // ── лицевые: пять участков, в 31-м — номера до 02260 с пропусками ──
  final namedAcc = {for (final s in _named) s.account};
  final accounts = <String>[];
  for (final e in _districts.entries) {
    final prefix = e.key;
    final want = prefix == '31' ? 2260 - 24 : e.value;
    final skip = <int>{};
    if (prefix == '31') {
      while (skip.length < 24) {
        final n = 1 + rng.nextInt(2259);
        if (!namedAcc.contains('31-${n.toString().padLeft(5, '0')}')) skip.add(n);
      }
    }
    var n = 0, made = 0;
    while (made < want) {
      n++;
      if (skip.contains(n)) continue;
      accounts.add('$prefix-${n.toString().padLeft(5, '0')}');
      made++;
    }
  }
  // Ровно 12 480: подрезаем последний участок.
  while (accounts.length > SeedTotals.subscribers) {
    accounts.removeLast();
  }
  assert(accounts.length == SeedTotals.subscribers);

  // Новые 1 октября: 37 последних номеров 31-го участка (среди них Осмонова).
  final d31 = [for (final a in accounts) if (a.startsWith('31-')) a];
  final newOct = d31.sublist(d31.length - 37).toSet();

  // ── абоненты ──
  final namedBy = {for (final s in _named) s.account: s};
  final subs = <Subscriber>[];
  final meters = <String>{};
  for (final a in accounts) {
    final named = namedBy[a];
    if (named != null) {
      subs.add(named);
      continue;
    }
    final female = rng.nextInt(2) == 0;
    final sur = rng.pick(_surnames);
    final name = '${female ? '$surа' : sur} ${rng.pick(female ? _female : _male)}';
    final st = streets[rng.weighted(streetWeights)];
    final house = '${1 + rng.nextInt(rng.nextInt(3) == 0 ? 320 : 90)}';
    final flat = rng.nextInt(100) < 55 ? '${1 + rng.nextInt(72)}' : '';
    final residents = 1 + rng.weighted(const [3, 8, 15, 22, 22, 14, 9, 5, 2]);
    final meter = rng.nextInt(100) < 6;
    if (meter) meters.add(a);
    final hasPhone = rng.nextInt(100) < 62;
    final phone = hasPhone
        ? '+996 ${rng.pick(const ['555', '700', '770', '505', '550', '222', '777', '999'])} '
            '${10 + rng.nextInt(90)} ${10 + rng.nextInt(90)} ${10 + rng.nextInt(90)}'
        : '';
    final created = newOct.contains(a)
        ? DateTime(2026, 10, 1, 9, 42)
        : DateTime(2008 + rng.nextInt(18), 1 + rng.nextInt(12), 1 + rng.nextInt(28));
    subs.add(Subscriber(
      account: a,
      name: name,
      street: st.full,
      house: house,
      flat: flat,
      residents: residents,
      phone: phone,
      meter: meter,
      createdAt: created,
    ));
  }

  // ── начисления за сентябрь: норма × жильцы, у счётчиков — подгоняем итог ──
  final sept = <String, double>{};
  var normSum = 0.0;
  for (final s in subs) {
    if (s.meter) continue;
    sept[s.account] = s.residents * tariff;
    normSum += s.residents * tariff;
  }
  final meterList = [for (final s in subs) if (s.meter) s.account];
  var need = SeedTotals.charged - normSum;
  // Средний счёт по счётчику держим в разумных 90–320 сом.
  var guard = 0;
  while ((need / meterList.length < 90 || need / meterList.length > 320) && guard++ < 100000) {
    final i = rng.nextInt(subs.length);
    final s = subs[i];
    if (s.meter || namedAcc.contains(s.account)) continue;
    final up = need / meterList.length > 320;
    if (!up && s.residents <= 1) continue;
    final r = s.residents + (up ? 1 : -1);
    subs[i] = Subscriber(
        account: s.account, name: s.name, street: s.street, house: s.house, flat: s.flat, residents: r,
        phone: s.phone, meter: false, createdAt: s.createdAt);
    sept[s.account] = r * tariff;
    normSum += (up ? 1 : -1) * tariff;
    need = SeedTotals.charged - normSum;
  }
  // Итог делим пропорционально случайным весам: каждая сумма положительна,
  // а их сумма — ровно сколько нужно (остаток от округления — по сому).
  final w = [for (var i = 0; i < meterList.length; i++) 0.55 + rng.nextDouble() * 0.9];
  final wSum = w.fold<double>(0, (a, b) => a + b);
  var given = 0.0;
  for (var i = 0; i < meterList.length; i++) {
    final v = (need * w[i] / wSum).floorToDouble();
    sept[meterList[i]] = v;
    given += v;
  }
  var rest = (need - given).round();
  for (var i = 0; rest > 0; i++, rest--) {
    sept[meterList[i % meterList.length]] = sept[meterList[i % meterList.length]]! + 1;
  }

  double priorCharge(String account, Period p) {
    if (account == '31-00562') return 164; // до импорта 1 октября жильцов было 4
    final base = sept[account] ?? 0;
    if (!meters.contains(account)) return base;
    final h = stableHash('$account/${p.key}') % 31; // счётчик гуляет ±15%
    return (base * (0.85 + h / 100)).roundToDouble();
  }

  // ── кто подключил счёт в приложении: 3 914 ──
  final inApp = <String>{for (final s in _named) if (s.inAppSince != null) s.account};
  while (inApp.length < SeedTotals.inApp) {
    final s = subs[rng.nextInt(subs.length)];
    if (namedAcc.contains(s.account) || newOct.contains(s.account)) continue;
    inApp.add(s.account);
  }
  for (var i = 0; i < subs.length; i++) {
    final s = subs[i];
    if (!inApp.contains(s.account) || s.inAppSince != null) continue;
    final day = rng.nextInt(226); // с 1 марта по 13 октября
    subs[i] = Subscriber(
      account: s.account, name: s.name, street: s.street, house: s.house, flat: s.flat, residents: s.residents,
      phone: s.phone, meter: s.meter, createdAt: s.createdAt,
      inAppSince: DateTime(2026, 3, 1, 8 + rng.nextInt(14), rng.nextInt(60)).add(Duration(days: day)),
    );
  }

  // ── кто как оплатил сентябрь ──
  final pool = [
    for (final s in subs)
      if (!namedAcc.contains(s.account)) s.account,
  ];
  // Перемешиваем (Фишер — Йетс), чтобы разбивка не шла по участкам.
  for (var i = pool.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = pool[i];
    pool[i] = pool[j];
    pool[j] = t;
  }
  final namedFull = [for (final e in _namedPayments.entries) if (e.key != '31-00944') e.key];
  final partialSet = pool.sublist(0, SeedTotals.partial - 1);
  final fullSet = pool.sublist(SeedTotals.partial - 1, SeedTotals.partial - 1 + SeedTotals.paidFull - namedFull.length);
  final unpaidSet = pool.sublist(SeedTotals.partial - 1 + fullSet.length);
  assert(unpaidSet.length + _namedUnpaid.length == SeedTotals.unpaid);

  final namedPaid = _namedPayments.values.fold<double>(0, (s, p) => s + p.amount);
  final partialCharge = partialSet.fold<double>(0, (s, a) => s + sept[a]!);
  // Частичные платят в среднем чуть больше половины счёта.
  var targetPartial = (partialCharge * 0.56).roundToDouble();
  final targetFull = SeedTotals.paid - namedPaid - targetPartial;
  // Полностью платят чаще маленькие счета (одинокие пенсионеры, семьи из двоих):
  // меняем местами крупный оплаченный и мелкий неоплаченный, пока сумма не сойдётся.
  var fullSum = fullSet.fold<double>(0, (s, a) => s + sept[a]!);
  guard = 0;
  while ((fullSum - targetFull).abs() > 0 && guard++ < 400000) {
    final i = rng.nextInt(fullSet.length);
    final j = rng.nextInt(unpaidSet.length);
    final ci = sept[fullSet[i]]!, cj = sept[unpaidSet[j]]!;
    final diff = fullSum - targetFull;
    final delta = cj - ci; // насколько изменится сумма оплаченных
    // Берём обмен, только если он приближает к цели и не перескакивает её.
    if (diff > 0 && delta < 0 && -delta <= diff || diff < 0 && delta > 0 && delta <= -diff) {
      final t = fullSet[i];
      fullSet[i] = unpaidSet[j];
      unpaidSet[j] = t;
      fullSum += delta;
    }
  }
  // Что не добрали обменами — добирают частичные оплаты.
  targetPartial = SeedTotals.paid - namedPaid - fullSum;

  // Подключённые в приложении платят вовремя чаще: им приходит
  // напоминание о сроке и оплата — в два касания. Меняем местами
  // неоплатившего подключённого и оплатившего неподключённого с ОДИНАКОВЫМ
  // начислением — сумма оплаченного не меняется ни на сом.
  final fullByCharge = <double, List<int>>{};
  for (var i = 0; i < fullSet.length; i++) {
    if (!inApp.contains(fullSet[i])) (fullByCharge[sept[fullSet[i]]!] ??= []).add(i);
  }
  final appTotal = inApp.length;
  var appUnpaid = unpaidSet.where(inApp.contains).length + _namedUnpaid.where(inApp.contains).length;
  for (var j = 0; j < unpaidSet.length && appUnpaid > appTotal * 0.15; j++) {
    final u = unpaidSet[j];
    if (!inApp.contains(u)) continue;
    final slots = fullByCharge[sept[u]!];
    if (slots == null || slots.isEmpty) continue;
    final i = slots.removeLast();
    unpaidSet[j] = fullSet[i];
    fullSet[i] = u;
    appUnpaid--;
  }

  // ── каналы: подключённые в приложении платят в ЭлPay ──
  Channel channelFor(String a) {
    final r = rng.nextInt(100);
    if (inApp.contains(a)) return r < 88 ? Channel.elpay : (r < 95 ? Channel.cashier : Channel.bank);
    return r < 52 ? Channel.elpay : (r < 80 ? Channel.cashier : Channel.bank);
  }

  final chOf = <String, Channel>{for (final a in fullSet) a: channelFor(a), for (final a in partialSet) a: channelFor(a)};
  final targets = {Channel.elpay: SeedTotals.viaElpay, Channel.cashier: SeedTotals.viaCashier, Channel.bank: SeedTotals.viaBank};
  for (final p in _namedPayments.values) {
    targets[p.ch] = targets[p.ch]! - p.amount;
  }
  Map<Channel, double> fullBy() {
    final m = {for (final c in Channel.values) c: 0.0};
    for (final a in fullSet) {
      m[chOf[a]!] = m[chOf[a]!]! + sept[a]!;
    }
    return m;
  }

  Map<Channel, double> partialChargeBy() {
    final m = {for (final c in Channel.values) c: 0.0};
    for (final a in partialSet) {
      m[chOf[a]!] = m[chOf[a]!]! + sept[a]!;
    }
    return m;
  }

  // Двигаем оплаты между каналами, пока частичным в каждом канале не
  // останется посильная доля: 30–80% их начислений.
  guard = 0;
  while (guard++ < 200000) {
    final fb = fullBy(), pc = partialChargeBy();
    Channel? over, under;
    for (final c in Channel.values) {
      final share = (targets[c]! - fb[c]!) / (pc[c]! == 0 ? 1 : pc[c]!);
      if (share > 0.8) under = c; // полных мало — надо добавить в канал
      if (share < 0.3) over = c; // полных много — убрать из канала
    }
    if (over == null && under == null) break;
    final from = over ?? Channel.values.firstWhere((c) => c != under);
    final to = under ?? Channel.values.firstWhere((c) => c != over);
    final cand = fullSet.where((a) => chOf[a] == from).toList();
    if (cand.isEmpty) break;
    chOf[cand[rng.nextInt(cand.length)]] = to;
  }

  // Суммы частичных: доля от счёта по каналу, хвост округления — по сому.
  final partialAmt = <String, double>{};
  final fb = fullBy();
  for (final c in Channel.values) {
    final members = [for (final a in partialSet) if (chOf[a] == c) a];
    if (members.isEmpty) continue;
    final need = targets[c]! - fb[c]!;
    final charge = members.fold<double>(0, (s, a) => s + sept[a]!);
    final share = need / charge;
    var sum = 0.0;
    for (final a in members) {
      final v = (sept[a]! * share).floorToDouble().clamp(1.0, sept[a]! - 1);
      partialAmt[a] = v;
      sum += v;
    }
    var rest = (need - sum).round();
    var k = 0;
    while (rest != 0 && k < members.length * 4) {
      final a = members[k % members.length];
      final step = rest > 0 ? 1.0 : -1.0;
      final v = partialAmt[a]! + step;
      if (v >= 1 && v <= sept[a]! - 1) {
        partialAmt[a] = v;
        rest -= step.toInt();
      }
      k++;
    }
  }

  // ── даты и способы ──
  DateTime dateFor() {
    final day = 1 + rng.weighted(_dayWeights);
    final hour = day == 14 ? 8 + rng.nextInt(4) : 7 + rng.weighted(const [3, 6, 9, 10, 10, 9, 8, 8, 9, 10, 11, 12, 10, 7, 4, 2]);
    return DateTime(2026, 10, day, hour, rng.nextInt(60), rng.nextInt(60));
  }

  String methodFor(Channel c) => switch (c) {
        Channel.elpay => rng.pick(const ['Visa', 'Visa', 'Элкарт', 'Элкарт', 'кошелёк ЭлPay', 'MBANK', 'О!Деньги']),
        Channel.cashier => 'Касса службы',
        Channel.bank => rng.pick(const ['MBANK', 'MBANK', 'Элкарт · терминал', 'О!Деньги', 'Айыл Банк']),
      };

  final payments = <Payment>[];
  var seq = 0;
  String receipt(DateTime at) => 'EP-${at.year % 100}${at.month.toString().padLeft(2, '0')}'
      '${at.day.toString().padLeft(2, '0')}-${(++seq).toString().padLeft(5, '0')}';

  for (final e in _namedPayments.entries) {
    final p = e.value;
    payments.add(Payment(
      id: 'p-${e.key}', account: e.key, amount: p.amount, at: p.at, period: openPeriod,
      channel: p.ch, method: p.method, receipt: receipt(p.at),
    ));
  }
  for (final a in [...fullSet, ...partialSet]) {
    final at = dateFor();
    final c = chOf[a]!;
    payments.add(Payment(
      id: 'p-$a', account: a, amount: partialAmt[a] ?? sept[a]!, at: at, period: openPeriod,
      channel: c, method: methodFor(c), receipt: receipt(at),
    ));
  }
  payments.sort((x, y) => y.at.compareTo(x.at));

  // ── долг прошлых периодов: 1 905 абонентов, 418 270 сом ──
  final debts = <String, PriorDebt>{
    '31-02071': const PriorDebt([Period(2026, 8)], 0),
  };
  // Должниками за лето не бывают те, кого завели только 1 октября.
  final debtPool = [...unpaidSet, ...partialSet].where((a) => !newOct.contains(a)).toList();
  var debtSum = 246.0;
  final debtorAcc = <String>[];
  while (debtorAcc.length < SeedTotals.debtors - 1) {
    final a = debtPool[rng.nextInt(debtPool.length)];
    if (debts.containsKey(a) || debtorAcc.contains(a)) continue;
    debtorAcc.add(a);
  }
  for (final a in debtorAcc) {
    final k = 1 + rng.weighted(const [86, 12, 2]);
    final periods = [for (var i = 0; i < k; i++) Period(2026, 8 - i)];
    final full = periods.fold<double>(0, (s, p) => s + priorCharge(a, p));
    debts[a] = PriorDebt(periods, 0);
    debtSum += full;
  }
  // Подгоняем итог долга частичными взносами в счёт самого старого месяца.
  var over = debtSum - SeedTotals.debt;
  for (final a in debtorAcc) {
    if (over.abs() < 0.5) break;
    final d = debts[a]!;
    final oldest = d.periods.last;
    final c = priorCharge(a, oldest);
    if (over > 0) {
      final take = (over < c - 1 ? over : c - 1).floorToDouble();
      if (take <= 0) continue;
      debts[a] = PriorDebt(d.periods, take);
      over -= take;
    }
  }
  if (over < -0.5) {
    // Долга не хватило — добавляем месяц тем, у кого был один.
    for (final a in debtorAcc) {
      if (over > -0.5) break;
      final d = debts[a]!;
      if (d.periods.length != 1) continue;
      final extra = priorCharge(a, const Period(2026, 7));
      final paidOn = extra + over > 0 ? (extra + over).roundToDouble() : 0.0;
      debts[a] = PriorDebt([...d.periods, const Period(2026, 7)], paidOn);
      over += extra - paidOn;
    }
  }

  return SeedData(
    subscribers: subs,
    septCharges: sept,
    priorCharge: priorCharge,
    payments: payments,
    debts: debts,
  );
}
