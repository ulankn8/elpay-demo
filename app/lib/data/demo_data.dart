import '../core/format.dart';
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
        account: 'Д-2291',
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

  // ───────────────────── каталог платежей ─────────────────────

  static const categories = <PayCategory>[
    PayCategory(
        id: 'util', title: 'Коммунальные услуги',
        lead: 'Свет, вода, мусор, газ', cat: 'water'),
    PayCategory(
        id: 'edu', title: 'Садик, школа, курсы',
        lead: 'Оплата по шаблону на месяц', cat: 'kid'),
    PayCategory(
        id: 'tax', title: 'Налоги и патент',
        lead: 'Начисления по ИНН', cat: 'tax'),
    PayCategory(
        id: 'net', title: 'Интернет и ТВ',
        lead: 'Домашний интернет, телевидение', cat: 'net'),
    PayCategory(
        id: 'mobile', title: 'Мобильная связь',
        lead: 'O!, Beeline, MegaCom', cat: 'mobile'),
    PayCategory(
        id: 'market', title: 'Маркет и билеты',
        lead: 'События и кино в Оше', cat: 'market'),
  ];

  static const providers = <ProviderItem>[
    ProviderItem(
      id: 'p-power', title: 'Ошэлектро', subtitle: 'Электроэнергия',
      cat: 'power', categoryId: 'util',
      accountLabel: 'Лицевой счёт', accountHint: '12-44530',
      requisites: [
        Field('Получатель', 'ОАО «Ошэлектро»'),
        Field('ИНН', '02905199510045'),
        Field('Расчётный счёт', '1091820100580127'),
      ],
    ),
    ProviderItem(
      id: 'p-water', title: 'Ошводоканал', subtitle: 'Холодная вода',
      cat: 'water', categoryId: 'util',
      accountLabel: 'Лицевой счёт', accountHint: '31-01187',
      requisites: [
        Field('Получатель', 'МП «Ошводоканал»'),
        Field('ИНН', '02212199410063'),
        Field('Расчётный счёт', '1091820110330281'),
      ],
    ),
    ProviderItem(
      id: 'p-trash', title: 'Ош-Тазалык', subtitle: 'Вывоз мусора',
      cat: 'trash', categoryId: 'util',
      accountLabel: 'Лицевой счёт', accountHint: '77-20841',
      requisites: [
        Field('Получатель', 'МП «Ош-Тазалык»'),
        Field('ИНН', '02308199210079'),
        Field('Расчётный счёт', '1091820100450193'),
      ],
    ),
    ProviderItem(
      id: 'p-gas', title: 'Газпром Кыргызстан', subtitle: 'Природный газ',
      cat: 'gas', categoryId: 'util',
      accountLabel: 'Лицевой счёт', accountHint: '55-20841',
      requisites: [
        Field('Получатель', 'ОсОО «Газпром Кыргызстан»'),
        Field('ИНН', '01502201410098'),
        Field('Расчётный счёт', '1280010009543211'),
      ],
    ),
    ProviderItem(
      id: 'p-kid', title: 'Садик «Балапан»', subtitle: 'Детский сад №14, Ош',
      cat: 'kid', categoryId: 'edu',
      accountLabel: 'Номер договора', accountHint: 'Д-2291',
      fixedAmount: 3500,
      requisites: [
        Field('Получатель', 'МДОУ «Балапан» №14'),
        Field('ИНН', '02106200110044'),
        Field('Расчётный счёт', '1091820100221904'),
      ],
    ),
    ProviderItem(
      id: 'p-school', title: 'Школа №29', subtitle: 'Питание и охрана',
      cat: 'school', categoryId: 'edu',
      accountLabel: 'Класс и фамилия', accountHint: '5В, Токтогулов',
      fixedAmount: 1200,
      requisites: [
        Field('Получатель', 'СОШ №29 им. А. Осмонова'),
        Field('ИНН', '02106200110098'),
        Field('Расчётный счёт', '1091820100223310'),
      ],
    ),
    ProviderItem(
      id: 'p-course', title: 'Курсы английского Smart', subtitle: 'Абонемент на месяц',
      cat: 'course', categoryId: 'edu',
      accountLabel: 'Номер ученика', accountHint: 'SM-1180',
      fixedAmount: 2400,
      requisites: [
        Field('Получатель', 'ОсОО «Смарт Эдьюкейшн»'),
        Field('ИНН', '01812201910033'),
        Field('Расчётный счёт', '1280010007781200'),
      ],
    ),
    ProviderItem(
      id: 'p-tax', title: 'Налоговая служба', subtitle: 'Начисления по ИНН',
      cat: 'tax', categoryId: 'tax',
      accountLabel: 'ИНН', accountHint: '22505199800123',
      requisites: [
        Field('Получатель', 'УГНС по г. Ош'),
        Field('ИНН', '00109199210012'),
        Field('Расчётный счёт', '4402011101000119'),
      ],
    ),
    ProviderItem(
      id: 'p-patent', title: 'Патент', subtitle: 'Месячный патент предпринимателя',
      cat: 'tax', categoryId: 'tax',
      accountLabel: 'ИНН', accountHint: '22505199800123',
      fixedAmount: 1800,
      requisites: [
        Field('Получатель', 'УГНС по г. Ош'),
        Field('ИНН', '00109199210012'),
        Field('Расчётный счёт', '4402011101000204'),
      ],
    ),
    ProviderItem(
      id: 'p-saima', title: 'Сайма Телеком', subtitle: 'Домашний интернет',
      cat: 'net', categoryId: 'net',
      accountLabel: 'Номер договора', accountHint: 'OSH-44120',
      fixedAmount: 1000,
      requisites: [
        Field('Получатель', 'ОсОО «Сайма Телеком»'),
        Field('ИНН', '01003199510077'),
        Field('Расчётный счёт', '1280010001122334'),
      ],
    ),
    ProviderItem(
      id: 'p-megaline', title: 'MegaLine', subtitle: 'Интернет и ТВ',
      cat: 'net', categoryId: 'net',
      accountLabel: 'Номер договора', accountHint: '0322-88190',
      fixedAmount: 900,
      requisites: [
        Field('Получатель', 'ОАО «Кыргызтелеком»'),
        Field('ИНН', '00108199410021'),
        Field('Расчётный счёт', '1280010002233445'),
      ],
    ),
    ProviderItem(
      id: 'p-o', title: 'O!', subtitle: 'Мобильная связь',
      cat: 'mobile', categoryId: 'mobile',
      accountLabel: 'Номер телефона', accountHint: '0700 12 34 56',
      requisites: [
        Field('Получатель', 'ЗАО «Альфа Телеком»'),
        Field('ИНН', '00510199710032'),
        Field('Расчётный счёт', '1280010005566778'),
      ],
    ),
    ProviderItem(
      id: 'p-beeline', title: 'Beeline', subtitle: 'Мобильная связь',
      cat: 'mobile', categoryId: 'mobile',
      accountLabel: 'Номер телефона', accountHint: '0770 12 34 56',
      requisites: [
        Field('Получатель', 'ОсОО «Скай Мобайл»'),
        Field('ИНН', '00306200210014'),
        Field('Расчётный счёт', '1280010006677889'),
      ],
    ),
    ProviderItem(
      id: 'p-mega', title: 'MegaCom', subtitle: 'Мобильная связь',
      cat: 'mobile', categoryId: 'mobile',
      accountLabel: 'Номер телефона', accountHint: '0555 12 34 56',
      requisites: [
        Field('Получатель', 'ЗАО «Альфа Телеком»'),
        Field('ИНН', '00510199710032'),
        Field('Расчётный счёт', '1280010007788990'),
      ],
    ),
  ];

  static ProviderItem? providerById(String id) {
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ───────────────────── история платежей ─────────────────────

  /// Прошлые платежи: шесть месяцев ровных начислений — на них
  /// строятся отчёты и графики.
  static List<Payment> history(DateTime now) {
    final out = <Payment>[];
    const rows = [
      ('Ош-Тазалык', 'trash', 180.0, 'o1', '04-118725'),
      ('Электросеть', 'power', 512.6, 'o1', '7710-3348'),
      ('Водоканал', 'water', 205.0, 'o1', '31-00562'),
      ('Садик «Балапан»', 'kid', 3500.0, 'o1', 'Д-2291'),
      ('Сайма Телеком', 'net', 1000.0, 'o1', 'OSH-44120'),
      ('Свет родителей', 'power', 318.4, 'o2', '7710-5521'),
    ];
    for (var m = 0; m <= 6; m++) {
      final month = DateTime(now.year, now.month - m, 1);
      for (var i = 0; i < rows.length; i++) {
        final (title, cat, base, obj, acc) = rows[i];
        // лёгкий разброс сумм, чтобы графики не были плоскими
        final amount = cat == 'power' || cat == 'water'
            ? (base * (1 + ((m * 7 + i * 13) % 17 - 8) / 100)).roundToDouble()
            : base;
        final date = DateTime(month.year, month.month, 4 + i * 2, 10, 15 + i);
        if (date.isAfter(now)) continue; // в текущем месяце — только прошедшие дни
        out.add(Payment(
          id: 'h-$m-$i',
          title: title,
          cat: cat,
          amount: amount,
          date: date,
          methodId: i.isEven ? 'visa' : 'wallet',
          receiptNo: 'ЭП-${204000 + m * 37 + i}',
          objectId: obj,
          account: acc,
          period: '${monthName(month.month)} ${month.year}',
        ));
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static const familyDemo = <FamilyMember>[
    FamilyMember(
        id: 'f1', name: 'Токтогулов Бакыт', phone: '+996 550 44 12 90',
        role: 'Супруг', canPay: true),
    FamilyMember(
        id: 'f2', name: 'Токтогулова Нургуль', phone: '+996 777 21 08 34',
        role: 'Мама', canPay: false),
  ];

  static const devicesDemo = <DeviceItem>[
    DeviceItem(
        id: 'd1', title: 'iPhone 14', place: 'Ош, Кыргызстан',
        lastSeen: 'сейчас', current: true),
    DeviceItem(
        id: 'd2', title: 'Redmi Note 12', place: 'Ош, Кыргызстан',
        lastSeen: '12 сентября, 19:40'),
    DeviceItem(
        id: 'd3', title: 'Браузер Chrome', place: 'Бишкек, Кыргызстан',
        lastSeen: '2 сентября, 08:12'),
  ];

  // ───────────────────── уведомления и маркет ─────────────────────

  static List<NoticeItem> notices(DateTime now) => [
        NoticeItem(
          id: 'n1',
          kind: NoticeKind.outage,
          title: 'Отключение воды 3 октября',
          text: 'Ош, ул. Курманжан Датка: с 09:00 до 17:00 — плановый ремонт сети.',
          date: now.subtract(const Duration(hours: 3)),
        ),
        NoticeItem(
          id: 'n2',
          kind: NoticeKind.bill,
          title: 'Пришёл счёт за электроэнергию',
          text: 'Электросеть, 564,44 сом. Оплатить до 25 числа.',
          date: now.subtract(const Duration(days: 1, hours: 2)),
        ),
        NoticeItem(
          id: 'n3',
          kind: NoticeKind.outage,
          title: 'Отключение света 28 сентября',
          text: 'Ош, ул. Масалиева: с 10:00 до 14:00 — замена трансформатора.',
          date: now.subtract(const Duration(days: 2)),
          read: true,
        ),
        NoticeItem(
          id: 'n4',
          kind: NoticeKind.payment,
          title: 'Платёж прошёл',
          text: 'Садик «Балапан», 3 500 сом. Квитанция сохранена в истории.',
          date: now.subtract(const Duration(days: 4)),
          read: true,
        ),
      ];

  static List<EventItem> events(DateTime now) {
    DateTime at(int days, int hour) =>
        DateTime(now.year, now.month, now.day + days, hour);
    return [
      EventItem(
        id: 'e1', title: 'Концерт «Ош сезону»', place: 'Ошский драмтеатр',
        date: at(6, 19), price: 800, cat: 'market', lead: 'Народные и эстрадные песни'),
      EventItem(
        id: 'e2', title: 'Кино: «Курманжан Датка»', place: 'Кинотеатр «Ынтымак»',
        date: at(2, 17), price: 250, cat: 'course', lead: 'Исторический фильм, 2 ч 10 мин'),
      EventItem(
        id: 'e3', title: 'Футбол: «Алай» — «Абдыш-Ата»', place: 'Стадион имени Ниязбекова',
        date: at(9, 16), price: 300, cat: 'school', lead: 'Премьер-лига Кыргызстана'),
      EventItem(
        id: 'e4', title: 'Детский спектакль «Алтын балык»', place: 'Театр кукол',
        date: at(4, 12), price: 200, cat: 'kid', lead: 'Для детей от 4 лет'),
    ];
  }
}
