import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../core/ids.dart';
import '../core/result.dart';
import 'models.dart';

/// Почему кандидат не готов к подключению.
///
/// Причина — значение, а не строка: по ней интерфейс выбирает подпись
/// (s.accountClosed, s.confirmOwnership, ...), а правила остаются
/// без локализации и без Flutter.
enum ConnectBlock {
  /// Такой счёт уже подключён — либо так сказал сервер, либо мы сами
  /// нашли его среди подключённых по нормализованному номеру.
  alreadyConnected,

  /// Счёт оформлен на другого человека: нужен код из квитанции или SMS.
  /// Блок снимается подтверждением, поэтому отметить галочкой кандидата
  /// всё равно можно.
  needsConfirm,

  /// Поставщик закрыл счёт (переехали, расторгли договор).
  closedByProvider,

  /// Поставщика нет в каталоге: мы не знаем ни его реквизитов, ни маски
  /// счёта, и подключать «что-то неизвестное» нельзя.
  unknownProvider,
}

/// Кандидат вместе с решением правил — то, что рисует список найденного.
///
/// Экран не выводит ничего сам: `ready`, `selectable` и `reason` уже
/// посчитаны, поэтому одна и та же логика работает в тесте и в интерфейсе.
@immutable
class CandidateView {
  const CandidateView({
    required this.candidate,
    this.blocks = const {},
    this.confirmed = false,
  });

  final AccountCandidate candidate;

  /// Все причины, по которым кандидат не готов.
  final Set<ConnectBlock> blocks;

  /// Владение подтверждено кодом в этом сеансе: блок [ConnectBlock.needsConfirm]
  /// снят, даже если сервер ещё отвечает прежним флагом.
  final bool confirmed;

  String get id => candidate.id;

  /// Подпись строки: название поставщика.
  String get title => candidate.providerTitle;

  /// Блоки с учётом подтверждения.
  Set<ConnectBlock> get effectiveBlocks => confirmed
      ? {
          for (final b in blocks)
            if (b != ConnectBlock.needsConfirm) b,
        }
      : blocks;

  /// Готов к подключению: ни одной причины не осталось.
  bool get ready => effectiveBlocks.isEmpty;

  /// Можно отметить галочкой. Подтверждение — не препятствие: его проходят
  /// в том же списке. Остальные блоки — препятствие.
  bool get selectable => !effectiveBlocks.any((b) => b != ConnectBlock.needsConfirm);

  /// Нужен код подтверждения и он ещё не введён.
  bool get needsConfirm => blocks.contains(ConnectBlock.needsConfirm) && !confirmed;

  /// Главная причина для подписи — в порядке важности для пользователя.
  ConnectBlock? get reason {
    for (final b in const [
      ConnectBlock.alreadyConnected,
      ConnectBlock.closedByProvider,
      ConnectBlock.unknownProvider,
      ConnectBlock.needsConfirm,
    ]) {
      if (effectiveBlocks.contains(b)) return b;
    }
    return null;
  }

  CandidateView copyWith({
    Set<ConnectBlock>? blocks,
    bool? confirmed,
    AccountCandidate? candidate,
  }) =>
      CandidateView(
        candidate: candidate ?? this.candidate,
        blocks: blocks ?? this.blocks,
        confirmed: confirmed ?? this.confirmed,
      );

  @override
  String toString() => 'CandidateView(${candidate.accountNo}, blocks: $blocks)';
}

/// Строка предпросмотра: одно начисление, которое придёт после подключения.
@immutable
class ChargeLine {
  const ChargeLine({
    required this.view,
    required this.amount,
    required this.period,
    required this.due,
    this.calc = const [],
  });

  final CandidateView view;
  final double amount;
  final String period;
  final DateTime due;

  /// Расшифровка начисления: показания, тариф, итог.
  final List<Field> calc;

  String get title => view.title;
}

/// Предпросмотр начислений по выбранному: что именно придёт после
/// подключения. Считается синхронно — данные уже лежат в кандидатах.
@immutable
class ChargesPreview {
  const ChargesPreview({
    required this.lines,
    required this.total,
    this.nearestDue,
    this.withoutCharges = const [],
  });

