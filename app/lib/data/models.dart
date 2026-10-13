import 'package:flutter/foundation.dart';

enum AuthMethod { phone, email, telegram }

@immutable
class Session {
  const Session({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.telegram,
    required this.method,
    this.address = '',
    this.city = 'Ош',
  });

  final String id, name;
  final String? phone, email, telegram;
  final AuthMethod method;
  final String address, city;

  String get firstName => name.trim().split(RegExp(r'\s+')).last;
  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return p.take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
  }

  Session copyWith({String? name, String? phone, String? email, String? address, String? city}) =>
      Session(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        telegram: telegram,
        method: method,
        address: address ?? this.address,
        city: city ?? this.city,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'telegram': telegram,
        'method': method.name,
        'address': address,
        'city': city,
      };

  static Session fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        telegram: j['telegram'] as String?,
        method: AuthMethod.values.firstWhere(
          (m) => m.name == j['method'],
          orElse: () => AuthMethod.phone,
        ),
        address: (j['address'] as String?) ?? '',
        city: (j['city'] as String?) ?? 'Ош',
      );
}

/// Объект: дом, квартира родителей, дача. У каждого свои счета.
@immutable
class PayObject {
  const PayObject({
    required this.id,
    required this.name,
    required this.icon,
    required this.cat,
    this.address = '',
  });
  final String id, name, icon, cat, address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'cat': cat,
        'address': address,
      };

  static PayObject fromJson(Map<String, dynamic> j) => PayObject(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? 'house',
        cat: j['cat'] as String? ?? 'water',
        address: j['address'] as String? ?? '',
      );
}

/// Строка расшифровки или реквизитов: подпись — значение.
@immutable
class Field {
  const Field(this.label, this.value);
  final String label, value;

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  static Field fromJson(Map<String, dynamic> j) =>
      Field('${j['label'] ?? ''}', '${j['value'] ?? ''}');

  static List<Field> listFrom(Object? raw) => [
        for (final f in (raw as List? ?? const []))
          if (f is Map) Field.fromJson(f.cast<String, dynamic>()),
      ];
}

@immutable
class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cat,
    required this.amount,
    required this.objectId,
    required this.period,
    required this.due,
    this.account = '',
    this.accountId = '',
    this.periodAt,
    this.calc = const [],
    this.requisites = const [],
    this.paid = false,
    this.autopay = false,
  });

  final String id, title, subtitle, cat, objectId, period, account;
  final double amount;
  final DateTime due;
  final List<Field> calc, requisites;
  final bool paid, autopay;

  /// id подключённого счёта ([ConnectedAccount.id]), по которому пришло
  /// начисление. Строка номера (`account`) для этого не годится: у разных
  /// поставщиков номера совпадают, и отключение одного счёта снесёт
  /// начисления другого. Пусто — начисление без привязки (демо-набор или
  /// бэкенд, который счёт не назвал).
  final String accountId;

  /// Начало расчётного периода. Нужно, чтобы подпись периода собиралась
  /// локализованно через `S.periodText(d)`, а не лежала русской строкой
  /// «сентябрь 2026» в кыргызской локали.
  final DateTime? periodAt;

  Bill copyWith({bool? paid, bool? autopay, double? amount, String? accountId}) => Bill(
        id: id,
        title: title,
        subtitle: subtitle,
        cat: cat,
        amount: amount ?? this.amount,
        objectId: objectId,
        period: period,
        due: due,
        account: account,
        accountId: accountId ?? this.accountId,
        periodAt: periodAt,
        calc: calc,
        requisites: requisites,
        paid: paid ?? this.paid,
        autopay: autopay ?? this.autopay,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'cat': cat,
        'amount': amount,
        'objectId': objectId,
        'period': period,
        'due': due.toIso8601String(),
        'account': account,
        'accountId': accountId,
        'periodAt': periodAt?.toIso8601String(),
        'calc': [for (final f in calc) f.toJson()],
        'requisites': [for (final f in requisites) f.toJson()],
        'paid': paid,
        'autopay': autopay,
      };

  static Bill fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        objectId: j['objectId'] as String? ?? '',
        period: j['period'] as String? ?? '',
        due: DateTime.tryParse(j['due'] as String? ?? '') ?? DateTime(2026),
        account: j['account'] as String? ?? '',
        accountId: j['accountId'] as String? ?? '',
        periodAt: DateTime.tryParse(j['periodAt'] as String? ?? ''),
        calc: Field.listFrom(j['calc']),
        requisites: Field.listFrom(j['requisites']),
        paid: j['paid'] as bool? ?? false,
        autopay: j['autopay'] as bool? ?? false,
      );

  /// Новый номер лицевого счёта и объект — при правке в профиле.
  /// [accountId] при этом сбрасывается: номер больше не тот, что был
  /// у подключённого счёта, и прежняя привязка стала неправдой.
  Bill withAccount(String account, String objectId) => Bill(
        id: id,
        title: title,
        subtitle: subtitle,
        cat: cat,
        amount: amount,
        objectId: objectId,
        period: period,
        due: due,
        account: account,
        periodAt: periodAt,
        calc: calc,
        requisites: [
          for (final f in requisites)
            f.label == 'Лицевой счёт' ? Field(f.label, account) : f,
        ],
        paid: paid,
        autopay: autopay,
      );

  int daysLeft(DateTime now) => due.difference(DateTime(now.year, now.month, now.day)).inDays;
}

