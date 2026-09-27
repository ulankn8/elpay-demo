import 'models.dart';

/// ЗАГЛУШКА ПЛАТЕЖЕЙ.
///
/// Платёжный шлюз (эквайринг, кошелёк, списание со счёта банка) ещё не
/// подключён. Этот класс имитирует ответ процессинга, чтобы можно было
/// разрабатывать и показывать весь остальной продукт.
///
/// Подключение боевого шлюза = новая реализация [PaymentsRepository];
/// экраны оплаты менять не придётся.
abstract class PaymentsRepository {
  Future<PayResult> pay({
    required List<Bill> bills,
    required String methodId,
    double? partialAmount,
  });

  bool get isStub;
}

class StubPaymentsRepository implements PaymentsRepository {
  @override
  bool get isStub => true;

  @override
  Future<PayResult> pay({
    required List<Bill> bills,
    required String methodId,
    double? partialAmount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final no = 'ЭП-${205100 + DateTime.now().millisecond}';
    return PayResult(PayStatus.success, receiptNo: no);
  }
}
