import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Очередь отложенных операций: пока сети нет, действия пользователя
/// не теряются.
void main() {
  Log.enabled = false;

  OutboxItem item(
    String id, {
    String kind = 'connect_account',
    DateTime? createdAt,
    Map<String, dynamic> payload = const {},
  }) =>
      OutboxItem(
        id: id,
        kind: kind,
        payload: payload,
        createdAt: createdAt ?? testNow,
      );

  test('Элементы отправляются в порядке добавления', () async {
    final outbox = Outbox(MemoryLocalStore());
    await outbox.add(item('1'));
    await outbox.add(item('2', createdAt: testNow.add(const Duration(minutes: 1))));
    await outbox.add(item('3', createdAt: testNow.add(const Duration(minutes: 2))));

    final sent = <String>[];
    final done = await outbox.flush((i) async {
      sent.add(i.id);
      return true;
    });

    // Подключение, потом отключение — порядок операций пользователя
    // менять нельзя, иначе отключится то, что ещё не подключилось.
    expect(sent, ['1', '2', '3']);
    expect(done, 3);
  });

  test('Выполненные снимаются с очереди, неудачные остаются и считают попытки', () async {
    final outbox = Outbox(MemoryLocalStore());
    await outbox.add(item('1'));
    await outbox.add(item('2'));

    final done = await outbox.flush((i) async => i.id == '1');

    expect(done, 1);
    expect(outbox.length, 1);
    expect(outbox.items.single.id, '2');
    expect(outbox.items.single.attempts, 1);
    expect(outbox.items.single.lastError, isNotEmpty);

    // Со второго раза прошло — очередь пуста.
    expect(await outbox.flush((i) async => true), 1);
    expect(outbox.isEmpty, isTrue);
  });

  test('После пяти неудач элемент выбывает', () async {
    final outbox = Outbox(MemoryLocalStore());
    await outbox.add(item('1'));

    for (var i = 0; i < 4; i++) {
      await outbox.flush((_) async => false);
      expect(outbox.length, 1, reason: 'попытка ${i + 1} из 5');
    }
    await outbox.flush((_) async => false);

    // Иначе битая операция ходит по кругу вечно и жжёт батарею.
    expect(outbox.isEmpty, isTrue);
  });

  test('Исключение при отправке считается неудачей, а не теряет элемент', () async {
    final outbox = Outbox(MemoryLocalStore());
    await outbox.add(item('1'));

    await outbox.flush((_) async => throw StateError('шлюз упал'));

    expect(outbox.length, 1);
    expect(outbox.items.single.attempts, 1);
    expect(outbox.items.single.lastError, contains('шлюз упал'));
  });

  test('Элемент очереди несёт ключ идемпотентности и переживает чтение', () async {
    final store = MemoryLocalStore();
    const key = IdempotencyKey.raw('accounts.connect-1');
    await Outbox(store).add(item(
      'connect-reg-gas-1',
      payload: {'candidateId': 'reg-gas-1', 'objectId': 'o1', 'key': key.toJson()},
    ));

    // Новый экземпляр поверх того же хранилища: так очередь читает
    // приложение после перезапуска.
    final restored = Outbox(store).items.single;

    expect(restored.kind, 'connect_account');
    expect(restored.payload['candidateId'], 'reg-gas-1');
    // Повтор из очереди идёт С ТЕМ ЖЕ ключом — иначе шлюз подключит
    // счёт второй раз.
    expect(IdempotencyKey.tryFromJson(restored.payload['key']), key);
  });

  test('Время записи очереди соответствует моменту записи', () async {
    final store = MemoryLocalStore();
    final outbox = Outbox(store);
    final long = testNow.subtract(const Duration(days: 3));

    await outbox.add(item('1', createdAt: long));

    // Запись сделана сейчас, а не три дня назад: по этой отметке
    // решается, не пора ли выбросить залежавшуюся очередь.
    expect(store.updatedAt(CacheKeys.outbox), isNot(long));
  });
}