enum PayStatus { success, declined, offline }

@immutable
class PayResult {
  const PayResult(this.status, {this.reason, this.receiptNo});
  final PayStatus status;
  final String? reason, receiptNo;
  bool get ok => status == PayStatus.success;
}

@immutable
class PayMethodItem {
  const PayMethodItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.isWallet = false,
    this.balance,
  });
  final String id, title, subtitle, badge;
  final bool isWallet;
  final double? balance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'badge': badge,
        'isWallet': isWallet,
        'balance': balance,
      };

  static PayMethodItem fromJson(Map<String, dynamic> j) => PayMethodItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        badge: j['badge'] as String? ?? '',
        isWallet: j['isWallet'] as bool? ?? false,
        balance: (j['balance'] as num?)?.toDouble(),
      );
}

/// Категория каталога платежей: «Коммунальные услуги», «Садик и школа»…
@immutable
class PayCategory {
  const PayCategory({
    required this.id,
    required this.title,
    required this.lead,
    required this.cat,
  });
  final String id, title, lead, cat;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'lead': lead,
        'cat': cat,
      };

  static PayCategory fromJson(Map<String, dynamic> j) => PayCategory(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        lead: j['lead'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
      );
}

/// Формат лицевого счёта. Принадлежит поставщику, а не экрану: одна и та же
/// проверка нужна форме подключения, правилам подключения и реестру, поэтому
/// номер нормализуется и проверяется в одном месте.
@immutable
class AccountMask {
  const AccountMask({
    required this.pattern,
    required this.hint,
    this.minLength = 4,
    this.maxLength = 20,
  });

  /// Регулярное выражение по «чистому» виду номера — без разделителей,
  /// буквы в верхнем регистре. Пусто — формат поставщику неизвестен,
  /// проверяется только длина.
  final String pattern;

  /// Образец номера: и подсказка в поле ввода, и шаблон расстановки
  /// разделителей для [normalize].
  final String hint;

  /// Границы длины «чистого» вида.
  final int minLength, maxLength;

  /// Формат неизвестен: принимаем любой номер разумной длины.
  static const any = AccountMask(pattern: '', hint: '');

  /// Мусор и разделители в номере: пробелы, дефисы, точки, запятые,
  /// «№», кавычки, косая черта.
  static final _noise = RegExp(r'[\s\-–—.,№"«»/]');

  /// «Чистый» вид: мусор убран, «ё» → «е», буквы в верхнем регистре —
  /// чтобы 'osh-44120' и 'OSH 44120' были одним номером.
  static String clean(String raw) => raw
      .replaceAll(_noise, '')
      .replaceAll('ё', 'е')
      .replaceAll('Ё', 'Е')
      .toUpperCase();

