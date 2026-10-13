import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import '../../core/failure.dart';
import '../../core/logger.dart';

/// Тонкий HTTP-клиент: таймауты, заголовки, повтор на сетевых сбоях и
/// превращение любого сбоя в [AppFailure].
///
/// Повтор делается только там, где он безопасен: GET повторяется всегда,
/// POST и DELETE — лишь когда у запроса есть заголовок
/// [idempotencyHeader], по которому шлюз узнает повтор. Иначе один
/// потерянный ответ превратился бы в две выполненные операции.
///
/// Выше по стеку про http уже никто не знает — только про Result и AppFailure.
class ApiClient {
  ApiClient({
    http.Client? client,
    AppConfig? config,
    this.tokenProvider,
  })  : _client = client ?? http.Client(),
        _config = config ?? AppConfig.current;

  final http.Client _client;
  final AppConfig _config;

  /// Откуда брать токен доступа. Пока вход — заглушка, возвращает null.
  final Future<String?> Function()? tokenProvider;

  static const _retries = 2;
  static const _retryDelay = Duration(milliseconds: 600);

  /// Заголовок ключа идемпотентности. По нему шлюз отличает повтор той же
  /// операции от второй такой же — и он же РАЗРЕШАЕТ клиенту повтор:
  /// без ключа потерянный ответ на POST превратился бы в два подключённых
  /// счёта, а не в одно подключение.
  static const idempotencyHeader = 'Idempotency-Key';

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) async =>
      _asMap(await _send('GET', path, query: query));

  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) async =>
      _asList(await _send('GET', path, query: query));

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async =>
      _asMap(await _send('POST', path, body: body, extra: headers));

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String>? headers,
  }) async =>
      _asMap(await _send('DELETE', path, extra: headers));

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? extra,
  }) async {
    final uri = Uri.parse('${_config.apiBaseUrl}$path').replace(queryParameters: query);
    final token = await tokenProvider?.call();
    final headers = <String, String>{
      'accept': 'application/json',
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...?extra,
    };

    // Повторять вслепую можно только чтение. Неидемпотентный метод
    // повторяется ТОЛЬКО с ключом идемпотентности: с ним шлюз отдаст
    // прежний результат, а без него второй POST — это второе подключение.
    final retries = method == 'GET' || _hasIdempotencyKey(extra) ? _retries : 0;

    AppFailure? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);

        // Дедлайн накрывает ВЕСЬ обмен, а не только send(): тот
        // завершается по приходу заголовков, и сбор тела оставался без
        // таймаута вообще. Сервер или прокси оператора, отдавший «200» и
        // замолчавший на теле, подвешивал запрос навсегда — ни ошибки,
        // ни повтора, ни отката на кэш, экран вечно в загрузке.
        final response = await _client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(_config.requestTimeout);
        Log.d('api', '$method $uri → ${response.statusCode}');
        return _decode(response);
      } on AppFailure catch (e) {
        // Ошибки сервера и валидации повторять бессмысленно.
        if (!e.isRetryable) rethrow;
        last = e;
      } on TimeoutException {
        last = const AppFailure.network('таймаут');
      } catch (e) {
        last = AppFailure(FailureKind.network, message: '$e', cause: e);
      }
      if (attempt < retries) await Future<void>.delayed(_retryDelay * (attempt + 1));
    }
    Log.w('api', '$method $uri не удалось: ${last?.message}');
    throw last ?? const AppFailure.network();
  }

  dynamic _decode(http.Response response) {
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw const AppFailure.auth();
    }
    if (code == 404) {
      throw const AppFailure.notFound();
    }
    if (code >= 500) {
      throw AppFailure.server('сервер вернул $code', '$code');
    }
    final text = response.body.isEmpty ? '{}' : utf8.decode(response.bodyBytes);
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (e) {
      throw AppFailure(FailureKind.server, message: 'ответ не JSON', cause: e);
    }
    if (code >= 400) {
      final message = decoded is Map ? '${decoded['message'] ?? 'ошибка запроса'}' : 'ошибка запроса';
      throw AppFailure(FailureKind.validation, message: message, code: '$code');
    }
    return decoded;
  }

  /// У запроса задан ключ идемпотентности. Имя заголовка сравнивается без
  /// учёта регистра: в HTTP он регистронезависим, и вызывающий вправе
  /// написать его как угодно.
  static bool _hasIdempotencyKey(Map<String, String>? headers) =>
      headers?.keys.any((k) => k.toLowerCase() == 'idempotency-key') ?? false;

  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    throw const AppFailure(FailureKind.server, message: 'ожидали объект');
  }

  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      return decoded['items'] as List;
    }
    throw const AppFailure(FailureKind.server, message: 'ожидали список');
  }

  void close() => _client.close();
}
