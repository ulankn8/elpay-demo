import 'models.dart';

/// Запись в реестре поставщика: лицевой счёт, его владелец, адрес и
/// последнее начисление. В бою это ответ бэкенда на поиск счёта;
/// здесь — демо-реестр пилота в Оше.
class RegistryAccount {
  const RegistryAccount({
    required this.id,
    required this.providerId,
    required this.accountNo,
    required this.holder,
    required this.city,
    required this.street,
    required this.house,
    this.flat = '',
    required this.amount,
    required this.period,
    required this.dueDay,
    this.calc = const [],
    this.confirmCode = '4815',
  });

  final String id, providerId, accountNo, holder, city, street, house, flat, period, confirmCode;
  final double amount;
  final int dueDay;
  final List<Field> calc;

  String get address =>
      [city, street, house.isEmpty ? '' : 'д. $house', flat.isEmpty ? '' : 'кв. $flat']
          .where((p) => p.isNotEmpty)
          .join(', ');

  /// Совпадение по адресу: сравниваем нормализованно, квартиру — если указана.
  bool matchesAddress(String c, String s, String h, String f) {
    bool eq(String a, String b) => _norm(a) == _norm(b);
    if (!eq(city, c) || !eq(street, s) || !eq(house, h)) return false;
    if (f.trim().isEmpty || flat.isEmpty) return true;
    return eq(flat, f);
  }

  bool matchesAccount(String no) => _norm(accountNo) == _norm(no);

