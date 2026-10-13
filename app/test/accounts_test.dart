import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/net/connectivity.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:elpay/core/result.dart';
import 'package:elpay/data/accounts_repository.dart';
import 'package:elpay/data/api/mock_api.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/data/registry_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({DefaultAccountsRepository repo, ManualConnectivity net, LocalStore store})>
    makeRepo() async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final net = ManualConnectivity();
  final repo = DefaultAccountsRepository(
    api: MockElPayApi(connectivity: net, latency: Duration.zero),
    store: store,
    connectivity: net,
    outbox: Outbox(store),
  );
  return (repo: repo, net: net, store: store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Поиск счёта', () {
    test('по лицевому счёту находит запись реестра', () async {
      final env = await makeRepo();
      final result = await env.repo.search(const AccountQuery.byAccount('31-00562'));

      expect(result.isOk, isTrue);
      final found = result.valueOrNull!;
      expect(found, hasLength(1));
      expect(found.first.providerTitle, contains('Ошводоканал'));
      expect(found.first.amount, 205);
    });

    test('по адресу находит все счета квартиры', () async {
      final env = await makeRepo();
      final (city, street, house, flat) = Registry.homeAddress;
      final result = await env.repo.search(
        AccountQuery.byAddress(city: city, street: street, house: house, flat: flat),
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.length, greaterThanOrEqualTo(5));
    });

    test('номер с пробелами и дефисами всё равно находится', () async {
      final env = await makeRepo();
      final result = await env.repo.search(const AccountQuery.byAccount(' 31 00562 '));
      expect(result.valueOrNull, hasLength(1));
    });

    test('чужой адрес ничего не находит', () async {
      final env = await makeRepo();
      final result = await env.repo.search(const AccountQuery.byAddress(
        city: 'Ош',
        street: 'ул. Несуществующая',
        house: '1',
      ));
      expect(result.valueOrNull, isEmpty);
    });

    test('без сети поиск возвращает ошибку сети', () async {
      final env = await makeRepo();
      env.net.setOnline(false);
      final result = await env.repo.search(const AccountQuery.byAccount('31-00562'));

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.network);
    });
  });

  group('Подтверждение владения', () {
    test('счёт на другого человека требует кода', () async {
      final env = await makeRepo();
      final found = await env.repo.search(const AccountQuery.byAccount('OSH-44120'));
      expect(found.valueOrNull!.first.needsConfirm, isTrue);
    });

    test('неверный код не подходит, верный — подтверждает', () async {
      final env = await makeRepo();
      final wrong = await env.repo.confirm(candidateId: 'reg-net-1', code: '0000');
      expect(wrong.isFail, isTrue);
      expect(wrong.failureOrNull!.kind, FailureKind.validation);

      final right = await env.repo.confirm(candidateId: 'reg-net-1', code: '4815');
      expect(right.isOk, isTrue);
      expect(right.valueOrNull!.needsConfirm, isFalse);
    });
  });

  group('Подключение счёта', () {
    test('подключение добавляет счёт и начисление', () async {
      final env = await makeRepo();
      final result = await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(result.isOk, isTrue);
      final value = result.valueOrNull!;
      expect(value.account.accountNo, '55-20841');
      expect(value.bill, isNotNull);
      expect(value.bill!.amount, 420);
      expect(value.bill!.objectId, 'o1');
    });

    test('повторное подключение того же счёта отклоняется', () async {
      final env = await makeRepo();
      await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      final again = await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(again.isFail, isTrue);
      expect(again.failureOrNull!.kind, FailureKind.validation);
    });

    test('подключённый счёт сохраняется в кэш', () async {
      final env = await makeRepo();
      await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');
      expect(env.repo.cachedAccounts().any((a) => a.accountNo == '55-20841'), isTrue);
    });

    test('уже подключённый счёт помечен в результатах поиска', () async {
      final env = await makeRepo();
      await env.repo.accounts();
      final found = await env.repo.search(const AccountQuery.byAccount('31-00562'));
      expect(found.valueOrNull!.first.alreadyConnected, isTrue);
    });

    test('без сети подключение уходит в очередь', () async {
      final env = await makeRepo();
      env.net.setOnline(false);
      final result = await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      expect(result.isFail, isTrue);
      expect(env.repo.outbox.length, 1);
      expect(env.repo.outbox.items.first.kind, 'connect_account');
    });

    test('когда сеть вернулась, очередь отправляется', () async {
      final env = await makeRepo();
      env.net.setOnline(false);
      await env.repo.connect(candidateId: 'reg-gas-1', objectId: 'o1');

      env.net.setOnline(true);
      final sent = await env.repo.flushOutbox();

      expect(sent, 1);
      expect(env.repo.outbox.isEmpty, isTrue);
      expect(env.repo.cachedAccounts().any((a) => a.accountNo == '55-20841'), isTrue);
    });
  });

  group('Отключение и обновление', () {
    test('отключение убирает счёт из кэша', () async {
      final env = await makeRepo();
      final connected = (await env.repo.accounts()).valueOrNull!;
      final first = connected.first;

      final result = await env.repo.disconnect(first.id);

      expect(result.isOk, isTrue);
      expect(env.repo.cachedAccounts().any((a) => a.id == first.id), isFalse);
    });

    test('обновление проставляет время синхронизации', () async {
      final env = await makeRepo();
      await env.repo.accounts();
      final result = await env.repo.sync();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.accounts.every((a) => a.syncedAt != null), isTrue);
      expect(result.valueOrNull!.accounts.every((a) => a.status == AccountSyncStatus.ok), isTrue);
    });

    test('без сети счета берутся из кэша, а не падают', () async {
      final env = await makeRepo();
      await env.repo.accounts();
      env.net.setOnline(false);

      final result = await env.repo.accounts(refresh: true);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });
  });
}