  /// Ключ сравнения двух номеров: тот же набор мусора, что у демо-реестра
  /// (`Registry.matchesAccount`), плюс косая черта. Сверка подключённого
  /// с найденным не зависит от того, как номер напечатали.
  static String keyOf(String raw) => clean(raw).toLowerCase();

  /// Формат не задан.
  bool get isAny => pattern.isEmpty;

  /// Проверка номера. Принимает и сырой ввод, и уже нормализованный:
  /// обе формы сводятся к «чистому» виду.
  bool matches(String value) {
    if (isAny) {
      final v = value.trim();
      return v.length >= minLength && v.length <= maxLength;
    }
    final v = clean(value);
    if (v.length < minLength || v.length > maxLength) return false;
    return RegExp(pattern).hasMatch(v);
  }

  /// Канонический вид для показа и отправки: '3101187' → '31-01187'.
  /// Разделители расставляются по образцу [hint]; если длина не совпала
  /// с образцом, возвращается «чистый» вид без разделителей — такой номер
  /// всё равно не пройдёт [matches], и ошибка покажется у поля.
  String normalize(String raw) {
    if (isAny || hint.isEmpty) return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final v = clean(raw);
    if (v.length != hint.replaceAll(_noise, '').length) return v;
    final out = StringBuffer();
    var i = 0;
    for (final ch in hint.split('')) {
      if (_noise.hasMatch(ch)) {
        out.write(ch);
      } else {
        out.write(v[i++]);
      }
    }
    return out.toString();
  }

  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        'hint': hint,
        'minLength': minLength,
        'maxLength': maxLength,
      };

  static AccountMask fromJson(Map<String, dynamic>? j) => j == null
      ? any
      : AccountMask(
          pattern: j['pattern'] as String? ?? '',
          hint: j['hint'] as String? ?? '',
          minLength: (j['minLength'] as num?)?.toInt() ?? 4,
          maxLength: (j['maxLength'] as num?)?.toInt() ?? 20,
        );
}

/// Поставщик из каталога: то, что подставляет реквизиты за пользователя.
@immutable
class ProviderItem {
  const ProviderItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cat,
    required this.categoryId,
    required this.accountLabel,
    required this.accountHint,
    this.requisites = const [],
    this.fixedAmount,
    this.mask = AccountMask.any,
  });

  final String id, title, subtitle, cat, categoryId, accountLabel, accountHint;
  final List<Field> requisites;
  final double? fixedAmount;

  /// Формат лицевого счёта: по нему номер проверяется ДО обращения в сеть.
  final AccountMask mask;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'cat': cat,
        'categoryId': categoryId,
        'accountLabel': accountLabel,
        'accountHint': accountHint,
        'requisites': [for (final f in requisites) f.toJson()],
        'fixedAmount': fixedAmount,
        'mask': mask.toJson(),
      };

  static ProviderItem fromJson(Map<String, dynamic> j) => ProviderItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        categoryId: j['categoryId'] as String? ?? '',
        accountLabel: j['accountLabel'] as String? ?? '',
        accountHint: j['accountHint'] as String? ?? '',
        requisites: Field.listFrom(j['requisites']),
        fixedAmount: (j['fixedAmount'] as num?)?.toDouble(),
        mask: AccountMask.fromJson((j['mask'] as Map?)?.cast<String, dynamic>()),
      );
}

/// Совершённый платёж — строка истории и основа квитанции.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.title,
    required this.cat,
    required this.amount,
    required this.date,
    required this.methodId,
    required this.receiptNo,
    this.objectId = '',
    this.account = '',
    this.period = '',
    this.status = PayStatus.success,
  });

  final String id, title, cat, methodId, receiptNo, objectId, account, period;
  final double amount;
  final DateTime date;
  final PayStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cat': cat,
        'amount': amount,
        'date': date.toIso8601String(),
        'methodId': methodId,
        'receiptNo': receiptNo,
        'objectId': objectId,
        'account': account,
        'period': period,
        'status': status.name,
      };

  static Payment fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime(2026),
        methodId: j['methodId'] as String? ?? '',
        receiptNo: j['receiptNo'] as String? ?? '',
        objectId: j['objectId'] as String? ?? '',
        account: j['account'] as String? ?? '',
        period: j['period'] as String? ?? '',
        status: PayStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => PayStatus.success,
        ),
      );
}

