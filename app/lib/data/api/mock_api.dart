import '../../core/cache/local_store.dart';
import '../../core/clock.dart';
import '../../core/failure.dart';
import '../../core/ids.dart';
import '../../core/logger.dart';
import '../../core/net/connectivity.dart';
import '../demo_data.dart';
import '../models.dart';
import '../registry_data.dart';
import 'elpay_api.dart';

/// Демо-бэкенд: отвечает из демо-данных и реестра счетов, имитируя сеть.
///
/// Он же проверяет офлайн: если [connectivity] говорит «сети нет»,
/// запрос падает с [AppFailure.network] — ровно как в бою.
///
/// СОСТОЯНИЕ ЛЕЖИТ В [LocalStore], А НЕ В ПАМЯТИ. Раньше подключённые счета
/// жили в полях `_connected/_extraBills/_confirmed`, а кэш репозитория
/// переживал перезапуск: после рестарта в списке были счета из кэша, которых
/// «бэкенд» уже не знал, id расходились и отключение падало в notFound.
/// Теперь демо-бэкенд пишет своё состояние в то же хранилище под своим
/// ключом ([CacheKeys.mockServer]) — id стабильны, и отключение работает.
///
/// Чего демо-бэкенд НЕ хранит: «оплачено» и автоплатёж. В контракте
/// [ElPayApi] методов записи этих флагов нет, в `_ServerState` их никто
/// не меняет, и `bills()` всегда отдаёт их такими, какими их задал
/// демо-набор. Живут они в кэше `DefaultBillsRepository`, который и
/// переносит их на ответ этого бэкенда.
///
/// Хранилище передаётся снаружи (`store: ref.watch(localStoreProvider)`).
/// Без него берётся [MemoryLocalStore]: состояние живёт столько же, сколько
/// сам объект, — прежнее поведение для вызовов, которые store ещё не передают.
class MockElPayApi implements ElPayApi {
  MockElPayApi({
    LocalStore? store,
    ConnectivityService? connectivity,
    Clock? clock,
    this.latency = const Duration(milliseconds: 420),
  })  : store = store ?? MemoryLocalStore(),
        _net = connectivity ?? const AlwaysOnline(),
        _clock = clock ?? systemClock;

  /// Где демо-бэкенд держит своё состояние. Публично, чтобы тест перезапуска
  /// мог построить второй экземпляр поверх ТОГО ЖЕ хранилища.
  final LocalStore store;

  final ConnectivityService _net;
  final Clock _clock;
  final Duration latency;

