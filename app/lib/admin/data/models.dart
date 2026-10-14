/// Модели кабинета служб. Чистый Dart: ни Flutter, ни Riverpod — их
/// разбирают и собирают тесты без виджетов.
library;

/// Служба, подключённая к ЭлPay: водоканал, электросеть, садик…
enum OrgStatus { active, onboarding }

class Org {
  const Org({
    required this.id,
    required this.name,
    required this.service,
    required this.cat,
    this.legalName = '',
    this.inn = '',
    this.bank = '',
    this.account = '',
    this.bik = '',
    this.contract = '',
    this.commission = '',
    this.status = OrgStatus.active,
    this.onboardingStep = 5,
    this.subscribers = 0,
    this.inAppShare = 0,
    this.paidShare = 0,
    this.lastImport = '',
    this.emailDomain = '',
  });

  final String id, name, service, cat, legalName, inn, bank, account, bik;
  final String contract, commission, lastImport, emailDomain;
  final OrgStatus status;

  /// Сколько шагов подключения из пяти пройдено.
  final int onboardingStep;

  /// Сводка для админа ЭлPay. У демо-службы (Ошводоканал) считается по
  /// реестру, у остальных служб пилота — витринные значения.
  final int subscribers;
  final double inAppShare, paidShare;

  Org copyWith({
    String? name,
    String? service,
    String? cat,
    String? legalName,
    String? inn,
    String? bank,
    String? account,
    String? bik,
    String? contract,
    String? commission,
    OrgStatus? status,
    int? onboardingStep,
    String? emailDomain,
  }) =>
      Org(
        id: id,
        name: name ?? this.name,
        service: service ?? this.service,
        cat: cat ?? this.cat,
        legalName: legalName ?? this.legalName,
        inn: inn ?? this.inn,
        bank: bank ?? this.bank,
        account: account ?? this.account,
        bik: bik ?? this.bik,
        contract: contract ?? this.contract,
        commission: commission ?? this.commission,
        status: status ?? this.status,
        onboardingStep: onboardingStep ?? this.onboardingStep,
        subscribers: subscribers,
        inAppShare: inAppShare,
        paidShare: paidShare,
        lastImport: lastImport,
        emailDomain: emailDomain ?? this.emailDomain,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'service': service,
        'cat': cat,
        'legalName': legalName,
        'inn': inn,
        'bank': bank,
        'account': account,
        'bik': bik,
        'contract': contract,
        'commission': commission,
        'status': status.name,
        'onboardingStep': onboardingStep,
        'subscribers': subscribers,
        'inAppShare': inAppShare,
        'paidShare': paidShare,
        'lastImport': lastImport,
        'emailDomain': emailDomain,
      };

  static Org fromJson(Map<String, dynamic> j) => Org(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        service: j['service'] as String? ?? '',
        cat: j['cat'] as String? ?? 'city',
        legalName: j['legalName'] as String? ?? '',
        inn: j['inn'] as String? ?? '',
        bank: j['bank'] as String? ?? '',
        account: j['account'] as String? ?? '',
        bik: j['bik'] as String? ?? '',
        contract: j['contract'] as String? ?? '',
        commission: j['commission'] as String? ?? '',
        status: OrgStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => OrgStatus.active),
        onboardingStep: (j['onboardingStep'] as num?)?.toInt() ?? 5,
        subscribers: (j['subscribers'] as num?)?.toInt() ?? 0,
        inAppShare: (j['inAppShare'] as num?)?.toDouble() ?? 0,
        paidShare: (j['paidShare'] as num?)?.toDouble() ?? 0,
        lastImport: j['lastImport'] as String? ?? '',
        emailDomain: j['emailDomain'] as String? ?? '',
      );
}

/// Сотрудник службы или администратор ЭлPay.
enum Role { staff, admin }

class Staff {
  const Staff({
    required this.id,
    required this.orgId,
    required this.name,
    required this.email,
    required this.invitedAt,
    this.lastLoginAt,
    this.device = '',
    this.role = Role.staff,
  });

