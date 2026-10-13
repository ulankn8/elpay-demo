import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/failure.dart';
import '../core/logger.dart';
import '../core/result.dart';
import '../data/bills_repository.dart';
import '../data/models.dart';
import 'providers.dart';

/// Объекты и начисления главной.
///
/// Запись идёт ЧЕРЕЗ РЕПОЗИТОРИЙ, а не локальными присваиваниями: до этого
/// «оплачено» и автоплатёж жили только в памяти нотифаера и не переживали
/// перезапуск приложения.
@immutable
class BillsState {
  const BillsState({
    required this.objects,
    required this.bills,
    this.syncedAt,
    this.fromCache = false,
    this.failure,
  });

  static const empty = BillsState(objects: [], bills: []);

  final List<PayObject> objects;
  final List<Bill> bills;

  /// Когда начисления последний раз приходили из источника.
  final DateTime? syncedAt;

  /// Данные из кэша: источник не ответил, но показать есть что.
  final bool fromCache;

  /// Последняя ошибка загрузки — для плашки над списком.
  final AppFailure? failure;

  List<Bill> byObject(String id) => [
        for (final b in bills)
          if (b.objectId == id) b,
      ];

  /// Начисления подключённого счёта — по accountId, а не по строке номера:
  /// у разных поставщиков номера совпадают.
  List<Bill> byAccount(String accountId) => [
        for (final b in bills)
          if (b.accountId == accountId) b,
      ];

  List<Bill> get unpaid => [
        for (final b in bills)
          if (!b.paid) b,
      ];

  double get dueTotal => unpaid.fold(0.0, (sum, b) => sum + b.amount);