  static const _tag = 'mock-api';

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (!_net.isOnline) {
      Log.w(_tag, 'запрос отклонён: нет сети');
      throw const AppFailure.network();
    }
  }

  // ─────────────────────── состояние демо-бэкенда ───────────────────────

  _ServerState _read() {
    final saved = store.readMap(CacheKeys.mockServer);
    if (saved == null) return _ServerState.empty();
    try {
      return _ServerState.fromJson(saved);
    } catch (e, st) {
      // Формат состояния изменился или запись побилась: начинаем заново,
      // иначе демо-бэкенд не поднимется вообще.
      Log.e(_tag, 'состояние не разобралось, начинаем с чистого', e, st);
      return _ServerState.empty();
    }
  }

  Future<void> _save(_ServerState state) =>
      store.writeJson(CacheKeys.mockServer, state.toJson(), now: _clock());

  /// Хвост очереди доступа к состоянию.
  Future<void> _gate = Future<void>.value();

  /// Выполнить операцию над состоянием ПО ОДНОЙ.
  ///
  /// Пишущие методы делают read-modify-write, а между чтением и записью
  /// стоит `await` (`_seeded`, `_save`). Два запроса, запущенные с
  /// перекрытием — подключение счёта и обновление начислений, — читали одну
  /// и ту же копию, и тот, кто записал последним, затирал чужую правку:
  /// connect отвечал успехом, а бэкенд о счёте не знал, после чего
  /// отключение по этому id падало в notFound, а операция из очереди
  /// не уходила никогда.
  ///
  /// Задержка сети [_wait] остаётся СНАРУЖИ: запросы по-прежнему идут
  /// параллельно, по одному меняется только состояние. Внутри тела нельзя
  /// звать методы, которые сами идут через [_tx], — это самоблокировка.
  Future<T> _tx<T>(Future<T> Function(_ServerState state) body) {
    final run = _gate.then((_) async => body(await _seeded()));
    // Отказ одной операции не должен рвать очередь остальным.
    _gate = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// Состояние для чтения — тем же порядком, что у записи.
  ///
  /// Засев демо-набора ([_seeded]) — тоже запись, поэтому читающие методы
  /// идут через ту же очередь: иначе два первых параллельных запроса
  /// засевали бы набор каждый по своей копии.
  Future<_ServerState> _state() => _tx((state) async => state);

  /// Состояние, гарантированно засеянное демо-набором.
  ///
  /// Засев делается ОДИН раз за всё время жизни хранилища (отметка `seeded`),
  /// а не один раз за время жизни объекта: иначе после перезапуска счета
  /// завелись бы заново с новыми id.
  Future<_ServerState> _seeded() async {
    final state = _read();
    if (state.seeded) return state;

    final now = _clock();
    state.objects.addAll(Demo.objects);
    final bills = Demo.bills(now);
    for (final b in bills) {
      final reg = Registry.accounts
          .where((r) => AccountMask.keyOf(r.accountNo) == AccountMask.keyOf(b.account))
          .firstOrNull;
      state.accounts.add(ConnectedAccount(
        // id начисления и id счёта связаны договорённостью 'acc-<billId>':
        // так demo_data задаёт Bill.accountId, и связь не теряется.
        id: 'acc-${b.id}',
        providerId: reg?.providerId ?? 'p-${b.cat}',
        title: b.title,
        subtitle: b.subtitle,
        cat: b.cat,
        accountNo: b.account,
        objectId: b.objectId,
        holder: reg?.holder ?? 'Токтогулова А.',
        address: reg?.address ?? '',
        connectedAt: now.subtract(Duration(days: 40 + state.accounts.length)),
        dueDay: b.due.day,
        syncedAt: now.subtract(const Duration(hours: 3)),
      ));
    }
    state.bills.addAll(bills);
    state.seeded = true;
    await _save(state);
    Log.i(_tag, 'демо-набор засеян: счетов ${state.accounts.length}');
    return state;
  }

  /// Стереть состояние демо-бэкенда — выход из аккаунта и удаление профиля.
  Future<void> reset() => store.remove(CacheKeys.mockServer);

  // ─────────────────────────────── чтение ───────────────────────────────

  @override
  Future<List<PayObject>> objects() async {
    await _wait();
    final state = await _state();
    return List.unmodifiable(state.objects);
  }

  @override
  Future<PayObject> saveObject(PayObject object) async {
    await _wait();
    return _tx((state) async {
      final i = state.objects.indexWhere((o) => o.id == object.id);
      if (i < 0) {
        state.objects.add(object);
      } else {
        state.objects[i] = object;
      }
      await _save(state);
      Log.i(_tag, i < 0 ? 'объект создан: ${object.id}' : 'объект обновлён: ${object.id}');
      return object;
    });
  }

  @override
  Future<void> deleteObject(String objectId) async {
    await _wait();
    return _tx((state) async {
      if (!state.objects.any((o) => o.id == objectId)) {
        throw AppFailure.notFound('объект $objectId не найден');
      }
      state.objects.removeWhere((o) => o.id == objectId);
      await _save(state);
      Log.i(_tag, 'объект удалён: $objectId');
    });
  }

  @override
  Future<List<Bill>> bills({String? objectId, String? cursor, int limit = 100}) async {
    await _wait();
    final state = await _state();
    // Курсор в демо не нужен: весь набор влезает в одну страницу. Параметр
    // остаётся в контракте — боевой ответ будет постраничным.
    final list = [
      for (final b in state.bills)
        if (objectId == null || b.objectId == objectId) b,
    ];
    return list.length <= limit ? list : list.sublist(0, limit);
  }

  @override
  Future<List<ConnectedAccount>> accounts() async {
    await _wait();
    final state = await _state();
    return List.unmodifiable(state.accounts);
  }

  @override
  Future<List<AccountCandidate>> search(AccountQuery query) async {
    await _wait();
    final state = await _state();

    final found = query.isByAccount
        ? Registry.byAccount(query.accountNo, providerId: query.providerId)
        // Поиск от значка услуги: адрес тот же, но показываем только одного
        // поставщика. Фильтр по providerId здесь, а не у вызывающего.
        : [
            for (final r in Registry.byAddress(query.city, query.street, query.house, query.flat))
              if (query.providerId == null || r.providerId == query.providerId) r,
          ];

    Log.i(_tag, 'поиск ${query.method}: найдено ${found.length}');

    final connected = {for (final a in state.accounts) _key(a.providerId, a.accountNo)};
    return [
      for (final r in found)
        AccountCandidate(
          id: r.id,
          providerId: r.providerId,
          providerTitle: Demo.providerById(r.providerId)?.title ?? r.providerId,
          serviceTitle: Demo.providerById(r.providerId)?.subtitle ?? '',
          cat: Demo.providerById(r.providerId)?.cat ?? 'city',
          accountNo: r.accountNo,
          holder: r.holder,
          address: r.address,
          amount: r.amount,
          period: r.period,
          dueDay: r.dueDay,
          calc: r.calc,
          // Счёт на другого человека подключаем только с подтверждением.
          needsConfirm:
              !r.holder.startsWith('Токтогулова А.') && !state.confirmed.contains(r.id),
          alreadyConnected: connected.contains(_key(r.providerId, r.accountNo)),
        ),
    ];
  }

  @override
  Future<Catalog> catalog({required String locale}) async {
    await _wait();
    // Демо-каталог один на все языки: названия в нём русские, перевод в бою
    // делает бэкенд. Локаль остаётся в контракте и в логе.
    Log.d(_tag, 'каталог для локали $locale');
    return Demo.catalog;
  }

  @override
  Future<List<Payment>> history({DateTime? from, DateTime? to, String? cursor}) async {
    await _wait();
    return [
      for (final p in Demo.history(_clock()))
        if ((from == null || !p.date.isBefore(from)) && (to == null || !p.date.isAfter(to))) p,
    ];
  }

  // ─────────────────────────────── запись ───────────────────────────────

  @override
  Future<AccountCandidate> confirm({required String candidateId, required String code}) async {
    await _wait();
    final reg = Registry.byId(candidateId);
    if (reg == null) throw const AppFailure.notFound('счёт не найден');
    if (code.trim() != reg.confirmCode) {
      throw const AppFailure.validation('код не подошёл', field: 'code');
    }
    await _tx((state) async {
      state.confirmed.add(candidateId);
      await _save(state);
    });

    final list = await search(AccountQuery.byAccount(reg.accountNo, providerId: reg.providerId));
    return list.firstWhere((c) => c.id == candidateId);
  }

  @override
  Future<ConnectResult> connect({
    required String candidateId,
    required String objectId,
    required IdempotencyKey key,
  }) async {
    await _wait();
    return _tx((state) async {
      // Повтор с тем же ключом (кнопка «ещё раз» или отправка из Outbox)
      // возвращает ТОТ ЖЕ результат, а не создаёт второй счёт.
      final already = state.resultOf(key);
      if (already != null) {
        Log.i(_tag, 'повтор по ключу ${key.value}: отдаём прежний результат');
        return already;
      }

      final reg = Registry.byId(candidateId);
      if (reg == null) throw const AppFailure.notFound('счёт не найден');
      if (state.accounts.any((a) => _key(a.providerId, a.accountNo) == _key(reg.providerId, reg.accountNo))) {
        throw const AppFailure.validation('счёт уже подключён');
      }

      final provider = Demo.providerById(reg.providerId);
      final now = _clock();
      final account = ConnectedAccount(
        id: 'acc-${reg.id}-${now.microsecondsSinceEpoch}',
        providerId: reg.providerId,
        title: provider?.title ?? reg.providerId,
        subtitle: provider?.subtitle ?? '',
        cat: provider?.cat ?? 'city',
        accountNo: reg.accountNo,
        objectId: objectId,
        holder: reg.holder,
        address: reg.address,
        connectedAt: now,
        dueDay: reg.dueDay,
        syncedAt: now,
      );
      state.accounts.add(account);

      Bill? bill;
      // Начисление создаётся ТОЛЬКО если оно выставлено. Счёт без начисления —
      // нормальное состояние, а Bill на 0 сом попадает «к оплате» и роняет
      // разбивку на главной делением на нулевой итог.
      if (reg.amount > 0) {
        bill = Bill(
          id: 'bill-${reg.id}-${now.microsecondsSinceEpoch}',
          // Начисление знает СВОЙ счёт по id: у разных поставщиков номера
          // совпадают, и отключение одного снесло бы начисления другого.
          accountId: account.id,
          title: account.title,
          subtitle: account.subtitle,
          cat: account.cat,
          amount: reg.amount,
          objectId: objectId,
          period: reg.period,
          // Тот же расчёт, что в ConnectRules.dueDateOf: предпросмотр обещает
          // пользователю эту дату, и она обязана совпасть с начислением.
          // periodAt не заполняем: у записи реестра нет даты начала периода,
          // а выдумывать её ради локализованной подписи нельзя.
          due: DateTime(now.year, now.month, reg.dueDay),
          account: reg.accountNo,
          calc: reg.calc,
          requisites: [
            ...?provider?.requisites,
            ...Demo.bank,
            Field('Лицевой счёт', reg.accountNo),
            Field('Назначение', '${provider?.subtitle ?? ''}, ${reg.period}'),
          ],
        );
        state.bills.add(bill);
      }

      state.remember(key, accountId: account.id, billId: bill?.id);
      await _save(state);
      Log.i(_tag, 'подключён счёт ${reg.accountNo}');
      return ConnectResult(account: account, bill: bill);
    });
  }

  @override
  Future<void> disconnect(String accountId, {required IdempotencyKey key}) async {
    await _wait();
    return _tx((state) async {
      // Тот же ключ — операция уже выполнена. Повтор из очереди не должен
      // падать в notFound только потому, что счёта уже нет.
      if (state.isDone(key)) {
        Log.i(_tag, 'повтор отключения по ключу ${key.value}: уже сделано');
        return;
      }

      final account = state.accounts.where((a) => a.id == accountId).firstOrNull;
      if (account == null) throw const AppFailure.notFound('счёт не подключён');

      state.accounts.removeWhere((a) => a.id == accountId);
      // Начисления убираем по accountId; строка номера — только для старых
      // записей, у которых привязки ещё нет.
      state.bills.removeWhere((b) => b.accountId.isEmpty
          ? AccountMask.keyOf(b.account) == AccountMask.keyOf(account.accountNo)
          : b.accountId == account.id);
      state.remember(key, accountId: accountId);
      await _save(state);
      Log.i(_tag, 'отключён счёт ${account.accountNo}');
    });
  }

  @override
  Future<ConnectedAccount> move({
    required String accountId,
    required String objectId,
  }) async {
    await _wait();
    return _tx((state) async {
      final index = state.accounts.indexWhere((a) => a.id == accountId);
      if (index < 0) throw const AppFailure.notFound('счёт не подключён');

      final moved = state.accounts[index].copyWith(objectId: objectId);
      state.accounts[index] = moved;
      for (var i = 0; i < state.bills.length; i++) {
        final b = state.bills[i];
        if (b.accountId != accountId) continue;
        // У Bill нет copyWith(objectId) — модели правит другая лана, поэтому
        // объект меняется через JSON-копию. Для демо-бэкенда этого достаточно.
        state.bills[i] = Bill.fromJson({...b.toJson(), 'objectId': objectId});
      }
      await _save(state);
      Log.i(_tag, 'счёт ${moved.accountNo} перенесён на объект $objectId');
      return moved;
    });
  }

  @override
  Future<SyncResult> syncCharges({List<String> accountIds = const []}) async {
    await _wait();
    return _tx((state) async {
      final now = _clock();

      final known = {for (final a in state.accounts) a.id};
      // Названы счета, которых бэкенд не знает, — это частичный отказ,
      // а не общая ошибка: остальные обновляются как обычно.
      final failed = <String, String>{
        for (final id in accountIds)
          if (!known.contains(id)) id: 'notFound',
      };
      final targets = accountIds.isEmpty ? known : accountIds.toSet();

      for (var i = 0; i < state.accounts.length; i++) {
        final a = state.accounts[i];
        if (!targets.contains(a.id)) continue;
        state.accounts[i] =
            a.copyWith(status: AccountSyncStatus.ok, syncedAt: now, clearError: true);
      }
      await _save(state);

      return SyncResult(
        bills: List.unmodifiable(state.bills),
        accounts: List.unmodifiable(state.accounts),
        syncedAt: now,
        failed: failed,
      );
    });
  }

  /// Ключ сравнения счёта: поставщик плюс нормализованный номер.
  /// Только номера мало — у разных поставщиков они совпадают.
  static String _key(String providerId, String accountNo) =>
      '$providerId|${AccountMask.keyOf(accountNo)}';
}

