import 'demo_data.dart';
import 'models.dart';

/// Счета и объекты. Сейчас — демо-данные пилота,
/// дальше — выдача бэкенда по подключённым лицевым счетам.
abstract class BillsRepository {
  Future<List<PayObject>> objects();
  Future<List<Bill>> bills();
}

class MockBillsRepository implements BillsRepository {
  @override
  Future<List<PayObject>> objects() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Demo.objects;
  }

  @override
  Future<List<Bill>> bills() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return Demo.bills(DateTime.now());
  }
}
