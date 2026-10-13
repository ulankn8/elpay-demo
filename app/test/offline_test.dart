import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/data/accounts_repository.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Офлайн: что происходит, когда сети нет, и что происходит, когда она
/// вернулась.
///
/// Проверяется боевой путь целиком — `DefaultAccountsRepository` поверх
/// настоящего [Outbox] и демо-бэкенда, который без сети честно падает.
/// Фейк репозитория здесь не годится: очередь — это как раз то, чего
/// у него нет.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Без сети', () {
    test('Поиск без сети возвращает network и не кладёт запрос в очередь',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();

      final result = await env.accounts.search(const AccountQuery.byAccount('31-00562'));

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
      // Ответ нужен сейчас: отложенный поиск бессмыслен, и в очередь
      // он не ложится — иначе она заполнится мусором.
      expect(env.outbox.isEmpty, isTrue);
    });

    test('Подключение без сети ложится в очередь и не теряется', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();

      final result = await env.accounts.connect(
        candidateId: 'reg-gas-1',
        objectId: 'o1',
      );

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
      expect(env.outbox.length, 1);
      expect(env.outbox.items.single.kind, DefaultAccountsRepository.kindConnect);
      expect(env.outbox.items.single.payload['candidateId'], 'reg-gas-1');
      expect(env.outbox.items.single.payload['objectId'], 'o1');
    });

    test('Элемент очереди несёт ключ идемпотентности', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();
      final key = env.ids.key('accounts.connect');

      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1', key: key);

      // Ключ лежит в очереди, а не выдаётся заново при отправке: иначе
      // шлюз увидит две разные попытки и подключит счёт дважды.
      final saved = IdempotencyKey.tryFromJson(env.outbox.items.single.payload['key']);
      expect(saved, key);
      // И он переживает чтение очереди из хранилища.
      expect(saved!.value, startsWith('accounts.connect'));
    });

    test('Отключение без сети даёт статус pendingDisconnect, '
        'строка остаётся видимой', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      final before = await container.read(accountsProvider.future);
      final victim = before.accounts.first;
      env.offline();

      final result = await container.read(accountsProvider.notifier).disconnect(victim.id);
      await settleProviders();

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
      final after = container.read(accountsProvider).value!;
      // Счёт НЕ исчезает из списка: поставщик о нём ещё не знает, и
      // пропавшая строка выглядела бы как успешное отключение.
      final saved = after.byId(victim.id);
      expect(saved, isNotNull);
      expect(saved!.isPendingDisconnect, isTrue);
      expect(after.pending.map((a) => a.id), contains(victim.id));
      expect(env.outbox.length, 1);
      expect(env.outbox.items.single.kind, DefaultAccountsRepository.kindDisconnect);
    });

    test('Плашка офлайна и счётчик очереди говорят правду', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      await container.read(accountsProvider.future);

      expect(container.read(onlineNowProvider), isTrue);
      expect(container.read(pendingOpsProvider), 0);

      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      // Очередь живёт в хранилище и сама об изменениях не сообщает,
      // поэтому значение пересчитывается по смене сети и списку счетов.
      container.invalidate(pendingOpsProvider);

      expect(container.read(pendingOpsProvider), 1);
    });
  });

  group('Сеть вернулась', () {
    test('Возврат сети отправляет очередь и обновляет списки', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      await container.read(accountsProvider.future);

      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      expect(env.outbox.length, 1);

      // Наблюдатель включается одной строкой в ElPayApp.build — до него
      // flushOutbox() не звал НИКТО, и подключение из офлайна пропадало
      // навсегда. Подписка, а не read: без живого слушателя Riverpod
      // закрывает провайдер сразу после чтения, и наблюдать становится
      // нечем.
      final watcher = container.listen(syncWatcherProvider, (_, _) {});
      addTearDown(watcher.close);
      await settleProviders();

      env.online();
      await waitFor(() => env.outbox.isEmpty);

      expect(env.outbox.isEmpty, isTrue, reason: 'очередь разгрузилась сама');
      final accounts = await container.read(accountsProvider.future);
      expect(accounts.accounts.any((a) => a.accountNo == '55-20841'), isTrue);
    });

    test('Повтор из очереди идёт с тем же ключом и не дублирует счёт',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await env.accounts.accounts();
      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      final queued = IdempotencyKey.tryFromJson(env.outbox.items.single.payload['key'])!;

      env.online();
      final sent = await env.accounts.flushOutbox();

      expect(sent, 1);
      expect(env.outbox.isEmpty, isTrue);

      // Пользователь нажал «подключить» ещё раз, пока очередь уходила:
      // ключ тот же, поэтому источник отдаёт ПРЕЖНИЙ счёт.
      final again = await env.accounts.connect(
        candidateId: 'reg-gas-1',
        objectId: 'o1',
        key: queued,
      );

      expect(again.isOk, isTrue);
      // Сверяемся с источником через refresh: true; дедупликация самого
      // кэша проверяется в test/accounts_test.dart, тестом «повтор по тому
      // же ключу не удваивает счёт в кэше».
      final all = (await env.accounts.accounts(refresh: true)).valueOrNull!;
      expect(all.where((a) => a.accountNo == '55-20841'), hasLength(1));
    });

    test('Без сети очередь не разгружается и не растёт копиями', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      final sent = await env.accounts.flushOutbox();

      expect(sent, 0);
      // Попытка отправки в офлайне положила бы в очередь копию той же
      // операции: connect без сети кладёт себя заново.
      expect(env.outbox.length, 1);
    });

    test('Подключённое из очереди переживает перезапуск приложения', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await env.accounts.accounts();
      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      env.online();
      await env.accounts.flushOutbox();

      // Новые репозитории и новый демо-бэкенд поверх ТОГО ЖЕ хранилища.
      final restarted = env.restart();
      addTearDown(restarted.dispose);

      final all = (await restarted.accounts.accounts(refresh: true)).valueOrNull!;
      final gas = all.where((a) => a.accountNo == '55-20841');
      expect(gas, hasLength(1));
      // id не разъехался — иначе отключение упало бы в notFound.
      expect(
        (await restarted.accounts.disconnect(gas.single.id)).isOk,
        isTrue,
      );
    });
  });

  // Рядом с офлайн-веткой того же жеста: ветка Ok у
  // AccountsNotifier.disconnect не исполнялась ни одним тестом вообще
  // (покрыты были только отказ через нотифаер и успех на уровне
  // репозитория), и приложение могло перестать убирать начисления
  // отключённого счёта при зелёном прогоне.
  group('Отключение при живой сети', () {
    test('Онлайн-отключение убирает начисления отключённого счёта', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final container = await env.container();
      final accounts = await container.read(accountsProvider.future);
      final bills = await container.read(billsProvider.future);

      final victim = accounts.accounts.firstWhere(
        (a) => bills.byAccount(a.id).any((b) => !b.paid),
      );
      final mine = bills
          .byAccount(victim.id)
          .where((b) => !b.paid)
          .fold<double>(0, (sum, b) => sum + b.amount);
      final dueBefore = bills.dueTotal;

      final result = await container.read(accountsProvider.notifier).disconnect(victim.id);

      expect(result.isOk, isTrue);
      // Начисления уходят СРАЗУ, не дожидаясь перечитывания из источника:
      // иначе пользователь видит долг по счёту, которого больше нет, —
      // и в ленте «к оплате», и на карточке объекта.
      final right = container.read(billsProvider).value!;
      expect(right.byAccount(victim.id), isEmpty);

      await settleProviders();

      final after = container.read(billsProvider).value!;
      expect(container.read(accountsProvider).value!.byId(victim.id), isNull);
      expect(after.byAccount(victim.id), isEmpty, reason: 'и не вернулись с обновлением');
      expect(after.dueTotal, closeTo(dueBefore - mine, 0.001));
    });
  });

  group('Чтение без сети', () {
    test('Список счетов открывается из кэша с пометкой fromCache', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await env.accounts.accounts();
      env.offline();

      final result = await env.accounts.load(refresh: true);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.value, isNotEmpty);
      expect(result.valueOrNull!.fromCache, isTrue);
    });

    test('Первый запуск без сети и без кэша — честный отказ, а не пустой экран',
        () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();
      // Кэша нет вообще: приложение открыли впервые и сразу без сети.
      expect(env.store.keys, isNot(contains(CacheKeys.accounts)));

      final result = await env.accounts.load();

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
    });
  });
}