  static String _norm(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[\s\-–—.,№"«»]'), '').replaceAll('ё', 'е');
}

/// Демо-реестр: по нему работают поиск счёта и подключение.
class Registry {
  const Registry._();

  static const _dom = ('Ош', 'ул. Курманжан Датка', '212', '14');
  static const _par = ('Ош', 'ул. Масалиева', '44', '12');

  static const accounts = <RegistryAccount>[
    // ── адрес семьи: ул. Курманжан Датка, 212, кв. 14 ──────────────
    RegistryAccount(
      id: 'reg-water-1', providerId: 'p-water', accountNo: '31-00562',
      holder: 'Токтогулова А.', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 205, period: 'сентябрь 2026', dueDay: 20,
      calc: [
        Field('Тариф', '41 сом с человека'),
        Field('Проживающих', '5 человек'),
        Field('Итого', '205 сом'),
      ],
    ),
    RegistryAccount(
      id: 'reg-power-1', providerId: 'p-power', accountNo: '7710-3348',
      holder: 'Токтогулова А.', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 564.44, period: 'сентябрь 2026', dueDay: 25,
      calc: [
        Field('Показания', '14 208 → 14 332'),
        Field('Расход', '124 кВт·ч'),
        Field('Тариф', '4,55 сом за кВт·ч'),
        Field('Итого', '564,44 сом'),
      ],
    ),
    RegistryAccount(
      id: 'reg-trash-1', providerId: 'p-trash', accountNo: '04-118725',
      holder: 'Токтогулова А.', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 180, period: 'сентябрь 2026', dueDay: 28,
      calc: [
        Field('Тариф', '45 сом с человека'),
        Field('Проживающих', '4 человека'),
        Field('Итого', '180 сом'),
      ],
    ),
    // не подключены — их пользователь находит при поиске по адресу
    RegistryAccount(
      id: 'reg-gas-1', providerId: 'p-gas', accountNo: '55-20841',
      holder: 'Токтогулова А.', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 420, period: 'сентябрь 2026', dueDay: 25,
      calc: [
        Field('Показания', '1 204 → 1 232'),
        Field('Расход', '28 м³'),
        Field('Тариф', '15 сом за м³'),
        Field('Итого', '420 сом'),
      ],
    ),
    RegistryAccount(
      id: 'reg-net-1', providerId: 'p-saima', accountNo: 'OSH-44120',
      holder: 'Токтогулов Б.', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 1000, period: 'октябрь 2026', dueDay: 5,
      calc: [
        Field('Тариф', 'Домашний 100 Мбит'),
        Field('Период', 'октябрь 2026'),
        Field('Итого', '1 000 сом'),
      ],
    ),
    // ── адрес родителей: ул. Масалиева, 44, кв. 12 ────────────────
    RegistryAccount(
      id: 'reg-power-2', providerId: 'p-power', accountNo: '7710-5521',
      holder: 'Токтогулова Н.', city: 'Ош', street: 'ул. Масалиева', house: '44', flat: '12',
      amount: 320, period: 'сентябрь 2026', dueDay: 25,
      calc: [
        Field('Показания', '9 870 → 9 940'),
        Field('Расход', '70 кВт·ч'),
        Field('Тариф', '4,55 сом за кВт·ч'),
        Field('Итого', '320 сом'),
      ],
    ),
    RegistryAccount(
      id: 'reg-water-2', providerId: 'p-water', accountNo: '31-01187',
      holder: 'Токтогулова Н.', city: 'Ош', street: 'ул. Масалиева', house: '44', flat: '12',
      amount: 150, period: 'сентябрь 2026', dueDay: 20,
      calc: [
        Field('Тариф', '41 сом с человека'),
        Field('Проживающих', '2 человека'),
        Field('Итого', '150 сом'),
      ],
    ),
    RegistryAccount(
      id: 'reg-trash-2', providerId: 'p-trash', accountNo: '04-990218',
      holder: 'Токтогулова Н.', city: 'Ош', street: 'ул. Масалиева', house: '44', flat: '12',
      amount: 90, period: 'сентябрь 2026', dueDay: 28,
      calc: [
        Field('Тариф', '45 сом с человека'),
        Field('Проживающих', '2 человека'),
        Field('Итого', '90 сом'),
      ],
    ),
    // ── садик: счёт по договору, адреса нет ───────────────────────
    RegistryAccount(
      id: 'reg-kid-1', providerId: 'p-kid', accountNo: 'Д-2291',
      holder: 'Токтогулов Амир', city: 'Ош', street: 'ул. Курманжан Датка', house: '212', flat: '14',
      amount: 3500, period: 'октябрь 2026', dueDay: 10,
      calc: [
        Field('Питание', '2 400 сом'),
        Field('Учебные материалы', '700 сом'),
        Field('Охрана', '400 сом'),
        Field('Итого', '3 500 сом'),
      ],
    ),
    // ── чужой адрес: чтобы поиск не выглядел «всегда находит» ─────
    RegistryAccount(
      id: 'reg-power-3', providerId: 'p-power', accountNo: '7710-7788',
      holder: 'Жээнбеков К.', city: 'Ош', street: 'ул. Навои', house: '18', flat: '3',
      amount: 410, period: 'сентябрь 2026', dueDay: 25,
      calc: [
        Field('Показания', '5 120 → 5 210'),
        Field('Расход', '90 кВт·ч'),
        Field('Тариф', '4,55 сом за кВт·ч'),
        Field('Итого', '410 сом'),
      ],
    ),
  ];

  /// Подсказки для формы адреса — то, что в бою придёт справочником улиц.
  static const cities = ['Ош', 'Бишкек', 'Джалал-Абад', 'Кара-Суу'];
  static const streets = [
    'ул. Курманжан Датка',
    'ул. Масалиева',
    'ул. Навои',
    'ул. Ленина',
    'ул. Алишера Навои',
  ];

  /// Адрес семьи и адрес родителей — ими заполняются формы по умолчанию.
  static (String, String, String, String) get homeAddress => _dom;
  static (String, String, String, String) get parentsAddress => _par;

  static List<RegistryAccount> byAccount(String accountNo, {String? providerId}) =>
      accounts
          .where((a) =>
              a.matchesAccount(accountNo) &&
              (providerId == null || a.providerId == providerId))
          .toList();

  static List<RegistryAccount> byAddress(String city, String street, String house, String flat) =>
      accounts.where((a) => a.matchesAddress(city, street, house, flat)).toList();

  static RegistryAccount? byId(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}