  final String id, orgId, name, email, device;
  final DateTime invitedAt;
  final DateTime? lastLoginAt;
  final Role role;

  /// Приглашён, но ещё ни разу не входил.
  bool get pending => lastLoginAt == null;

  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  Staff copyWith({DateTime? lastLoginAt, String? device}) => Staff(
        id: id,
        orgId: orgId,
        name: name,
        email: email,
        invitedAt: invitedAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        device: device ?? this.device,
        role: role,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'name': name,
        'email': email,
        'invitedAt': invitedAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'device': device,
        'role': role.name,
      };

  static Staff fromJson(Map<String, dynamic> j) => Staff(
        id: j['id'] as String,
        orgId: j['orgId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        invitedAt: DateTime.tryParse(j['invitedAt'] as String? ?? '') ?? DateTime(2026),
        lastLoginAt: DateTime.tryParse(j['lastLoginAt'] as String? ?? ''),
        device: j['device'] as String? ?? '',
        role: Role.values.firstWhere((r) => r.name == j['role'], orElse: () => Role.staff),
      );
}

/// Абонент службы: один лицевой счёт.
class Subscriber {
  const Subscriber({
    required this.account,
    required this.name,
    required this.street,
    required this.house,
    this.flat = '',
    this.residents = 1,
    this.phone = '',
    this.inAppSince,
    this.meter = false,
    this.active = true,
    this.note = '',
    this.createdAt,
  });

  /// Лицевой счёт: 31-00562.
  final String account;
  final String name, street, house, flat, phone, note;

  /// Сколько человек прописано — по ним считается начисление по норме.
  final int residents;

  /// Когда житель подключил этот счёт в приложении ЭлPay; null — не подключал.
  final DateTime? inAppSince;

  /// Начисление по счётчику, а не по норме на человека.
  final bool meter;

  /// Отключённый абонент остаётся в истории, но новых начислений не получает.
  final bool active;

  final DateTime? createdAt;

  bool get inApp => inAppSince != null;

  /// «ул. Курманжан Датка, 212, кв. 14»
  String get address => [
        street,
        house,
        if (flat.isNotEmpty) 'кв. $flat',
      ].where((p) => p.isNotEmpty).join(', ');

  Subscriber copyWith({
    String? name,
    String? street,
    String? house,
    String? flat,
    int? residents,
    String? phone,
    bool? active,
    String? note,
  }) =>
      Subscriber(
        account: account,
        name: name ?? this.name,
        street: street ?? this.street,
        house: house ?? this.house,
        flat: flat ?? this.flat,
        residents: residents ?? this.residents,
        phone: phone ?? this.phone,
        inAppSince: inAppSince,
        meter: meter,
        active: active ?? this.active,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  /// Те же данные из файла или формы? Сравниваем только то, что приходит
  /// из 1С: подключение в приложении и дата заведения — не её поля.
  bool sameDataAs(Subscriber o) =>
      name == o.name &&
      street == o.street &&
      house == o.house &&
      flat == o.flat &&
      residents == o.residents &&
      phone == o.phone;

  Map<String, dynamic> toJson() => {
        'a': account,
        'n': name,
        's': street,
        'h': house,
        if (flat.isNotEmpty) 'f': flat,
        'r': residents,
        if (phone.isNotEmpty) 'p': phone,
        if (inAppSince != null) 'app': inAppSince!.toIso8601String(),
        if (meter) 'm': true,
        if (!active) 'off': true,
        if (note.isNotEmpty) 'note': note,
        if (createdAt != null) 'c': createdAt!.toIso8601String(),
      };

  static Subscriber fromJson(Map<String, dynamic> j) => Subscriber(
        account: j['a'] as String,
        name: j['n'] as String? ?? '',
        street: j['s'] as String? ?? '',
        house: j['h'] as String? ?? '',
        flat: j['f'] as String? ?? '',
        residents: (j['r'] as num?)?.toInt() ?? 1,
        phone: j['p'] as String? ?? '',
        inAppSince: DateTime.tryParse(j['app'] as String? ?? ''),
        meter: j['m'] as bool? ?? false,
        active: !(j['off'] as bool? ?? false),
        note: j['note'] as String? ?? '',
        createdAt: DateTime.tryParse(j['c'] as String? ?? ''),
      );
}

/// Период начисления: «2026-09».
class Period implements Comparable<Period> {
  const Period(this.year, this.month);