/// Состояние демо-бэкенда: то, что в бою лежит в базе поставщика.
///
/// Лежит в [LocalStore] под [CacheKeys.mockServer] — отдельно от кэша
/// репозиториев, чтобы «бэкенд» и «клиент» не читали одну и ту же запись.
class _ServerState {
  _ServerState({
    required this.objects,
    required this.accounts,
    required this.bills,
    required this.confirmed,
    required this.done,
    required this.seeded,
  });

  _ServerState.empty()
      : objects = [],
        accounts = [],
        bills = [],
        confirmed = {},
        done = {},
        seeded = false;

  /// Объекты («Дом», «Родители») — их создаёт и удаляет пользователь,
  /// поэтому они часть состояния бэкенда, а не статический демо-набор.
  final List<PayObject> objects;

  final List<ConnectedAccount> accounts;
  final List<Bill> bills;

  /// Кандидаты, владение которыми подтверждено кодом.
  final Set<String> confirmed;

  /// Выполненные операции: ключ идемпотентности → что получилось.
  /// По нему повтор возвращает прежний результат, а не делает второй счёт.
  final Map<String, Map<String, dynamic>> done;

  /// Демо-набор уже засеян. Отметка живёт в хранилище, а не в объекте.
  bool seeded;

  bool isDone(IdempotencyKey key) => done.containsKey(key.value);

