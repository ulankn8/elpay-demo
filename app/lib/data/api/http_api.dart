import '../models.dart';
import 'api_client.dart';
import 'elpay_api.dart';

/// Боевая реализация контракта: те же методы поверх HTTP.
///
/// Эндпоинты зафиксированы здесь — когда бэкенд будет готов, правок
/// ждёт только этот файл, экраны и репозитории остаются как есть.
/// Включается одной строкой в providers.dart:
/// `apiProvider → HttpElPayApi(ApiClient())`.
class HttpElPayApi implements ElPayApi {
  HttpElPayApi(this._client);

  final ApiClient _client;

  @override
  Future<List<PayObject>> objects() async {
    final list = await _client.getList('/objects');
    return [
      for (final o in list)
        if (o is Map<String, dynamic>) PayObject.fromJson(o),
    ];
  }

  @override
  Future<List<Bill>> bills() async {
    final list = await _client.getList('/bills');
    return [
      for (final b in list)
        if (b is Map<String, dynamic>) Bill.fromJson(b),
    ];
  }

  @override
  Future<List<ConnectedAccount>> accounts() async {
    final list = await _client.getList('/accounts');
    return [
      for (final a in list)
        if (a is Map<String, dynamic>) ConnectedAccount.fromJson(a),
    ];
  }

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

  @override
  Future<AccountCandidate> confirm({required String candidateId, required String code}) async {
    final json = await _client.postJson('/accounts/confirm', body: {
      'candidateId': candidateId,
      'code': code,
    });
    return AccountCandidate.fromJson(json);
  }

  @override
  Future<ConnectResult> connect({required String candidateId, required String objectId}) async {
    final json = await _client.postJson('/accounts/connect', body: {
      'candidateId': candidateId,
      'objectId': objectId,
    });
    final bill = json['bill'];
    return ConnectResult(
      account: ConnectedAccount.fromJson((json['account'] as Map).cast<String, dynamic>()),
      bill: bill is Map ? Bill.fromJson(bill.cast<String, dynamic>()) : null,
    );
  }

  @override
  Future<void> disconnect(String accountId) =>
      _client.deleteJson('/accounts/$accountId');

  @override
  Future<SyncResult> syncCharges() async {
    final json = await _client.postJson('/accounts/sync');
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
    );
  }

  @override
  Future<List<Payment>> history() async {
    final list = await _client.getList('/payments');
    return [
      for (final p in list)
        if (p is Map<String, dynamic>) Payment.fromJson(p),
    ];
  }
}