  static const empty = ChargesPreview(lines: [], total: 0);

  final List<ChargeLine> lines;
  final double total;

  /// Ближайший срок оплаты из всех строк.
  final DateTime? nearestDue;

  /// Счета без выставленного начисления: подключаем, но Bill на 0 сом
  /// НЕ создаём — именно такой фальшивый счёт ломает разбивку на главной.
  final List<CandidateView> withoutCharges;

  bool get isEmpty => lines.isEmpty;

  /// Сколько счетов подключится всего — со начислениями и без.
  int get count => lines.length + withoutCharges.length;
}

/// Что именно отправляем на подключение. Строится правилами, а не экраном:
/// экран показывает план, а не придумывает его.
@immutable
class ConnectPlan {
  const ConnectPlan({
    required this.items,
    required this.objectId,
    required this.keys,
  });

  final List<CandidateView> items;
  final String objectId;

  /// candidateId → ключ идемпотентности: тот же при повторе по кнопке
  /// и при отправке из Outbox, поэтому счёт не подключится дважды.
  final Map<String, IdempotencyKey> keys;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  IdempotencyKey keyOf(String candidateId) =>
      keys[candidateId] ?? IdempotencyKey.create(ConnectRules.connectScope);
}

/// Можно ли отключать: предупреждаем про неоплаченное и про последний
/// счёт объекта. Решение остаётся за пользователем — правила не запрещают,
/// а говорят, о чём он должен знать.
@immutable
class DisconnectCheck {
  const DisconnectCheck({
    required this.allowed,
    this.unpaidAmount = 0,
    this.lastForObject = false,
  });

  /// Отключение возможно. false — операция уже в очереди, второй раз
  /// отправлять нечего.
  final bool allowed;

  /// Сумма неоплаченных начислений по этому счёту.
  final double unpaidAmount;

  /// Это последний счёт объекта: после отключения объект останется пустым.
  final bool lastForObject;

  /// Нужно предупредить до отключения.
  bool get needsWarning => allowed && (unpaidAmount > 0 || lastForObject);
}

/// Правила подключения счёта.
///
/// Ни async, ни Flutter, ни Riverpod — поэтому главный тест фичи это
/// обычный юнит-тест правила, а не тест мока через ProviderContainer,
/// и то же правило покрывает боевую реализацию.
///
/// Всё, что решается без сети, решается здесь: проверка номера по маске
/// поставщика, сверка с уже подключёнными, предвыбор, подсказка объекта,
/// состав плана с ключами идемпотентности, предпросмотр начислений,
/// предупреждения перед отключением.
class ConnectRules {
  const ConnectRules({this.maxBatch = 10, this.chargeEpsilon = 0.01});

  /// Сколько счетов отправляем за одну попытку. Больше — это почти всегда
  /// случайный «выбрать всё» по адресу многоквартирного дома.
  final int maxBatch;

  /// Начисление меньше этого считается отсутствующим: Bill на 0 сом
  /// не создаётся ни в демо, ни в бою.
  final double chargeEpsilon;

  /// Область ключа идемпотентности для подключения.
  static const connectScope = 'accounts.connect';

  /// Область ключа идемпотентности для отключения.
  static const disconnectScope = 'accounts.disconnect';

  /// Поле формы, к которому привязывается ошибка номера счёта.
  static const fieldAccountNo = 'accountNo';

  /// Поле «объект»: к нему привязывается «объект не выбран».
  static const fieldObjectId = 'objectId';

  /// Псевдополе «выбранные счета»: к нему привязывается «нечего подключать».
  static const fieldSelected = 'selected';

  // ────────────────────────── проверка формы ──────────────────────────

