import '../core/cache/local_store.dart';
import '../core/clock.dart';
import '../core/failure.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/result.dart';
import 'api/elpay_api.dart';
import 'cache_policy.dart';
import 'models.dart';

/// Снимок данных главной: объекты, начисления и время последнего обновления.
///
/// Поля [fromCache] и [syncedAt] дублируют то же самое в [Cached] — это
/// переходное состояние: пока состояние экрана (state/providers.dart)
/// не переехало на [Cached], снимок обязан нести происхождение в себе.
/// Когда переедет, оба поля отсюда уходят, а их читают у [Cached].
class BillsSnapshot {
  const BillsSnapshot({
    required this.objects,
    required this.bills,
    this.syncedAt,
    this.fromCache = false,
  });

  final List<PayObject> objects;
  final List<Bill> bills;
  final DateTime? syncedAt;

  /// Данные показаны из кэша — сеть не ответила.
  final bool fromCache;

  static const empty = BillsSnapshot(objects: [], bills: []);

  bool get isEmpty => objects.isEmpty && bills.isEmpty;

  BillsSnapshot copyWith({
    List<PayObject>? objects,
    List<Bill>? bills,
    DateTime? syncedAt,
    bool? fromCache,
  }) =>
      BillsSnapshot(
        objects: objects ?? this.objects,
        bills: bills ?? this.bills,
        syncedAt: syncedAt ?? this.syncedAt,
        fromCache: fromCache ?? this.fromCache,
      );
}

/// Объекты и начисления. Отдаёт сохранённое мгновенно, затем обновляет
/// из источника — правило доставки целиком лежит в [CachePolicy], а не
/// переписывается здесь своими восемью строками про TTL.
///
/// Запись тоже идёт через репозиторий: до этого «оплачено» и автоплатёж
/// жили локальными присваиваниями в нотифаере и не переживали перезапуск,
/// потому что write-методов у репозитория не было вообще.
abstract class BillsRepository {
  /// Сохранённый снимок без обращения к сети (может быть пустым).
  BillsSnapshot cached();

  /// Загрузка со происхождением данных: [refresh] = true — всегда идём
  /// в источник. [objectId] — только начисления этого объекта.
  ///
  /// Источник молчит, а кэш есть — `Ok(Cached.stale)`: экран рисует плашку
  /// офлайна и подпись «обновлено в ...». Нет ни того, ни другого — `Fail`.
  Future<Result<Cached<BillsSnapshot>>> loadCached({
    bool refresh = false,
    String? objectId,
  });

  /// ПЕРЕХОДНАЯ ОБЁРТКА над [loadCached] без происхождения данных.
  ///
  /// Нужна ровно до того момента, когда BillsNotifier уедет из
  /// state/providers.dart в state/bills.dart и начнёт читать [Cached]
  /// напрямую (его автор — соседняя лана). После этого метод удаляется.
  Future<Result<BillsSnapshot>> load({bool refresh = false, String? objectId});

  /// Автоплатёж по начислению. [key] — ключ попытки: повтор по кнопке
  /// и повтор из очереди не должны переключить тумблер дважды.
  Future<Result<Bill>> setAutopay({
    required String billId,
    required bool on,
    required IdempotencyKey key,
  });

  /// Отметить начисления оплаченными. [receiptNo] приходит от процессинга —
  /// клиент его не выдумывает.
  Future<Result<List<Bill>>> markPaid(
    List<String> billIds, {
    required String receiptNo,
  });

  /// Создать или обновить объект («Дом», «Родители»).
  Future<Result<PayObject>> saveObject(PayObject object);

  /// Удалить объект. Каскада на сервере не будет, поэтому счета объекта
  /// отключает вызывающий через AccountsRepository — порядок задаёт он.
  Future<Result<void>> removeObject(String objectId, {required bool detachAccounts});

  /// Дописать начисления (после подключения счёта или частичной синхронизации),
  /// чтобы счёт появился на главной без полного перезапроса.
  Future<Result<List<Bill>>> merge(List<Bill> bills);

  /// Убрать начисления отключённого счёта — по [accountId], а не по строке
  /// номера: у разных поставщиков номера совпадают.
  Future<Result<List<Bill>>> dropByAccount(String accountId);
}

class DefaultBillsRepository implements BillsRepository {
  DefaultBillsRepository({
    required this.api,
    required this.store,
    Clock? clock,
    this.ttl = defaultTtl,
  }) : _clock = clock ?? systemClock;

  final ElPayApi api;
  final LocalStore store;
  final Clock _clock;

