import 'dart:async';

import '../failure.dart';
import 's.dart';

/// Единственное место, где [FailureKind] превращается в текст интерфейса.
///
/// До этого файла единственным показом ошибки был `Text('$e')` в home_page —
/// пользователь читал «AppFailure(network): нет связи». Экраны больше не
/// разбирают ошибку сами: берут отсюда заголовок, подпись и решение про
/// кнопку «Повторить».

/// Заголовок ошибки для пользователя.
String failureTitle(S s, AppFailure f) => switch (f.kind) {
      FailureKind.network => s.errorNetwork,
      FailureKind.server => s.errorServer,
      FailureKind.notFound => s.errorNotFound,
      FailureKind.validation => s.errorValidation,
      FailureKind.auth => s.errorAuth,
      FailureKind.cancelled => s.errorUnknown,
      FailureKind.unknown => s.errorUnknown,
    };

/// Подсказка под заголовком. Для network — что данные ниже сохранённые.
/// null — когда заголовок уже всё сказал (ошибка валидации садится в поле).
String? failureLead(S s, AppFailure f) => switch (f.kind) {
      FailureKind.network => s.errorNetworkLead,
      FailureKind.validation => null,
      _ => s.errorTitle,
    };

/// Текст под конкретным полем формы, если сервер назвал поле в
/// [AppFailure.field]. Чужое поле и не-валидация дают null, поэтому
/// форма может спрашивать про каждое своё поле без проверок.
///
/// Образец формата (маску лицевого счёта) передают в [AppFailure.code]:
/// `AppFailure(FailureKind.validation, field: 'accountNo', code: '31-01187')`.
String? failureFieldText(S s, AppFailure f, String field) {
  if (f.kind != FailureKind.validation || f.field != field) return null;
  final hint = f.code;
  return switch (field) {
        'accountNo' =>
          hint != null && hint.isNotEmpty ? s.accountNoFormat(hint) : s.accountNoInvalid,
        'code' => s.otpWrong,
        _ => s.errorValidation,
      };
}

/// Рисовать ли кнопку «Повторить». Повтор помогает только там, где виновата
/// связь или сервер: неверный номер счёта от повтора верным не станет.
bool showRetry(AppFailure f) => f.isRetryable;

/// Любая ошибка AsyncValue приводится к [AppFailure]: экран не разбирает
/// сырые исключения и не печатает '$e'.
///
/// Слой данных обязан отдавать [AppFailure] сам — эта функция страхует
/// случаи, когда исключение пролетело мимо guard (например, из `unwrap()`
/// внутри AsyncNotifier.build).
AppFailure failureOf(Object? error) {
  if (error is AppFailure) return error;
  if (error == null) {
    return const AppFailure(FailureKind.unknown, message: 'ошибка без описания');
  }
  if (error is TimeoutException) {
    return AppFailure(FailureKind.network, message: 'таймаут', cause: error);
  }
  // Сетевые исключения приходят разными классами (SocketException в io,
  // ClientException в http, TypeError в браузере), а dart:io в веб-сборку
  // не входит — поэтому опознаём по тексту, а не по типу.
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection closed') ||
      text.contains('XMLHttpRequest')) {
    return AppFailure(FailureKind.network, message: text, cause: error);
  }
  return AppFailure(FailureKind.unknown, message: text, cause: error);
}
