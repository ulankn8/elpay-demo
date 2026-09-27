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
}

/// Строка расшифровки или реквизитов: подпись — значение.
@immutable
class Field {
  const Field(this.label, this.value);
  final String label, value;
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