/// Участник семейного доступа.
@immutable
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.canPay = false,
  });
  final String id, name, phone, role;
  final bool canPay;

  FamilyMember copyWith({String? role, bool? canPay}) => FamilyMember(
        id: id,
        name: name,
        phone: phone,
        role: role ?? this.role,
        canPay: canPay ?? this.canPay,
      );
}

/// Устройство, с которого входили в аккаунт.
@immutable
class DeviceItem {
  const DeviceItem({
    required this.id,
    required this.title,
    required this.place,
    required this.lastSeen,
    this.current = false,
  });
  final String id, title, place, lastSeen;
  final bool current;
}

enum NoticeKind { outage, bill, payment, market }

/// Уведомление в ленте: отключение, новый счёт, прошедший платёж.
@immutable
class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    required this.date,
    this.read = false,
  });
  final String id, title, text;
  final NoticeKind kind;
  final DateTime date;
  final bool read;

  NoticeItem copyWith({bool? read}) => NoticeItem(
        id: id,
        kind: kind,
        title: title,
        text: text,
        date: date,
        read: read ?? this.read,
      );
}

/// Событие маркета: концерт, кино, спорт.
@immutable
class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.place,
    required this.date,
    required this.price,
    required this.cat,
    required this.lead,
  });
  final String id, title, place, cat, lead;
  final DateTime date;
  final double price;
}

/// Купленный билет с QR.
@immutable
class TicketItem {
  const TicketItem({
    required this.id,
    required this.eventId,
    required this.title,
    required this.place,
    required this.date,
    required this.price,
    required this.code,
    required this.seats,
    this.used = false,
  });
  final String id, eventId, title, place, code;
  final DateTime date;
  final double price;
  final int seats;
  final bool used;

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'title': title,
        'place': place,
        'date': date.toIso8601String(),
        'price': price,
        'code': code,
        'seats': seats,
        'used': used,
      };

  static TicketItem fromJson(Map<String, dynamic> j) => TicketItem(
        id: j['id'] as String,
        eventId: j['eventId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        place: j['place'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime(2026),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        code: j['code'] as String? ?? '',
        seats: (j['seats'] as num?)?.toInt() ?? 1,
        used: j['used'] as bool? ?? false,
      );

  TicketItem copyWith({bool? used}) => TicketItem(
        id: id,
        eventId: eventId,
        title: title,
        place: place,
        date: date,
        price: price,
        code: code,
        seats: seats,
        used: used ?? this.used,
      );
}

/// Кадр сториса: иллюстрация, заголовок, текст и кнопка-ссылка.
@immutable
class StoryFrame {
  const StoryFrame({
    required this.title,
    required this.text,
    this.ctaLabel,
    this.ctaRoute,
  });
  final String title, text;
  final String? ctaLabel, ctaRoute;
}

/// Сторис: одна рамка на главной, внутри — до трёх кадров.
@immutable
class StoryItem {
  const StoryItem({
    required this.id,
    required this.tag,
    required this.preview,
    required this.cat,
    required this.icon,
    required this.author,
    required this.ago,
    required this.frames,
    this.seen = false,
  });

  final String id, tag, preview, cat, icon, author, ago;
  final List<StoryFrame> frames;
  final bool seen;

  StoryItem copyWith({bool? seen}) => StoryItem(
        id: id,
        tag: tag,
        preview: preview,
        cat: cat,
        icon: icon,
        author: author,
        ago: ago,
        frames: frames,
        seen: seen ?? this.seen,
      );
}

/// Значок услуги на главной: быстрый вход в оплату или подключение счёта.
@immutable
class QuickService {
  const QuickService({
    required this.cat,
    required this.label,
    required this.providerId,
  });
  final String cat, label, providerId;

