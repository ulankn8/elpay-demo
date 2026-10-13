import '../../core/ids.dart';
import '../models.dart';

/// Контракт бэкенда ЭлPay. Одна и та же поверхность у демо-реализации
/// ([MockElPayApi]) и у боевой ([HttpElPayApi]) — репозитории и экраны
/// не знают, с какой из них работают.
///
/// Контракт СОХРАНЯЕТСЯ как единственный шов на бэкенд: подмена демо на бой
/// остаётся одной строкой в `apiProvider`. Параметры здесь не «на будущее»,
/// а те, без которых боевой API придётся менять вместе с репозиториями:
/// постраничность начислений, ключ идемпотентности у операций со счетами,
/// список счетов у обновления начислений и локаль у каталога.
abstract class ElPayApi {
  /// Объекты пользователя (Дом, Родители).
  Future<List<PayObject>> objects();

  /// Создать или обновить объект. Возвращает сохранённый объект: id и
  /// нормализованные поля задаёт источник, а не клиент.
  Future<PayObject> saveObject(PayObject object);

  /// Удалить объект. Каскада на счета нет — их отключает вызывающий.
  Future<void> deleteObject(String objectId);

  /// Текущие начисления по подключённым счетам.
  ///
  /// [objectId] — начисления одного объекта (карточка объекта не тянет всё).
  /// [cursor] и [limit] — постраничность: у семьи с десятью объектами
  /// начислений больше, чем влезает в один ответ.
  Future<List<Bill>> bills({String? objectId, String? cursor, int limit = 100});

  /// Подключённые лицевые счета.
  Future<List<ConnectedAccount>> accounts();

  /// Поиск счетов в реестрах поставщиков — по номеру или по адресу.
  /// [AccountQuery] несёт `providerId`: поиск от значка услуги на главной
  /// показывает только одного поставщика, а не всё, что найдено по адресу.
  Future<List<AccountCandidate>> search(AccountQuery query);

  /// Подтверждение владения счётом кодом из квитанции или SMS.
  Future<AccountCandidate> confirm({required String candidateId, required String code});

  /// Подключение найденного счёта к объекту. Возвращает счёт и начисление,
  /// если оно уже выставлено.
  ///
  /// [key] уходит заголовком `Idempotency-Key`: повтор по кнопке и повтор
  /// из Outbox идут с ТЕМ ЖЕ ключом, поэтому шлюз не подключит счёт дважды.
  Future<ConnectResult> connect({
    required String candidateId,
    required String objectId,
    required IdempotencyKey key,
  });

  /// Отключение счёта: начисления перестают приходить, история остаётся.
  /// [key] — та же защита от двойного выполнения, что у [connect].
  Future<void> disconnect(String accountId, {required IdempotencyKey key});

  /// Перенос счёта на другой объект — вместо «отключить и подключить заново»:
  /// повторное подключение теряет историю и может потребовать код заново.
  Future<ConnectedAccount> move({required String accountId, required String objectId});

  /// Обновление начислений. Пустой [accountIds] — по всем счетам;
  /// непустой — только по названным (кнопка «повторить только упавшие»).
  Future<SyncResult> syncCharges({List<String> accountIds = const []});

  /// Каталог платежей: категории, поставщики, значки услуг, способы оплаты,
  /// реквизиты банка. Названия приходят уже переведёнными, поэтому локаль —
  /// параметр запроса, а не дело клиента.
  Future<Catalog> catalog({required String locale});

  /// История платежей. [from]/[to] — период для отчётов, [cursor] —
  /// постраничность: история растёт каждый месяц и целиком не нужна.
  Future<List<Payment>> history({DateTime? from, DateTime? to, String? cursor});
}

/// Что вернулось после подключения счёта.
class ConnectResult {
  const ConnectResult({required this.account, this.bill, this.pending = false});

  final ConnectedAccount account;

  /// Начисление, если поставщик его уже выставил. null — счёт подключён,
  /// но платить пока нечего; фальшивое начисление на 0 сом НЕ создаётся.
  final Bill? bill;

  /// Поставщик подтверждает подключение асинхронно: счёт в списке есть,
  /// но начисления по нему придут не сразу. Строка рисуется как «подключаем»
  /// (s.pendingConnect), а не как готовая.
  final bool pending;
}

/// Результат обновления начислений.
class SyncResult {
  const SyncResult({
    required this.bills,
    required this.accounts,
    required this.syncedAt,
    this.failed = const {},
  });

  final List<Bill> bills;
  final List<ConnectedAccount> accounts;
  final DateTime syncedAt;

  /// Счета, по которым обновление не прошло: accountId → код ошибки.
  ///
  /// Частичный отказ у одного поставщика не должен выглядеть общей ошибкой:
  /// остальные счета обновились, и экран обязан показать оба факта.
  final Map<String, String> failed;

  /// По каким счетам обновление не прошло — для «повторить только упавшие».
  List<String> get failedIds => failed.keys.toList();

  bool get hasFailures => failed.isNotEmpty;

  /// Что-то обновилось, но не всё.
  bool get isPartial => failed.isNotEmpty && failed.length < accounts.length;
}
