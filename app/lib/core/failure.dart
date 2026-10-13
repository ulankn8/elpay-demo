/// Что именно пошло не так. По этому типу UI решает, что показать
/// пользователю: повтор, сообщение об адресе, повторный вход.
enum FailureKind {
  /// Нет сети или сервер недоступен.
  network,

  /// Сервер ответил ошибкой (5xx, неожиданный формат).
  server,

  /// Данные не прошли проверку (неверный счёт, пустое поле).
  validation,

  /// Запрошенного объекта нет.
  notFound,

  /// Нужно войти заново.
  auth,

  /// Операция отменена пользователем или таймаутом.
  cancelled,

  /// Всё остальное.
  unknown,
}

/// Ошибка уровня приложения. Исключения из сети и парсинга превращаются
/// в неё на границе слоя данных, выше по стеку их уже нет.
class AppFailure implements Exception {
  const AppFailure(
    this.kind, {
    this.message = '',
    this.code,
    this.cause,
    this.field,
  });

  final FailureKind kind;

  /// Техническое пояснение для логов. Пользователю показываем текст из S.
  final String message;

  /// Код ошибки сервера, если он был.
  final String? code;

  /// Исходное исключение — только для логов.
  final Object? cause;

  /// Поле формы, к которому относится ошибка валидации.
  final String? field;

  const AppFailure.network([String message = 'нет связи'])
      : this(FailureKind.network, message: message);

  const AppFailure.server([String message = 'сервер не ответил', String? code])
      : this(FailureKind.server, message: message, code: code);

  const AppFailure.validation(String message, {String? field})
      : this(FailureKind.validation, message: message, field: field);

  const AppFailure.notFound([String message = 'не найдено'])
      : this(FailureKind.notFound, message: message);

  const AppFailure.auth([String message = 'нужен вход'])
      : this(FailureKind.auth, message: message);

  bool get isNetwork => kind == FailureKind.network;
  bool get isRetryable => kind == FailureKind.network || kind == FailureKind.server;

  @override
  String toString() => 'AppFailure(${kind.name}${code == null ? '' : ' $code'}): $message';
}
