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
    final current = state.value;
    final result = await _repo.loadCached(refresh: true);
    state = AsyncData(result.fold(
      (data) => _fromSnapshot(
        data.value,
        fromCache: data.fromCache,
        syncedAt: data.updatedAt,
      ).copyWith(clearFailure: true),
      (failure) => (current ?? BillsState.empty)
          .copyWith(failure: failure, fromCache: true),
    ));
  }

  // ───────────────────────── мутации ─────────────────────────

  /// Оптимистично: тумблер переключается сразу, на отказе возвращается
  /// назад. Один образец для всех мутаций ниже.
  Future<Result<void>> setAutopay(String billId, {required bool on}) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('начисления ещё не загружены'));
    }
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
        _set(current); // откат к тому, что было до нажатия
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
        _set(current);
        return Fail<void>(failure);
      },
    );
  }

  Future<Result<PayObject>> saveObject(PayObject object) async {
    final current = state.value;
    if (current == null) {
      return const Fail(AppFailure.notFound('объекты ещё не загружены'));
    }
    final known = current.objects.any((o) => o.id == object.id);
    _set(current.copyWith(
      objects: known
          ? [for (final o in current.objects) o.id == object.id ? object : o]
          : [...current.objects, object],
      clearFailure: true,
    ));

    final result = await _repo.saveObject(object);
    return result.fold(Ok<PayObject>.new, (failure) {
      _set(current);
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
      _set(current.copyWith(failure: result.failureOrNull));
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
