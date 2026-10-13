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

  Bill copyWith({bool? paid, bool? autopay, double? amount}) => Bill(
        id: id,
        title: title,
        subtitle: subtitle,
        cat: cat,
        amount: amount ?? this.amount,
        objectId: objectId,
        period: period,
        due: due,
        account: account,
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
        calc: Field.listFrom(j['calc']),
        requisites: Field.listFrom(j['requisites']),
        paid: j['paid'] as bool? ?? false,
        autopay: j['autopay'] as bool? ?? false,
      );

  /// Новый номер лицевого счёта и объект — при правке в профиле.
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
  });

  final String id, title, subtitle, cat, categoryId, accountLabel, accountHint;
  final List<Field> requisites;
  final double? fixedAmount;
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
}

/// Как давно обновлялись начисления по подключённому счёту.
enum AccountSyncStatus { ok, syncing, failed }

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
    this.status = AccountSyncStatus.ok,
    this.syncedAt,
    this.lastError,
  });

  final String id, providerId, title, subtitle, cat, accountNo, objectId, holder, address;
  final DateTime connectedAt;
  final AccountSyncStatus status;
  final DateTime? syncedAt;
  final String? lastError;

  /// [clearError] — явно стереть прошлую ошибку (после удачного обновления).
  ConnectedAccount copyWith({
    String? objectId,
    AccountSyncStatus? status,
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
        status: status ?? this.status,
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
        'status': status.name,
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
