import 'package:elpay/core/failure.dart';
import 'package:elpay/core/logger.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Перезапуск приложения.
///
/// Ради этого и правился демо-бэкенд: раньше подключённые счета жили
/// в полях `_connected/_extraBills`, а кэш репозитория переживал
/// перезапуск. После рестарта в списке были счета из кэша, которых
/// «бэкенд» уже не знал: id расходились, отключение падало в notFound.
/// Теперь состояние демо-бэкенда лежит в том же [MemoryLocalStore] под
/// своим ключом, и перезапуск — это новые объекты поверх ТОГО ЖЕ
/// хранилища (`env.restart()`).
void main() {
  Log.enabled = false;

  test('Подключённый счёт переживает перезапуск: новый экземпляр мока '
      'и репозитория поверх того же хранилища видит тот же счёт', () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    final connected = await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
    expect(connected.isOk, isTrue);
    final account = connected.valueOrNull!.account;
    expect(account.accountNo, '55-20841');

    final restarted = env.restart();
    addTearDown(restarted.dispose);
    final after = await restarted.accounts.accounts(refresh: true);

    expect(after.isOk, isTrue);
    expect(
      after.valueOrNull!.where((a) => a.id == account.id),
      hasLength(1),
      reason: 'счёт ровно один: ни пропал, ни удвоился',
    );
    expect(
      after.valueOrNull!.firstWhere((a) => a.id == account.id).objectId,
      'o1',
    );
  });

  test('id счёта после перезапуска не меняется, и отключение не падает в notFound',
      () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    final before = (await env.accounts.accounts()).valueOrNull!;
    expect(before, isNotEmpty);
    final target = before.first;

    final restarted = env.restart();
    addTearDown(restarted.dispose);
    final after = (await restarted.accounts.accounts(refresh: true)).valueOrNull!;

    // Главное: id те же. Именно их расхождение и ломало отключение.
    expect(after.map((a) => a.id), before.map((a) => a.id));

    final off = await restarted.accounts.disconnect(target.id);
    expect(off.failureOrNull?.kind, isNot(FailureKind.notFound));
    expect(off.isOk, isTrue);

    final left = (await restarted.accounts.accounts(refresh: true)).valueOrNull!;
    expect(left.any((a) => a.id == target.id), isFalse);
  });

  test('Начисления подключённого счёта тоже переживают перезапуск', () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    final result = await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
    final bill = result.valueOrNull!.bill;
    expect(bill, isNotNull, reason: 'у реестровой записи начисление выставлено');

    final restarted = env.restart();
    addTearDown(restarted.dispose);
    final snapshot = await restarted.bills.load(refresh: true);

    expect(snapshot.isOk, isTrue);
    final saved = snapshot.valueOrNull!.bills.where((b) => b.id == bill!.id);
    expect(saved, hasLength(1));
    expect(saved.single.accountId, result.valueOrNull!.account.id,
        reason: 'привязка начисления к счёту не теряется');
  });

  test('Выход из аккаунта чистит оба хранилища, и следующий вход '
      'не видит данных предыдущего', () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
    expect(env.accounts.cachedAccounts().any((a) => a.accountNo == '55-20841'), isTrue);
    expect(env.store.isEmpty, isFalse);

    // Это и делает signOutEverywhere: чистит кэш клиента и очередь. Состояние
    // демо-бэкенда лежит в том же хранилище под своим ключом, поэтому уходит
    // вместе с ним — в бою его место занимает база поставщика.
    await env.outbox.clear();
    await env.store.clear();
    expect(env.store.isEmpty, isTrue);

    final next = env.restart();
    addTearDown(next.dispose);
    final after = (await next.accounts.accounts(refresh: true)).valueOrNull!;

    expect(after.any((a) => a.accountNo == '55-20841'), isFalse,
        reason: 'чужое подключение не должно достаться следующему входу');
    expect(after, isNotEmpty, reason: 'демо-набор засевается заново');
  });
}
