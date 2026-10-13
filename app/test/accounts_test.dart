import 'package:elpay/core/clock.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/data/connect_rules.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/data/registry_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fake_accounts_repository.dart';
import 'support/fixtures.dart';

/// Подключение счетов на боевом репозитории поверх демо-бэкенда.
///
/// Биндинга и SharedPreferences здесь больше нет: стенд (`makeEnv`) даёт
/// MemoryLocalStore, фиксированные часы и демо-бэкенд без задержки —
/// прогон перестал ждать по 420 мс на каждый запрос.
void main() {
  group('Поиск счёта', () {
    test('по лицевому счёту находит запись реестра', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final result = await env.accounts.search(const AccountQuery.byAccount('31-00562'));

      expect(result.isOk, isTrue);
      final found = result.valueOrNull!;
      expect(found, hasLength(1));
      expect(found.first.providerTitle, contains('Ошводоканал'));
      expect(found.first.amount, 205);
    });

    test('по адресу находит все счета квартиры', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final (city, street, house, flat) = Registry.homeAddress;
      final result = await env.accounts.search(
        AccountQuery.byAddress(city: city, street: street, house: house, flat: flat),
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.length, greaterThanOrEqualTo(5));
    });

    test('номер с пробелами и дефисами всё равно находится', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final result = await env.accounts.search(const AccountQuery.byAccount(' 31 00562 '));

      expect(result.valueOrNull, hasLength(1));
    });

    test('чужой адрес ничего не находит', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final result = await env.accounts.search(const AccountQuery.byAddress(
        city: 'Ош',
        street: 'ул. Несуществующая',
        house: '1',
      ));

      expect(result.valueOrNull, isEmpty);
    });

    test('без сети поиск возвращает ошибку сети и не копит очередь', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();

      final result = await env.accounts.search(const AccountQuery.byAccount('31-00562'));

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
      // Ответ нужен сейчас: поиск в очередь не кладут.
      expect(env.outbox.isEmpty, isTrue);
    });
  });

  group('Подтверждение владения', () {
    test('счёт на другого человека требует кода', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final found = await env.accounts.search(const AccountQuery.byAccount('OSH-44120'));

      expect(found.valueOrNull!.first.needsConfirm, isTrue);
    });

    test('неверный код не подходит, верный — подтверждает', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final wrong = await env.accounts.confirm(candidateId: 'reg-net-1', code: '0000');
      expect(wrong.isFail, isTrue);
      expect(wrong.failureOrNull!.kind, FailureKind.validation);
      expect(wrong.failureOrNull!.field, 'code');

      final right = await env.accounts.confirm(candidateId: 'reg-net-1', code: '4815');
      expect(right.isOk, isTrue);
      expect(right.valueOrNull!.needsConfirm, isFalse);
    });
  });

  group('Подключение счёта', () {
    test('подключение добавляет счёт и начисление', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final result = await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(result.isOk, isTrue);
      final value = result.valueOrNull!;
      expect(value.account.accountNo, '55-20841');
      expect(value.bill, isNotNull);
      expect(value.bill!.amount, 420);
      expect(value.bill!.objectId, 'o1');
      // Начисление знает свой счёт по id, а не по строке номера.
      expect(value.bill!.accountId, value.account.id);
    });

    test('повторное подключение того же счёта отклоняется', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      final again = await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(again.isFail, isTrue);
      expect(again.failureOrNull!.kind, FailureKind.validation);
    });

    test('повтор с тем же ключом идемпотентности не создаёт второй счёт', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final key = env.ids.key('accounts.connect');
      final first = await env.accounts
          .connect(candidateId: 'reg-gas-1', objectId: 'o1', key: key);
      final repeat = await env.accounts
          .connect(candidateId: 'reg-gas-1', objectId: 'o1', key: key);

      expect(first.isOk, isTrue);
      // Тот же ключ — тот же результат, а не «счёт уже подключён» и не дубль.
      expect(repeat.isOk, isTrue);
      expect(repeat.valueOrNull!.account.id, first.valueOrNull!.account.id);
      // Сверяемся с источником, а не с кэшем: кэш правится отдельным
      // дефектом, он проверяется следующим тестом.
      final all = (await env.accounts.accounts(refresh: true)).valueOrNull!;
      expect(all.where((a) => a.accountNo == '55-20841'), hasLength(1));
    });

    test('повтор по тому же ключу не удваивает счёт в кэше', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final key = env.ids.key('accounts.connect');
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1', key: key);
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1', key: key);

      expect(
        env.accounts.cachedAccounts().where((a) => a.accountNo == '55-20841'),
        hasLength(1),
      );
    });

    test('подключённый счёт сохраняется в кэш', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(env.accounts.cachedAccounts().any((a) => a.accountNo == '55-20841'), isTrue);
    });

    test('уже подключённый счёт помечен в результатах поиска', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await env.accounts.accounts();
      final found = await env.accounts.search(const AccountQuery.byAccount('31-00562'));

      expect(found.valueOrNull!.first.alreadyConnected, isTrue);
    });

    test('без сети подключение уходит в очередь', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();

      final result = await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(result.isFail, isTrue);
      expect(env.outbox.length, 1);
      expect(env.outbox.items.first.kind, 'connect_account');
      // В очереди лежит ключ попытки: повтор пойдёт с тем же.
      expect(env.outbox.items.first.payload['key'], isNotNull);
    });

    test('когда сеть вернулась, очередь отправляется', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      env.offline();
      await env.accounts.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      env.online();
      final sent = await env.accounts.flushOutbox();

      expect(sent, 1);
      expect(env.outbox.isEmpty, isTrue);
      expect(env.accounts.cachedAccounts().any((a) => a.accountNo == '55-20841'), isTrue);
    });
  });

  group('Отключение и обновление', () {
    test('отключение убирает счёт из кэша', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final connected = (await env.accounts.accounts()).valueOrNull!;
      final first = connected.first;

      final result = await env.accounts.disconnect(first.id);

      expect(result.isOk, isTrue);
      expect(env.accounts.cachedAccounts().any((a) => a.id == first.id), isFalse);
    });

    test('без сети счёт остаётся видимым со статусом «отключаем»', () async {
      final env = makeEnv();
      addTearDown(env.dispose);
      final connected = (await env.accounts.accounts()).valueOrNull!;
      final first = connected.first;
      env.offline();

      final result = await env.accounts.disconnect(first.id);

      expect(result.failureOrNull!.kind, FailureKind.network);
      // Строка не исчезает: поставщик о ней ещё не знает.
      final saved = env.accounts.cachedAccounts().firstWhere((a) => a.id == first.id);
      expect(saved.isPendingDisconnect, isTrue);
      expect(env.outbox.length, 1);
    });

    test('обновление проставляет время синхронизации', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await env.accounts.accounts();
      final result = await env.accounts.sync();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.accounts.every((a) => a.syncedAt != null), isTrue);
      expect(
        result.valueOrNull!.accounts.every((a) => a.status == AccountSyncStatus.ok),
        isTrue,
      );
      expect(result.valueOrNull!.syncedAt, env.now);
    });

    test('без сети счета берутся из кэша, а не падают', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      await env.accounts.accounts();
      env.offline();

      final result = await env.accounts.load(refresh: true);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.value, isNotEmpty);
      // Экран обязан узнать, что данные сохранённые, — иначе плашки
      // офлайна не будет.
      expect(result.valueOrNull!.fromCache, isTrue);
    });

    test('перенос счёта на другой объект не требует переподключения', () async {
      final env = makeEnv();
      addTearDown(env.dispose);

      final connected = (await env.accounts.accounts()).valueOrNull!;
      final first = connected.first;

      final moved = await env.accounts.move(accountId: first.id, objectId: 'o2');

      expect(moved.isOk, isTrue);
      expect(moved.valueOrNull!.objectId, 'o2');
      expect(moved.valueOrNull!.id, first.id, reason: 'id и история сохраняются');
      expect(
        env.accounts.cachedAccounts().firstWhere((a) => a.id == first.id).objectId,
        'o2',
      );
    });
  });

  // Демо-бэкенд ведёт себя как настоящий, и поэтому им не проверить то,
  // что должно происходить РЕДКО: отказ по одному счёту из трёх и повтор
  // по уже использованному ключу. Для этого есть управляемый фейк.
  group('Пакетное подключение на управляемом фейке', () {
    const rules = ConnectRules();

    FakeAccountsRepository fake() => FakeAccountsRepository(
          candidates: [
            candidate(id: 'c1', accountNo: '31-00562', amount: 205),
            candidate(id: 'c2', accountNo: '55-20841', providerId: 'p-gas', amount: 420),
            // Счёт есть, начисления нет — обычное состояние.
            candidate(id: 'c3', accountNo: '04-118725', providerId: 'p-trash', amount: 0),
          ],
          clock: at(testNow),
          ids: SeqIdGen(),
        );

    ConnectPlan planOf(FakeAccountsRepository repo) => rules
        .plan(
          views: rules.classify(found: repo.candidates, connected: const []),
          selected: {'c1', 'c2', 'c3'},
          objectId: homeObject.id,
          objects: const [homeObject],
          ids: repo.ids,
        )
        .valueOrNull!;

    test('Частичный успех: два счёта подключены, третий в failed с причиной', () async {
      final repo = fake();
      repo.failConnect('c2', const AppFailure.server('поставщик не ответил'));

      final batch = await repo.connectPlan(planOf(repo));

      expect(batch.total, 3);
      expect(batch.isPartial, isTrue);
      expect(batch.isSuccess, isFalse);
      expect(batch.isTotalFailure, isFalse);
      expect(batch.connected.map((a) => a.accountNo), ['31-00562', '04-118725']);
      // Про упавший счёт пользователь обязан узнать — и по названию,
      // а не по id кандидата.
      expect(batch.failed, hasLength(1));
      expect(batch.failed.single.candidateId, 'c2');
      expect(batch.failed.single.title, isNotEmpty);
      expect(batch.firstFailure!.kind, FailureKind.server);
      // Начисление создано только там, где оно выставлено.
      expect(batch.charges, hasLength(1));
      expect(batch.charges.single.amount, 205);
    });

    test('Повтор идёт с теми же ключами и не создаёт второй счёт', () async {
      final repo = fake();
      repo.failConnect('c2', const AppFailure.server());
      final plan = planOf(repo);
      await repo.connectPlan(plan);

      // Поставщик ожил, пользователь нажал «повторить» — план ТОТ ЖЕ.
      repo.clearFailures();
      final again = await repo.connectPlan(plan);

      expect(again.isSuccess, isTrue);
      // c1 и c3 уже подключены: источник отдал прежний результат по ключу.
      expect(repo.callsOf('connect.repeat'), 2);
      expect(repo.connected.map((a) => a.accountNo).toSet(), hasLength(3));
      expect(repo.keyOf['c1'], plan.keyOf('c1'));
    });

    test('Без сети план целиком уходит в очередь, а не в отказ', () async {
      final repo = fake();
      final plan = planOf(repo);
      repo.online = false;

      final batch = await repo.connectPlan(plan);

      expect(batch.queued, ['c1', 'c2', 'c3']);
      // Очередь — это не отказ: подключим, когда появится сеть.
      expect(batch.failed, isEmpty);
      expect(repo.connected, isEmpty);
    });

    test('Фейк соблюдает код подтверждения и считает вызовы', () async {
      final repo = FakeAccountsRepository(
        candidates: [
          candidate(id: 'c1', accountNo: 'OSH-44120', holder: 'Жээнбеков К.', needsConfirm: true),
        ],
        clock: at(testNow),
      );

      final wrong = await repo.confirm(candidateId: 'c1', code: '0000');
      expect(wrong.failureOrNull!.field, 'code');

      final right = await repo.confirm(candidateId: 'c1', code: '4815');
      expect(right.valueOrNull!.needsConfirm, isFalse);
      expect(repo.callsOf('confirm'), 2);
    });
  });
}