  Map<String, dynamic> toJson() => {
        'cat': cat,
        'label': label,
        'providerId': providerId,
      };

  static QuickService fromJson(Map<String, dynamic> j) => QuickService(
        cat: j['cat'] as String? ?? 'city',
        label: j['label'] as String? ?? '',
        providerId: j['providerId'] as String? ?? '',
      );
}

/// Каталог платежей одним объектом: пять списков всегда нужны вместе,
/// поэтому это один тип, один репозиторий и один провайдер, а не пять.
///
/// Лежит в моделях, а не в `catalog_repository.dart`, как предполагал план:
/// иначе `demo_data.dart` (ему нужен тип для `Demo.catalog`) и репозиторий
/// (ему нужны демо-данные как источник) импортировали бы друг друга.
/// Репозиторий этот тип реэкспортирует, поэтому `import 'catalog_repository.dart'`
/// из плана тоже работает.
@immutable
class Catalog {
  const Catalog({
    required this.categories,
    required this.providers,
    required this.quickServices,
    required this.methods,
    required this.bank,
  });

  final List<PayCategory> categories;
  final List<ProviderItem> providers;
  final List<QuickService> quickServices;
  final List<PayMethodItem> methods;

  /// Реквизиты банка-получателя — общая часть каждой квитанции.
  final List<Field> bank;

  static const empty = Catalog(
      categories: [], providers: [], quickServices: [], methods: [], bank: []);

  /// Каталога нет: ни категорий, ни поставщиков, ни способов оплаты.
  bool get isEmpty => categories.isEmpty && providers.isEmpty && methods.isEmpty;

  ProviderItem? providerById(String id) {
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  PayMethodItem? methodById(String id) {
    for (final m in methods) {
      if (m.id == id) return m;
    }
    return null;
  }

  PayCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ProviderItem> byCategory(String categoryId) =>
      [for (final p in providers) if (p.categoryId == categoryId) p];

  /// Значки услуг: все или только те, чей поставщик из этой категории.
  List<QuickService> quickFor(String? categoryId) {
    if (categoryId == null) return quickServices;
    return [
      for (final q in quickServices)
        if (providerById(q.providerId)?.categoryId == categoryId) q,
    ];
  }

  /// Поиск поставщика по названию, услуге и номеру-образцу. Пустой запрос —
  /// весь список, чтобы шторка выбора не начиналась с пустого экрана.
  /// [tr] — перевод строки данных на язык экрана. Без него поиск шёл по
  /// русским ключам, которых на кыргызском пользователю никто не показывал:
  /// набрав увиденное слово, он не находил ничего.
  List<ProviderItem> searchProviders(
    String query, {
    String? categoryId,
    String Function(String)? tr,
  }) {
    final pool = categoryId == null ? providers : byCategory(categoryId);
    final q = _fold(query);
    if (q.isEmpty) return pool;
    bool hit(String raw) =>
        _fold(raw).contains(q) || (tr != null && _fold(tr(raw)).contains(q));
    return [
      for (final p in pool)
        if (hit(p.title) || hit(p.subtitle) || hit(p.accountLabel) || hit(p.accountHint)) p,
    ];
  }

  /// Формат лицевого счёта у поставщика — проверка номера до обращения
  /// в сеть. Поставщик неизвестен — [AccountMask.any], а не отказ.
  AccountMask maskOf(String providerId) => providerById(providerId)?.mask ?? AccountMask.any;

  Map<String, dynamic> toJson() => {
        'categories': [for (final c in categories) c.toJson()],
        'providers': [for (final p in providers) p.toJson()],
        'quickServices': [for (final q in quickServices) q.toJson()],
        'methods': [for (final m in methods) m.toJson()],
        'bank': [for (final f in bank) f.toJson()],
      };

  static Catalog fromJson(Map<String, dynamic> j) => Catalog(
        categories: [for (final r in _rows(j['categories'])) PayCategory.fromJson(r)],
        providers: [for (final r in _rows(j['providers'])) ProviderItem.fromJson(r)],
        quickServices: [for (final r in _rows(j['quickServices'])) QuickService.fromJson(r)],
        methods: [for (final r in _rows(j['methods'])) PayMethodItem.fromJson(r)],
        bank: Field.listFrom(j['bank']),
      );

  static List<Map<String, dynamic>> _rows(Object? raw) => [
        for (final r in (raw as List? ?? const []))
          if (r is Map) r.cast<String, dynamic>(),
      ];
}

/// Сравнение без регистра и «ё» — чтобы поиск по каталогу не зависел
/// от того, как напечатали.
String _fold(String v) => v.trim().toLowerCase().replaceAll('ё', 'е');

/// Как давно обновлялись начисления по подключённому счёту.
///
/// ВНИМАНИЕ: значения не добавлять, не поправив switch'и по статусу в
/// features/accounts/accounts_page.dart — они исчерпывающие, и новое
/// значение ломает сборку. Поэтому операция в очереди живёт отдельным
/// полем [ConnectedAccount.pendingOp], а не значениями статуса.
enum AccountSyncStatus { ok, syncing, failed }

/// Операция со счётом, которая ещё не дошла до поставщика: лежит в очереди
/// (Outbox) и ждёт сети. Нужна, чтобы «подключаем» и «отключаем» были
/// видимым состоянием строки, а не невидимым ожиданием.
enum AccountOp { connect, disconnect }

AccountOp? _opFrom(Object? raw) {
  for (final o in AccountOp.values) {
    if (o.name == raw) return o;
  }
  return null;
}

/// Найденный в реестре поставщика счёт — кандидат на подключение.
@immutable
class AccountCandidate {
  const AccountCandidate({
    required this.id,
    required this.providerId,
    required this.providerTitle,
    required this.serviceTitle,
    required this.cat,
    required this.accountNo,
    required this.holder,
    required this.address,
    required this.amount,
    required this.period,
    required this.dueDay,
    this.calc = const [],
    this.needsConfirm = false,
    this.alreadyConnected = false,
  });