  /// Насколько свежим считаем кэш, прежде чем идти в источник.
  final Duration ttl;

  static const defaultTtl = Duration(minutes: 15);
  static const _tag = 'bills';

  /// Политики кэша — по одной на ключ. Создаются лениво, чтобы в списке
  /// инициализации конструктора не повторять store/ttl/clock.
  late final CachePolicy<List<PayObject>> _objectsCache =
      CachePolicy.list<PayObject>(
    store: store,
    key: CacheKeys.objects,
    ttl: ttl,
    item: PayObject.fromJson,
    row: (o) => o.toJson(),
    clock: _clock,
  );

  late final CachePolicy<List<Bill>> _billsCache = CachePolicy.list<Bill>(
    store: store,
    key: CacheKeys.bills,
    ttl: ttl,
    item: Bill.fromJson,
    row: (b) => b.toJson(),
    clock: _clock,
  );

  @override
  BillsSnapshot cached() {
    final objects = _objectsCache.read() ?? const <PayObject>[];
    final bills = _billsCache.read() ?? const <Bill>[];
    if (objects.isEmpty && bills.isEmpty) return BillsSnapshot.empty;
    return BillsSnapshot(
      objects: objects,
      bills: bills,
      syncedAt: _billsCache.updatedAt(),
      fromCache: true,
    );
  }

  @override
  Future<Result<Cached<BillsSnapshot>>> loadCached({
    bool refresh = false,
    String? objectId,
  }) async {
    final now = _clock();

    // Два ключа — две политики, и каждая решает про свой TTL сама. Поэтому
    // свежие объекты не тянут за собой лишний запрос начислений и наоборот.
    final Cached<List<PayObject>> objects;
    switch (await _objectsCache.load(refresh: refresh, now: now, fetch: api.objects)) {
      case Ok(:final value):
        objects = value;
      case Fail(:final failure):
        // Ни сети, ни сохранённых объектов — показывать нечего.
        Log.w(_tag, 'объекты не загрузились: ${failure.message}');
        return Fail<Cached<BillsSnapshot>>(failure);
    }

    final Cached<List<Bill>> bills;
    switch (await _billsCache.load(refresh: refresh, now: now, fetch: api.bills)) {
      case Ok(:final value):
        bills = value;
      case Fail(:final failure):
        Log.w(_tag, 'начисления не загрузились: ${failure.message}');
        return Fail<Cached<BillsSnapshot>>(failure);
    }

    // Фильтр по объекту делаем здесь: в контракте ElPayApi у bills() ещё нет
    // параметра objectId (его добавляет автор api/), а кэш всё равно держим
    // целиком — иначе переход между объектами затирал бы чужие начисления.
    final rows = objectId == null
        ? bills.value
        : [for (final b in bills.value) if (b.objectId == objectId) b];

    final fromCache = objects.fromCache || bills.fromCache;
    final at = bills.updatedAt ?? objects.updatedAt;
    final snapshot = BillsSnapshot(
      objects: objects.value,
      bills: rows,
      syncedAt: at,
      fromCache: fromCache,
    );

    return Ok(fromCache
        ? Cached<BillsSnapshot>.stale(snapshot, at)
        : Cached<BillsSnapshot>.fresh(snapshot, at ?? now));
  }

  @override
  Future<Result<BillsSnapshot>> load({bool refresh = false, String? objectId}) async {
    final result = await loadCached(refresh: refresh, objectId: objectId);
    return result.map((c) => c.value);
  }

  @override
  Future<Result<Bill>> setAutopay({
    required String billId,
    required bool on,
    required IdempotencyKey key,
  }) async {
    final bills = _billsCache.read();
    if (bills == null) return const Fail(AppFailure.notFound('начислений нет'));
    final i = bills.indexWhere((b) => b.id == billId);
    if (i < 0) {
      return Fail(AppFailure.notFound('начисление $billId не найдено'));
    }
    if (bills[i].autopay == on) {
      // Повтор той же попытки: состояние уже такое, второй раз не пишем.
      Log.d(_tag, 'автоплатёж $billId уже ${on ? 'включён' : 'выключен'}');
      return Ok(bills[i]);
    }
    final updated = bills[i].copyWith(autopay: on);
    await _writeBills([...bills]..[i] = updated);
    Log.i(_tag, 'автоплатёж $billId: ${on ? 'включён' : 'выключен'} (${key.value})');
    return Ok(updated);
  }