  /// Проверка номера ДО сети. Номер нормализуется по образцу поставщика
  /// и проверяется по его маске.
  ///
  /// Ошибка идёт как `AppFailure.validation(field: 'accountNo')` и садится
  /// в `errorText` поля, а не в снек: пользователь видит её там, где
  /// ошибся. Поставщик неизвестен — проверяется только разумная длина.
  Result<AccountQuery> buildAccountQuery(String rawAccountNo, {ProviderItem? provider}) {
    final mask = provider?.mask ?? AccountMask.any;
    final raw = rawAccountNo.trim();
    if (raw.isEmpty) {
      return const Fail(AppFailure.validation('номер счёта не введён', field: fieldAccountNo));
    }
    final value = mask.normalize(raw);
    if (!mask.matches(value)) {
      return Fail(AppFailure.validation(
        mask.hint.isEmpty
            ? 'номер не похож на лицевой счёт'
            : 'номер не по формату поставщика (образец ${mask.hint})',
        field: fieldAccountNo,
      ));
    }
    return Ok(AccountQuery.byAccount(value, providerId: provider?.id));
  }

  /// Проверка адресной формы. Город, улица и дом обязательны, квартира —
  /// нет: в частном доме её не бывает.
  Result<AccountQuery> buildAddressQuery({
    required String city,
    required String street,
    required String house,
    String flat = '',
    String? providerId,
  }) {
    if (city.trim().isEmpty) {
      return const Fail(AppFailure.validation('город не указан', field: 'city'));
    }
    if (street.trim().isEmpty) {
      return const Fail(AppFailure.validation('улица не указана', field: 'street'));
    }
    if (house.trim().isEmpty) {
      return const Fail(AppFailure.validation('дом не указан', field: 'house'));
    }
    return Ok(AccountQuery.byAddress(
      city: city.trim(),
      street: street.trim(),
      house: house.trim(),
      flat: flat.trim(),
      providerId: providerId,
    ));
  }

  // ───────────────────────── главное правило ─────────────────────────

  /// Что с найденным делать.
  ///
  /// Серверные флаги (`needsConfirm`, `alreadyConnected`) ПРИОРИТЕТНЫ:
  /// правила их не отменяют, а добирают то, чего сервер знать не может —
  /// сверку с локально подключёнными по НОРМАЛИЗОВАННОМУ номеру (сервер
  /// не знает, что мы уже подключили этот счёт на другом устройстве),
  /// неизвестного поставщика и вывод о владельце по [session].
  ///
  /// [closedIds] — кандидаты, закрытые поставщиком. Отдельным списком,
  /// потому что в `AccountCandidate` флага «счёт закрыт» ещё нет
  /// (models.dart правит другая лана); как только поле появится, список
  /// уйдёт, а значение [ConnectBlock.closedByProvider] останется.
  List<CandidateView> classify({
    required List<AccountCandidate> found,
    required List<ConnectedAccount> connected,
    Session? session,
    Catalog? catalog,
    Set<String> closedIds = const {},
  }) {
    final mine = {for (final a in connected) _accountKey(a.providerId, a.accountNo)};

    return [
      for (final c in found)
        CandidateView(
          candidate: c,
          blocks: {
            // Серверные флаги — первыми и без условий.
            if (c.alreadyConnected) ConnectBlock.alreadyConnected,
            if (c.needsConfirm) ConnectBlock.needsConfirm,
            // Своё знание: тот же счёт уже в списке подключённых.
            if (mine.contains(_accountKey(c.providerId, c.accountNo)))
              ConnectBlock.alreadyConnected,
            if (closedIds.contains(c.id)) ConnectBlock.closedByProvider,
            // Каталог не загружен (null) — не повод блокировать: это наша
            // проблема, а не пользователя.
            if (catalog != null && catalog.providerById(c.providerId) == null)
              ConnectBlock.unknownProvider,
            // Счёт на другую фамилию: сервер мог не прислать флаг, но
            // подключать чужой счёт без кода всё равно нельзя.
            if (session != null && !_sameHolder(c.holder, session)) ConnectBlock.needsConfirm,
          },
        ),
    ];
  }