  void remember(IdempotencyKey key, {required String accountId, String? billId}) =>
      done[key.value] = {'accountId': accountId, 'billId': ?billId};

  /// Прежний результат подключения по ключу — или null, если ключ новый
  /// либо счёт из прошлого ответа уже отключили.
  ConnectResult? resultOf(IdempotencyKey key) {
    final saved = done[key.value];
    if (saved == null) return null;
    final accountId = '${saved['accountId']}';
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return null;
    final billId = saved['billId'];
    return ConnectResult(
      account: account,
      bill: billId == null ? null : bills.where((b) => b.id == billId).firstOrNull,
    );
  }

  Map<String, dynamic> toJson() => {
        'objects': [for (final o in objects) o.toJson()],
        'accounts': [for (final a in accounts) a.toJson()],
        'bills': [for (final b in bills) b.toJson()],
        'confirmed': confirmed.toList(),
        'done': done,
        'seeded': seeded,
      };

  static _ServerState fromJson(Map<String, dynamic> j) => _ServerState(
        objects: [for (final r in _rows(j['objects'])) PayObject.fromJson(r)],
        accounts: [for (final r in _rows(j['accounts'])) ConnectedAccount.fromJson(r)],
        bills: [for (final r in _rows(j['bills'])) Bill.fromJson(r)],
        confirmed: {
          for (final c in (j['confirmed'] as List? ?? const [])) '$c',
        },
        done: {
          for (final e in ((j['done'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{})
              .entries)
            e.key: (e.value as Map?)?.cast<String, dynamic>() ?? const {},
        },
        seeded: j['seeded'] as bool? ?? false,
      );

  static List<Map<String, dynamic>> _rows(Object? raw) => [
        for (final r in (raw as List? ?? const []))
          if (r is Map) r.cast<String, dynamic>(),
      ];
}
