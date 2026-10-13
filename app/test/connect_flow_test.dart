import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fake_accounts_repository.dart';
import 'support/fixtures.dart';

/// Сценарий подключения счёта целиком: форма → найденное → предпросмотр →
/// честный итог, через `ConnectNotifier` — то есть ровно тот путь, по
/// которому ходит экран, но без вёрстки.
///
/// Источник подменён [FakeAccountsRepository]: демо-бэкенд честный, и им
/// не воспроизвести то, что должно случаться РЕДКО — отказ по одному счёту
/// из трёх и повтор по уже использованному ключу. Правила (`ConnectRules`)
/// проверяются отдельно и синхронно в connect_rules_test; здесь —
/// оркестрация: что состояние делает с их решениями.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Кандидаты по адресу семьи: вода с начислением, газ с начислением,
  /// мусор без начисления и интернет на чужое имя.
  FakeAccountsRepository fake({List<AccountCandidate>? candidates}) =>
      FakeAccountsRepository(
        candidates: candidates ??
            [
              candidate(id: 'c-water', accountNo: '31-00562', amount: 205),
              candidate(
                id: 'c-gas',
                accountNo: '55-20841',
                providerId: 'p-gas',
                providerTitle: 'Ошгаз',
                amount: 420,
              ),
              // Счёт есть, начисления нет — обычное состояние, и Bill
              // на 0 сом по нему создавать нельзя.
              candidate(
                id: 'c-trash',
                accountNo: '04-118725',
                providerId: 'p-trash',
                providerTitle: 'Тазалык',
                amount: 0,
              ),
              // Счёт оформлен на другого человека: нужен код из квитанции.
              candidate(
                id: 'c-net',
                accountNo: 'OSH-44120',
                providerId: 'p-saima',
                providerTitle: 'Сайма Телеком',
                holder: 'Жээнбеков К.',
                needsConfirm: true,
                amount: 700,
              ),
              // Другая квартира: по адресу семьи находиться не должен.
              candidate(
                id: 'c-parents',
                accountNo: '7710-5521',
                providerId: 'p-power',
                providerTitle: 'Ошэлектро',
                address: parentsAddress,
                amount: 310,
              ),
            ],
        clock: () => testNow,
        ids: SeqIdGen(),
      );

  /// Мастер поверх стенда. [withObjects] = false оставляет пользователя
  /// без объектов — счёт подключать некуда.
  Future<({TestEnv env, ProviderContainer c, ConnectNotifier notifier})> wizard(
    FakeAccountsRepository repo, {
    bool withObjects = true,
  }) async {
    final env = makeEnv();
    addTearDown(env.dispose);
    final c = await env.container(accountsRepo: repo, session: testSession);
    // Объекты приходят из начислений: без них правила не дадут плана.
    if (withObjects) await c.read(billsProvider.future);
    return (env: env, c: c, notifier: c.read(connectProvider.notifier));
  }

  /// Адрес семьи полями формы.
  Future<void> searchHome(ConnectNotifier notifier) => notifier.searchByAddress(
        city: 'Ош',
        street: 'ул. Курманжан Датка',
        house: '212',
        flat: '14',
      );

  group('Поиск', () {
    test('Поиск по лицевому счёту находит счёт в реестре', () async {
      final w = await wizard(fake());

      await w.notifier.searchByAccount('31-00562');

      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.results);
      expect(state.searching, isFalse);
      expect(state.views, hasLength(1));
      expect(state.views.single.candidate.accountNo, '31-00562');
      // Готовый счёт отмечен сразу — пользователю нечего доделывать.
      expect(state.selected, {'c-water'});
      // Объект предложен по совпадению адреса, а не «какой-нибудь».
      expect(state.suggestedObjectId, 'o1');
    });

    test('Поиск по адресу находит все счета квартиры', () async {
      final w = await wizard(fake());

      await searchHome(w.notifier);

      final state = w.c.read(connectProvider);
      expect(state.byAddress, isTrue);
      expect(
        state.views.map((v) => v.id),
        containsAll(<String>['c-water', 'c-gas', 'c-trash', 'c-net']),
      );
      // Чужая квартира в выдачу не попадает.
      expect(state.views.map((v) => v.id), isNot(contains('c-parents')));
    });

    test('Поиск по адресу с фильтром поставщика возвращает только его счета',
        () async {
      final w = await wizard(fake());

      // С значка услуги на главной приходят уже с поставщиком.
      w.notifier.pickProvider('p-gas');
      await searchHome(w.notifier);

      final state = w.c.read(connectProvider);
      expect(state.views, hasLength(1));
      expect(state.views.single.candidate.providerId, 'p-gas');
    });

    test('Пустой номер не тратит запрос и садится в ошибку поля', () async {
      final repo = fake();
      final w = await wizard(repo);

      await w.notifier.searchByAccount('   ');

      final state = w.c.read(connectProvider);
      expect(repo.callsOf('search'), 0, reason: 'проверка формы идёт ДО сети');
      expect(state.step, ConnectStep.form);
      expect(state.failure!.kind, FailureKind.validation);
      expect(state.fieldErrors.keys, contains('accountNo'));
    });
  });

  group('Подтверждение владения', () {
    test('Счёт на чужое имя требует код, неверный код даёт validation '
        'с полем code', () async {
      final w = await wizard(fake());
      await w.notifier.searchByAccount('OSH-44120');
      expect(w.c.read(connectProvider).views.single.needsConfirm, isTrue);

      final result = await w.notifier.confirm('c-net', '0000');

      expect(result.isFail, isTrue);
      expect(result.failureOrNull!.kind, FailureKind.validation);
      expect(result.failureOrNull!.field, 'code');
      final state = w.c.read(connectProvider);
      // Ошибка идёт в поле шторки, а не в снек, и строка остаётся живой.
      expect(state.fieldErrors['code'], isNotNull);
      expect(state.confirming, isEmpty);
      expect(state.views.single.needsConfirm, isTrue);
    });

    test('Верный код снимает блок needsConfirm и кандидат попадает в план',
        () async {
      final w = await wizard(fake());
      await w.notifier.searchByAccount('OSH-44120');
      // Счёт на чужое имя сам галочкой не отмечается — его ставит
      // пользователь, а код спрашивается уже при подключении.
      expect(w.c.read(connectProvider).selected, isEmpty);
      w.notifier.toggle('c-net');

      final result = await w.notifier.confirm('c-net', '4815');

      expect(result.isOk, isTrue);
      final view = w.c.read(connectProvider).views.single;
      expect(view.confirmed, isTrue);
      expect(view.needsConfirm, isFalse);
      expect(view.ready, isTrue);

      // И после подтверждения он действительно подключается. Объект
      // выбираем руками: адреса у чужого счёта с объектами не совпали,
      // и правила намеренно не угадывают, куда его класть.
      w.notifier.pickObject('o1');
      final outcome = await w.notifier.connectChosen();
      await settleProviders();
      expect(outcome.connected.map((a) => a.accountNo), ['OSH-44120']);
    });
  });

  group('Предпросмотр', () {
    test('Предпросмотр считает выбранное и не создаёт строку для счёта '
        'без начисления', () async {
      final w = await wizard(fake());
      await searchHome(w.notifier);

      w.notifier.preview(null);

      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.preview);
      final preview = state.preview!;
      expect(preview.lines.map((l) => l.view.id), ['c-water', 'c-gas']);
      expect(preview.total, 205 + 420);
      // Счёт без начисления подключаем, но строки у него нет.
      expect(preview.withoutCharges.map((v) => v.id), ['c-trash']);
      expect(preview.count, 3);
    });

    test('«Назад» с предпросмотра возвращает к найденному, а не к форме',
        () async {
      final w = await wizard(fake());
      await searchHome(w.notifier);
      w.notifier.preview(null);

      w.notifier.backToResults();

      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.results);
      expect(state.preview, isNull);
      expect(state.views, isNotEmpty, reason: 'ввод не потерян');
    });
  });

  group('Подключение', () {
    test('Подключение создаёт счёт и начисление', () async {
      final repo = fake();
      final w = await wizard(repo);
      await w.notifier.searchByAccount('31-00562');

      final outcome = await w.notifier.connectChosen();
      await settleProviders();

      expect(outcome.isSuccess, isTrue);
      expect(outcome.connected, hasLength(1));
      expect(outcome.connected.single.accountNo, '31-00562');
      expect(outcome.connected.single.objectId, 'o1');
      expect(outcome.charges, hasLength(1));
      expect(outcome.charges.single.amount, 205);
      // Начисление знает свой счёт по id, а не по строке номера.
      expect(outcome.charges.single.accountId, outcome.connected.single.id);
      expect(outcome.failed, isEmpty);
      expect(outcome.queued, isEmpty);

      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.done);
      expect(state.failure, isNull);
      expect(state.connecting, isFalse);
    });

    test('Подключение счёта без начислений не создаёт Bill на 0 сом', () async {
      final w = await wizard(fake());
      await w.notifier.searchByAccount('04-118725');

      final outcome = await w.notifier.connectChosen();
      await settleProviders();

      expect(outcome.connected, hasLength(1));
      // Именно фальшивое начисление на 0 сом ломало разбивку на главной.
      expect(outcome.charges, isEmpty);
    });

    test('Повтор подключения с тем же ключом идемпотентности '
        'не создаёт второй счёт', () async {
      final repo = fake();
      final w = await wizard(repo);
      await searchHome(w.notifier);
      // Мусор в выборе не нужен: оставляем воду и газ.
      w.notifier.selectNone();
      w.notifier.toggle('c-water');
      w.notifier.toggle('c-gas');
      // Газ не прошёл — это даёт повод нажать «повторить».
      repo.failConnect('c-gas', const AppFailure.server('поставщик не ответил'));

      await w.notifier.connectChosen();
      await settleProviders();
      final keys = Map<String, IdempotencyKey>.from(w.c.read(connectProvider).keys);
      expect(keys.keys, containsAll(<String>['c-water', 'c-gas']));

      // Поставщик ожил, пользователь повторяет — и воду тоже, чтобы
      // проверить, что второй счёт по тому же ключу не появится.
      repo.clearFailures();
      w.notifier.toggle('c-water');
      final again = await w.notifier.connectChosen();
      await settleProviders();

      expect(again.connected.map((a) => a.accountNo).toSet(),
          {'31-00562', '55-20841'});
      // Ключи те же — источник отдал прежний результат, а не завёл дубль.
      expect(w.c.read(connectProvider).keys['c-water'], keys['c-water']);
      expect(w.c.read(connectProvider).keys['c-gas'], keys['c-gas']);
      expect(repo.keyOf['c-water'], keys['c-water']);
      expect(repo.callsOf('connect.repeat'), 1);
      expect(repo.connected.map((a) => a.accountNo),
          ['31-00562', '55-20841']);
    });

    test('Частичный успех: два счёта подключены, третий в failed с причиной',
        () async {
      final repo = fake();
      final w = await wizard(repo);
      await searchHome(w.notifier);
      repo.failConnect('c-gas', const AppFailure.server('реестр недоступен'));

      final outcome = await w.notifier.connectChosen();
      await settleProviders();

      expect(outcome.total, 3);
      expect(outcome.isPartial, isTrue);
      expect(outcome.isSuccess, isFalse);
      expect(outcome.isTotalFailure, isFalse);
      expect(outcome.connected.map((a) => a.accountNo),
          ['31-00562', '04-118725']);
      expect(outcome.failed, hasLength(1));
      expect(outcome.failed.single.candidateId, 'c-gas');
      expect(outcome.failed.single.failure.kind, FailureKind.server);
    });

    test('Частичный успех не обнуляет сведения об упавшем счёте', () async {
      final repo = fake();
      final w = await wizard(repo);
      await searchHome(w.notifier);
      repo.failConnect('c-gas', const AppFailure.server('реестр недоступен'));

      await w.notifier.connectChosen();
      await settleProviders();

      final state = w.c.read(connectProvider);
      // Раньше при частичном успехе ошибка затиралась (failure: null),
      // и про упавший счёт пользователь не узнавал ВООБЩЕ. Теперь факт
      // живёт в итоге: экран рисует и подключённые, и непрошедшие.
      expect(state.step, ConnectStep.done);
      expect(state.outcome!.isPartial, isTrue);
      expect(state.outcome!.failed.single.candidateId, 'c-gas');
      expect(state.outcome!.failed.single.title, isNotEmpty,
          reason: 'счёт назван по поставщику, а не по id кандидата');
      expect(state.outcome!.firstFailure!.message, 'реестр недоступен');
      // Прошедшие из выбора ушли, упавший остался — повторять есть что.
      expect(state.selected, contains('c-gas'));
      expect(state.selected, isNot(contains('c-water')));
    });

    test('Полный отказ оставляет мастер на списке и называет причину',
        () async {
      final repo = fake();
      final w = await wizard(repo);
      await w.notifier.searchByAccount('31-00562');
      repo.failConnect('c-water', const AppFailure.server());

      final outcome = await w.notifier.connectChosen();

      expect(outcome.isTotalFailure, isTrue);
      final state = w.c.read(connectProvider);
      // Экран итога с «подключено 0» ничего пользователю не говорит.
      expect(state.step, ConnectStep.results);
      expect(state.failure!.kind, FailureKind.server);
    });

    test('Подключение без объектов возвращает validation с понятной причиной',
        () async {
      final repo = fake();
      final w = await wizard(repo, withObjects: false);
      await w.notifier.searchByAccount('31-00562');

      final outcome = await w.notifier.connectChosen();

      expect(outcome.isEmpty, isTrue);
      expect(repo.callsOf('connect'), 0, reason: 'в сеть не ходим');
      final state = w.c.read(connectProvider);
      // Раньше подключение в этом случае молча выходило из метода:
      // ни снека, ни подсказки — экран просто ничего не делал.
      expect(state.failure!.kind, FailureKind.validation);
      expect(state.failure!.field, 'objectId');
      expect(state.fieldErrors.keys, contains('objectId'));
      expect(state.connecting, isFalse);
    });

    test('Без сети план уходит в очередь, и это не объявляется ошибкой счёта',
        () async {
      final repo = fake();
      final w = await wizard(repo);
      await w.notifier.searchByAccount('31-00562');
      repo.online = false;

      final outcome = await w.notifier.connectChosen();

      expect(outcome.queued, ['c-water']);
      expect(outcome.failed, isEmpty);
      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.results);
      // Пользователь обязан услышать, что подключим, когда появится сеть.
      expect(state.failure!.kind, FailureKind.network);
    });
  });

  group('Вход в мастер', () {
    test('start сбрасывает прошлый ввод, но помнит, с чем пришли', () async {
      final w = await wizard(fake());
      await searchHome(w.notifier);
      expect(w.c.read(connectProvider).views, isNotEmpty);

      w.notifier.start(providerId: 'p-gas', objectId: 'o2', source: 'service');

      final state = w.c.read(connectProvider);
      expect(state.step, ConnectStep.form);
      expect(state.views, isEmpty);
      expect(state.selected, isEmpty);
      expect(state.providerId, 'p-gas');
      expect(state.objectId, 'o2');
    });

    test('Смена способа поиска чистит найденное, но не теряет поставщика',
        () async {
      final w = await wizard(fake());
      w.notifier.pickProvider('p-gas');
      await w.notifier.searchByAccount('55-20841');

      w.notifier.setMode(byAddress: true);

      final state = w.c.read(connectProvider);
      expect(state.byAddress, isTrue);
      expect(state.views, isEmpty);
      expect(state.providerId, 'p-gas');
    });
  });
}
