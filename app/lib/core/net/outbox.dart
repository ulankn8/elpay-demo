import 'dart:convert';

import '../cache/local_store.dart';
import '../logger.dart';

/// Операция, которую не удалось выполнить из-за сети: ждёт своей очереди.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError = '',
  });

  final String id;

  /// Что это за операция: 'connect_account', 'disconnect_account', 'payment'.
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String lastError;

  OutboxItem retried(String error) => OutboxItem(
        id: id,
        kind: kind,
        payload: payload,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastError: error,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  static OutboxItem fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2026),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String? ?? '',
      );
}

/// Очередь отложенных операций. Пока сети нет, действия пользователя
/// не теряются: они ложатся сюда и уходят, когда связь появится.
class Outbox {
  Outbox(this._store);

  final LocalStore _store;
  static const _maxAttempts = 5;

  List<OutboxItem> get items =>
      (_store.readList(CacheKeys.outbox) ?? const []).map(OutboxItem.fromJson).toList();

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  Future<void> add(OutboxItem item) async {
    final next = [...items, item];
    await _save(next);
    Log.i('outbox', 'в очередь: ${item.kind} (${next.length} шт.)');
  }

  Future<void> remove(String id) async {
    await _save(items.where((i) => i.id != id).toList());
  }

  /// Пытается выполнить всё, что накопилось. [send] возвращает true,
  /// если операция прошла. Неудачные остаются в очереди, пока не исчерпают попытки.
  Future<int> flush(Future<bool> Function(OutboxItem item) send) async {
    final queue = items;
    if (queue.isEmpty) return 0;

    var done = 0;
    final left = <OutboxItem>[];
    for (final item in queue) {
      try {
        if (await send(item)) {
          done++;
          continue;
        }
        final retried = item.retried('не прошло');
        if (retried.attempts < _maxAttempts) left.add(retried);
      } catch (e, st) {
        Log.e('outbox', 'ошибка отправки ${item.kind}', e, st);
        final retried = item.retried('$e');
        if (retried.attempts < _maxAttempts) left.add(retried);
      }
    }
    await _save(left);
    Log.i('outbox', 'отправлено $done, осталось ${left.length}');
    return done;
  }

  Future<void> clear() => _store.remove(CacheKeys.outbox);

  Future<void> _save(List<OutboxItem> list) async {
    final now = list.isEmpty ? DateTime(2026) : list.last.createdAt;
    await _store.writeJson(CacheKeys.outbox, list.map((i) => i.toJson()).toList(), now: now);
  }

  /// Для отладки: что лежит в очереди.
  String describe() => jsonEncode(items.map((i) => {'kind': i.kind, 'attempts': i.attempts}).toList());
}
