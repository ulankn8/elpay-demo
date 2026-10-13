import 'dart:developer' as dev;

import 'app_config.dart';

/// Уровень записи. Ошибки видны всегда, остальное — только в отладочных сборках.
enum LogLevel { debug, info, warn, error }

/// Простое логирование без внешних пакетов. Все сообщения идут через него,
/// чтобы в боевой сборке их можно было отключить или отправить в Sentry —
/// поменяв одну реализацию.
class Log {
  const Log._();

  static bool enabled = AppConfig.current.verboseLogs;

  static void d(String tag, String message) => _write(LogLevel.debug, tag, message);
  static void i(String tag, String message) => _write(LogLevel.info, tag, message);
  static void w(String tag, String message) => _write(LogLevel.warn, tag, message);

  static void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      _write(LogLevel.error, tag, message, error, stack);

  static void _write(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!enabled && level != LogLevel.error) return;
    dev.log(
      message,
      name: 'ЭлPay/$tag',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stack,
    );
  }
}
