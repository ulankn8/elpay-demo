import '../core/clock.dart';
import '../core/failure.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/result.dart';
import 'models.dart';

/// ЗАГЛУШКА ПЛАТЕЖЕЙ.
///
/// Платёжный шлюз (эквайринг, кошелёк, списание со счёта банка) ещё не
/// подключён. [StubPaymentsRepository] имитирует ответ процессинга, чтобы
/// можно было разрабатывать и показывать весь остальной продукт, и честно
/// сообщает об этом через [isStub] — экран оплаты рисует по нему плашку.
///
/// Форма контракта — уже боевая, и меняться при подключении шлюза не должна:
///   * [charge] возвращает [Result], а не бросает исключение;
///   * у каждой попытки есть [IdempotencyKey] — повтор по кнопке и повтор из
///     очереди идут с тем же ключом, поэтому шлюз не спишет деньги дважды;
///   * [status] существует потому, что боевой шлюз асинхронный: он отвечает
///     «принято», а исход приходит позже;
///   * [partialAmount] доезжает до репозитория, а не теряется в экране.
///
/// Подключение боевого шлюза = новая реализация этого контракта и одна
/// строка в `paymentsRepoProvider`; экраны оплаты не правятся.
abstract class PaymentsRepository {
  /// Списание. [bills] пуст — платёж по реквизитам или QR, тогда сумму
  /// задаёт [partialAmount].
  Future<Result<PayResult>> charge({
    required List<Bill> bills,
    required String methodId,
    required IdempotencyKey key,
    double? partialAmount,
  });

  /// Чем кончилась попытка [key]. Боевой шлюз отвечает по ключу, поэтому
  /// экран может дождаться исхода после обрыва связи или перезапуска.
  /// Про незнакомый ключ — `Fail(notFound)`.
  Future<Result<PayResult>> status(IdempotencyKey key);

  /// Это заглушка, а не боевой шлюз. Экран обязан предупредить.
  bool get isStub;

  /// ПЕРЕХОДНАЯ ОБЁРТКА для features/payments/pay_flow.dart и
  /// test/payment_flow_test.dart: они пока разбирают [PayResult] напрямую.
  ///
  /// Ключ здесь выдаётся на КАЖДЫЙ вызов, поэтому защиты от двойного
  /// списания у этого пути нет — ровно поэтому он и должен уйти вместе
  /// с переводом pay_flow на [charge] (его автор — соседняя лана).
  Future<PayResult> pay({
    required List<Bill> bills,
    required String methodId,
    double? partialAmount,
  }) async {
    final result = await charge(
      bills: bills,
      methodId: methodId,
      key: IdempotencyKey.create('payments.pay'),
      partialAmount: partialAmount,
    );
    return result.fold(
      (value) => value,
      // Старый путь умеет показать только reason — отдаём ему текст ошибки,
      // иначе снек у пользователя оказывается пустым.
      (failure) => PayResult(PayStatus.declined, reason: failure.message),
    );
  }
}

class StubPaymentsRepository extends PaymentsRepository {
  StubPaymentsRepository({
    Clock? clock,
    this.latency = const Duration(milliseconds: 1400),
  }) : _clock = clock ?? systemClock;

  /// Сколько «думает» процессинг. В тестах — `Duration.zero`.
  final Duration latency;

  final Clock _clock;

  static const _tag = 'payments';

  /// Исходы попыток по ключу идемпотентности — в памяти: перезапуск их
  /// забывает, и это ограничение заглушки, а не контракта. Повтор с тем же ключом
  /// получает ТОТ ЖЕ результат и тот же номер квитанции — это и есть
  /// защита от двойного списания, которую обязан иметь и боевой шлюз.
  final Map<String, PayResult> _attempts = {};

  /// Счётчик номеров квитанций — чтобы они не совпадали в пределах секунды.
  int _issued = 0;

  @override
  bool get isStub => true;

  @override
  Future<Result<PayResult>> charge({
    required List<Bill> bills,
    required String methodId,
    required IdempotencyKey key,
    double? partialAmount,
  }) async {
    final known = _attempts[key.value];
    if (known != null) {
      Log.i(_tag, 'повтор попытки ${key.value} — отдаём прошлый результат');
      return Ok(known);
    }

    final total = bills.fold<double>(0, (sum, b) => sum + b.amount);
    if (partialAmount != null) {
      if (partialAmount <= 0) {
        return const Fail(
          AppFailure.validation('сумма должна быть больше нуля', field: 'amount'),
        );
      }
      if (bills.length > 1) {
        return const Fail(AppFailure.validation(
          'частичная сумма возможна только по одному начислению',
          field: 'amount',
        ));
      }
      if (bills.isNotEmpty && partialAmount > total + 0.01) {
        return const Fail(
          AppFailure.validation('сумма больше начисления', field: 'amount'),
        );
      }
    }
    if (methodId.isEmpty) {
      Log.w(_tag, 'способ оплаты не выбран — боевой шлюз такой запрос отклонит');
    }

    await Future<void>.delayed(latency);

    // Ветки declined/offline заглушка не воспроизводит — она всегда отвечает
    // успехом. Это известная дыра: пока нет шлюза, обработка отказа в экранах
    // непроверена, и закрывается она вместе с боевой реализацией.
    final result = PayResult(PayStatus.success, receiptNo: _nextReceiptNo());
    _attempts[key.value] = result;
    Log.i(_tag,
        'заглушка провела платёж ${key.value} на ${partialAmount ?? total} в ${_clock()}');
    return Ok(result);
  }

  @override
  Future<Result<PayResult>> status(IdempotencyKey key) async {
    final known = _attempts[key.value];
    if (known == null) {
      return Fail(AppFailure.notFound('о попытке ${key.value} ничего не известно'));
    }
    return Ok(known);
  }

  /// ЕДИНСТВЕННОЕ место, где номер квитанции выдумывается клиентом.
  ///
  /// В бою номер выдаёт процессинг. Клиентский `'ЭП-${DateTime.now().millisecond}'`
  /// до прода доживать не должен: в пределах секунды номера совпадают, и
  /// сверка с выпиской по такому номеру невозможна. Счётчик здесь — чтобы
  /// хотя бы в демо номера не повторялись и были предсказуемы в тестах.
  String _nextReceiptNo() => 'ЭП-${205100 + ++_issued}';
}