  /// Что отметить галочками сразу: всё готовое к подключению, но не больше
  /// [maxBatch] — иначе «выбрать всё» по адресу дома отметит десятки счетов.
  Set<String> preselect(List<CandidateView> views) {
    final out = <String>{};
    for (final v in views) {
      if (!v.ready) continue;
      if (out.length >= maxBatch) break;
      out.add(v.id);
    }
    return out;
  }

  /// К какому объекту предложить подключение: по совпадению адреса
  /// кандидата с адресом объекта, иначе единственный объект, иначе null —
  /// и тогда экран спрашивает, а не подключает «куда-нибудь».
  ///
  /// Адреса сравниваются по словам, а не строкой: «Ош, ул. Курманжан Датка,
  /// 212» у объекта и «Ош, ул. Курманжан Датка, д. 212, кв. 14» у кандидата
  /// это одно место, и равенство строк здесь не работает.
  String? suggestObject({
    required List<CandidateView> chosen,
    required List<PayObject> objects,
  }) {
    if (objects.isEmpty) return null;
    final addresses = [
      for (final v in chosen)
        if (v.candidate.address.trim().isNotEmpty) _addressTokens(v.candidate.address),
    ];

    String? best;
    var bestScore = 0;
    for (final o in objects) {
      final tokens = _addressTokens(o.address);
      if (tokens.isEmpty) continue;
      var score = 0;
      for (final a in addresses) {
        // Все слова адреса объекта есть в адресе кандидата: объект описан
        // короче, поэтому проверяем вложенность, а не равенство.
        if (tokens.every(a.contains)) score += tokens.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = o.id;
      }
    }
    if (best != null) return best;
    return objects.length == 1 ? objects.first.id : null;
  }

  /// Собирает план: отбрасывает заблокированных, режет по [maxBatch],
  /// выдаёт ключи идемпотентности.
  ///
  /// `Fail(validation)` — когда плана нет: объектов вообще не создано,
  /// объект не выбран или подключать нечего. Раньше в этом случае
  /// подключение молча выходило из метода: ни снека, ни подсказки.
  ///
  /// [reuse] — ключи прошлой попытки: повтор идёт с теми же ключами,
  /// поэтому шлюз не проведёт подключение второй раз.
  Result<ConnectPlan> plan({
    required List<CandidateView> views,
    required Set<String> selected,
    required String? objectId,
    required List<PayObject> objects,
    required IdGen ids,
    Map<String, IdempotencyKey> reuse = const {},
  }) {
    if (objects.isEmpty) {
      return const Fail(AppFailure.validation('нет ни одного объекта', field: fieldObjectId));
    }
    final target = objectId?.trim() ?? '';
    if (target.isEmpty) {
      return const Fail(AppFailure.validation('объект не выбран', field: fieldObjectId));
    }
    if (!objects.any((o) => o.id == target)) {
      return Fail(AppFailure.validation('объект $target не найден', field: fieldObjectId));
    }

    final chosen = [
      for (final v in views)
        if (selected.contains(v.id) && v.ready) v,
    ];
    if (chosen.isEmpty) {
      return const Fail(AppFailure.validation('нечего подключать', field: fieldSelected));
    }

    final items = chosen.length <= maxBatch ? chosen : chosen.sublist(0, maxBatch);
    return Ok(ConnectPlan(
      items: items,
      objectId: target,
      keys: {
        for (final v in items) v.id: reuse[v.id] ?? ids.key(connectScope),
      },
    ));
  }

  /// Предпросмотр начислений по выбранному — синхронно, без сети.
  ///
  /// Срок считается так же, как его поставит источник при создании
  /// начисления, иначе предпросмотр обещал бы одну дату, а приходила
  /// другая.
  ChargesPreview preview(Iterable<CandidateView> chosen, {required DateTime now}) {
    final lines = <ChargeLine>[];
    final without = <CandidateView>[];

    for (final v in chosen) {
      final c = v.candidate;
      if (c.amount <= chargeEpsilon) {
        // Счёт есть, начисления нет: подключаем, но строки не рисуем
        // и Bill на 0 сом не ждём.
        without.add(v);
        continue;
      }
      lines.add(ChargeLine(
        view: v,
        amount: c.amount,
        period: c.period,
        due: dueDateOf(c.dueDay, now),
        calc: c.calc,
      ));
    }
    lines.sort((a, b) => a.due.compareTo(b.due));

    return ChargesPreview(
      lines: lines,
      total: lines.fold<double>(0, (sum, l) => sum + l.amount),
      nearestDue: lines.isEmpty ? null : lines.first.due,
      withoutCharges: without,
    );
  }