  Bill? billById(String id) {
    for (final b in bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// [clearFailure] — СБРОСИТЬ ошибку явно.
  ///
  /// Без этого флага было ровно наоборот: `failure` затирался при каждом
  /// вызове copyWith, и плашка ошибки пропадала от любого соседнего
  /// обновления. Теперь молчаливой потери нет: либо передают новую ошибку,
  /// либо просят её стереть.
  BillsState copyWith({
    List<PayObject>? objects,
    List<Bill>? bills,
    DateTime? syncedAt,
    bool? fromCache,
    AppFailure? failure,
    bool clearFailure = false,
  }) =>
      BillsState(
        objects: objects ?? this.objects,
        bills: bills ?? this.bills,
        syncedAt: syncedAt ?? this.syncedAt,
        fromCache: fromCache ?? this.fromCache,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// Состояние главной: сохранённое показывается сразу, затем обновляется
/// из источника. Каждая мутация — оптимистичная, с откатом при отказе.
class BillsNotifier extends AsyncNotifier<BillsState> {
  static const _tag = 'bills-state';

  BillsRepository get _repo => ref.read(billsRepoProvider);

  @override
  Future<BillsState> build() async {
    final cached = _repo.cached();
    // Сохранённое показываем сразу, не дожидаясь сети.
    if (!cached.isEmpty) state = AsyncData(_fromSnapshot(cached));

    final result = await _repo.loadCached();
    return result.fold(
      (data) => _fromSnapshot(
        data.value,
        fromCache: data.fromCache,
        syncedAt: data.updatedAt,
      ),
      (failure) {
        // 401/403 повтором не лечится: нужен новый вход.
        unawaited(handleAuthFailure(ref, failure));
        if (cached.isEmpty) throw failure;
        // Данные есть, свежих нет — это офлайн, а не пустой экран.
        return _fromSnapshot(cached).copyWith(failure: failure);
      },
    );
  }

  BillsState _fromSnapshot(
    BillsSnapshot snapshot, {
    bool fromCache = true,
    DateTime? syncedAt,
  }) =>
      BillsState(
        objects: snapshot.objects,
        bills: snapshot.bills,
        syncedAt: syncedAt ?? snapshot.syncedAt,
        fromCache: fromCache && snapshot.fromCache,
      );

  /// Потянули вниз: идём в источник, ошибку показываем плашкой,
  /// данные при этом не теряем.
  Future<void> refresh() async {
    final before = state.value;
    final result = await _repo.loadCached(refresh: true);
    // Состояние перечитываем ПОСЛЕ запроса. Пока он был в полёте,
    // пользователь мог оплатить начисление, переключить автоплатёж или
    // править объекты, а источник об этих правках не знает: в [ElPayApi]
    // нет ни «отметить оплаченным», ни автоплатежа, ни объектов. Снимок,
    // снятый до await, молча откатывал их назад — оплаченное начисление
    // снова висело «к оплате», и его оплачивали второй раз.
    final latest = state.value;
    state = AsyncData(result.fold(
      (data) => _keepInFlightEdits(
        _fromSnapshot(
          data.value,
          fromCache: data.fromCache,
          syncedAt: data.updatedAt,
        ),
        before: before,
        latest: latest,
      ).copyWith(clearFailure: true),
      (failure) =>
          (latest ?? BillsState.empty).copyWith(failure: failure, fromCache: true),
    ));
  }

  /// Ответ источника с сохранёнными правками, которые пользователь успел
  /// сделать ВО ВРЕМЯ запроса.
  ///
  /// Сравниваем снимок до запроса ([before]) со свежим состоянием
  /// ([latest]): что успело измениться — остаётся за пользователем,
  /// всё остальное берём из источника. Так правка не теряется, а список
  /// по-прежнему обновляется.
  BillsState _keepInFlightEdits(
    BillsState loaded, {
    required BillsState? before,
    required BillsState? latest,
  }) {
    if (before == null || latest == null) return loaded;

    final wasBills = {for (final b in before.bills) b.id: b};
    final myBills = {for (final b in latest.bills) b.id: b};
    final loadedBills = {for (final b in loaded.bills) b.id};
    final bills = <Bill>[
      for (final b in loaded.bills)
        // Начисление, убранное в полёте (удалили объект, отключили счёт),
        // не возвращаем.
        if (!wasBills.containsKey(b.id) || myBills.containsKey(b.id))
          _withLocalFlags(b, wasBills[b.id], myBills[b.id]),
      // Начисления, дописанные в полёте: источник о них ещё не знает.
      for (final b in latest.bills)
        if (!loadedBills.contains(b.id) && !wasBills.containsKey(b.id)) b,
    ];

    final wasObjects = {for (final o in before.objects) o.id: o};
    final myObjects = {for (final o in latest.objects) o.id: o};
    final loadedObjects = {for (final o in loaded.objects) o.id};
    final objects = <PayObject>[
      for (final o in loaded.objects)
        if (myObjects[o.id] case final edited?)
          // Правка в полёте сильнее ответа: записать объект источнику
          // всё равно некуда, он их не хранит.
          (identical(edited, wasObjects[o.id]) ? o : edited)
        // Объект, удалённый в полёте, не возвращаем.
        else if (!wasObjects.containsKey(o.id))
          o,
      for (final o in latest.objects)
        if (!loadedObjects.contains(o.id)) o,
    ];

    return loaded.copyWith(bills: bills, objects: objects);
  }

  /// «Оплачено» и автоплатёж: в ответе источника их нет (писать их
  /// в [ElPayApi] некуда), поэтому локальное значение сильнее.
  ///
  /// `paid` ЗАЛИПАЕТ в true: отменить оплату нечем, а вернув начисление
  /// в «к оплате», мы приглашаем оплатить его второй раз и списать
  /// кошелёк повторно. Автоплатёж выключать можно, поэтому его берём
  /// из источника — кроме случая, когда пользователь переключил тумблер,
  /// пока шёл запрос.
  Bill _withLocalFlags(Bill source, Bill? was, Bill? mine) {
    if (mine == null) return source;
    final paid = source.paid || mine.paid;
    final autopay =
        was != null && was.autopay == mine.autopay ? source.autopay : mine.autopay;
    return paid == source.paid && autopay == source.autopay
        ? source
        : source.copyWith(paid: paid, autopay: autopay);
  }

  // ───────────────────────── мутации ─────────────────────────

  /// Оптимистично: тумблер переключается сразу, на отказе возвращается
  /// назад. Один образец для всех мутаций ниже.
  Future<Result<void>> setAutopay(String billId, {required bool on}) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('начисления ещё не загружены'));
    }
    final was = current.billById(billId)?.autopay ?? false;
    _set(current.copyWith(
      bills: [
        for (final b in current.bills) b.id == billId ? b.copyWith(autopay: on) : b,
      ],
      clearFailure: true,
    ));

    final result = await _repo.setAutopay(
      billId: billId,
      on: on,
      key: ref.read(idGenProvider).key('bills.autopay'),
    );
    return result.fold(
      (_) => const Ok<void>(null),
      (failure) {
        Log.w(_tag, 'автоплатёж не сохранился: ${failure.message}');
        // Откат к тому, что было до нажатия, — но ТОЛЬКО своего тумблера
        // и по свежему состоянию: запись целого снимка затирала правки,
        // сделанные пока шёл запрос (оплату, объекты, соседний тумблер).
        final latest = state.value ?? current;
        _set(latest.copyWith(
          bills: [
            for (final b in latest.bills)
              b.id == billId ? b.copyWith(autopay: was) : b,
          ],
        ));
        return Fail<void>(failure);
      },
    );
  }

  /// ПЕРЕХОДНАЯ ОБЁРТКА: экраны ещё переключают автоплатёж «вслепую»,
  /// не зная целевого значения. Уходит, когда они перейдут на [setAutopay].
  Future<Result<void>> toggleAutopay(String billId) {
    final bill = state.value?.billById(billId);
    return setAutopay(billId, on: !(bill?.autopay ?? false));
  }

  /// [receiptNo] приходит от процессинга — клиент его не выдумывает.
  Future<Result<void>> markPaid(
    Iterable<String> billIds, {
    String receiptNo = '',
  }) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('начисления ещё не загружены'));
    }
    final ids = billIds.toSet();
    if (ids.isEmpty) {
      return const Fail(AppFailure.validation('нечего отмечать оплаченным'));
    }
    final was = {
      for (final id in ids) id: current.billById(id)?.paid ?? false,
    };
    _set(current.copyWith(
      bills: [
        for (final b in current.bills) ids.contains(b.id) ? b.copyWith(paid: true) : b,
      ],
      clearFailure: true,
    ));

    final result = await _repo.markPaid(ids.toList(), receiptNo: receiptNo);
    return result.fold(
      (_) => const Ok<void>(null),
      (failure) {
        Log.w(_tag, 'отметка оплаты не сохранилась: ${failure.message}');
        // Возвращаем ТОЛЬКО свои отметки и по свежему состоянию.
        final latest = state.value ?? current;
        _set(latest.copyWith(
          bills: [
            for (final b in latest.bills)
              if (was[b.id] case final mark?) b.copyWith(paid: mark) else b,
          ],
        ));
        return Fail<void>(failure);
      },
    );
  }

  Future<Result<PayObject>> saveObject(PayObject object) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('объекты ещё не загружены'));
    }
    // Прежняя версия объекта — для отката: пустой список значит, что
    // объект новый и при отказе его надо просто убрать.
    final previous = [
      for (final o in current.objects)
        if (o.id == object.id) o,
    ];
    final known = previous.isNotEmpty;
    _set(current.copyWith(
      objects: known
          ? [for (final o in current.objects) o.id == object.id ? object : o]
          : [...current.objects, object],
      clearFailure: true,
    ));

    final result = await _repo.saveObject(object);
    return result.fold(Ok<PayObject>.new, (failure) {
      // Откатываем ТОЛЬКО свой объект по свежему состоянию: снимок целиком
      // стирал оплату и автоплатёж, сохранённые пока шла запись.
      final latest = state.value ?? current;
      _set(latest.copyWith(
        objects: [
          for (final o in latest.objects)
            if (o.id != object.id)
              o
            else if (known)
              previous.first,
        ],
      ));
      return Fail<PayObject>(failure);
    });
  }

  /// ПЕРЕХОДНЫЕ ОБЁРТКИ над [saveObject]: экран объектов ещё различает
  /// добавление и правку, хотя репозиторий давно нет.
  Future<Result<PayObject>> addObject(PayObject object) => saveObject(object);

  Future<Result<PayObject>> updateObject(PayObject object) => saveObject(object);

  /// Сначала ОТКЛЮЧАЕТ счета объекта, потом удаляет объект: каскада
  /// на сервере не будет, и контракт не должен на него рассчитывать.
  Future<Result<void>> removeObject(String objectId) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('объекты ещё не загружены'));
    }
    // Что именно убираем — чтобы при отказе вернуть ровно это, а не
    // весь снимок: за время отключения счетов состояние уже уехало.
    final removedObjects = [
      for (final o in current.objects)
        if (o.id == objectId) o,
    ];
    final removedBills = [
      for (final b in current.bills)
        if (b.objectId == objectId) b,
    ];
    _set(current.copyWith(
      objects: [
        for (final o in current.objects)
          if (o.id != objectId) o,
      ],
      bills: [
        for (final b in current.bills)
          if (b.objectId != objectId) b,
      ],
      clearFailure: true,
    ));

    final accountsRepo = ref.read(accountsRepoProvider);
    final attached = [
      for (final a in accountsRepo.cachedAccounts())
        if (a.objectId == objectId) a,
    ];
    for (final account in attached) {
      final off = await accountsRepo.disconnect(account.id);
      if (off.isFail) {
        Log.w(_tag, 'счёт ${account.id} не отключился: ${off.failureOrNull?.message}');
      }
    }

    final result = await _repo.removeObject(objectId, detachAccounts: true);
    if (result.isFail) {
      final latest = state.value ?? current;
      final aliveObjects = {for (final o in latest.objects) o.id};
      final aliveBills = {for (final b in latest.bills) b.id};
      _set(latest.copyWith(
        objects: [
          ...latest.objects,
          for (final o in removedObjects)
            if (!aliveObjects.contains(o.id)) o,
        ],
        bills: [
          ...latest.bills,
          for (final b in removedBills)
            if (!aliveBills.contains(b.id)) b,
        ],
        failure: result.failureOrNull,
      ));
      return result;
    }
    if (attached.isNotEmpty) ref.invalidate(accountsProvider);
    return result;
  }

  /// Дописывает начисления подключённого счёта, чтобы он появился
  /// на главной без полного перезапроса.
  Future<Result<void>> mergeCharges(List<Bill> charges) async {
    if (charges.isEmpty) return const Ok<void>(null);
    final current = state.value;
    if (current != null) {
      final byId = {for (final b in current.bills) b.id: b};
      for (final b in charges) {
        byId[b.id] = b;
      }
      _set(current.copyWith(bills: byId.values.toList(), clearFailure: true));
    }
    final result = await _repo.merge(charges);
    return result.fold((_) => const Ok<void>(null), Fail<void>.new);
  }

  /// ПЕРЕХОДНАЯ: разовая оплата ещё создаёт начисление сама.
  /// Уходит вместе с режимом connect в new_payment_page.
  Future<Result<void>> addBill(Bill bill) => mergeCharges([bill]);

  /// Убирает начисления отключённого счёта ПО accountId.
  void dropByAccount(String accountId) {
    final current = state.value;
    if (current == null || accountId.isEmpty) return;
    final next = [
      for (final b in current.bills)
        if (b.accountId != accountId) b,
    ];
    if (next.length == current.bills.length) return;
    _set(current.copyWith(bills: next));
  }

  void _set(BillsState value) => state = AsyncData(value);
}

final billsProvider = AsyncNotifierProvider<BillsNotifier, BillsState>(BillsNotifier.new);

/// Объекты отдельно: их читают восемь экранов, и начисления им не нужны.
final objectsProvider = Provider<List<PayObject>>(
  (ref) => ref.watch(billsProvider).value?.objects ?? const <PayObject>[],
);

/// Начисления одного объекта — чтобы карточка не пересчитывала список сама.
final billsByObjectProvider = Provider.family<List<Bill>, String>(
  (ref, objectId) => ref.watch(billsProvider).value?.byObject(objectId) ?? const <Bill>[],
);