  factory Period.parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(s.trim());
    if (m == null) throw FormatException('период не разобран: $s');
    return Period(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  factory Period.of(DateTime d) => Period(d.year, d.month);

  final int year, month;

  Period get next => month == 12 ? Period(year + 1, 1) : Period(year, month + 1);
  Period get prev => month == 1 ? Period(year - 1, 12) : Period(year, month - 1);

  /// Срок оплаты: 25-е число следующего месяца.
  DateTime get due => DateTime(next.year, next.month, 25);

  String get key => '$year-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(Period other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) => other is Period && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// Начисление одному абоненту за период.
class Charge {
  const Charge({
    required this.account,
    required this.period,
    required this.amount,
    this.calc = '',
  });

  final String account;
  final Period period;
  final double amount;

  /// Как посчитано: «5 чел × 41 сом», «по счётчику 9 м³».
  final String calc;

  Map<String, dynamic> toJson() => {'a': account, 'p': period.key, 's': amount, if (calc.isNotEmpty) 'c': calc};

  static Charge fromJson(Map<String, dynamic> j) => Charge(
        account: j['a'] as String,
        period: Period.parse(j['p'] as String),
        amount: (j['s'] as num).toDouble(),
        calc: j['c'] as String? ?? '',
      );
}

/// Как пришли деньги.
enum Channel { elpay, cashier, bank }

/// Платёж от жителя.
class Payment {
  const Payment({
    required this.id,
    required this.account,
    required this.amount,
    required this.at,
    required this.period,
    required this.channel,
    required this.method,
    required this.receipt,
  });

  final String id, account, method, receipt;
  final double amount;
  final DateTime at;
  final Period period;
  final Channel channel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'a': account,
        's': amount,
        't': at.toIso8601String(),
        'p': period.key,
        'ch': channel.name,
        'm': method,
        'r': receipt,
      };

  static Payment fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        account: j['a'] as String,
        amount: (j['s'] as num).toDouble(),
        at: DateTime.parse(j['t'] as String),
        period: Period.parse(j['p'] as String),
        channel: Channel.values.firstWhere((c) => c.name == j['ch'], orElse: () => Channel.elpay),
        method: j['m'] as String? ?? '',
        receipt: j['r'] as String? ?? '',
      );
}

/// Статус оплаты абонента за период — то, ради чего служба открывает кабинет.
enum PayStatus { paid, partial, unpaid, noCharge }

/// Сводка по абоненту за открытый период.
class SubscriberView {
  const SubscriberView({
    required this.sub,
    required this.charged,
    required this.paid,
    required this.status,
    required this.debt,
    this.lastPayment,
  });

  final Subscriber sub;

  /// Начислено и оплачено за открытый период.
  final double charged, paid;
  final PayStatus status;

  /// Долг прошлых периодов.
  final double debt;
  final Payment? lastPayment;

  double get leftToPay => (charged - paid).clamp(0, double.infinity).toDouble();
  bool get hasDebt => debt > 0.009;
}

/// Что загружаем файлом.
enum ImportKind { subscribers, charges }

enum ImportStatus { applied, rolledBack }

/// Запись журнала импортов.
class ImportJob {
  const ImportJob({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.at,
    required this.by,
    required this.rows,
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.errors,
    this.status = ImportStatus.applied,
    this.period,
    this.total = 0,
    this.undo = const {},
    this.createdAccounts = const [],
    this.replacedCharges,
  });

  final String id, fileName, by;
  final ImportKind kind;
  final DateTime at;
  final int rows, created, updated, unchanged, errors;
  final ImportStatus status;

  /// Для начислений: за какой период и на какую сумму.
  final Period? period;
  final double total;

