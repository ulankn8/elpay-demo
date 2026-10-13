/// Инъекция «сейчас».
///
/// `DateTime.now()` прошит в десятке мест — в `build()` нотифаеров, в
/// демо-данных, в расчёте сроков оплаты. Из-за этого тест, который зависит
/// от даты, зелёный сегодня и красный первого числа. Все, кому нужно время,
/// принимают [Clock] и получают в тестах фиксированное значение.
typedef Clock = DateTime Function();

/// Системные часы — значение по умолчанию в боевом коде.
///
/// Передаётся как `clock ?? systemClock`, а не как `() => DateTime.now()`,
/// чтобы в стеке было видно, кто именно спросил время.
DateTime systemClock() => DateTime.now();

/// Фиксированное время для тестов: `Clock c = at(DateTime(2026, 3, 10))`.
Clock at(DateTime value) => () => value;

/// Часы, которые двигаются только руками теста.
///
/// Нужны там, где важна не дата, а разница: протухание кэша по TTL,
/// пауза между попытками очереди, «начисления давно не обновлялись».
///
/// Передаётся как `clock.call` — у [Clock] тип функции, а не объекта:
/// ```dart
/// final clock = MovableClock(DateTime(2026, 3, 10));
/// final store = CachePolicy(..., clock: clock.call);
/// clock.advance(const Duration(hours: 13));
/// ```
class MovableClock {
  MovableClock(this.value);

  /// Текущее «сейчас». Можно и присвоить напрямую, если нужен прыжок назад.
  DateTime value;

  void advance(Duration d) => value = value.add(d);

  /// Позволяет вызывать объект как функцию: `clock()`.
  DateTime call() => value;

  /// Часы как значение типа [Clock] — для параметров и провайдеров.
  Clock get clock => () => value;
}