  /// Срок оплаты по дню месяца. День вне 1..31 — ошибка на той стороне,
  /// поджимаем, чтобы дата не уехала в прошлый месяц.
  static DateTime dueDateOf(int dueDay, DateTime now) =>
      DateTime(now.year, now.month, dueDay.clamp(1, 31));

  /// О чём предупредить до отключения счёта.
  DisconnectCheck checkDisconnect({
    required ConnectedAccount account,
    required List<ConnectedAccount> all,
    required List<Bill> bills,
  }) {
    if (account.isPendingDisconnect) {
      // Отключение уже в очереди: второй раз отправлять нечего.
      return const DisconnectCheck(allowed: false);
    }
    var unpaid = 0.0;
    for (final b in bills) {
      if (b.paid) continue;
      if (billBelongsTo(b, account)) unpaid += b.amount;
    }
    final sameObject = all.where((a) => a.objectId == account.objectId && a.id != account.id);
    return DisconnectCheck(
      allowed: true,
      unpaidAmount: unpaid,
      lastForObject: sameObject.isEmpty,
    );
  }

  /// Начисление принадлежит счёту.
  ///
  /// Сверяем по `accountId`; строка номера — только для записей, у которых
  /// привязки ещё нет: у разных поставщиков номера совпадают, и сверка
  /// по номеру снесла бы начисления чужого счёта.
  static bool billBelongsTo(Bill bill, ConnectedAccount account) =>
      bill.accountId.isEmpty
          ? AccountMask.keyOf(bill.account) == AccountMask.keyOf(account.accountNo)
          : bill.accountId == account.id;

  /// Предложить ли обновление начислений: давно не синхронизировали
  /// или есть счета, которые в прошлый раз не обновились.
  bool shouldSuggestSync({
    required DateTime? lastSyncAt,
    required List<ConnectedAccount> accounts,
    required DateTime now,
    Duration stale = const Duration(hours: 12),
  }) {
    if (accounts.isEmpty) return false;
    if (accounts.any((a) => a.status == AccountSyncStatus.failed)) return true;
    if (lastSyncAt == null) return true;
    return now.difference(lastSyncAt) > stale;
  }

  /// Ключ сравнения счёта: поставщик плюс нормализованный номер.
  /// Только номера мало — у разных поставщиков они совпадают.
  static String _accountKey(String providerId, String accountNo) =>
      '$providerId|${AccountMask.keyOf(accountNo)}';

  /// Счёт оформлен на этого пользователя: сравниваем фамилию. Полного
  /// совпадения ждать нельзя — поставщик пишет «Токтогулова А.», а в
  /// профиле «Токтогулова Айнура».
  static bool _sameHolder(String holder, Session session) {
    final a = _word(holder);
    final b = _word(session.name);
    return a.isEmpty || b.isEmpty || a == b;
  }

  static String _word(String raw) {
    final parts = raw.trim().toLowerCase().replaceAll('ё', 'е').split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }
}

/// Слова адреса, которые пишут как угодно и которые ничего не различают.
const _addressNoise = <String>{
  'ул', 'улица', 'д', 'дом', 'кв', 'квартира', 'г', 'город',
  'мкр', 'микрорайон', 'пр', 'проспект', 'пер', 'переулок', 'стр', 'корпус',
};

/// Адрес как набор значащих слов: регистр, «ё», запятые и «д./кв.» убраны.
Set<String> _addressTokens(String raw) => {
      for (final part in raw.toLowerCase().replaceAll('ё', 'е').split(RegExp(r'[^0-9a-zа-я]+')))
        if (part.isNotEmpty && !_addressNoise.contains(part)) part,
    };
