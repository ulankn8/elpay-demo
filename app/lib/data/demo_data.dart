import 'models.dart';

/// Демо-данные пилота (город Ош). Заменяются ответами бэкенда —
/// структура специально повторяет будущий API.
class Demo {
  static final objects = <PayObject>[
    const PayObject(
        id: 'o1', name: 'Дом', icon: 'house', cat: 'water',
        address: 'Ош, ул. Курманжан Датка, 212'),
    const PayObject(
        id: 'o2', name: 'Родители', icon: 'users', cat: 'door',
        address: 'Ош, ул. Масалиева, 44'),
  ];

  static const bank = [
    Field('Банк', '«Оптима Банк», филиал в г. Ош'),
    Field('БИК', '109003'),
  ];

  static List<Bill> bills(DateTime now) {
    DateTime due(int day) => DateTime(now.year, now.month, day);
    return [
      Bill(
        id: 'trash-1',
        title: 'Ош-Тазалык',
        subtitle: 'Вывоз мусора',
        cat: 'trash',
        amount: 180,
        objectId: 'o1',
        period: 'сентябрь 2026',
        due: due(28),
        account: '04-118725',
        calc: const [
          Field('Тариф', '45 сом с человека'),
          Field('Начислено на', '4 проживающих'),
          Field('Итого', '180 сом'),
        ],
        requisites: const [
          Field('Получатель', 'МП «Ош-Тазалык»'),
          Field('ИНН', '02508199610087'),
          ...bank,
          Field('Расчётный счёт', '1091820110280103'),
          Field('Лицевой счёт', '04-118725'),
          Field('Назначение', 'Вывоз мусора, сентябрь 2026'),
        ],
      ),
      Bill(
        id: 'power-1',
        title: 'Электросеть',
        subtitle: 'Электроэнергия',
        cat: 'power',
        amount: 564.44,
        objectId: 'o1',
        period: 'август 2026',
        due: due(25),
        account: '7710-3348',
        calc: const [
          Field('Тариф', '1,37 сом за кВт·ч'),
          Field('Расход', '412 кВт·ч'),
          Field('Итого', '564,44 сом'),
        ],
        requisites: const [
          Field('Получатель', 'ОАО «Ошэлектро»'),
          Field('ИНН', '01709199510045'),
          ...bank,
          Field('Расчётный счёт', '1091820110120457'),
          Field('Лицевой счёт', '7710-3348'),
          Field('Назначение', 'Электроэнергия, август 2026'),
        ],
      ),
      Bill(
        id: 'water-1',
        title: 'Водоканал',
        subtitle: 'Холодная вода',
        cat: 'water',
        amount: 205,
        objectId: 'o1',
        period: 'август 2026',
        due: due(25),
        account: '31-00562',
        calc: const [
          Field('Тариф', '22,78 сом за м³'),
          Field('Расход', '9 м³'),
          Field('Итого', '205 сом'),
        ],
        requisites: const [
          Field('Получатель', 'МП «Ошводоканал»'),
          Field('ИНН', '02212199410063'),
          ...bank,
          Field('Расчётный счёт', '1091820110330281'),
          Field('Лицевой счёт', '31-00562'),
          Field('Назначение', 'Холодная вода, август 2026'),
        ],
      ),
      Bill(
        id: 'kid-1',
        title: 'Садик «Балапан»',
        subtitle: 'Амир · октябрь',
        cat: 'kid',
        amount: 3500,
        objectId: 'o1',
        period: 'октябрь 2026',
        due: DateTime(now.year, now.month + 1, 5),
        account: '—',
        calc: const [
          Field('Услуга', 'Детский сад «Балапан»'),
          Field('Период', 'октябрь 2026'),
          Field('Итого', '3 500 сом'),
        ],
        requisites: const [
          Field('Получатель', 'ЧУ «Детский сад Балапан»'),
          Field('ИНН', '01203201110094'),
          ...bank,
          Field('Расчётный счёт', '1091820110775412'),
          Field('Ребёнок', 'Токтогулов Амир'),
          Field('Назначение', 'Оплата за детский сад, Амир, октябрь 2026'),
        ],
      ),
      Bill(
        id: 'power-2',
        title: 'Свет родителей',
        subtitle: 'Электроэнергия',
        cat: 'power',
        amount: 320,
        objectId: 'o2',
        period: 'август 2026',
        due: due(25),
        account: '7710-5521',
        calc: const [
          Field('Тариф', '1,37 сом за кВт·ч'),
          Field('Расход', '234 кВт·ч'),
          Field('Итого', '320 сом'),
        ],
        requisites: const [
          Field('Получатель', 'ОАО «Ошэлектро»'),
          Field('ИНН', '01709199510045'),
          ...bank,
          Field('Расчётный счёт', '1091820110120457'),
          Field('Лицевой счёт', '7710-5521'),
          Field('Назначение', 'Электроэнергия, август 2026'),
        ],
      ),
      Bill(
        id: 'water-2',
        title: 'Вода родителей',
        subtitle: 'Холодная вода',
        cat: 'water',
        amount: 150,
        objectId: 'o2',
        period: 'август 2026',
        due: due(18),
        account: '31-01187',
        calc: const [
          Field('Тариф', '22,78 сом за м³'),
          Field('Расход', '6,6 м³'),
          Field('Итого', '150 сом'),
        ],
        requisites: const [
          Field('Получатель', 'МП «Ошводоканал»'),
          Field('ИНН', '02212199410063'),
          ...bank,
          Field('Расчётный счёт', '1091820110330281'),
          Field('Лицевой счёт', '31-01187'),
          Field('Назначение', 'Холодная вода, август 2026'),
        ],
      ),
    ];
  }

  static const methods = <PayMethodItem>[
    PayMethodItem(
        id: 'wallet', title: 'Кошелёк ЭлPay', subtitle: '', badge: 'ЭЛПЕЙ',
        isWallet: true, balance: 1240),
    PayMethodItem(id: 'visa', title: 'Visa •••• 4417', subtitle: 'Основная карта', badge: 'VISA'),
    PayMethodItem(id: 'elcard', title: 'Элкарт •••• 0921', subtitle: 'Дополнительная', badge: 'ЭЛКАРТ'),
    PayMethodItem(id: 'mbank', title: 'MBANK', subtitle: 'Списание со счёта в банке', badge: 'MBANK'),
    PayMethodItem(id: 'odengi', title: 'О! Деньги', subtitle: 'Кошелёк оператора', badge: 'O!'),
  ];
}
