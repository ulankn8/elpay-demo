import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:elpay/core/result.dart';
import 'package:elpay/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Result', () {
    test('Ok несёт значение, Fail — ошибку', () {
      const ok = Ok<int>(5);
      const fail = Fail<int>(AppFailure.network());

      expect(ok.isOk, isTrue);
      expect(ok.valueOrNull, 5);
      expect(fail.isFail, isTrue);
      expect(fail.failureOrNull!.kind, FailureKind.network);
      expect(fail.valueOrNull, isNull);
    });

    test('fold выбирает нужную ветку', () {
      const ok = Ok<int>(2);
      const fail = Fail<int>(AppFailure.notFound());

      expect(ok.fold((v) => 'ок $v', (f) => 'ошибка'), 'ок 2');
      expect(fail.fold((v) => 'ок', (f) => 'ошибка ${f.kind.name}'), 'ошибка notFound');
    });

    test('map меняет значение, ошибку пропускает', () {
      expect(const Ok<int>(3).map((v) => v * 2).valueOrNull, 6);
      expect(const Fail<int>(AppFailure.auth()).map((v) => v * 2).isFail, isTrue);
    });

    test('guard превращает исключение в Fail', () async {
      final ok = await guard<int>(() async => 1);
      final bad = await guard<int>(() async => throw StateError('упало'));
      final typed = await guard<int>(() async => throw const AppFailure.notFound());

      expect(ok.valueOrNull, 1);
      expect(bad.failureOrNull!.kind, FailureKind.unknown);
      expect(typed.failureOrNull!.kind, FailureKind.notFound);
    });

    test('unwrap бросает ошибку', () {
      expect(() => const Fail<int>(AppFailure.server()).unwrap(), throwsA(isA<AppFailure>()));
    });
  });

  group('AppFailure', () {
    test('сетевые и серверные можно повторить, валидацию — нет', () {
      expect(const AppFailure.network().isRetryable, isTrue);
      expect(const AppFailure.server().isRetryable, isTrue);
      expect(const AppFailure.validation('плохо').isRetryable, isFalse);
    });
  });

  group('LocalStore', () {
    test('пишет и читает список, помнит время', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final now = DateTime(2026, 10, 13, 9, 30);

      await store.writeJson('bills', [
        {'id': 'b1', 'title': 'Вода'},
      ], now: now);

      expect(store.readList('bills'), hasLength(1));
      expect(store.updatedAt('bills'), now);
      expect(store.isStale('bills', const Duration(minutes: 10), now: now), isFalse);
      expect(
        store.isStale('bills', const Duration(minutes: 10),
            now: now.add(const Duration(minutes: 11))),
        isTrue,
      );
    });

    test('нет записи — считается устаревшей', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      expect(store.isStale('bills', const Duration(days: 1), now: DateTime(2026)), isTrue);
      expect(store.readList('bills'), isNull);
    });

    test('clear стирает только кэш', () async {
      SharedPreferences.setMockInitialValues({'flutter.session': 'оставить'});
      final store = await LocalStore.open();
      await store.writeJson('bills', [], now: DateTime(2026));

      await store.clear();

      expect(store.readList('bills'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session'), 'оставить');
    });
  });

  group('Outbox', () {
    test('копит операции и отдаёт их по очереди', () async {
      SharedPreferences.setMockInitialValues({});
      final outbox = Outbox(await LocalStore.open());

      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {'candidateId': 'reg-gas-1'},
        createdAt: DateTime(2026, 10, 13),
      ));

      expect(outbox.length, 1);
      final sent = await outbox.flush((item) async => true);
      expect(sent, 1);
      expect(outbox.isEmpty, isTrue);
    });

    test('неудачная отправка остаётся в очереди и считает попытки', () async {
      SharedPreferences.setMockInitialValues({});
      final outbox = Outbox(await LocalStore.open());
      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {},
        createdAt: DateTime(2026, 10, 13),
      ));

      await outbox.flush((item) async => false);

      expect(outbox.length, 1);
      expect(outbox.items.first.attempts, 1);
    });

    test('после пяти неудач операция выбрасывается', () async {
      SharedPreferences.setMockInitialValues({});
      final outbox = Outbox(await LocalStore.open());
      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {},
        createdAt: DateTime(2026, 10, 13),
      ));

      for (var i = 0; i < 5; i++) {
        await outbox.flush((item) async => false);
      }

      expect(outbox.isEmpty, isTrue);
    });
  });

  group('Сериализация моделей', () {
    test('счёт переживает запись в кэш и чтение обратно', () {
      final bill = Bill(
        id: 'b1',
        title: 'Водоканал',
        subtitle: 'Холодная вода',
        cat: 'water',
        amount: 205,
        objectId: 'o1',
        period: 'сентябрь 2026',
        due: DateTime(2026, 9, 20),
        account: '31-00562',
        calc: const [Field('Тариф', '41 сом')],
        requisites: const [Field('ИНН', '0221')],
      );

      final back = Bill.fromJson(bill.toJson());

      expect(back.id, bill.id);
      expect(back.amount, bill.amount);
      expect(back.due, bill.due);
      expect(back.calc.first.value, '41 сом');
      expect(back.requisites.first.label, 'ИНН');
    });

    test('подключённый счёт переживает запись и чтение', () {
      final account = ConnectedAccount(
        id: 'acc1',
        providerId: 'p-water',
        title: 'Ошводоканал',
        subtitle: 'Холодная вода',
        cat: 'water',
        accountNo: '31-00562',
        objectId: 'o1',
        holder: 'Токтогулова А.',
        address: 'Ош',
        connectedAt: DateTime(2026, 9, 1),
        status: AccountSyncStatus.failed,
        syncedAt: DateTime(2026, 10, 1),
        lastError: 'нет связи',
      );

      final back = ConnectedAccount.fromJson(account.toJson());

      expect(back.status, AccountSyncStatus.failed);
      expect(back.syncedAt, DateTime(2026, 10, 1));
      expect(back.lastError, 'нет связи');
    });
  });
}
