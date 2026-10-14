import 'package:elpay/admin/data/models.dart';
import 'package:elpay/admin/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

/// Итоги демо-реестра обязаны совпадать с концептом до сома: концепт уже
/// видели инвестор и службы, и цифры там те же.
void main() {
  final seed = generateSeed();
  final byAcc = {for (final s in seed.subscribers) s.account: s};
  double sum(Iterable<double> v) => v.fold(0.0, (a, b) => a + b);

  test('12 480 абонентов, лицевые уникальны и по формату', () {
    expect(seed.subscribers, hasLength(SeedTotals.subscribers));
    expect(byAcc, hasLength(SeedTotals.subscribers));
    expect(seed.subscribers.every((s) => RegExp(r'^\d{2}-\d{5}$').hasMatch(s.account)), isTrue);
  });

  test('начислено за сентябрь — ровно 2 368 940 сом', () {
    expect(sum(seed.septCharges.values), SeedTotals.charged);
    expect(seed.septCharges.values.every((c) => c > 0), isTrue);
  });

  test('оплачено 1 487 310: полностью 7 806, частично 642, не оплатили 4 032', () {
    final paid = <String, double>{};
    for (final p in seed.payments) {
      paid[p.account] = (paid[p.account] ?? 0) + p.amount;
    }
    expect(sum(seed.payments.map((p) => p.amount)), SeedTotals.paid);
    var full = 0, part = 0;
    for (final e in paid.entries) {
      final c = seed.septCharges[e.key]!;
      if (e.value >= c) {
        full++;
      } else {
        part++;
        expect(e.value, greaterThan(0));
      }
    }
    expect(full, SeedTotals.paidFull);
    expect(part, SeedTotals.partial);
    expect(SeedTotals.subscribers - paid.length, SeedTotals.unpaid);
  });

  test('каналы: ЭлPay 912 450, касса 341 280, банки 233 580', () {
    double by(Channel c) => sum(seed.payments.where((p) => p.channel == c).map((p) => p.amount));
    expect(by(Channel.elpay), SeedTotals.viaElpay);
    expect(by(Channel.cashier), SeedTotals.viaCashier);
    expect(by(Channel.bank), SeedTotals.viaBank);
  });

  test('3 914 подключили счёт в приложении', () {
    expect(seed.subscribers.where((s) => s.inApp).length, SeedTotals.inApp);
  });

  test('долг прошлых периодов: 1 905 абонентов на 418 270 сом', () {
    expect(seed.debts, hasLength(SeedTotals.debtors));
    final total = sum(seed.debts.entries.map((e) =>
        sum(e.value.periods.map((p) => seed.priorCharge(e.key, p))) - e.value.paidOnOldest));
    expect(total, SeedTotals.debt);
  });

  test('абоненты концепта — те же, что на экранах и в мобильном приложении', () {
    final a = byAcc['31-00562']!;
    expect(a.name, 'Токтогулова Айгерим');
    expect(a.address, 'ул. Курманжан Датка, 212, кв. 14');
    expect(seed.septCharges['31-00562'], 205);
    expect(seed.priorCharge('31-00562', const Period(2026, 8)), 164, reason: 'до импорта 1 окт жильцов было 4');
    expect(seed.payments.where((p) => p.account == '31-00562'), isEmpty, reason: 'вода за сентябрь не оплачена');
    expect(seed.payments.firstWhere((p) => p.account == '31-00944').amount, 100);
    expect(seed.debts['31-02071']!.periods, [const Period(2026, 8)]);
    expect(byAcc['31-02260']!.createdAt, DateTime(2026, 10, 1, 9, 42));
  });

  test('генератор детерминированный: второй прогон — те же данные', () {
    final again = generateSeed();
    expect(again.subscribers[777].name, seed.subscribers[777].name);
    expect(again.payments[1234].receipt, seed.payments[1234].receipt);
    expect(stableHash('31-00562/2026-08'), 2104011184, reason: 'тот же хеш и в браузере');
  });
}
