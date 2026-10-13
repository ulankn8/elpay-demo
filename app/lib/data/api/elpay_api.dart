import '../models.dart';

/// Контракт бэкенда ЭлPay. Одна и та же поверхность у демо-реализации
/// ([MockElPayApi]) и у боевой ([HttpElPayApi]) — репозитории и экраны
/// не знают, с какой из них работают.
abstract class ElPayApi {
  /// Объекты пользователя (Дом, Родители).
  Future<List<PayObject>> objects();

  /// Текущие начисления по подключённым счетам.
  Future<List<Bill>> bills();

  /// Подключённые лицевые счета.
  Future<List<ConnectedAccount>> accounts();

  /// Поиск счетов в реестрах поставщиков — по номеру или по адресу.
  Future<List<AccountCandidate>> search(AccountQuery query);

  /// Подтверждение владения счётом кодом из квитанции или SMS.
  Future<AccountCandidate> confirm({required String candidateId, required String code});

  /// Подключение найденного счёта к объекту. Возвращает счёт и начисление,
  /// если оно уже выставлено.
  Future<ConnectResult> connect({required String candidateId, required String objectId});

  /// Отключение счёта: начисления перестают приходить, история остаётся.
  Future<void> disconnect(String accountId);

  /// Обновление начислений по всем подключённым счетам.
  Future<SyncResult> syncCharges();

  /// История платежей.
  Future<List<Payment>> history();
}

/// Что вернулось после подключения счёта.
class ConnectResult {
  const ConnectResult({required this.account, this.bill});
  final ConnectedAccount account;
  final Bill? bill;
}

/// Результат обновления начислений.
class SyncResult {
  const SyncResult({
    required this.bills,
    required this.accounts,
    required this.syncedAt,
  });
  final List<Bill> bills;
  final List<ConnectedAccount> accounts;
  final DateTime syncedAt;
}