  /// Чем откатывать: прежние данные обновлённых абонентов и список заведённых.
  final Map<String, Subscriber> undo;
  final List<String> createdAccounts;

  /// Для начислений: что лежало за этот период до загрузки (null — ничего).
  final List<Charge>? replacedCharges;

  /// Откатить можно сутки и только применённый импорт.
  bool canRollback(DateTime now) =>
      status == ImportStatus.applied && now.difference(at) < const Duration(hours: 24);

  ImportJob copyWith({ImportStatus? status}) => ImportJob(
        id: id,
        kind: kind,
        fileName: fileName,
        at: at,
        by: by,
        rows: rows,
        created: created,
        updated: updated,
        unchanged: unchanged,
        errors: errors,
        status: status ?? this.status,
        period: period,
        total: total,
        undo: undo,
        createdAccounts: createdAccounts,
        replacedCharges: replacedCharges,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'file': fileName,
        'at': at.toIso8601String(),
        'by': by,
        'rows': rows,
        'created': created,
        'updated': updated,
        'unchanged': unchanged,
        'errors': errors,
        'status': status.name,
        if (period != null) 'period': period!.key,
        'total': total,
        if (undo.isNotEmpty) 'undo': {for (final e in undo.entries) e.key: e.value.toJson()},
        if (createdAccounts.isNotEmpty) 'createdAccounts': createdAccounts,
        if (replacedCharges != null) 'replaced': [for (final c in replacedCharges!) c.toJson()],
      };

  static ImportJob fromJson(Map<String, dynamic> j) => ImportJob(
        id: j['id'] as String,
        kind: ImportKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => ImportKind.subscribers),
        fileName: j['file'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        by: j['by'] as String? ?? '',
        rows: (j['rows'] as num?)?.toInt() ?? 0,
        created: (j['created'] as num?)?.toInt() ?? 0,
        updated: (j['updated'] as num?)?.toInt() ?? 0,
        unchanged: (j['unchanged'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        status: ImportStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ImportStatus.applied),
        period: j['period'] == null ? null : Period.parse(j['period'] as String),
        total: (j['total'] as num?)?.toDouble() ?? 0,
        undo: {
          for (final e in ((j['undo'] as Map?)?.cast<String, dynamic>() ?? const {}).entries)
            e.key: Subscriber.fromJson((e.value as Map).cast<String, dynamic>()),
        },
        createdAccounts: [for (final a in (j['createdAccounts'] as List? ?? const [])) '$a'],
        replacedCharges: j['replaced'] == null
            ? null
            : [for (final c in j['replaced'] as List) Charge.fromJson((c as Map).cast<String, dynamic>())],
      );
}

/// Выгрузка реестра платежей в 1С.
class ExportBatch {
  const ExportBatch({
    required this.id,
    required this.at,
    required this.until,
    required this.count,
    required this.total,
    required this.fileName,
    required this.by,
  });

  final String id, fileName, by;
  final DateTime at;

  /// Все платежи до этого момента включительно попали в реестр.
  final DateTime until;
  final int count;
  final double total;

  bool get auto => by == 'автовыгрузка';

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'until': until.toIso8601String(),
        'count': count,
        'total': total,
        'file': fileName,
        'by': by,
      };

  static ExportBatch fromJson(Map<String, dynamic> j) => ExportBatch(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        until: DateTime.parse(j['until'] as String),
        count: (j['count'] as num).toInt(),
        total: (j['total'] as num).toDouble(),
        fileName: j['file'] as String? ?? '',
        by: j['by'] as String? ?? '',
      );
}

/// Кому рассылаем напоминание.
enum Segment { unpaid, debt, partial }

/// Рассылка должникам.
class Campaign {
  const Campaign({
    required this.id,
    required this.at,
    required this.sendAt,
    required this.segment,
    required this.template,
    required this.text,
    required this.push,
    required this.sms,
    required this.by,
    this.paidAfter,
    this.accounts = const [],
  });

  final String id, template, text, by;

