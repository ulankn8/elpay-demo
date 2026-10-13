import 'dart:math';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'logger.dart';

/// Источник случайности по умолчанию. `Random.secure()` доступен не везде
/// (на вебе зависит от окружения), поэтому падение не роняет приложение:
/// ключ идемпотентности защищает от двойного списания, а не от подбора.
final Random _defaultRandom = _makeRandom();

Random _makeRandom() {
  try {
    return Random.secure();
  } catch (_) {
    Log.w('ids', 'Random.secure() недоступен, берём обычный');
    return Random();
  }
}

String _hex(int bytes, Random random) {
  final sb = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    sb.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Ключ идемпотентности: один на ПОПЫТКУ пользователя, а не на HTTP-запрос.
///
/// Случайный, не выводится из входных данных: иначе «отключил и подключил
/// заново» боевой шлюз дедупит навсегда. Повтор по кнопке и повтор из Outbox
/// идут с тем же ключом, поэтому шлюз не проведёт операцию дважды.
@immutable
class IdempotencyKey {
  /// `<scope>-<16 случайных байт в hex>`, scope — 'accounts.connect',
  /// 'payments.pay'. [random] передают только тесты.
  factory IdempotencyKey.create(String scope, {Random? random}) =>
      IdempotencyKey.raw('$scope-${_hex(16, random ?? _defaultRandom)}');

  const IdempotencyKey.raw(this.value);

  final String value;

  /// Пустой ключ — признак, что операция ещё не получила своей попытки.
  bool get isEmpty => value.isEmpty;

  /// Префикс до первого дефиса: по нему в логах видно, что за операция.
  String get scope {
    final i = value.indexOf('-');
    return i <= 0 ? value : value.substring(0, i);
  }

  String toJson() => value;

  /// Разбор сохранённого ключа (очередь, кэш попытки).
  ///
  /// Если в хранилище ключа нет или он битый, выдаётся НОВЫЙ: без ключа
  /// запрос всё равно уйдёт, и лучше новая попытка, чем падение при чтении
  /// очереди. Там, где важно отличить «не было ключа», берите [tryFromJson].
  static IdempotencyKey fromJson(Object? j) {
    final parsed = tryFromJson(j);
    if (parsed != null) return parsed;
    Log.w('ids', 'ключ идемпотентности не прочитан ($j), выдаём новый');
    return IdempotencyKey.create('restored');
  }

  /// Тот же разбор, но null вместо нового ключа — для Outbox и миграций.
  static IdempotencyKey? tryFromJson(Object? j) {
    if (j is IdempotencyKey) return j;
    if (j is String && j.isNotEmpty) return IdempotencyKey.raw(j);
    if (j is Map) {
      final v = j['value'];
      if (v is String && v.isNotEmpty) return IdempotencyKey.raw(v);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is IdempotencyKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'IdempotencyKey($value)';
}

/// Генерация id. Инъектируется, чтобы тесты получали предсказуемые значения.
///
/// Сейчас id делаются прямо в UI как 'b-${DateTime.now().millisecondsSinceEpoch}'
/// (accounts_page, new_payment_page, objects_page, event_page) — два нажатия
/// в одну миллисекунду дают один id, и локальный id не отличить от серверного.
abstract class IdGen {
  /// Локальный id до ответа сервера: `loc_<prefix>_<...>`.
  /// Префикс 'loc_' — договорённость: по нему видно, что id ещё не серверный.
  String local(String prefix);

  IdempotencyKey key(String scope);
}

/// Боевая генерация: время для порядка, случайность против коллизий.
class DefaultIdGen implements IdGen {
  DefaultIdGen({Clock? clock, Random? random})
      : _clock = clock ?? systemClock,
        _random = random ?? _defaultRandom;

  final Clock _clock;
  final Random _random;

  @override
  String local(String prefix) =>
      'loc_${prefix}_${_clock().millisecondsSinceEpoch.toRadixString(36)}_${_hex(3, _random)}';

  @override
  IdempotencyKey key(String scope) =>
      IdempotencyKey.create(scope, random: _random);
}

/// Выдаёт 'loc_bill_1', 'accounts.connect-1' — для тестов.
///
/// Счётчики id и ключей раздельные, чтобы ожидаемое значение в тесте
/// не зависело от того, сколько раз до этого спросили соседний метод.
class SeqIdGen implements IdGen {
  SeqIdGen();

  int _locals = 0;
  int _keys = 0;

  /// Сколько значений выдано всего — для проверки «лишних» вызовов.
  int get issued => _locals + _keys;

  @override
  String local(String prefix) => 'loc_${prefix}_${++_locals}';

  @override
  IdempotencyKey key(String scope) => IdempotencyKey.raw('$scope-${++_keys}');

  void reset() {
    _locals = 0;
    _keys = 0;
  }
}