  final String id, providerId, providerTitle, serviceTitle, cat, accountNo, holder, address, period;
  final double amount;
  final int dueDay;
  final List<Field> calc;

  /// Счёт оформлен не на этого пользователя — нужен код подтверждения.
  final bool needsConfirm;

  /// Такой счёт уже подключён к ЭлPay.
  final bool alreadyConnected;

  AccountCandidate copyWith({bool? alreadyConnected, bool? needsConfirm}) => AccountCandidate(
        id: id,
        providerId: providerId,
        providerTitle: providerTitle,
        serviceTitle: serviceTitle,
        cat: cat,
        accountNo: accountNo,
        holder: holder,
        address: address,
        amount: amount,
        period: period,
        dueDay: dueDay,
        calc: calc,
        needsConfirm: needsConfirm ?? this.needsConfirm,
        alreadyConnected: alreadyConnected ?? this.alreadyConnected,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'providerTitle': providerTitle,
        'serviceTitle': serviceTitle,
        'cat': cat,
        'accountNo': accountNo,
        'holder': holder,
        'address': address,
        'amount': amount,
        'period': period,
        'dueDay': dueDay,
        'calc': [for (final f in calc) {'label': f.label, 'value': f.value}],
        'needsConfirm': needsConfirm,
        'alreadyConnected': alreadyConnected,
      };

  static AccountCandidate fromJson(Map<String, dynamic> j) => AccountCandidate(
        id: j['id'] as String,
        providerId: j['providerId'] as String,
        providerTitle: j['providerTitle'] as String? ?? '',
        serviceTitle: j['serviceTitle'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        accountNo: j['accountNo'] as String? ?? '',
        holder: j['holder'] as String? ?? '',
        address: j['address'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        period: j['period'] as String? ?? '',
        dueDay: (j['dueDay'] as num?)?.toInt() ?? 25,
        calc: [
          for (final f in (j['calc'] as List? ?? const []))
            if (f is Map) Field('${f['label']}', '${f['value']}'),
        ],
        needsConfirm: j['needsConfirm'] as bool? ?? false,
        alreadyConnected: j['alreadyConnected'] as bool? ?? false,
      );
}

/// Подключённый к ЭлPay лицевой счёт: по нему приходят начисления.
@immutable
class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.providerId,
    required this.title,
    required this.subtitle,
    required this.cat,
    required this.accountNo,
    required this.objectId,
    required this.holder,
    required this.address,
    required this.connectedAt,
    this.dueDay = 25,
    this.status = AccountSyncStatus.ok,
    this.pendingOp,
    this.syncedAt,
    this.lastError,
  });

