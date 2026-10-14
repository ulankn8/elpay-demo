/// Хранилище кабинета служб.
///
/// Реестр Ошводоканала (12 480 абонентов, начисления, платежи) каждый раз
/// заново собирает детерминированный генератор, а в браузере хранится
/// только то, что сделали в кабинете: правки и новые абоненты, загрузки,
/// выгрузки, рассылки, приглашения, разбор платежей. Так localStorage не
/// упирается в свои 5 МБ, а после перезагрузки страницы всё на месте.
///
/// Это демо-источник. Боевой заменит его на HTTP-клиент кабинета с теми же
/// методами — экраны работают с этим классом через состояние, а не напрямую.
library;

import '../../core/cache/local_store.dart';
import '../../core/clock.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../core/result.dart';
import 'fixtures.dart';
import 'import_engine.dart';
import 'mapping.dart';
import 'models.dart';
import 'registry.dart';
import 'seed.dart';

abstract final class AdminKeys {
  static const anchor = 'adm.anchor';
  static const session = 'adm.session';
  static const subs = 'adm.subs';
  static const charges = 'adm.charges';
  static const adjust = 'adm.adjust';
  static const imports = 'adm.imports';
  static const exports = 'adm.exports';
  static const autoExport = 'adm.autoExport';
  static const campaigns = 'adm.campaigns';
  static const audit = 'adm.audit';
  static const staff = 'adm.staff';
  static const orgs = 'adm.orgs';
  static const unmatched = 'adm.unmatched';
  static const extraPayments = 'adm.payments';
  static const templates = 'adm.templates';
  static const removedStaff = 'adm.staff.removed';

  /// Всё, что меняет пользователь. Сессия сюда не входит: сброс демо
  /// не выкидывает из кабинета.
  static const userData = [
    anchor, subs, charges, adjust, imports, exports, autoExport, campaigns, //
    audit, staff, orgs, unmatched, extraPayments, templates, removedStaff,
  ];
}

/// Строка истории абонента: начисление за месяц и как оно оплачено.
class HistoryRow {
  const HistoryRow({required this.period, required this.charged, required this.paid, this.paidAt, this.how = ''});
  final Period period;
  final double charged, paid;
  final DateTime? paidAt;
  final String how;
}

/// Сводка за период — для экрана начислений.
class PeriodSummary {
  const PeriodSummary({
    required this.period,
    required this.charged,
    required this.paid,
    required this.count,
    required this.open,
    this.job,
  });
  final Period period;
  final double charged, paid;
  final int count;
  final bool open;
  final ImportJob? job;
  double get share => charged == 0 ? 0 : paid / charged;
}

/// Итоги открытого периода — для обзора.
class Dashboard {
  const Dashboard({
    required this.period,
    required this.subscribers,
    required this.charged,
    required this.paid,
    required this.paidFull,
    required this.partial,
    required this.unpaid,
    required this.inApp,
    required this.byChannel,
    required this.byDay,
    required this.debtors,
    required this.debt,
    required this.inAppPaidRate,
    required this.otherPaidRate,
  });
  final Period period;

  /// Доля оплативших (полностью или частично) среди подключённых в
  /// приложении и среди остальных — главный довод для служб.
  final double inAppPaidRate, otherPaidRate;
  final int subscribers, paidFull, partial, unpaid, inApp, debtors;
  final double charged, paid, debt;
  final Map<Channel, double> byChannel;

  /// Поступления по дням месяца, когда пришли деньги.
  final Map<DateTime, double> byDay;
}

enum SubFilter { all, paid, partial, unpaid, debt, inApp, notInApp, fresh }

/// Журнал пишется по-человечески: «1 567», «269 808 сом», без «.00».
String _n(num v) => som(v);
String _money(double v) => som(v);

class AdminStore {
  AdminStore({required this.store, Clock? clock, SeedData? seed})
      : _realClock = clock ?? systemClock,
        _seed = seed ?? generateSeed() {
    _load();
  }

  final LocalStore store;
  final Clock _realClock;
  final SeedData _seed;

  /// Растёт при каждой правке — состояние по нему понимает, что пересчитать.
  int revision = 0;

  // ───────────────────────── время ─────────────────────────

  late DateTime _anchor;

  /// Время кабинета: демо-реестр живёт «14 октября 2026, 12:00», дальше
  /// часы идут вместе с настоящими — порядок событий не ломается, даже
  /// если демо открыли через месяц.
  DateTime now() {
    final passed = _realClock().difference(_anchor);
    return seedNow.add(passed.isNegative ? Duration.zero : passed);
  }

  // ───────────────────────── состояние ─────────────────────────

  late Map<String, Subscriber> _subs;
  final Map<String, Subscriber> _edits = {};
  final Map<Period, Map<String, double>> _loadedCharges = {};
  final Map<String, double> _adjust = {};
  final List<ImportJob> _imports = [];
  final List<ExportBatch> _exports = [];
  final List<Campaign> _campaigns = [];
  final List<AuditEntry> _audit = [];
  final Map<String, Staff> _staff = {};
  final Map<String, Org> _orgs = {};
  final Map<String, Unmatched> _unmatched = {};
  final List<Payment> _extraPayments = [];
  final Map<ImportKind, Map<String, Field>> _templates = {};
  bool _autoExport = true;
  Staff? _session;

