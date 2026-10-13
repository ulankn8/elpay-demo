import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/core/service_cat.dart';
import 'package:elpay/data/connect_rules.dart';
import 'package:elpay/data/demo_data.dart';
import 'package:elpay/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';
import 'support/fixtures.dart';

/// Главный тест фичи подключения — обычный юнит-тест.
///
/// Ни async, ни ProviderContainer, ни биндинга: [ConnectRules] синхронны и
/// ничего не знают про Flutter. Поэтому эти же правила покрывают и боевую
/// реализацию, а не только демо-бэкенд.
void main() {
  Log.enabled = false;

  const rules = ConnectRules();
  final water = Demo.catalog.providerById('p-water')!;

  group('Проверка формы до сети', () {
    test('Нормализация номера убирает пробелы, дефисы и № и приводит ё к е', () {
      final q = rules.buildAccountQuery('№ 31 01187 ', provider: water);

      expect(q.isOk, isTrue);
      // Номер приведён к виду поставщика, а не отправлен как напечатали.
      expect(q.valueOrNull!.accountNo, '31-01187');
      expect(q.valueOrNull!.providerId, 'p-water');

      // «Ё» в номере не делает его другим номером.
      expect(AccountMask.clean('ОШ-ёЁ/12'), 'ОШЕЕ12');
      expect(AccountMask.keyOf(' 31 00562 '), AccountMask.keyOf('31-00562'));
    });

    test('Номер не по маске поставщика даёт validation с полем accountNo и не идёт в сеть', () {
      // Правило синхронное: сети здесь нет вовсе, поэтому неверный номер
      // физически не может превратиться в запрос.
      final short = rules.buildAccountQuery('12345', provider: water);

      expect(short.isFail, isTrue);
      expect(short.failureOrNull!.kind, FailureKind.validation);
      expect(short.failureOrNull!.field, ConnectRules.fieldAccountNo);
      // Образец попадает в текст: пользователь видит, чего от него хотят.
      expect(short.failureOrNull!.message, contains('31-01187'));

      final empty = rules.buildAccountQuery('   ', provider: water);
      expect(empty.failureOrNull!.field, ConnectRules.fieldAccountNo);
    });

    test('Адресный запрос требует улицу и доносит поставщика', () {
      final noStreet = rules.buildAddressQuery(city: 'Ош', street: '  ', house: '212');
      expect(noStreet.failureOrNull!.field, 'street');

      final ok = rules.buildAddressQuery(
        city: 'Ош',
        street: 'ул. Масалиева',
        house: '44',
        flat: '12',
        providerId: 'p-power',
      );
      expect(ok.isOk, isTrue);
      // Поиск от значка услуги показывает ОДНОГО поставщика: id обязан
      // доехать до запроса, а не потеряться по дороге.
      expect(ok.valueOrNull!.providerId, 'p-power');
      expect(ok.valueOrNull!.isByAccount, isFalse);
    });
  });

  group('Разбор найденного', () {
    test('Уже подключённый счёт помечается блоком по нормализованному номеру, '
        'даже если сервер флаг не прислал', () {
      final views = rules.classify(
        found: [
          candidate(id: 'c1', accountNo: ' 31 00562 '),
        ],
        connected: [account(id: 'a1', accountNo: '31-00562')],
      );

      final view = views.single;
      expect(view.candidate.alreadyConnected, isFalse, reason: 'сервер флаг не прислал');
      expect(view.blocks, contains(ConnectBlock.alreadyConnected));
      expect(view.ready, isFalse);
      expect(view.selectable, isFalse);
      expect(view.reason, ConnectBlock.alreadyConnected);
    });

    test('Серверный флаг needsConfirm приоритетнее локального вывода о владельце', () {
      final views = rules.classify(
        // Фамилия совпадает с профилем: локально мы бы решили «счёт свой».
        found: [candidate(id: 'c1', accountNo: '31-00562', needsConfirm: true)],
        connected: const [],
        session: testSession,
      );

      final view = views.single;
      expect(view.needsConfirm, isTrue);
      expect(view.ready, isFalse);
      // Подтверждение — не препятствие: его проходят в том же списке.
      expect(view.selectable, isTrue);
      expect(view.copyWith(confirmed: true).ready, isTrue);
      expect(view.copyWith(confirmed: true).needsConfirm, isFalse);
    });

    test('Счёт на чужое имя требует подтверждения, даже если сервер флага не дал', () {
      final views = rules.classify(
        found: [candidate(id: 'c1', accountNo: 'OSH-44120', holder: 'Жээнбеков К.')],
        connected: const [],
        session: testSession,
      );

      expect(views.single.needsConfirm, isTrue);
    });

    test('Неизвестная категория поставщика даёт other, а не падение', () {
      // Разбор категории не бросает исключение ни на пустом, ни на чужом.
      expect(ServiceCat.parse('телепатия'), ServiceCat.other);
      expect(ServiceCat.parse(null), ServiceCat.other);
      expect(ServiceCat.parse('water'), ServiceCat.water);
      expect(ServiceCat.other.token, 'city', reason: 'рисуется нейтрально');

      final views = rules.classify(
        found: [
          candidate(id: 'c1', accountNo: '31-00562', cat: 'телепатия'),
          candidate(id: 'c2', accountNo: '7710-3348', providerId: 'p-ufo', cat: 'телепатия'),
        ],
        connected: const [],
        catalog: Demo.catalog,
      );

      // Категория незнакомая, но поставщик известен — подключать можно.
      expect(views.first.ready, isTrue);
      // Поставщика нет в каталоге — вот это блок: реквизитов мы не знаем.
      expect(views.last.blocks, contains(ConnectBlock.unknownProvider));
      expect(views.last.selectable, isFalse);
    });

    test('Каталог ещё не загружен — поставщик не считается неизвестным', () {
      final views = rules.classify(
        found: [candidate(id: 'c1', accountNo: '31-00562', providerId: 'p-ufo')],
        connected: const [],
      );

      // Каталога нет — это наша проблема, а не пользователя.
      expect(views.single.ready, isTrue);
    });
  });

  group('Объект подключения', () {
    test('Объект предлагается по совпадению адреса кандидата с адресом объекта', () {
      final views = rules.classify(
        found: [
          candidate(
            id: 'c1',
            accountNo: '7710-5521',
            providerId: 'p-power',
            address: parentsAddress,
          ),
        ],
        connected: const [],
      );

      final suggested = rules.suggestObject(
        chosen: views,
        objects: const [homeObject, parentsObject],
      );

      // «д. 44, кв. 12» у кандидата и «44» у объекта — одно место.
      expect(suggested, parentsObject.id);
    });

    test('Единственный объект предлагается без адреса, двух без совпадения — не угадываем', () {
      final views = rules.classify(
        found: [candidate(id: 'c1', accountNo: '31-00562', address: '')],
        connected: const [],
      );

      expect(rules.suggestObject(chosen: views, objects: const [homeObject]), homeObject.id);
      expect(
        rules.suggestObject(chosen: views, objects: const [homeObject, parentsObject]),
        isNull,
        reason: 'экран обязан спросить, а не подключить куда-нибудь',
      );
      expect(rules.suggestObject(chosen: views, objects: const []), isNull);
    });
  });

  group('План подключения', () {
    List<CandidateView> three() => rules.classify(
          found: [
            candidate(id: 'c1', accountNo: '31-00562'),
            candidate(id: 'c2', accountNo: '55-20841', providerId: 'p-gas', amount: 420),
            candidate(id: 'c3', accountNo: '04-118725', providerId: 'p-trash', amount: 180),
          ],
          connected: const [],
        );

    test('План без выбранного объекта возвращает validation, а не пустой результат', () {
      final views = three();

      final noObject = rules.plan(
        views: views,
        selected: {'c1'},
        objectId: null,
        objects: const [homeObject],
        ids: SeqIdGen(),
      );
      expect(noObject.isFail, isTrue);
      expect(noObject.failureOrNull!.kind, FailureKind.validation);
      expect(noObject.failureOrNull!.field, ConnectRules.fieldObjectId);

      // Объектов не создано вообще — отдельная причина, свой текст.
      final noObjects = rules.plan(
        views: views,
        selected: {'c1'},
        objectId: 'o1',
        objects: const [],
        ids: SeqIdGen(),
      );
      expect(noObjects.failureOrNull!.field, ConnectRules.fieldObjectId);

      // Галочек нет — тоже не молчание, а понятная причина.
      final nothing = rules.plan(
        views: views,
        selected: const {},
        objectId: 'o1',
        objects: const [homeObject],
        ids: SeqIdGen(),
      );
      expect(nothing.failureOrNull!.field, ConnectRules.fieldSelected);
    });

    test('План режет выбор по maxBatch', () {
      const small = ConnectRules(maxBatch: 2);
      final views = small.classify(
        found: [
          candidate(id: 'c1', accountNo: '31-00562'),
          candidate(id: 'c2', accountNo: '55-20841', providerId: 'p-gas'),
          candidate(id: 'c3', accountNo: '04-118725', providerId: 'p-trash'),
        ],
        connected: const [],
      );
      final ids = SeqIdGen();

      final plan = small.plan(
        views: views,
        selected: {'c1', 'c2', 'c3'},
        objectId: 'o1',
        objects: const [homeObject],
        ids: ids,
      );

      expect(plan.valueOrNull!.length, 2);
      expect(plan.valueOrNull!.keys, hasLength(2));
      // Лишних ключей не выдано: каждый ключ — это попытка на шлюзе.
      expect(ids.issued, 2);
      // Предвыбор держит тот же предел.
      expect(small.preselect(views), hasLength(2));
    });

    test('Заблокированные в план не попадают', () {
      final views = rules.classify(
        found: [
          candidate(id: 'c1', accountNo: '31-00562'),
          candidate(id: 'c2', accountNo: '7710-3348', providerId: 'p-power'),
        ],
        connected: [account(id: 'a1', accountNo: '7710-3348', providerId: 'p-power')],
      );

      final plan = rules.plan(
        views: views,
        selected: {'c1', 'c2'},
        objectId: 'o1',
        objects: const [homeObject],
        ids: SeqIdGen(),
      );

      expect(plan.valueOrNull!.items.map((v) => v.id), ['c1']);
    });

    test('План переиспользует ранее выданные ключи идемпотентности при повторе', () {
      final views = three();
      final ids = SeqIdGen();

      final first = rules
          .plan(
            views: views,
            selected: {'c1', 'c2'},
            objectId: 'o1',
            objects: const [homeObject],
            ids: ids,
          )
          .valueOrNull!;
      final issued = ids.issued;

      final again = rules
          .plan(
            views: views,
            selected: {'c1', 'c2'},
            objectId: 'o1',
            objects: const [homeObject],
            ids: ids,
            reuse: first.keys,
          )
          .valueOrNull!;

      expect(again.keys, first.keys);
      expect(again.keyOf('c1'), first.keyOf('c1'));
      // Новых ключей не выдавали — иначе шлюз провёл бы подключение дважды.
      expect(ids.issued, issued);
    });
  });

  group('Предпросмотр начислений', () {
    test('Предпросмотр не создаёт строку для счёта без начисления '
        'и кладёт его в withoutCharges', () {
      final views = rules.classify(
        found: [
          candidate(id: 'c1', accountNo: '31-00562', amount: 205),
          candidate(id: 'c2', accountNo: '55-20841', providerId: 'p-gas', amount: 0),
        ],
        connected: const [],
      );

      final preview = rules.preview(views, now: testNow);

      expect(preview.lines, hasLength(1));
      expect(preview.lines.single.view.id, 'c1');
      // Счёт подключаем, но Bill на 0 сом не ждём: именно он ломает
      // разбивку на главной.
      expect(preview.withoutCharges.single.id, 'c2');
      expect(preview.count, 2);
      expect(preview.isEmpty, isFalse);
    });

    test('Предпросмотр считает итог и ближайший срок', () {
      final views = rules.classify(
        found: [
          candidate(
            id: 'c1',
            accountNo: '55-20841',
            providerId: 'p-gas',
            amount: 420,
            dueDay: 25,
          ),
          candidate(id: 'c2', accountNo: '31-00562', amount: 205, dueDay: 20),
        ],
        connected: const [],
      );

      final preview = rules.preview(views, now: testNow);

      expect(preview.total, closeTo(625, 0.001));
      expect(preview.nearestDue, DateTime(testNow.year, testNow.month, 20));
      // Строки отсортированы по сроку, а не по порядку находки.
      expect(preview.lines.map((l) => l.view.id), ['c2', 'c1']);
      expect(preview.lines.first.due, DateTime(testNow.year, testNow.month, 20));
    });

    test('Пустой выбор даёт пустой предпросмотр без исключений', () {
      final preview = rules.preview(const [], now: testNow);

      expect(preview.isEmpty, isTrue);
      expect(preview.total, 0);
      expect(preview.nearestDue, isNull);
    });
  });

  group('Отключение и обновление', () {
    test('checkDisconnect предупреждает о неоплаченном начислении '
        'и о последнем счёте объекта', () {
      final acc = account(id: 'a1', accountNo: '31-00562');

      final check = rules.checkDisconnect(
        account: acc,
        all: [acc],
        bills: [
          charge(id: 'b1', accountId: 'a1', amount: 205),
          charge(id: 'b2', accountId: 'a1', amount: 100, paid: true),
        ],
      );

      expect(check.allowed, isTrue);
      // Оплаченное в сумму предупреждения не входит.
      expect(check.unpaidAmount, closeTo(205, 0.001));
      expect(check.lastForObject, isTrue);
      expect(check.needsWarning, isTrue);

      final other = account(id: 'a2', accountNo: '7710-3348', providerId: 'p-power');
      final quiet = rules.checkDisconnect(
        account: acc,
        all: [acc, other],
        bills: [charge(id: 'b2', accountId: 'a1', paid: true)],
      );
      expect(quiet.needsWarning, isFalse);

      // Отключение уже в очереди — второй раз отправлять нечего.
      final pending = rules.checkDisconnect(
        account: acc.copyWith(pendingOp: AccountOp.disconnect),
        all: [acc],
        bills: const [],
      );
      expect(pending.allowed, isFalse);
      expect(pending.needsWarning, isFalse);
    });

    test('Начисление принадлежит счёту по accountId, а не по строке номера', () {
      final mine = account(id: 'a1', accountNo: '31-00562');
      final foreign = account(id: 'a2', accountNo: '31-00562', providerId: 'p-power');

      // Номера совпали, но привязка у начисления своя.
      expect(ConnectRules.billBelongsTo(charge(id: 'b1', accountId: 'a1'), mine), isTrue);
      expect(ConnectRules.billBelongsTo(charge(id: 'b1', accountId: 'a1'), foreign), isFalse);
      // Привязки нет (демо-набор) — тогда и только тогда сверяем номер.
      expect(ConnectRules.billBelongsTo(charge(id: 'b1'), foreign), isTrue);
    });

    test('shouldSuggestSync срабатывает по давности и по статусу failed', () {
      final fresh = [account(id: 'a1', accountNo: '31-00562')];

      expect(
        rules.shouldSuggestSync(
          lastSyncAt: testNow.subtract(const Duration(hours: 1)),
          accounts: fresh,
          now: testNow,
        ),
        isFalse,
      );
      expect(
        rules.shouldSuggestSync(
          lastSyncAt: testNow.subtract(const Duration(hours: 13)),
          accounts: fresh,
          now: testNow,
        ),
        isTrue,
        reason: 'давно не обновляли',
      );
      expect(
        rules.shouldSuggestSync(lastSyncAt: null, accounts: fresh, now: testNow),
        isTrue,
        reason: 'не обновляли ни разу',
      );
      expect(
        rules.shouldSuggestSync(
          lastSyncAt: testNow,
          accounts: [
            account(id: 'a1', accountNo: '31-00562', status: AccountSyncStatus.failed),
          ],
          now: testNow,
        ),
        isTrue,
        reason: 'в прошлый раз не обновилось',
      );
      // Счетов нет — предлагать нечего.
      expect(
        rules.shouldSuggestSync(lastSyncAt: null, accounts: const [], now: testNow),
        isFalse,
      );
    });
  });
}