  final String id, providerId, title, subtitle, cat, accountNo, objectId, holder, address;
  final DateTime connectedAt;

  /// День месяца, до которого поставщик просит оплатить. Нужен, чтобы срок
  /// у начисления не выдумывался экраном.
  final int dueDay;

  final AccountSyncStatus status;

  /// Операция в очереди: счёт подключается или отключается без сети.
  /// null — со счётом ничего не ждёт отправки.
  final AccountOp? pendingOp;

  final DateTime? syncedAt;
  final String? lastError;

  bool get isPendingConnect => pendingOp == AccountOp.connect;
  bool get isPendingDisconnect => pendingOp == AccountOp.disconnect;
  bool get isPending => pendingOp != null;

  /// [clearError] — явно стереть прошлую ошибку (после удачного обновления).
  /// [clearPendingOp] — операция дошла до поставщика, ожидание снимается.
  ConnectedAccount copyWith({
    String? objectId,
    int? dueDay,
    AccountSyncStatus? status,
    AccountOp? pendingOp,
    bool clearPendingOp = false,
    DateTime? syncedAt,
    String? lastError,
    bool clearError = false,
  }) =>
      ConnectedAccount(
        id: id,
        providerId: providerId,
        title: title,
        subtitle: subtitle,
        cat: cat,
        accountNo: accountNo,
        objectId: objectId ?? this.objectId,
        holder: holder,
        address: address,
        connectedAt: connectedAt,
        dueDay: dueDay ?? this.dueDay,
        status: status ?? this.status,
        pendingOp: clearPendingOp ? null : (pendingOp ?? this.pendingOp),
        syncedAt: syncedAt ?? this.syncedAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'title': title,
        'subtitle': subtitle,
        'cat': cat,
        'accountNo': accountNo,
        'objectId': objectId,
        'holder': holder,
        'address': address,
        'connectedAt': connectedAt.toIso8601String(),
        'dueDay': dueDay,
        'status': status.name,
        'pendingOp': pendingOp?.name,
        'syncedAt': syncedAt?.toIso8601String(),
        'lastError': lastError,
      };

  static ConnectedAccount fromJson(Map<String, dynamic> j) => ConnectedAccount(
        id: j['id'] as String,
        providerId: j['providerId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        accountNo: j['accountNo'] as String? ?? '',
        objectId: j['objectId'] as String? ?? '',
        holder: j['holder'] as String? ?? '',
        address: j['address'] as String? ?? '',
        connectedAt: DateTime.tryParse(j['connectedAt'] as String? ?? '') ?? DateTime(2026),
        dueDay: (j['dueDay'] as num?)?.toInt() ?? 25,
        pendingOp: _opFrom(j['pendingOp']),
        status: AccountSyncStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => AccountSyncStatus.ok,
        ),
        syncedAt: DateTime.tryParse(j['syncedAt'] as String? ?? ''),
        lastError: j['lastError'] as String?,
      );
}

/// Запрос на поиск счёта: либо по номеру, либо по адресу.
@immutable
class AccountQuery {
  const AccountQuery.byAccount(this.accountNo, {this.providerId})
      : city = '',
        street = '',
        house = '',
        flat = '';

  const AccountQuery.byAddress({
    required this.city,
    required this.street,
    required this.house,
    this.flat = '',
    this.providerId,
  }) : accountNo = '';

  final String accountNo;
  final String? providerId;
  final String city, street, house, flat;

  bool get isByAccount => accountNo.isNotEmpty;
  String get method => isByAccount ? 'account' : 'address';
}