  void _load() {
    final a = store.readMap(AdminKeys.anchor);
    _anchor = DateTime.tryParse(a?['at'] as String? ?? '') ?? _realClock();
    if (a == null) store.writeJson(AdminKeys.anchor, {'at': _anchor.toIso8601String()}, now: _anchor);

    _subs = {for (final s in _seed.subscribers) s.account: s};
    for (final e in (store.readMap(AdminKeys.subs) ?? const {}).entries) {
      final s = Subscriber.fromJson((e.value as Map).cast<String, dynamic>());
      _edits[e.key] = s;
      _subs[e.key] = s;
    }
    for (final e in (store.readMap(AdminKeys.charges) ?? const {}).entries) {
      _loadedCharges[Period.parse(e.key)] = {
        for (final c in ((e.value as Map).cast<String, dynamic>()).entries) c.key: (c.value as num).toDouble(),
      };
    }
    for (final e in (store.readMap(AdminKeys.adjust) ?? const {}).entries) {
      _adjust[e.key] = (e.value as num).toDouble();
    }
    _imports.addAll((store.readList(AdminKeys.imports) ?? const []).map(ImportJob.fromJson));
    _exports.addAll((store.readList(AdminKeys.exports) ?? const []).map(ExportBatch.fromJson));
    _campaigns.addAll((store.readList(AdminKeys.campaigns) ?? const []).map(Campaign.fromJson));
    _audit.addAll((store.readList(AdminKeys.audit) ?? const []).map(AuditEntry.fromJson));
    for (final s in pilotStaff) {
      _staff[s.id] = s;
    }
    for (final s in (store.readList(AdminKeys.staff) ?? const []).map(Staff.fromJson)) {
      _staff[s.id] = s;
    }
    for (final id in (store.readMap(AdminKeys.removedStaff)?['ids'] as List? ?? const [])) {
      _staff.remove('$id');
    }
    for (final o in pilotOrgs) {
      _orgs[o.id] = o;
    }
    for (final o in (store.readList(AdminKeys.orgs) ?? const []).map(Org.fromJson)) {
      _orgs[o.id] = o;
    }
    for (final u in seedUnmatched) {
      _unmatched[u.id] = u;
    }
    for (final u in (store.readList(AdminKeys.unmatched) ?? const []).map(Unmatched.fromJson)) {
      _unmatched[u.id] = u;
    }
    _extraPayments.addAll((store.readList(AdminKeys.extraPayments) ?? const []).map(Payment.fromJson));
    _templates[ImportKind.subscribers] = Map.of(seedTemplate);
    final tpl = store.readMap(AdminKeys.templates);
    if (tpl != null) {
      for (final k in ImportKind.values) {
        final m = (tpl[k.name] as Map?)?.cast<String, dynamic>();
        if (m == null) continue;
        _templates[k] = {
          for (final e in m.entries) e.key: Field.values.firstWhere((f) => f.name == e.value, orElse: () => Field.skip),
        };
      }
    }
    _autoExport = store.readMap(AdminKeys.autoExport)?['on'] as bool? ?? true;
    final sid = store.readMap(AdminKeys.session)?['id'] as String?;
    _session = sid == null ? null : _staff[sid];
  }

  /// Возвращает демо к исходным цифрам: всё, что загрузили и поменяли,
  /// стирается, часы снова идут с 14 октября 12:00. Кто вошёл — остаётся.
  Future<void> resetDemo() async {
    final who = _session?.id;
    for (final k in AdminKeys.userData) {
      await store.remove(k);
    }
    _edits.clear();
    _loadedCharges.clear();
    _adjust.clear();
    _imports.clear();
    _exports.clear();
    _campaigns.clear();
    _audit.clear();
    _staff.clear();
    _orgs.clear();
    _unmatched.clear();
    _extraPayments.clear();
    _templates.clear();
    _load();
    _session = who == null ? null : _staff[who];
    await _touch();
  }

  Future<void> _save(String key, Object value) => store.writeJson(key, value, now: _realClock());

  Future<void> _touch() async {
    revision++;
    _views = null;
  }

  Future<void> _log(String action, {String? orgId}) async {
    _audit.insert(0, AuditEntry(at: now(), who: _session?.name ?? 'Система', action: action, orgId: orgId ?? _session?.orgId ?? ovkId));
    await _save(AdminKeys.audit, [for (final a in _audit.take(500)) a.toJson()]);
  }

  // ───────────────────────── вход ─────────────────────────

  Staff? get session => _session;
  bool get isAdmin => _session?.role == Role.admin;

