import 'package:elpay/core/prefs.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await AppPrefs.open();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Оплата счёта убирает его из ленты к оплате', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    final state = await container.read(billsProvider.future);
    final first = state.unpaid.first;
    final wasDue = state.dueTotal;

    container.read(billsProvider.notifier).markPaid([first.id]);

    final after = container.read(billsProvider).value!;
    expect(after.bills.firstWhere((b) => b.id == first.id).paid, isTrue);
    expect(after.dueTotal, closeTo(wasDue - first.amount, 0.001));
  });

  test('Заглушка платежей возвращает успех и номер квитанции', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    final state = await container.read(billsProvider.future);
    final result = await container.read(paymentsRepoProvider).pay(
          bills: [state.unpaid.first],
          methodId: 'visa',
        );

    expect(result.ok, isTrue);
    expect(result.receiptNo, isNotEmpty);
    expect(container.read(paymentsRepoProvider).isStub, isTrue);
  });

  test('Кошелёк: пополнение и списание', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

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
    final container = await makeContainer();
    addTearDown(container.dispose);

    final state = await container.read(billsProvider.future);
    final object = state.objects.first;
    expect(state.byObject(object.id), isNotEmpty);

    container.read(billsProvider.notifier).removeObject(object.id);

    final after = container.read(billsProvider).value!;
    expect(after.objects.any((o) => o.id == object.id), isFalse);
    expect(after.bills.any((b) => b.objectId == object.id), isFalse);
  });

  test('История пополняется новым платежом и сортируется по дате', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    final before = container.read(historyProvider).length;
    final now = DateTime.now();
    container.read(historyProvider.notifier).add([
      Payment(
        id: 'test-1',
        title: 'Тестовый платёж',
        cat: 'water',
        amount: 100,
        date: now,
        methodId: 'wallet',
        receiptNo: 'ЭП-000001',
      ),
    ]);

    final after = container.read(historyProvider);
    expect(after.length, before + 1);
    expect(after.first.id, 'test-1');
  });
}
