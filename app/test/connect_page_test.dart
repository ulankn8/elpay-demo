import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/data/bills_repository.dart';
import 'package:elpay/data/connect_rules.dart';
import 'package:elpay/data/models.dart';
import 'package:elpay/features/accounts/charges_preview.dart';
import 'package:elpay/features/accounts/connect_args.dart';
import 'package:elpay/features/accounts/connect_page.dart';
import 'package:elpay/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fake_accounts_repository.dart';
import 'support/fixtures.dart';
import 'support/probe_api.dart';
import 'support/widget_harness.dart';

/// ЕДИНСТВЕННЫЙ виджет-тест мастера подключения.
///
/// Он проверяет вёрстку и переходы, а не правила: что показать, что
/// отметить и что отправить, решает `ConnectRules` — это проверено
/// синхронными юнит-тестами (connect_rules_test), а оркестрация —
/// в connect_flow_test. Дублировать их виджет-тестом значит платить
/// секундами за то, что уже проверено миллисекундами.
///
/// Группы здесь три: мастер целиком, шаг предпросмотра и экран итога —
/// шаги проверяются отдельно от прохода по мастеру, иначе падение вёрстки
/// одного шага не отличить от сломанного перехода.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FakeAccountsRepository fake() => FakeAccountsRepository(
        candidates: [
          candidate(id: 'c-water', accountNo: '31-00562', amount: 205),
          candidate(
            id: 'c-gas',
            accountNo: '55-20841',
            providerId: 'p-gas',
            providerTitle: 'Ошгаз',
            amount: 420,
          ),
          candidate(
            id: 'c-trash',
            accountNo: '04-118725',
            providerId: 'p-trash',
            providerTitle: 'Тазалык',
            amount: 0,
          ),
        ],
        clock: () => testNow,
        ids: SeqIdGen(),
      );

  group('Мастер целиком', () {
    /// Открыть мастер так, как его открывает маршрут `/connect`.
    ///
    /// [withObjects] = false — у пользователя нет ни одного объекта:
    /// источник отдаёт пустой список, и счёт подключать некуда.
    Future<TestEnv> openWizard(
      WidgetTester tester, {
      required FakeAccountsRepository repo,
      ConnectArgs args = const ConnectArgs(),
      bool withObjects = true,
    }) async {
      final env = makeEnv();
      addTearDown(env.dispose);

      BillsRepository? bills;
      if (!withObjects) {
        final probe = ProbeElPayApi(env.api)..onObjects = (_) => const <PayObject>[];
        bills = DefaultBillsRepository(
          api: probe,
          // Своё хранилище: иначе в кэше окажутся объекты, записанные
          // стендом, и «объектов нет» проверить не выйдет.
          store: MemoryLocalStore(),
          clock: () => env.now,
        );
      }

      await pumpRouteUnderTest(
        tester,
        ConnectAccountPage(args: args),
        overrides: await env.overrides(
          accountsRepo: repo,
          billsRepo: bills,
          session: testSession,
        ),
      );
      await settleData(tester);
      return env;
    }

    /// Ввести номер и нажать «Найти».
    Future<void> searchFor(WidgetTester tester, String accountNo) async {
      await tester.enterText(find.byType(TextField).first, accountNo);
      await tester.tap(find.text('Найти'));
      await settleData(tester);
    }

    testWidgets('Мастер проходит путь поиск → найденное → предпросмотр → готово',
        (tester) async {
      final repo = fake();
      await openWizard(tester, repo: repo);

      // ШАГ 1 — форма.
      expect(find.text('Подключение счёта'), findsOneWidget);
      expect(find.text('Найти'), findsOneWidget);

      // ШАГ 2 — найденное.
      await searchFor(tester, '31-00562');
      expect(find.text('Нашли 1 счёт'), findsOneWidget);
      expect(find.text('Ошводоканал'), findsWidgets);
      expect(find.text('Посмотреть начисления'), findsOneWidget);

      // ШАГ 3 — предпросмотр: пользователь видит, ЧТО будет приходить,
      // ещё до подключения.
      await tester.tap(find.text('Посмотреть начисления'));
      await settleData(tester);
      expect(find.text('Что будет приходить'), findsOneWidget);
      expect(find.text('Начислено по выбранным'), findsOneWidget);

      // ШАГ 4 — итог.
      await tester.tap(find.text('Подключить счёт'));
      await settleData(tester);
      expect(find.text('Подключили 1 счёт'), findsOneWidget);
      expect(find.text('К моим счетам'), findsOneWidget);
      expect(repo.connected.map((a) => a.accountNo), ['31-00562']);

      // «К моим счетам» уводит в список счетов, а не оставляет на итоге.
      await tester.tap(find.text('К моим счетам'));
      await settleData(tester);
      expect(find.text('ЗАГЛУШКА: счета'), findsOneWidget);
    });

    testWidgets('С предпросмотра «назад» возвращает к найденному, а не '
        'закрывает мастер', (tester) async {
      await openWizard(tester, repo: fake());
      await searchFor(tester, '31-00562');
      await tester.tap(find.text('Посмотреть начисления'));
      await settleData(tester);

      await tester.tap(find.text('Назад'));
      await settleData(tester);

      // Один промах по стрелке не должен стоить всего ввода.
      expect(find.text('Нашли 1 счёт'), findsOneWidget);
      expect(find.text('Подключение счёта'), findsOneWidget);
    });

    testWidgets('Ошибка формата номера показывается под полем, а не снеком',
        (tester) async {
      final repo = fake();
      // С поставщиком известен формат счёта: '31-01187', семь цифр.
      await openWizard(
        tester,
        repo: repo,
        args: const ConnectArgs(providerId: 'p-water', source: 'service'),
      );

      await searchFor(tester, '123');

      // Образец формата полезнее общего «проверьте номер».
      expect(find.text('Формат: 31-01187'), findsOneWidget);
      // Снека нет: ошибка видна там, где ошиблись.
      expect(find.byType(SnackBar), findsNothing);
      // И запрос не потрачен: формат проверяется ДО сети.
      expect(repo.callsOf('search'), 0);
      expect(find.text('Нашли 1 счёт'), findsNothing);
    });

    testWidgets('Ничего не нашлось — понятное пустое состояние, а не тишина',
        (tester) async {
      await openWizard(tester, repo: fake());

      await searchFor(tester, '99-99999');

      expect(find.text('По этим данным счетов не нашлось'), findsOneWidget);
    });

    testWidgets('При отсутствии объектов показывается подсказка создать '
        'объект, а не пустой экран', (tester) async {
      await openWizard(tester, repo: fake(), withObjects: false);

      expect(find.text('Сначала добавьте объект'), findsOneWidget);
      expect(find.text('Создать объект'), findsOneWidget);
      // Формы нет совсем: искать счёт, который некуда подключить, незачем.
      expect(find.text('Найти'), findsNothing);

      await tester.tap(find.text('Создать объект'));
      await settleData(tester);
      expect(find.text('ЗАГЛУШКА: объекты'), findsOneWidget);
    });

    testWidgets('Частичный успех показывает и подключённые, и непрошедшие',
        (tester) async {
      final repo = fake();
      await openWizard(tester, repo: repo);
      // Поиск по адресу: в квартире три счёта.
      await tester.tap(find.text('По адресу'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Найти'));
      await settleData(tester);
      expect(find.text('Нашли 3 счёта'), findsOneWidget);

      repo.failConnect('c-gas', const AppFailure.server('реестр недоступен'));
      await tester.tap(find.text('Подключить выбранные · 3'));
      await settleData(tester);

      // Заголовок не спорит с итогом: «Счёт подключён» при частичном
      // успехе — ровно то вранье, из-за которого упавший счёт не замечали.
      expect(find.text('Подключено 2 из 3'), findsOneWidget);
      expect(find.text('Счёт подключён'), findsNothing);
      expect(find.text('Не удалось: Ошгаз'), findsOneWidget);
      expect(find.text('Повторить для неудачных'), findsOneWidget);
    });

    testWidgets('Уже подключённый счёт ведёт на его экран, а не создаёт дубль',
        (tester) async {
      final repo = FakeAccountsRepository(
        candidates: [
          candidate(id: 'c-water', accountNo: '31-00562', alreadyConnected: true),
        ],
        connected: [account(id: 'acc-1', accountNo: '31-00562')],
        clock: () => testNow,
      );
      await openWizard(tester, repo: repo);

      await searchFor(tester, '31-00562');
      // Отметить такой счёт нельзя — только открыть.
      expect(find.text('Посмотреть начисления'), findsNothing);
      await tester.tap(find.text('Ошводоканал').first);
      await settleData(tester);

      expect(find.text('ЗАГЛУШКА: счёт'), findsOneWidget);
      expect(repo.callsOf('connect'), 0);
    });

    testWidgets('Счёт на чужое имя просит код шторкой, а не молча пропускает',
        (tester) async {
      final repo = FakeAccountsRepository(
        candidates: [
          candidate(
            id: 'c-net',
            accountNo: 'OSH-44120',
            providerId: 'p-saima',
            providerTitle: 'Сайма Телеком',
            holder: 'Жээнбеков К.',
            needsConfirm: true,
            amount: 700,
          ),
        ],
        clock: () => testNow,
      );
      await openWizard(tester, repo: repo);
      await searchFor(tester, 'OSH-44120');

      // Тап по строке открывает шторку подтверждения. Текст «Подтвердите,
      // что счёт ваш» к этому моменту на экране дважды: чип в строке и
      // заголовок шторки — поэтому саму шторку ищем по её кнопке.
      await tester.tap(find.text('Сайма Телеком').first);
      await settleData(tester);
      expect(find.text('Подтвердите, что счёт ваш'), findsNWidgets(2));
      expect(find.text('Продолжить'), findsOneWidget);

      // Неверный код подсвечивает поле и шторку не закрывает.
      await tester.enterText(find.byType(TextField).last, '0000');
      await tester.tap(find.text('Продолжить'));
      await settleData(tester);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(repo.callsOf('confirm'), 1);
    });
  });

  group('Шаг предпросмотра', () {
    /// Предпросмотр считает `ConnectRules` — виджет только рисует.
    ChargesPreview previewOf(List<AccountCandidate> candidates) =>
        const ConnectRules().preview(
          [for (final c in candidates) CandidateView(candidate: c)],
          now: testNow,
        );

    Future<void> pumpPreview(
      WidgetTester tester, {
      required ChargesPreview preview,
      VoidCallback? onBack,
      VoidCallback? onConnect,
    }) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await pumpWidgetUnderTest(
        tester,
        ChargesPreviewView(
          preview: preview,
          onBack: onBack ?? () {},
          onConnect: onConnect ?? () {},
        ),
        overrides: await env.overrides(session: testSession),
      );
      await settleData(tester, steps: 2);
    }

    testWidgets('Начисления, итог и ближайший срок видны до подключения',
        (tester) async {
      await pumpPreview(
        tester,
        preview: previewOf([
          candidate(id: 'c-water', accountNo: '31-00562', amount: 205, dueDay: 20),
          candidate(
            id: 'c-gas',
            accountNo: '55-20841',
            providerId: 'p-gas',
            providerTitle: 'Ошгаз',
            amount: 420,
            dueDay: 25,
          ),
        ]),
      );

      expect(find.text('Ошводоканал'), findsOneWidget);
      expect(find.text('Ошгаз'), findsOneWidget);
      expect(find.text('Начислено по выбранным'), findsOneWidget);
      // Итог 205 + 420 и ближайший из двух сроков — 20 марта.
      expect(find.textContaining('625', findRichText: true), findsWidgets);
      expect(find.textContaining('20 мар'), findsWidgets);
    });

    testWidgets('Счёт без начисления показан отдельно и суммы не обещает',
        (tester) async {
      await pumpPreview(
        tester,
        preview: previewOf([
          candidate(id: 'c-water', accountNo: '31-00562', amount: 205),
          candidate(
            id: 'c-trash',
            accountNo: '04-118725',
            providerId: 'p-trash',
            providerTitle: 'Тазалык',
            amount: 0,
          ),
        ]),
      );

      // Счёт подключится, но начисления на 0 сом ему не создадут —
      // именно такое фальшивое начисление ломало разбивку на главной.
      expect(find.text('Тазалык'), findsOneWidget);
      expect(find.text('Начислений пока нет'), findsWidgets);
    });

    testWidgets('«Подключить» и «Назад» делают именно то, что написано',
        (tester) async {
      var connected = 0;
      var back = 0;
      await pumpPreview(
        tester,
        preview: previewOf([
          candidate(id: 'c-water', accountNo: '31-00562', amount: 205),
        ]),
        onConnect: () => connected++,
        onBack: () => back++,
      );

      await tester.tap(find.text('Подключить счёт'));
      await tester.tap(find.text('Назад'));

      expect(connected, 1);
      expect(back, 1);
    });

    testWidgets('Пустой предпросмотр не рисует пустую карточку', (tester) async {
      await pumpPreview(tester, preview: previewOf(const []));

      expect(find.text('Начислений пока нет'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Экран итога', () {
    Future<void> pumpResult(
      WidgetTester tester, {
      required ConnectOutcome outcome,
      VoidCallback? onDone,
    }) async {
      final env = makeEnv();
      addTearDown(env.dispose);
      await pumpWidgetUnderTest(
        tester,
        ConnectResultView(outcome: outcome, onDone: onDone ?? () {}),
        overrides: await env.overrides(session: testSession),
      );
      await settleData(tester, steps: 2);
    }

    testWidgets('Полный успех называет число счетов и их начисления',
        (tester) async {
      await pumpResult(
        tester,
        outcome: ConnectOutcome(
          connected: [account(id: 'acc-1', accountNo: '31-00562')],
          charges: [charge(id: 'b1', accountId: 'acc-1', amount: 205)],
        ),
      );

      expect(find.text('Подключили 1 счёт'), findsOneWidget);
      expect(find.text('Ошводоканал'), findsOneWidget);
      expect(find.textContaining('205', findRichText: true), findsWidgets);
      expect(find.text('К моим счетам'), findsOneWidget);
      expect(find.text('Повторить для неудачных'), findsNothing);
    });

    testWidgets('Частичный успех показывает и подключённые, и непрошедшие',
        (tester) async {
      await pumpResult(
        tester,
        outcome: ConnectOutcome(
          connected: [
            account(id: 'acc-1', accountNo: '31-00562'),
            account(
              id: 'acc-2',
              accountNo: '04-118725',
              providerId: 'p-trash',
              title: 'Тазалык',
              cat: 'trash',
            ),
          ],
          charges: [charge(id: 'b1', accountId: 'acc-1', amount: 205)],
          failed: const [
            ConnectFailure('c-gas', 'Ошгаз', AppFailure.server('реестр недоступен')),
          ],
        ),
      );

      // Заголовок не спорит с итогом: «Счёт подключён» при частичном
      // успехе — ровно то вранье, из-за которого упавший счёт не замечали.
      expect(find.text('Подключено 2 из 3'), findsOneWidget);
      expect(find.text('Подключили 2 счёта'), findsNothing);
      // Причина — по каждому счёту, а не одним снеком, и текстом из S,
      // а не техническим сообщением источника.
      expect(find.text('Не удалось: Ошгаз'), findsOneWidget);
      expect(find.text('Сервер не ответил'), findsOneWidget);
      expect(find.textContaining('реестр недоступен'), findsNothing);
      expect(find.text('Повторить для неудачных'), findsOneWidget);
      // Подключённые при этом видны — оба факта на одном экране.
      expect(find.text('Ошводоканал'), findsOneWidget);
      expect(find.text('Тазалык'), findsOneWidget);
    });

    testWidgets('Счёт без начисления помечен, а не показан нулём',
        (tester) async {
      await pumpResult(
        tester,
        outcome: ConnectOutcome(
          connected: [account(id: 'acc-1', accountNo: '31-00562')],
        ),
      );

      expect(find.text('Начислений пока нет'), findsOneWidget);
      expect(find.textContaining('0 сом', findRichText: true), findsNothing);
    });

    testWidgets('Ушедшее в очередь названо очередью, а не отказом',
        (tester) async {
      await pumpResult(
        tester,
        outcome: ConnectOutcome(
          connected: [account(id: 'acc-1', accountNo: '31-00562')],
          queued: const ['c-gas'],
        ),
      );

      expect(find.text('Подключено 1 из 2'), findsOneWidget);
      // Очередь — это не ошибка: подключим, когда появится сеть.
      expect(find.text('Сервер не ответил'), findsNothing);
      expect(find.textContaining('сет'), findsWidgets);
    });

    testWidgets('«К моим счетам» возвращает к списку', (tester) async {
      var done = 0;
      await pumpResult(
        tester,
        outcome: ConnectOutcome(
          connected: [account(id: 'acc-1', accountNo: '31-00562')],
        ),
        onDone: () => done++,
      );

      await tester.tap(find.text('К моим счетам'));

      expect(done, 1);
    });
  });
}