  Staff? staffByEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final s in _staff.values) {
      if (s.email.toLowerCase() == e) return s;
    }
    return null;
  }

  /// Шаг 1 входа: есть ли доступ у этой почты. Код в демо всегда 4815.
  Result<Staff> requestCode(String email) {
    final s = staffByEmail(email);
    if (s == null) {
      return const Fail(AppFailure(FailureKind.auth,
          message: 'У этой почты нет доступа к кабинету. Доступ выдаёт менеджер ЭлPay.', field: 'email'));
    }
    return Ok(s);
  }

  Future<Result<Staff>> signIn(String email, String code) async {
    final s = staffByEmail(email);
    if (s == null) return const Fail(AppFailure(FailureKind.auth, message: 'Нет доступа', field: 'email'));
    if (code.trim() != demoCode) {
      return const Fail(AppFailure(FailureKind.validation, message: 'Код не подошёл — проверьте письмо', field: 'code'));
    }
    final signed = s.copyWith(lastLoginAt: now(), device: 'Браузер');
    _staff[s.id] = signed;
    _session = signed;
    await _saveStaff();
    await _save(AdminKeys.session, {'id': s.id});
    await _log(s.pending ? 'Первый вход в кабинет' : 'Вход в кабинет', orgId: s.orgId);
    await _touch();
    return Ok(signed);
  }

  Future<void> signOut() async {
    _session = null;
    await store.remove(AdminKeys.session);
    await _touch();
  }

  Future<void> _saveStaff() => _save(AdminKeys.staff, [for (final s in _staff.values) s.toJson()]);

  // ───────────────────────── службы и сотрудники ─────────────────────────

  List<Org> get orgs => _orgs.values.toList();
  Org org(String id) => _orgs[id] ?? pilotOrgs.first;
  Org get demoOrg => org(ovkId);

  List<Staff> staffOf(String orgId) => [for (final s in _staff.values) if (s.orgId == orgId) s];

  Future<Result<Staff>> invite({required String orgId, required String name, required String email}) async {
    final o = org(orgId);
    final e = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      return const Fail(AppFailure.validation('Проверьте адрес почты', field: 'email'));
    }
    if (o.emailDomain.isNotEmpty && !e.endsWith('@${o.emailDomain}')) {
      return Fail(AppFailure.validation('Только рабочая почта @${o.emailDomain}', field: 'email'));
    }
    if (staffByEmail(e) != null) return const Fail(AppFailure.validation('У этой почты уже есть доступ', field: 'email'));
    if (name.trim().isEmpty) return const Fail(AppFailure.validation('Укажите имя сотрудника', field: 'name'));
    final s = Staff(id: 'st-${now().microsecondsSinceEpoch}', orgId: orgId, name: normalizeName(name), email: e, invitedAt: now());
    _staff[s.id] = s;
    await _saveStaff();
    await _log('Приглашение сотрудника $e', orgId: orgId);
    await _touch();
    return Ok(s);
  }

  Future<Result<void>> removeStaff(String id) async {
    final s = _staff[id];
    if (s == null) return const Fail(AppFailure.notFound());
    if (s.id == _session?.id) return const Fail(AppFailure.validation('Себя удалить нельзя — попросите коллегу'));
    _staff.remove(id);
    final removed = [...(store.readMap(AdminKeys.removedStaff)?['ids'] as List? ?? const []), id];
    await _save(AdminKeys.removedStaff, {'ids': removed});
    await _saveStaff();
    await _log('Доступ закрыт: ${s.email}', orgId: s.orgId);
    await _touch();
    return const Ok(null);
  }

  Future<Org> saveOrg(Org o, {String? logAction}) async {
    _orgs[o.id] = o;
    await _save(AdminKeys.orgs, [for (final x in _orgs.values) x.toJson()]);
    if (logAction != null) await _log(logAction, orgId: o.id);
    await _touch();
    return o;
  }

  List<AuditEntry> audit({String? orgId}) => [
        for (final a in [..._audit, ...seedAudit]..sort((x, y) => y.at.compareTo(x.at)))
          if (orgId == null || a.orgId == orgId) a,
      ];

  // ───────────────────────── абоненты ─────────────────────────

  Map<String, Subscriber> get subscribers => _subs;
  Subscriber? subscriber(String account) => _subs[account];

  /// Открытый период — последний, за который загружены начисления.
  Period get openPeriod {
    var p = const Period(2026, 9);
    for (final k in _loadedCharges.keys) {
      if (k.compareTo(p) > 0) p = k;
    }
    return p;
  }

  /// Начисление абонента за период.
  double chargeOf(String account, Period p) {
    final adj = _adjust['$account|${p.key}'];
    if (adj != null) return adj;
    final loaded = _loadedCharges[p];
    if (loaded != null) return loaded[account] ?? 0;
    if (p == const Period(2026, 9)) return _seed.septCharges[account] ?? 0;
    if (p.compareTo(const Period(2026, 4)) >= 0 && p.compareTo(const Period(2026, 8)) <= 0) {
      final s = _subs[account];
      if (s?.createdAt != null && s!.createdAt!.isAfter(DateTime(p.year, p.month + 1, 1))) return 0;
      return _seed.priorCharge(account, p);
    }
    return 0;
  }

  List<Payment> get payments {
    final all = [..._seed.payments, ..._extraPayments];
    all.sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  Map<String, List<Payment>>? _byAccount;
  Map<String, List<Payment>> get _paymentsByAccount {
    if (_byAccount != null && _byAccountRev == revision) return _byAccount!;
    final m = <String, List<Payment>>{};
    for (final p in payments) {
      (m[p.account] ??= []).add(p);
    }
    _byAccountRev = revision;
    return _byAccount = m;
  }

  int _byAccountRev = -1;

  double paidFor(String account, Period p) {
    var s = 0.0;
    for (final x in _paymentsByAccount[account] ?? const <Payment>[]) {
      if (x.period == p) s += x.amount;
    }
    if (p.compareTo(const Period(2026, 9)) < 0) {
      // Апрель–август: оплачено всё, кроме долга.
      final d = _seed.debts[account];
      final charge = chargeOf(account, p);
      if (d == null || !d.periods.contains(p)) return charge;
      return d.periods.last == p ? d.paidOnOldest : 0;
    }
    return s;
  }

  /// Долг за все закрытые периоды до открытого.
  double debtOf(String account) {
    final open = openPeriod;
    var debt = 0.0;
    final d = _seed.debts[account];
    if (d != null) {
      for (final p in d.periods) {
        debt += chargeOf(account, p) - (d.periods.last == p ? d.paidOnOldest : 0);
      }
    }
    // Месяцы между сентябрём и открытым периодом, если начисления уже грузили.
    for (var p = const Period(2026, 9); p.compareTo(open) < 0; p = p.next) {
      final left = chargeOf(account, p) - paidFor(account, p);
      if (left > 0.004) debt += left;
    }
    return debt;
  }

  List<SubscriberView>? _views;

  /// Сводка по всем абонентам за открытый период. Считается раз на правку.
  List<SubscriberView> views() {
    if (_views != null) return _views!;
    final p = openPeriod;
    final out = <SubscriberView>[];
    for (final s in _subs.values) {
      final charged = chargeOf(s.account, p);
      final pays = _paymentsByAccount[s.account] ?? const <Payment>[];
      var paid = 0.0;
      Payment? last;
      for (final x in pays) {
        if (x.period != p) continue;
        paid += x.amount;
        if (last == null || x.at.isAfter(last.at)) last = x;
      }
      final status = charged <= 0
          ? PayStatus.noCharge
          : paid >= charged - 0.004
              ? PayStatus.paid
              : paid > 0
                  ? PayStatus.partial
                  : PayStatus.unpaid;
      out.add(SubscriberView(sub: s, charged: charged, paid: paid, status: status, debt: debtOf(s.account), lastPayment: last));
    }
    out.sort((a, b) => a.sub.account.compareTo(b.sub.account));
    return _views = out;
  }

  Map<String, SubscriberView>? _viewIndex;
  int _viewIndexRev = -1;

  SubscriberView? view(String account) {
    if (_viewIndex == null || _viewIndexRev != revision) {
      _viewIndex = {for (final v in views()) v.sub.account: v};
      _viewIndexRev = revision;
    }
    return _viewIndex![account];
  }

  bool matches(SubscriberView v, SubFilter f) => switch (f) {
        SubFilter.all => true,
        SubFilter.paid => v.status == PayStatus.paid,
        SubFilter.partial => v.status == PayStatus.partial,
        SubFilter.unpaid => v.status == PayStatus.unpaid,
        SubFilter.debt => v.hasDebt,
        SubFilter.inApp => v.sub.inApp,
        SubFilter.notInApp => !v.sub.inApp,
        SubFilter.fresh => v.sub.createdAt != null && now().difference(v.sub.createdAt!).inDays < 30,
      };

  /// Поиск по лицевому, ФИО, адресу и телефону.
  List<SubscriberView> search({SubFilter filter = SubFilter.all, String query = ''}) {
    final q = query.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return [
      for (final v in views())
        if (matches(v, filter) &&
            (q.isEmpty ||
                v.sub.account.contains(q) ||
                v.sub.name.toLowerCase().contains(q) ||
                v.sub.address.toLowerCase().contains(q) ||
                (digits.length >= 4 && v.sub.phone.replaceAll(RegExp(r'\D'), '').contains(digits))))
          v,
    ];
  }

  Map<SubFilter, int> counts() => {for (final f in SubFilter.values) f: views().where((v) => matches(v, f)).length};

  List<HistoryRow> history(String account, {int months = 6}) {
    final rows = <HistoryRow>[];
    var p = openPeriod;
    for (var i = 0; i < months; i++, p = p.prev) {
      final charged = chargeOf(account, p);
      final paid = paidFor(account, p);
      DateTime? at;
      var how = '';
      final pays = [for (final x in _paymentsByAccount[account] ?? const <Payment>[]) if (x.period == p) x];
      if (pays.isNotEmpty) {
        at = pays.first.at;
        how = '${channelLabel(pays.first.channel)} · ${pays.first.method}';
      } else if (paid > 0) {
        // Прошлые месяцы демо: день и способ — устойчиво от лицевого.
        final h = stableHash('$account/${p.key}');
        at = DateTime(p.next.year, p.next.month, 3 + h % 20, 9 + h % 11, h % 60);
        final s = _subs[account];
        how = s?.inApp == true && s!.inAppSince!.isBefore(at) ? 'ЭлPay · ${h % 2 == 0 ? 'Visa' : 'Элкарт'}' : (h % 3 == 0 ? 'Банк · MBANK' : 'Касса службы');
      }
      if (charged > 0 || paid > 0) rows.add(HistoryRow(period: p, charged: charged, paid: paid, paidAt: at, how: how));
    }
    return rows;
  }

  List<AuditEntry> subscriberLog(String account) => [
        for (final a in audit(orgId: ovkId))
          if (a.action.contains(account)) a,
        if (account == '31-00562')
          AuditEntry(at: DateTime(2026, 10, 1, 9, 42), who: 'Жыпар Турсунова', action: 'Обновлён из импорта abonenty_2026-10-01.csv: жильцов 4 → 5'),
        if (account == '31-00562')
          AuditEntry(at: DateTime(2026, 9, 3, 19, 12), who: 'Житель', action: 'Подключила счёт в приложении ЭлPay'),
      ];

  /// Следующий свободный лицевой на участке: 31-02261.
  String nextFreeAccount([String district = '31']) {
    var max = 0;
    for (final a in _subs.keys) {
      if (!a.startsWith('$district-')) continue;
      final n = int.tryParse(a.substring(3)) ?? 0;
      if (n > max) max = n;
    }
    return '$district-${(max + 1).toString().padLeft(5, '0')}';
  }

  Future<Result<Subscriber>> saveSubscriber(Subscriber s, {required bool isNew}) async {
    final rule = AccountRule.water;
    final account = rule.normalize(s.account);
    if (!rule.pattern.hasMatch(account)) {
      return Fail(AppFailure.validation('Лицевой должен быть вида ${rule.example}', field: 'account'));
    }
    if (isNew && _subs.containsKey(account)) {
      return Fail(AppFailure.validation('Лицевой $account уже есть — ${_subs[account]!.name}', field: 'account'));
    }
    if (s.name.trim().isEmpty) return const Fail(AppFailure.validation('Укажите ФИО', field: 'name'));
    if (s.street.trim().isEmpty || s.house.trim().isEmpty) {
      return const Fail(AppFailure.validation('Укажите улицу и дом', field: 'street'));
    }
    if (s.residents < 0 || s.residents > 40) return const Fail(AppFailure.validation('Жильцов — от 0 до 40', field: 'residents'));
    final before = _subs[account];
    final next = Subscriber(
      account: account,
      name: normalizeName(s.name),
      street: s.street.trim(),
      house: s.house.trim(),
      flat: s.flat.trim(),
      residents: s.residents,
      phone: s.phone.isEmpty ? '' : (normalizePhone(s.phone).isEmpty ? s.phone : normalizePhone(s.phone)),
      inAppSince: before?.inAppSince,
      meter: before?.meter ?? false,
      active: s.active,
      note: s.note,
      createdAt: before?.createdAt ?? now(),
    );
    _subs[account] = next;
    _edits[account] = next;
    await _saveSubs();
    if (isNew) {
      await _log('Абонент $account добавлен вручную: ${next.name}, ${next.address}');
    } else if (before != null) {
      final what = [
        if (before.name != next.name) 'ФИО',
        if (before.address != next.address) 'адрес',
        if (before.residents != next.residents) 'жильцов ${before.residents} → ${next.residents}',
        if (before.phone != next.phone) 'телефон',
        if (before.active != next.active) next.active ? 'включён' : 'отключён',
      ];
      await _log('Абонент $account изменён: ${what.isEmpty ? 'без изменений' : what.join(', ')}');
    }
    await _touch();
    return Ok(next);
  }

  Future<void> _saveSubs() => _save(AdminKeys.subs, {for (final e in _edits.entries) e.key: e.value.toJson()});

  // ───────────────────────── начисления ─────────────────────────

  List<PeriodSummary>? _periodsCache;
  int _periodsRev = -1;

  List<PeriodSummary> periods() {
    if (_periodsCache != null && _periodsRev == revision) return _periodsCache!;
    _periodsRev = revision;
    return _periodsCache = _buildPeriods();
  }

  List<PeriodSummary> _buildPeriods() {
    final open = openPeriod;
    final list = <PeriodSummary>[];
    for (var p = open; p.compareTo(const Period(2026, 6)) >= 0; p = p.prev) {
      var charged = 0.0, paid = 0.0;
      var n = 0;
      for (final a in _subs.keys) {
        final c = chargeOf(a, p);
        if (c <= 0) continue;
        n++;
        charged += c;
        paid += paidFor(a, p).clamp(0, c);
      }
      ImportJob? job;
      for (final j in [..._imports, ...seedImports]) {
        if (j.kind == ImportKind.charges && j.period == p && j.status == ImportStatus.applied) {
          job = j;
          break;
        }
      }
      list.add(PeriodSummary(period: p, charged: charged, paid: paid, count: n, open: p == open, job: job));
    }
    return list;
  }

  Future<Result<void>> adjustCharge(String account, Period p, double amount, String reason) async {
    if (amount < 0) return const Fail(AppFailure.validation('Сумма не может быть меньше нуля', field: 'amount'));
    if (reason.trim().isEmpty) return const Fail(AppFailure.validation('Укажите причину корректировки', field: 'reason'));
    final before = chargeOf(account, p);
    _adjust['$account|${p.key}'] = amount;
    await _save(AdminKeys.adjust, _adjust);
    await _log('Корректировка $account за ${p.key}: ${_money(before)} → ${_money(amount)} сом · $reason');
    await _touch();
    return const Ok(null);
  }

  // ───────────────────────── импорт ─────────────────────────

  /// Журнал: свои загрузки и прошлые. У прошлых загрузок начислений итог и
  /// число строк считаются из данных — иначе журнал разошёлся бы с экраном
  /// начислений.
  List<ImportJob> imports() {
    final byPeriod = {for (final p in periods()) p.period: p};
    final seeded = [
      for (final j in seedImports)
        if (j.kind == ImportKind.charges && byPeriod[j.period] != null)
          ImportJob(
            id: j.id, kind: j.kind, fileName: j.fileName, at: j.at, by: j.by,
            rows: byPeriod[j.period]!.count, created: byPeriod[j.period]!.count,
            updated: 0, unchanged: 0, errors: 0, period: j.period, total: _seedTotal(j.period!),
          )
        else
          j,
    ];
    return [..._imports, ...seeded]..sort((a, b) => b.at.compareTo(a.at));
  }

  /// Итог загрузки начислений по демо-генератору — без поздних корректировок.
  double _seedTotal(Period p) {
    var t = 0.0;
    for (final s in _seed.subscribers) {
      if (p == const Period(2026, 9)) {
        t += _seed.septCharges[s.account] ?? 0;
      } else if (s.createdAt == null || !s.createdAt!.isAfter(DateTime(p.year, p.month + 1, 1))) {
        t += _seed.priorCharge(s.account, p);
      }
    }
    return t;
  }

  Map<String, Field>? template(ImportKind k) => _templates[k];

  Future<void> saveTemplate(ImportKind k, Map<String, Field> t) async {
    _templates[k] = t;
    await _save(AdminKeys.templates, {for (final e in _templates.entries) e.key.name: {for (final f in e.value.entries) f.key: f.value.name}});
  }

  Future<void> _saveImports() => _save(AdminKeys.imports, [for (final j in _imports) j.toJson()]);

  Future<ImportJob> applySubscribers(SubscriberPlan plan, {required String fileName}) async {
    final undo = <String, Subscriber>{for (final c in plan.updated) c.before.account: c.before};
    for (final s in plan.created) {
      _subs[s.account] = s;
      _edits[s.account] = s;
    }
    for (final c in plan.updated) {
      _subs[c.after.account] = c.after;
      _edits[c.after.account] = c.after;
    }
    await _saveSubs();
    final job = ImportJob(
      id: 'imp-${now().microsecondsSinceEpoch}',
      kind: ImportKind.subscribers,
      fileName: fileName,
      at: now(),
      by: _session?.name ?? '',
      rows: plan.rows,
      created: plan.created.length,
      updated: plan.updated.length,
      unchanged: plan.unchanged,
      errors: plan.issues.length,
      undo: undo,
      createdAccounts: [for (final s in plan.created) s.account],
    );
    _imports.insert(0, job);
    await _saveImports();
    await _log('Импорт абонентов $fileName: +${plan.created.length}, обновлено ${plan.updated.length}, ошибок ${plan.issues.length}');
    await _touch();
    return job;
  }

  Future<ImportJob> applyCharges(ChargesPlan plan, {required String fileName}) async {
    final before = _loadedCharges[plan.period];
    _loadedCharges[plan.period] = {for (final c in plan.charges) c.account: c.amount};
    await _saveCharges();
    final job = ImportJob(
      id: 'imp-${now().microsecondsSinceEpoch}',
      kind: ImportKind.charges,
      fileName: fileName,
      at: now(),
      by: _session?.name ?? '',
      rows: plan.rows,
      created: plan.charges.length,
      updated: 0,
      unchanged: 0,
      errors: plan.issues.length,
      period: plan.period,
      total: plan.total,
      replacedCharges: before == null
          ? null
          : [for (final e in before.entries) Charge(account: e.key, period: plan.period, amount: e.value)],
    );
    _imports.insert(0, job);
    await _saveImports();
    await _log('Начисления за ${plan.period.key} загружены: $fileName, ${_n(plan.charges.length)} строк на ${_money(plan.total)} сом');
    await _touch();
    return job;
  }

  Future<void> _saveCharges() => _save(AdminKeys.charges, {
        for (final e in _loadedCharges.entries) e.key.key: e.value,
      });

  Future<Result<void>> rollback(String jobId) async {
    final i = _imports.indexWhere((j) => j.id == jobId);
    if (i < 0) return const Fail(AppFailure.validation('Этот импорт откатить нельзя — он старше суток'));
    final job = _imports[i];
    if (!job.canRollback(now())) return const Fail(AppFailure.validation('Откатить можно в течение суток после загрузки'));
    if (job.kind == ImportKind.subscribers) {
      for (final a in job.createdAccounts) {
        _edits.remove(a);
        final base = _seed.subscribers.where((s) => s.account == a).firstOrNull;
        if (base == null) {
          _subs.remove(a);
        } else {
          _subs[a] = base;
        }
      }
      for (final e in job.undo.entries) {
        _subs[e.key] = e.value;
        _edits[e.key] = e.value;
      }
      await _saveSubs();
    } else {
      final p = job.period!;
      if (job.replacedCharges == null) {
        _loadedCharges.remove(p);
      } else {
        _loadedCharges[p] = {for (final c in job.replacedCharges!) c.account: c.amount};
      }
      await _saveCharges();
    }
    _imports[i] = job.copyWith(status: ImportStatus.rolledBack);
    await _saveImports();
    await _log('Импорт ${job.fileName} отменён');
    await _touch();
    return const Ok(null);
  }

  // ───────────────────────── реестр в 1С ─────────────────────────

  /// Выгрузки: свои и ежедневные автоматические в 18:00 за 1–13 октября.
  List<ExportBatch>? _exportsCache;
  int _exportsRev = -1;

  List<ExportBatch> exports() {
    if (_exportsCache != null && _exportsRev == revision) return _exportsCache!;
    _exportsRev = revision;
    return _exportsCache = _buildExports();
  }

  List<ExportBatch> _buildExports() {
    final auto = <ExportBatch>[];
    var from = DateTime(2026, 10, 1);
    for (var d = 1; d <= 13; d++) {
      final until = DateTime(2026, 10, d, 18);
      final batch = [for (final p in _seed.payments) if (!p.at.isBefore(from) && p.at.isBefore(until)) p];
      auto.add(ExportBatch(
        id: 'exp-auto-$d',
        at: until,
        until: until,
        count: batch.length,
        total: batch.fold(0, (s, p) => s + p.amount),
        fileName: 'reestr_2026-10-${d.toString().padLeft(2, '0')}.csv',
        by: 'автовыгрузка',
      ));
      from = until;
    }
    return [..._exports, ...auto.reversed]..sort((a, b) => b.at.compareTo(a.at));
  }

  DateTime get exportedUntil => exports().first.until;

  /// Платежи, которых ещё нет в 1С.
  List<Payment> pendingExport() {
    final until = exportedUntil; // один раз, а не на каждый платёж
    return [for (final p in payments) if (!p.at.isBefore(until)) p];
  }

  bool get autoExport => _autoExport;

  Future<void> setAutoExport(bool on) async {
    _autoExport = on;
    await _save(AdminKeys.autoExport, {'on': on});
    await _log(on ? 'Автовыгрузка реестра в 18:00 включена' : 'Автовыгрузка реестра выключена');
    await _touch();
  }

  /// Выгрузить реестр: файл и отметка, что эти платежи уже в 1С.
  Future<(ExportBatch, RegistryFile)> exportRegistry(RegistryFormat format) async {
    final batch = pendingExport();
    final at = now();
    final file = buildRegistry(batch, format: format, at: at);
    final b = ExportBatch(
      id: 'exp-${at.microsecondsSinceEpoch}',
      at: at,
      until: at,
      count: batch.length,
      total: batch.fold(0, (s, p) => s + p.amount),
      fileName: file.name,
      by: _session?.name ?? '',
    );
    _exports.insert(0, b);
    await _save(AdminKeys.exports, [for (final e in _exports) e.toJson()]);
    await _log('Выгрузка реестра в 1С: ${_n(b.count)} платежей на ${_money(b.total)} сом, ${file.name}');
    await _touch();
    return (b, file);
  }

  /// Повторно скачать прежнюю выгрузку — те же платежи, без новой отметки.
  RegistryFile redownload(ExportBatch b, RegistryFormat format) {
    final all = exports();
    final i = all.indexWhere((x) => x.id == b.id);
    final from = i + 1 < all.length ? all[i + 1].until : DateTime(2026, 10, 1);
    final batch = [for (final p in payments) if (!p.at.isBefore(from) && p.at.isBefore(b.until)) p];
    return buildRegistry(batch, format: format, at: b.at);
  }

  // ───────────────────────── рассылки ─────────────────────────

  List<Campaign> campaigns() => [..._campaigns, ...seedCampaigns]..sort((a, b) => b.sendAt.compareTo(a.sendAt));

  List<SubscriberView> segment(Segment s) => [
        for (final v in views())
          if (v.sub.active &&
              switch (s) {
                Segment.unpaid => v.status == PayStatus.unpaid,
                Segment.debt => v.hasDebt,
                Segment.partial => v.status == PayStatus.partial,
              })
            v,
      ];

  /// Одному абоненту — не чаще раза в три дня. Кто получил недавно, тот
  /// в этот раз пропускается.
  Set<String> recentlyNotified({Duration window = const Duration(days: 3)}) {
    final since = now().subtract(window);
    final out = <String>{};
    for (final c in _campaigns) {
      if (!c.sendAt.isAfter(since)) continue;
      out.addAll(c.accounts.isNotEmpty ? c.accounts : segment(c.segment).map((v) => v.sub.account));
    }
    return out;
  }

  Future<Campaign> scheduleCampaign({
    required Segment segment,
    required String template,
    required String text,
    required bool sms,
    required DateTime sendAt,
    Set<String>? onlyAccounts,
  }) async {
    final skip = recentlyNotified();
    // Выбранным в таблице — ровно им; иначе — всему сегменту.
    final pool = onlyAccounts == null ? this.segment(segment) : [for (final a in onlyAccounts) ?view(a)];
    final people = [for (final v in pool) if (!skip.contains(v.sub.account)) v];
    final push = people.where((v) => v.sub.inApp).length;
    final smsCount = sms ? people.where((v) => !v.sub.inApp && v.sub.phone.isNotEmpty).length : 0;
    final c = Campaign(
      id: 'cmp-${now().microsecondsSinceEpoch}',
      at: now(),
      sendAt: sendAt,
      segment: segment,
      template: template,
      text: text,
      push: push,
      sms: smsCount,
      by: _session?.name ?? '',
      accounts: onlyAccounts == null ? const [] : [for (final v in people) v.sub.account],
    );
    _campaigns.insert(0, c);
    await _save(AdminKeys.campaigns, [for (final x in _campaigns) x.toJson()]);
    await _log('Рассылка «$template»: push ${_n(push)}${sms ? ', SMS ${_n(smsCount)}' : ''}');
    await _touch();
    return c;
  }

  // ───────────────────────── платежи без сопоставления ─────────────────────────

  List<Unmatched> unmatched() => _unmatched.values.toList()..sort((a, b) => a.deadline.compareTo(b.deadline));

  MatchHint? hintFor(Unmatched u) {
    if (u.orgId != ovkId) return null;
    final p = openPeriod;
    return suggestAccount(
      entered: u.entered,
      amount: u.amount,
      payerPhone: u.payerPhone,
      subscribers: _subs,
      chargeOf: (a) => chargeOf(a, p),
      paidOpenPeriod: (a) => paidFor(a, p) >= chargeOf(a, p) - 0.004 && chargeOf(a, p) > 0,
    );
  }

  Future<Result<void>> bindPayment(String id, String account) async {
    final u = _unmatched[id];
    if (u == null || u.state != UnmatchedState.open) return const Fail(AppFailure.notFound('Платёж уже разобран'));
    if (u.orgId == ovkId && !_subs.containsKey(account)) {
      return Fail(AppFailure.validation('Лицевого $account нет у службы', field: 'account'));
    }
    _unmatched[id] = u.copyWith(state: UnmatchedState.bound, boundTo: account);
    if (u.orgId == ovkId) {
      _extraPayments.add(Payment(
        id: 'p-bound-${u.id}', account: account, amount: u.amount, at: u.at, period: openPeriod,
        channel: Channel.elpay, method: u.method, receipt: u.receipt,
      ));
      await _save(AdminKeys.extraPayments, [for (final p in _extraPayments) p.toJson()]);
    }
    await _save(AdminKeys.unmatched, [for (final x in _unmatched.values) x.toJson()]);
    await _log('Платёж ${u.receipt} (${_money(u.amount)} сом, введён «${u.entered}») привязан к $account', orgId: u.orgId);
    await _touch();
    return const Ok(null);
  }

  Future<Result<void>> refundPayment(String id) async {
    final u = _unmatched[id];
    if (u == null || u.state != UnmatchedState.open) return const Fail(AppFailure.notFound('Платёж уже разобран'));
    _unmatched[id] = u.copyWith(state: UnmatchedState.refunded, closedNote: 'возврат на ${u.method}, 1–3 рабочих дня');
    await _save(AdminKeys.unmatched, [for (final x in _unmatched.values) x.toJson()]);
    await _log('Платёж ${u.receipt} — ${_money(u.amount)} сом возвращён плательщику', orgId: u.orgId);
    await _touch();
    return const Ok(null);
  }

  // ───────────────────────── обзор ─────────────────────────

  Dashboard? _dashCache;
  int _dashRev = -1;

  Dashboard dashboard() {
    if (_dashCache != null && _dashRev == revision) return _dashCache!;
    _dashRev = revision;
    return _dashCache = _buildDashboard();
  }

  Dashboard _buildDashboard() {
    final p = openPeriod;
    final v = views();
    final byChannel = {for (final c in Channel.values) c: 0.0};
    final byDay = <DateTime, double>{};
    for (final x in payments) {
      if (x.period != p) continue;
      byChannel[x.channel] = byChannel[x.channel]! + x.amount;
      final d = DateTime(x.at.year, x.at.month, x.at.day);
      byDay[d] = (byDay[d] ?? 0) + x.amount;
    }
    var charged = 0.0, paid = 0.0, debt = 0.0;
    var full = 0, part = 0, un = 0, app = 0, debtors = 0, appPaid = 0, otherPaid = 0, others = 0;
    for (final x in v) {
      final paidAny = x.status == PayStatus.paid || x.status == PayStatus.partial;
      if (x.charged > 0) {
        if (x.sub.inApp) {
          if (paidAny) appPaid++;
        } else {
          others++;
          if (paidAny) otherPaid++;
        }
      }
      charged += x.charged;
      paid += x.paid;
      if (x.status == PayStatus.paid) full++;
      if (x.status == PayStatus.partial) part++;
      if (x.status == PayStatus.unpaid) un++;
      if (x.sub.inApp) app++;
      if (x.hasDebt) {
        debtors++;
        debt += x.debt;
      }
    }
    return Dashboard(
      period: p,
      subscribers: v.length,
      charged: charged,
      paid: paid,
      paidFull: full,
      partial: part,
      unpaid: un,
      inApp: app,
      byChannel: byChannel,
      byDay: byDay,
      debtors: debtors,
      debt: debt,
      inAppPaidRate: app == 0 ? 0 : appPaid / app,
      otherPaidRate: others == 0 ? 0 : otherPaid / others,
    );
  }
}
