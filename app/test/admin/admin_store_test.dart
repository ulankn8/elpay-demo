import 'package:elpay/admin/data/admin_store.dart';
import 'package:elpay/admin/data/csv.dart';
import 'package:elpay/admin/data/import_engine.dart';
import 'package:elpay/admin/data/mapping.dart';
import 'package:elpay/admin/data/models.dart';
import 'package:elpay/admin/data/registry.dart';
import 'package:elpay/admin/data/seed.dart';
import 'package:elpay/admin/data/text_codec.dart';
import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Генератор дорогой — собираем один раз на файл.
final seed = generateSeed();

void main() {
  late MemoryLocalStore mem;
  late MovableClock clock;

  AdminStore open() => AdminStore(store: mem, clock: clock.clock, seed: seed);

  setUp(() {
    mem = MemoryLocalStore();
    clock = MovableClock(DateTime(2026, 11, 2, 10));
  });

  test('обзор сходится с концептом до сома', () {
    final d = open().dashboard();
    expect(d.subscribers, 12480);
    expect(d.charged, 2368940);
    expect(d.paid, 1487310);
    expect((d.paidFull, d.partial, d.unpaid), (7806, 642, 4032));
    expect(d.inApp, 3914);
    expect(d.byChannel[Channel.elpay], 912450);
    expect(d.debtors, 1905);
    expect(d.debt, 418270);
  });

  test('часы кабинета идут от 14 октября 12:00, а не от настоящей даты', () {
    final s = open();
    expect(s.now(), seedNow);
    clock.advance(const Duration(hours: 3));
    expect(s.now(), seedNow.add(const Duration(hours: 3)));
  });

  test('вход: чужая почта — отказ, неверный код — отказ, 4815 — вход и журнал', () async {
    final s = open();
    expect(s.requestCode('ivan@gmail.com').isFail, isTrue);
    expect((await s.signIn('jypar@oshvodokanal.kg', '0000')).failureOrNull!.field, 'code');
    final ok = await s.signIn('Jypar@OshVodokanal.kg ', '4815');
    expect(ok.valueOrNull!.name, 'Жыпар Турсунова');
    expect(s.audit(orgId: ovkId).first.action, 'Вход в кабинет');
    // Сессия переживает перезагрузку страницы.
    expect(open().session?.id, 'st-jypar');
  });

  test('ручное добавление: проверка лицевого, затем абонент виден и после перезагрузки', () async {
    final s = open();
    await s.signIn('jypar@oshvodokanal.kg', '4815');
    expect(s.nextFreeAccount(), '31-02261');
    final dup = await s.saveSubscriber(
        const Subscriber(account: '31-00562', name: 'Кто-то', street: 'ул. Навои', house: '1'), isNew: true);
    expect(dup.failureOrNull!.message, contains('Токтогулова'));
    final ok = await s.saveSubscriber(
        const Subscriber(account: '31 02261', name: 'жумабаева асель', street: 'ул. Курманжан Датка', house: '218', flat: '9', residents: 3, phone: '0555 12 34 56'),
        isNew: true);
    expect(ok.valueOrNull!.account, '31-02261');
    expect(ok.valueOrNull!.name, 'Жумабаева Асель');
    expect(ok.valueOrNull!.phone, '+996 555 12 34 56');
    final again = open();
    expect(again.subscriber('31-02261')!.address, 'ул. Курманжан Датка, 218, кв. 9');
    expect(again.view('31-02261')!.status, PayStatus.noCharge, reason: 'начисление придёт со следующей загрузкой');
    expect(again.dashboard().subscribers, 12481);
  });

  test('импорт абонентов применяется, переживает перезагрузку и откатывается в течение суток', () async {
    final s = open();
    await s.signIn('bakyt@oshvodokanal.kg', '4815');
    final t = toTable(parseCsv('Лиц_счет;Абонент;Улица;Дом;Кв;Кол_прож\n'
        '31-00562;Токтогулова Айгерим;ул. Курманжан Датка;212;14;6\n'
        '31-09001;Новый Абонент;ул. Навои;40;;2\n'));
    final plan = planSubscribers(
        table: t, map: autoMap(t, ImportKind.subscribers, template: s.template(ImportKind.subscribers)),
        existing: s.subscribers, now: s.now());
    expect((plan.created.length, plan.updated.length), (1, 1));
    final job = await s.applySubscribers(plan, fileName: 'test.csv');
    expect(s.subscriber('31-00562')!.residents, 6);

    final reopened = open();
    expect(reopened.subscriber('31-09001')!.name, 'Новый Абонент');
    expect(reopened.imports().first.fileName, 'test.csv');

    clock.advance(const Duration(hours: 2));
    expect((await reopened.rollback(job.id)).isOk, isTrue);
    expect(reopened.subscriber('31-00562')!.residents, 5);
    expect(reopened.subscriber('31-09001'), isNull);
    expect(open().subscriber('31-09001'), isNull, reason: 'откат тоже сохраняется');

    // Импорты старше суток не откатываются.
    expect((await reopened.rollback('imp-1009')).isFail, isTrue);
  });

  test('начисления за октябрь открывают новый период: сентябрьский недоплат становится долгом', () async {
    final s = open();
    await s.signIn('bakyt@oshvodokanal.kg', '4815');
    final rows = [
      ['ЛС', 'Сумма', 'Период'],
      for (final sub in s.subscribers.values.take(100)) [sub.account, '${sub.residents * 41}', 'октябрь 2026'],
    ];
    final t = toTable(rows);
    final plan = planCharges(
        table: t, map: autoMap(t, ImportKind.charges), subscribers: s.subscribers,
        period: const Period(2026, 10), alreadyLoaded: 0);
    expect(plan.issues, isEmpty);
    await s.applyCharges(plan, fileName: 'nachisleniya_oktyabr.xlsx');
    expect(s.openPeriod, const Period(2026, 10));
    final first = s.subscribers.values.first.account;
    expect(s.view(first)!.status, PayStatus.unpaid);
    expect(s.periods().first.period, const Period(2026, 10));
    // Токтогулова не оплатила сентябрь — 205 сом ушли в долг.
    expect(s.view('31-00562')!.debt, 205);
  });

  test('реестр в 1С: Windows-1251, отметка выгруженного, повторная выгрузка пуста', () async {
    final s = open();
    await s.signIn('jypar@oshvodokanal.kg', '4815');
    final pending = s.pendingExport();
    expect(pending, isNotEmpty);
    expect(pending.every((p) => !p.at.isBefore(DateTime(2026, 10, 13, 18))), isTrue);
    final (batch, file) = await s.exportRegistry(RegistryFormat.csv1c);
    expect(batch.count, pending.length);
    expect(file.encoding, 'Windows-1251');
    final text = decodeText(file.bytes);
    expect(text.encoding, TextEncoding.cp1251);
    final rows = parseCsv(text.text);
    expect(rows.first, registryHeader);
    expect(rows, hasLength(pending.length + 1));
    expect(s.pendingExport(), isEmpty);
    expect(open().pendingExport(), isEmpty, reason: 'отметка переживает перезагрузку');
  });

  test('рассылка: push бесплатно подключённым, SMS по желанию, не чаще раза в три дня', () async {
    final s = open();
    await s.signIn('jypar@oshvodokanal.kg', '4815');
    final seg = s.segment(Segment.unpaid);
    expect(seg, hasLength(4032));
    final c = await s.scheduleCampaign(
        segment: Segment.unpaid, template: 'Напоминание о сроке', text: 't', sms: true, sendAt: s.now());
    expect(c.push, seg.where((v) => v.sub.inApp).length);
    expect(c.sms, seg.where((v) => !v.sub.inApp && v.sub.phone.isNotEmpty).length);
    expect(c.cost, closeTo(c.sms * 1.2, .001));
    final again = await s.scheduleCampaign(
        segment: Segment.unpaid, template: 'Ещё раз', text: 't', sms: false, sendAt: s.now());
    expect(again.recipients, 0, reason: 'тем же людям через час — нельзя');
  });

  test('платёж без сопоставления: подсказка с причинами и привязка', () async {
    final s = open();
    await s.signIn('a.kadyrov@elpay.kg', '4815');
    expect(s.isAdmin, isTrue);
    final u = s.unmatched().firstWhere((x) => x.entered == '31-0562');
    final hint = s.hintFor(u)!;
    expect(hint.account, '31-00562');
    expect(hint.why, contains('нуля'));
    expect(hint.checks.any((c) => c.$1.contains('Телефон') && c.$2), isTrue);
    final swapped = s.hintFor(s.unmatched().firstWhere((x) => x.entered == '31-01854'))!;
    expect(swapped.account, '31-01845');
    expect(swapped.why, contains('Переставлены'));
    expect(s.hintFor(s.unmatched().firstWhere((x) => x.entered == 'OSH-44102')), isNull);

    final paidBefore = s.view('31-00562')!.paid;
    await s.bindPayment(u.id, '31-00562');
    expect(s.view('31-00562')!.paid, paidBefore + 300);
    expect(s.view('31-00562')!.status, PayStatus.paid);
    expect(open().unmatched().firstWhere((x) => x.id == u.id).state, UnmatchedState.bound);
  });

  test('приглашение: только рабочая почта службы', () async {
    final s = open();
    await s.signIn('jypar@oshvodokanal.kg', '4815');
    expect((await s.invite(orgId: ovkId, name: 'Айбек', email: 'aibek@gmail.com')).failureOrNull!.message, contains('@oshvodokanal.kg'));
    final ok = await s.invite(orgId: ovkId, name: 'айбек мамытов', email: 'aibek@oshvodokanal.kg');
    expect(ok.valueOrNull!.pending, isTrue);
    expect(open().staffOf(ovkId).map((x) => x.email), contains('aibek@oshvodokanal.kg'));
    expect((await s.removeStaff('st-jypar')).isFail, isTrue, reason: 'себя удалить нельзя');
  });

  test('история абонента: полгода, сентябрь не оплачен, раньше — оплачено', () {
    final h = open().history('31-00562');
    expect(h.first.period, const Period(2026, 9));
    expect(h.first.charged, 205);
    expect(h.first.paid, 0);
    expect(h[1].charged, 164);
    expect(h[1].paid, 164);
    expect(h[1].how, isNotEmpty);
  });

  test('сброс демо: правки, выгрузки и разбор стираются, часы и цифры — как в начале, вход остаётся', () async {
    final s = open();
    await s.signIn('jypar@oshvodokanal.kg', '4815');
    clock.advance(const Duration(days: 2));
    await s.saveSubscriber(const Subscriber(account: '31-02261', name: 'Жумабаева Асель', street: 'ул. Навои', house: '5'), isNew: true);
    await s.exportRegistry(RegistryFormat.csv1c);
    await s.setAutoExport(false);
    await s.bindPayment(s.unmatched().first.id, '31-01845');
    expect(s.dashboard().subscribers, 12481);

    await s.resetDemo();

    for (final store in [s, open()]) {
      expect(store.dashboard().subscribers, 12480);
      expect(store.subscriber('31-02261'), isNull);
      expect(store.pendingExport().length, open().pendingExport().length);
      expect(store.unmatched().where((u) => u.state == UnmatchedState.open).length, 3);
      expect(store.now(), seedNow, reason: 'часы снова с 14 октября 12:00');
      expect(store.session?.id, 'st-jypar');
    }
    expect(mem.raw(AdminKeys.audit), isNull);
  });
}
