import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/core/net/outbox.dart';
import 'package:elpay/core/result.dart';
import 'package:elpay/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/env.dart';

void main() {
  // Биндинг нужен ТОЛЬКО группе «LocalStore: боевая реализация»: она про
  // SharedPreferences и есть. Всё остальное обходится без него.
  TestWidgetsFlutterBinding.ensureInitialized();
  Log.enabled = false;

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

    test('ошибка валидации называет поле формы', () {
      const f = AppFailure.validation('номер не по формату', field: 'accountNo');

      // По этому полю ошибка садится в errorText, а не в снек.
      expect(f.field, 'accountNo');
      expect(f.isNetwork, isFalse);
    });
  });

  // Контракт хранилища один, реализаций две. Проверяем ОБЕ одним набором
  // ожиданий: иначе тесты гоняют MemoryLocalStore, а на устройстве
  // работает PrefsLocalStore, и расхождение находит пользователь.
  group('LocalStore: контракт', () {
    for (final (name, open) in <(String, Future<LocalStore> Function())>[
      ('в памяти', _openMemory),
      ('поверх SharedPreferences', _openPrefs),
    ]) {
      test('$name: пишет и читает список, помнит время', () async {
        final store = await open();

        await store.writeJson('bills', [
          {'id': 'b1', 'title': 'Вода'},
        ], now: testNow);

        expect(store.readList('bills'), hasLength(1));
        expect(store.readList('bills')!.first['title'], 'Вода');
        expect(store.updatedAt('bills'), testNow);
        expect(
          store.isStale('bills', const Duration(minutes: 10), now: testNow),
          isFalse,
        );
        expect(
          store.isStale('bills', const Duration(minutes: 10),
              now: testNow.add(const Duration(minutes: 11))),
          isTrue,
        );
      });

      test('$name: нет записи — считается устаревшей', () async {
        final store = await open();

        expect(store.isStale('bills', const Duration(days: 1), now: testNow), isTrue);
        expect(store.readList('bills'), isNull);
        expect(store.updatedAt('bills'), isNull);
      });

      test('$name: карта читается отдельно от списка', () async {
        final store = await open();

        await store.writeJson('catalog', {'providers': []}, now: testNow);

        expect(store.readMap('catalog'), isNotNull);
        // Запись есть, но это не список: читатель получает null, а не падение.
        expect(store.readList('catalog'), isNull);
      });

      test('$name: remove убирает и запись, и отметку времени', () async {
        final store = await open();
        await store.writeJson('bills', const [], now: testNow);

        await store.remove('bills');

        expect(store.readList('bills'), isNull);
        expect(store.updatedAt('bills'), isNull);
      });
    }
  });

  group('LocalStore: боевая реализация', () {
    test('clear стирает кэш и не задевает настройки', () async {
      SharedPreferences.setMockInitialValues({'flutter.session': 'оставить'});
      final store = await LocalStore.open();
      await store.writeJson('bills', const [], now: testNow);

      await store.clear();

      expect(store.readList('bills'), isNull);
      // Сессия, язык, тема и код-пароль живут в AppPrefs без префикса
      // 'cache.' — выход из кэша их не касается.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session'), 'оставить');
    });
  });

  group('MemoryLocalStore: то, чего нет у боевой', () {
    test('битая запись стирается при чтении', () {
      final store = MemoryLocalStore();
      store.corrupt('bills', now: testNow);

      expect(store.readList('bills'), isNull);
      expect(store.raw('bills'), isNull);
    });

    test('считает записи — по нему проверяется, что кэш дождались', () async {
      final store = MemoryLocalStore();

      await store.writeJson('bills', const [], now: testNow);
      await store.writeJson('bills', const [], now: testNow);

      expect(store.writes, 2);
      expect(store.keys, contains('bills'));
    });
  });

  group('Outbox', () {
    test('копит операции и отдаёт их по очереди', () async {
      final outbox = Outbox(MemoryLocalStore());

      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {'candidateId': 'reg-gas-1'},
        createdAt: testNow,
      ));

      expect(outbox.length, 1);
      final sent = await outbox.flush((item) async => true);
      expect(sent, 1);
      expect(outbox.isEmpty, isTrue);
    });

    test('неудачная отправка остаётся в очереди и считает попытки', () async {
      final outbox = Outbox(MemoryLocalStore());
      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {},
        createdAt: testNow,
      ));

      await outbox.flush((item) async => false);

      expect(outbox.length, 1);
      expect(outbox.items.first.attempts, 1);
    });

    test('после пяти неудач операция выбрасывается', () async {
      final outbox = Outbox(MemoryLocalStore());
      await outbox.add(OutboxItem(
        id: '1',
        kind: 'connect_account',
        payload: const {},
        createdAt: testNow,
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
        accountId: 'acc-b1',
        calc: const [Field('Тариф', '41 сом')],
        requisites: const [Field('ИНН', '0221')],
      );

      final back = Bill.fromJson(bill.toJson());

      expect(back.id, bill.id);
      expect(back.amount, bill.amount);
      expect(back.due, bill.due);
      // Привязка к счёту обязана переживать кэш: по ней убирают начисления
      // отключённого счёта.
      expect(back.accountId, 'acc-b1');
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
        pendingOp: AccountOp.disconnect,
        syncedAt: DateTime(2026, 10, 1),
        lastError: 'нет связи',
      );

      final back = ConnectedAccount.fromJson(account.toJson());

      expect(back.status, AccountSyncStatus.failed);
      expect(back.syncedAt, DateTime(2026, 10, 1));
      expect(back.lastError, 'нет связи');
      // Операция в очереди — тоже состояние устройства, а не экрана.
      expect(back.isPendingDisconnect, isTrue);
    });

    test('copyWith умеет СТЕРЕТЬ ошибку, а не только записать новую', () {
      final failed = ConnectedAccount(
        id: 'acc1',
        providerId: 'p-water',
        title: 'Ошводоканал',
        subtitle: '',
        cat: 'water',
        accountNo: '31-00562',
        objectId: 'o1',
        holder: 'Токтогулова А.',
        address: 'Ош',
        connectedAt: testNow,
        status: AccountSyncStatus.failed,
        lastError: 'нет связи',
      );

      // Без clearError прошлая ошибка переживала удачное обновление,
      // и в списке висела подпись об отказе, которого больше нет.
      expect(failed.copyWith(status: AccountSyncStatus.ok).lastError, 'нет связи');
      expect(
        failed.copyWith(status: AccountSyncStatus.ok, clearError: true).lastError,
        isNull,
      );
      expect(failed.copyWith(clearPendingOp: true).pendingOp, isNull);
    });
  });
}

Future<LocalStore> _openMemory() async => MemoryLocalStore();

Future<LocalStore> _openPrefs() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return LocalStore.open();
}
