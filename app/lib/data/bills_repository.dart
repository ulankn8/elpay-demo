import '../core/cache/local_store.dart';
import '../core/logger.dart';
import '../core/result.dart';
import 'api/elpay_api.dart';
import 'models.dart';

/// Снимок данных главной: объекты, начисления и время последнего обновления.
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
}

/// Объекты и начисления. Отдаёт сохранённое мгновенно, затем обновляет из API.
abstract class BillsRepository {
  /// Сохранённый снимок без обращения к сети (может быть пустым).
  BillsSnapshot cached();

  /// Загрузка: [refresh] = true — всегда идём в сеть.
  Future<Result<BillsSnapshot>> load({bool refresh = false});
}

class DefaultBillsRepository implements BillsRepository {
  DefaultBillsRepository({
    required this.api,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ElPayApi api;
  final LocalStore store;
  final DateTime Function() _clock;

  /// Насколько свежим считаем кэш, прежде чем идти в сеть.
  static const ttl = Duration(minutes: 15);
  static const _tag = 'bills';

  @override
  BillsSnapshot cached() {
    final objects = (store.readList(CacheKeys.objects) ?? const []).map(PayObject.fromJson).toList();
    final bills = (store.readList(CacheKeys.bills) ?? const []).map(Bill.fromJson).toList();
    if (objects.isEmpty && bills.isEmpty) return BillsSnapshot.empty;
    return BillsSnapshot(
      objects: objects,
      bills: bills,
      syncedAt: store.updatedAt(CacheKeys.bills),
      fromCache: true,
    );
  }

  @override
  Future<Result<BillsSnapshot>> load({bool refresh = false}) async {
    final now = _clock();
    final cache = cached();
    final fresh = !store.isStale(CacheKeys.bills, ttl, now: now);
    if (!refresh && fresh && cache.objects.isNotEmpty) {
      Log.d(_tag, 'отдаём кэш, он свежий');
      return Ok(cache);
    }

    final result = await guard(() async {
      final objects = await api.objects();
      final bills = await api.bills();
      return BillsSnapshot(objects: objects, bills: bills, syncedAt: now);
    });

    return result.fold(
      (snapshot) async {
        await store.writeJson(CacheKeys.objects,
            [for (final o in snapshot.objects) o.toJson()], now: now);
        await store.writeJson(CacheKeys.bills,
            [for (final b in snapshot.bills) b.toJson()], now: now);
        return Ok(snapshot);
      },
      (failure) {
        Log.w(_tag, 'загрузка не удалась: ${failure.message}');
        // Есть сохранённое — показываем его, экран сам нарисует плашку офлайна.
        if (cache.objects.isNotEmpty) return Ok(cache);
        return Fail<BillsSnapshot>(failure);
      },
    );
  }
}