  @override
  Future<Result<List<Bill>>> markPaid(
    List<String> billIds, {
    required String receiptNo,
  }) async {
    if (billIds.isEmpty) {
      return const Fail(AppFailure.validation('нечего отмечать оплаченным'));
    }
    if (receiptNo.isEmpty) {
      // Не отказ: без отметки «оплачено» пользователь увидит уже оплаченное
      // начисление снова, и это хуже отсутствующего номера квитанции.
      Log.w(_tag, 'отметка оплаты без номера квитанции — так быть не должно');
    }
    final bills = _billsCache.read();
    if (bills == null) return const Fail(AppFailure.notFound('начислений нет'));

    final ids = billIds.toSet();
    final known = {for (final b in bills) b.id};
    final missing = ids.difference(known);
    if (missing.length == ids.length) {
      return Fail(AppFailure.notFound('начисления не найдены: ${missing.join(', ')}'));
    }
    if (missing.isNotEmpty) {
      Log.w(_tag, 'оплачены начисления, которых нет в кэше: ${missing.join(', ')}');
    }

    final next = [
      for (final b in bills) ids.contains(b.id) ? b.copyWith(paid: true) : b,
    ];
    await _writeBills(next);
    Log.i(_tag, 'оплачено начислений: ${ids.length - missing.length}, квитанция $receiptNo');
    return Ok([for (final b in next) if (ids.contains(b.id)) b]);
  }

  @override
  Future<Result<PayObject>> saveObject(PayObject object) async {
    if (object.id.isEmpty) {
      return const Fail(AppFailure.validation('у объекта нет id', field: 'id'));
    }
    if (object.name.trim().isEmpty) {
      return const Fail(AppFailure.validation('у объекта нет названия', field: 'name'));
    }
    final objects = _objectsCache.read() ?? const <PayObject>[];
    final i = objects.indexWhere((o) => o.id == object.id);
    final next = i < 0 ? [...objects, object] : ([...objects]..[i] = object);
    await _writeObjects(next);
    Log.i(_tag, i < 0 ? 'объект добавлен: ${object.id}' : 'объект обновлён: ${object.id}');
    return Ok(object);
  }

  @override
  Future<Result<void>> removeObject(
    String objectId, {
    required bool detachAccounts,
  }) async {
    final objects = _objectsCache.read() ?? const <PayObject>[];
    if (!objects.any((o) => o.id == objectId)) {
      return Fail(AppFailure.notFound('объект $objectId не найден'));
    }
    await _writeObjects([for (final o in objects) if (o.id != objectId) o]);

    // [detachAccounts] = true — счета объекта уже отключены вызывающим,
    // поэтому их начисления уходят вместе с объектом. false — начисления
    // остаются: так объект исчезает из списка, но перенос счетов на другой
    // объект не теряет то, что по ним уже начислено.
    final bills = _billsCache.read();
    if (detachAccounts && bills != null) {
      await _writeBills([for (final b in bills) if (b.objectId != objectId) b]);
    }
    Log.i(_tag, 'объект удалён: $objectId (начисления ${detachAccounts ? 'убраны' : 'оставлены'})');
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Bill>>> merge(List<Bill> bills) async {
    final current = _billsCache.read() ?? const <Bill>[];
    if (bills.isEmpty) return Ok(current);
    final byId = <String, Bill>{for (final b in current) b.id: b};
    for (final b in bills) {
      byId[b.id] = b;
    }
    final next = byId.values.toList();
    await _writeBills(next);
    Log.i(_tag, 'дописано начислений: ${bills.length}, всего ${next.length}');
    return Ok(next);
  }

  @override
  Future<Result<List<Bill>>> dropByAccount(String accountId) async {
    if (accountId.isEmpty) {
      return const Fail(AppFailure.validation('не указан счёт'));
    }
    final bills = _billsCache.read();
    if (bills == null) return const Ok(<Bill>[]);
    final next = [for (final b in bills) if (b.accountId != accountId) b];
    if (next.length == bills.length) return Ok(next);
    await _writeBills(next);
    Log.i(_tag, 'убрано начислений отключённого счёта: ${bills.length - next.length}');
    return Ok(next);
  }

  /// Локальная правка — не синхронизация: отметку времени не двигаем.
  /// Иначе протухший кэш «омолодится» от нажатия тумблера, и приложение
  /// перестанет ходить за свежими начислениями.
  Future<void> _writeBills(List<Bill> list) =>
      _billsCache.write(list, now: _billsCache.updatedAt() ?? _clock());

  Future<void> _writeObjects(List<PayObject> list) =>
      _objectsCache.write(list, now: _objectsCache.updatedAt() ?? _clock());
}