  /// Адресная рассылка — выбранным в таблице. Пусто — весь сегмент.
  final List<String> accounts;
  final DateTime at, sendAt;
  final Segment segment;
  final int push, sms;

  /// Сколько получателей оплатили после рассылки (известно у прошедших).
  final int? paidAfter;

  int get recipients => push + sms;
  double get cost => sms * smsPrice;

  static const smsPrice = 1.2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'sendAt': sendAt.toIso8601String(),
        'segment': segment.name,
        'template': template,
        'text': text,
        'push': push,
        'sms': sms,
        'by': by,
        if (paidAfter != null) 'paidAfter': paidAfter,
        if (accounts.isNotEmpty) 'accounts': accounts,
      };

  static Campaign fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        sendAt: DateTime.parse(j['sendAt'] as String),
        segment: Segment.values.firstWhere((s) => s.name == j['segment'], orElse: () => Segment.unpaid),
        template: j['template'] as String? ?? '',
        text: j['text'] as String? ?? '',
        push: (j['push'] as num?)?.toInt() ?? 0,
        sms: (j['sms'] as num?)?.toInt() ?? 0,
        by: j['by'] as String? ?? '',
        paidAfter: (j['paidAfter'] as num?)?.toInt(),
        accounts: [for (final a in (j['accounts'] as List? ?? const [])) '$a'],
      );
}

/// Запись журнала действий: кто что сделал в кабинете.
class AuditEntry {
  const AuditEntry({required this.at, required this.who, required this.action, this.orgId = ''});

  final DateTime at;
  final String who, action, orgId;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'who': who, 'what': action, 'org': orgId};

  static AuditEntry fromJson(Map<String, dynamic> j) => AuditEntry(
        at: DateTime.parse(j['at'] as String),
        who: j['who'] as String? ?? '',
        action: j['what'] as String? ?? '',
        orgId: j['org'] as String? ?? '',
      );
}

/// Платёж, который пришёл, а лицевой не нашёлся.
enum UnmatchedState { open, bound, refunded }

class Unmatched {
  const Unmatched({
    required this.id,
    required this.orgId,
    required this.entered,
    required this.amount,
    required this.at,
    required this.method,
    required this.receipt,
    this.payerPhone = '',
    this.state = UnmatchedState.open,
    this.boundTo = '',
    this.closedNote = '',
  });

  final String id, orgId, entered, method, receipt, payerPhone, boundTo, closedNote;
  final double amount;
  final DateTime at;
  final UnmatchedState state;

  /// На разбор — три рабочих дня от поступления.
  DateTime get deadline {
    var d = at;
    var left = 3;
    while (left > 0) {
      d = d.add(const Duration(days: 1));
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) left--;
    }
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  Unmatched copyWith({UnmatchedState? state, String? boundTo, String? closedNote}) => Unmatched(
        id: id,
        orgId: orgId,
        entered: entered,
        amount: amount,
        at: at,
        method: method,
        receipt: receipt,
        payerPhone: payerPhone,
        state: state ?? this.state,
        boundTo: boundTo ?? this.boundTo,
        closedNote: closedNote ?? this.closedNote,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'org': orgId,
        'entered': entered,
        's': amount,
        't': at.toIso8601String(),
        'm': method,
        'r': receipt,
        'phone': payerPhone,
        'state': state.name,
        'to': boundTo,
        'note': closedNote,
      };

  static Unmatched fromJson(Map<String, dynamic> j) => Unmatched(
        id: j['id'] as String,
        orgId: j['org'] as String? ?? '',
        entered: j['entered'] as String? ?? '',
        amount: (j['s'] as num).toDouble(),
        at: DateTime.parse(j['t'] as String),
        method: j['m'] as String? ?? '',
        receipt: j['r'] as String? ?? '',
        payerPhone: j['phone'] as String? ?? '',
        state: UnmatchedState.values.firstWhere((s) => s.name == j['state'], orElse: () => UnmatchedState.open),
        boundTo: j['to'] as String? ?? '',
        closedNote: j['note'] as String? ?? '',
      );
}
