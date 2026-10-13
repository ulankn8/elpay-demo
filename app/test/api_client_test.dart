import 'dart:convert';

import 'package:elpay/core/app_config.dart';
import 'package:elpay/core/failure.dart';
import 'package:elpay/core/ids.dart';
import 'package:elpay/core/logger.dart';
import 'package:elpay/data/api/api_client.dart';
import 'package:elpay/data/api/http_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Боевой HTTP-клиент: превращение любого сбоя в [AppFailure] и повторы.
///
/// MockClient из package:http/testing — новый пакет не нужен, http уже
/// в pubspec. Проверяется ровно то, что увидит пользователь: 401 это
/// «нужен вход», а не «что-то пошло не так», и валидацию никто не
/// повторяет три раза.
void main() {
  Log.enabled = false;

  /// Заголовок с кодировкой обязателен: без него package:http кодирует
  /// тело в latin1, и русский текст ошибки в нём не живёт.
  const jsonUtf8 = {'content-type': 'application/json; charset=utf-8'};

  AppConfig config({Duration timeout = const Duration(milliseconds: 80)}) => AppConfig(
        apiBaseUrl: 'https://test.elpay.local/v1',
        useMockData: false,
        paymentsEnabled: false,
        realAuthEnabled: false,
        requestTimeout: timeout,
        verboseLogs: false,
      );

  Matcher failsWith(FailureKind kind) =>
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', kind));

  test('401 превращается в auth', () async {
    var calls = 0;
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 401, headers: jsonUtf8);
      }),
    );

    await expectLater(client.getJson('/accounts'), failsWith(FailureKind.auth));
    // Повторять нечего: токен не станет годным от второй попытки.
    expect(calls, 1);
  });

  test('403 тоже превращается в auth', () async {
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async => http.Response('{}', 403, headers: jsonUtf8)),
    );

    await expectLater(client.getJson('/accounts'), failsWith(FailureKind.auth));
  });

  test('404 — в notFound', () async {
    var calls = 0;
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 404, headers: jsonUtf8);
      }),
    );

    await expectLater(client.getJson('/accounts/missing'), failsWith(FailureKind.notFound));
    expect(calls, 1);
  });

  test('500 — в server и делает два повтора', () async {
    var calls = 0;
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500, headers: jsonUtf8);
      }),
    );

    await expectLater(
      client.getJson('/accounts'),
      throwsA(isA<AppFailure>()
          .having((f) => f.kind, 'kind', FailureKind.server)
          .having((f) => f.code, 'code', '500')),
    );
    // Первая попытка плюс два повтора: сервер мог просто перезагружаться.
    expect(calls, 3);
  });

  test('Таймаут — в network', () async {
    var calls = 0;
    final client = ApiClient(
      config: config(timeout: const Duration(milliseconds: 40)),
      client: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200, headers: jsonUtf8);
      }),
    );

    await expectLater(client.getJson('/accounts'), failsWith(FailureKind.network));
    expect(calls, 3, reason: 'сеть могла мигнуть — повторяем');
  });

  test('Повторы не делаются для ошибок валидации', () async {
    var calls = 0;
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({'message': 'номер счёта не найден в реестре'}),
          422,
          headers: jsonUtf8,
        );
      }),
    );

    await expectLater(
      client.postJson('/accounts/connect', body: const {'candidateId': 'нет'}),
      throwsA(isA<AppFailure>()
          .having((f) => f.kind, 'kind', FailureKind.validation)
          // Текст сервера доезжает до пользователя и не ломается в utf-8.
          .having((f) => f.message, 'message', 'номер счёта не найден в реестре')
          .having((f) => f.code, 'code', '422')),
    );
    expect(calls, 1, reason: 'повторять валидацию бессмысленно');
  });

  test('Ответ не JSON — это ошибка сервера, а не падение разбора', () async {
    final client = ApiClient(
      config: config(),
      client: MockClient((_) async => http.Response('<html>502</html>', 200)),
    );

    await expectLater(client.getJson('/accounts'), failsWith(FailureKind.server));
  });

  test('Ключ идемпотентности уходит на сервер в POST подключения', () async {
    Map<String, dynamic>? sentBody;
    Map<String, String>? sentHeaders;
    const key = IdempotencyKey.raw('accounts.connect-1');

    final api = HttpElPayApi(ApiClient(
      config: config(),
      client: MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        sentHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'account': {
              'id': 'acc-1',
              'providerId': 'p-gas',
              'title': 'Газпром Кыргызстан',
              'accountNo': '55-20841',
              'objectId': 'o1',
              'connectedAt': '2026-03-10T09:30:00.000',
            },
            'bill': null,
            'pending': false,
          }),
          200,
          headers: jsonUtf8,
        );
      }),
    ));

    final result = await api.connect(
      candidateId: 'reg-gas-1',
      objectId: 'o1',
      key: key,
    );

    expect(result.account.id, 'acc-1');
    expect(result.bill, isNull, reason: 'начисления нет — Bill на 0 сом не выдумываем');
    expect(sentBody!['candidateId'], 'reg-gas-1');
    expect(sentBody!['objectId'], 'o1');

    // РАСХОЖДЕНИЕ С ПЛАНОМ, зафиксированное честно: ApiClient пока не умеет
    // своих заголовков, поэтому ключ уходит ПОЛЕМ ТЕЛА `idempotencyKey`,
    // а не заголовком `Idempotency-Key` (см. комментарий в http_api.dart).
    // Проверяем, что ключ доезжает хоть одним из путей, — тогда правка
    // ApiClient (добавление headers) этот тест не ломает.
    final viaHeader = sentHeaders!['idempotency-key'] ?? sentHeaders!['Idempotency-Key'];
    expect(viaHeader ?? sentBody!['idempotencyKey'], key.value);
  });
}
