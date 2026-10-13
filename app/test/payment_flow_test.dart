import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

void main() {
  // Биндинг нужен ровно из-за AppPrefs поверх SharedPreferences: кэш,
  // очередь и демо-бэкенд в этом тесте живут в MemoryLocalStore.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Оплата счёта убирает его из ленты к оплате', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final state = await container.read(billsProvider.future);
    final first = state.unpaid.first;
    final wasDue = state.dueTotal;

    final result = await container
        .read(billsProvider.notifier)
        .markPaid([first.id], receiptNo: 'ЭП-205101');

    expect(result.isOk, isTrue);
    final after = container.read(billsProvider).value!;
    expect(after.bills.firstWhere((b) => b.id == first.id).paid, isTrue);
    expect(after.dueTotal, closeTo(wasDue - first.amount, 0.001));
  });

  test('Отметка оплаты переживает перезагрузку состояния', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final state = await container.read(billsProvider.future);
    final first = state.unpaid.first;
    await container
        .read(billsProvider.notifier)
        .markPaid([first.id], receiptNo: 'ЭП-205102');

    // Запись идёт через репозиторий, а не локальным присваиванием:
    // поэтому «оплачено» видно и из кэша, а не только на экране.
    final saved = env.bills.cached().bills.firstWhere((b) => b.id == first.id);
    expect(saved.paid, isTrue);
  });

  test('Заглушка платежей возвращает успех и номер квитанции', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final state = await container.read(billsProvider.future);
    final result = await container.read(paymentsRepoProvider).pay(
          bills: [state.unpaid.first],
          methodId: 'visa',
        );

    expect(result.ok, isTrue);
    expect(result.receiptNo, isNotEmpty);
    // Экран обязан честно предупредить: шлюза ещё нет.
    expect(container.read(paymentsRepoProvider).isStub, isTrue);
  });

  test('Кошелёк: пополнение и списание', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final start = container.read(walletProvider);
    container.read(walletProvider.notifier).topUp(500);
    expect(container.read(walletProvider), start + 500);

    container.read(walletProvider.notifier).spend(200);
    expect(container.read(walletProvider), start + 300);

    // Списать больше, чем есть, нельзя — баланс не уходит в минус.
    container.read(walletProvider.notifier).spend(1000000);
    expect(container.read(walletProvider), 0);
  });

  test('Объект удаляется вместе со своими счетами', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final state = await container.read(billsProvider.future);
    final object = state.objects.first;
    expect(state.byObject(object.id), isNotEmpty);

    final result = await container.read(billsProvider.notifier).removeObject(object.id);

    expect(result.isOk, isTrue);
    final after = container.read(billsProvider).value!;
    expect(after.objects.any((o) => o.id == object.id), isFalse);
    expect(after.bills.any((b) => b.objectId == object.id), isFalse);
  });

  test('История пополняется новым платежом и сортируется по дате', () async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final container = await env.container();

    final before = container.read(historyProvider).length;
    // Дата от часов стенда, а не DateTime.now(): иначе тест зависит
    // от дня запуска.
    final at = env.now.add(const Duration(hours: 1));
    container.read(historyProvider.notifier).add([
      Payment(
        id: 'test-1',
        title: 'Тестовый платёж',
        cat: 'water',
        amount: 100,
        date: at,
        methodId: 'wallet',
        receiptNo: 'ЭП-000001',
      ),
    ]);

    final after = container.read(historyProvider);
    expect(after.length, before + 1);
    expect(after.first.id, 'test-1');
  });
}
