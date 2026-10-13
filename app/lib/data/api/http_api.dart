import '../../core/ids.dart';
import '../../core/logger.dart';
import '../models.dart';
import 'api_client.dart';
import 'elpay_api.dart';

/// Боевая реализация контракта: те же методы поверх HTTP.
///
/// ЭНДПОИНТЫ ЗАФИКСИРОВАНЫ В DOC-КОММЕНТАРИЯХ КАЖДОГО МЕТОДА — это и есть
/// спецификация для бэкендера, а не отдельный файл, который разъедется
/// с кодом. Когда бэкенд будет готов, правок ждёт только этот файл: экраны
/// и репозитории остаются как есть.
///
/// Включается одной строкой в providers.dart:
/// `apiProvider → HttpElPayApi(ApiClient())`.
///
/// ЧЕГО НЕ ХВАТАЕТ КЛИЕНТУ (правка `api/api_client.dart`, другой автор):
/// метода PATCH и своих заголовков у запроса. Из-за этого ключ
/// идемпотентности пока уходит ПОЛЕМ ТЕЛА `idempotencyKey`, а не заголовком
/// `Idempotency-Key`, а перенос счёта отправляется POST'ом. Контракт для
/// бэкенда в комментариях описан целевой — расхождение снимается добавлением
/// `ApiClient.postJson(..., headers:)`, `deleteJson(..., headers:)` и
/// `patchJson`, и тогда правятся только три строки ниже.
class HttpElPayApi implements ElPayApi {
  HttpElPayApi(this._client);

  final ApiClient _client;

  /// `GET /objects`
  @override
  Future<List<PayObject>> objects() async {
    final list = await _client.getList('/objects');
    return [
      for (final o in list)
        if (o is Map<String, dynamic>) PayObject.fromJson(o),
    ];
  }

  /// `GET /bills?objectId=&cursor=&limit=`
  @override
  Future<List<Bill>> bills({String? objectId, String? cursor, int limit = 100}) async {
    final list = await _client.getList('/bills', query: {
      'objectId': ?objectId,
      'cursor': ?cursor,
      'limit': '$limit',
    });
    return [
      for (final b in list)
        if (b is Map<String, dynamic>) Bill.fromJson(b),
    ];
  }

  /// `GET /accounts`
  @override
  Future<List<ConnectedAccount>> accounts() async {
    final list = await _client.getList('/accounts');
    return [
      for (final a in list)
        if (a is Map<String, dynamic>) ConnectedAccount.fromJson(a),
    ];
  }

  /// `GET /accounts/search?account=&provider=&city=&street=&house=&flat=`
  @override
  Future<List<AccountCandidate>> search(AccountQuery query) async {
    final list = await _client.getList('/accounts/search', query: {
      if (query.isByAccount) 'account': query.accountNo,
      if (query.providerId != null) 'provider': query.providerId!,
      if (!query.isByAccount) ...{
        'city': query.city,
        'street': query.street,
        'house': query.house,
        if (query.flat.isNotEmpty) 'flat': query.flat,
      },
    });
    return [
      for (final c in list)
        if (c is Map<String, dynamic>) AccountCandidate.fromJson(c),
    ];
  }

  /// `POST /accounts/confirm {candidateId, code}`
  @override
  Future<AccountCandidate> confirm({required String candidateId, required String code}) async {
    final json = await _client.postJson('/accounts/confirm', body: {
      'candidateId': candidateId,
      'code': code,
    });
    return AccountCandidate.fromJson(json);
  }

  /// `POST /accounts/connect {candidateId, objectId}` + заголовок
  /// `Idempotency-Key: <key>`.
  ///
  /// Ответ: `{account: {...}, bill: {...}|null, pending: bool}`. `pending`
  /// значит, что поставщик подтвердит подключение позже.
  @override
  Future<ConnectResult> connect({
    required String candidateId,
    required String objectId,
    required IdempotencyKey key,
  }) async {
    final json = await _client.postJson('/accounts/connect', body: {
      'candidateId': candidateId,
      'objectId': objectId,
      // До появления своих заголовков в ApiClient ключ идёт телом.
      'idempotencyKey': key.value,
    });
    final bill = json['bill'];
    return ConnectResult(
      account: ConnectedAccount.fromJson((json['account'] as Map).cast<String, dynamic>()),
      bill: bill is Map ? Bill.fromJson(bill.cast<String, dynamic>()) : null,
      pending: json['pending'] as bool? ?? false,
    );
  }

  /// `DELETE /accounts/{id}` + заголовок `Idempotency-Key: <key>`.
  @override
  Future<void> disconnect(String accountId, {required IdempotencyKey key}) async {
    // У DELETE тела нет, а своих заголовков ApiClient пока не умеет: ключ
    // не доезжает. Пишем его в лог, чтобы потеря была видна при разборе,
    // а не превратилась в «иногда счёт отключается дважды».
    Log.w('api', 'DELETE /accounts/$accountId без Idempotency-Key ${key.value}');
    await _client.deleteJson('/accounts/$accountId');
  }

  /// `PATCH /accounts/{id} {objectId}`. Пока ApiClient не умеет PATCH,
  /// отправляется `POST /accounts/{id}/move {objectId}`.
  @override
  Future<ConnectedAccount> move({
    required String accountId,
    required String objectId,
  }) async {
    final json = await _client.postJson('/accounts/$accountId/move', body: {
      'objectId': objectId,
    });
    return ConnectedAccount.fromJson(json);
  }

  /// `POST /accounts/sync {accountIds}` — пустой список означает «все счета».
  ///
  /// Ответ: `{bills: [...], accounts: [...], syncedAt: iso,
  /// failed: {accountId: code}}`. `failed` — частичный отказ: у одного
  /// поставщика не получилось, остальные счета обновились.
  @override
  Future<SyncResult> syncCharges({List<String> accountIds = const []}) async {
    final json = await _client.postJson('/accounts/sync', body: {
      'accountIds': accountIds,
    });
    return SyncResult(
      bills: [
        for (final b in (json['bills'] as List? ?? const []))
          if (b is Map<String, dynamic>) Bill.fromJson(b),
      ],
      accounts: [
        for (final a in (json['accounts'] as List? ?? const []))
          if (a is Map<String, dynamic>) ConnectedAccount.fromJson(a),
      ],
      syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? '') ?? DateTime(2026),
      failed: {
        for (final e in ((json['failed'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{})
            .entries)
          e.key: '${e.value}',
      },
    );
  }

  /// `GET /catalog?locale=` — категории, поставщики (с маской лицевого
  /// счёта), значки услуг, способы оплаты, реквизиты банка одним ответом.
  @override
  Future<Catalog> catalog({required String locale}) async {
    final json = await _client.getJson('/catalog', query: {'locale': locale});
    return Catalog.fromJson(json);
  }

  /// `GET /payments?from=&to=&cursor=`
  @override
  Future<List<Payment>> history({DateTime? from, DateTime? to, String? cursor}) async {
    final list = await _client.getList('/payments', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'cursor': ?cursor,
    });
    return [
      for (final p in list)
        if (p is Map<String, dynamic>) Payment.fromJson(p),
    ];
  }
}
