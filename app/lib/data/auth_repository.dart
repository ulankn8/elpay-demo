import 'dart:async';
import 'models.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Контракт авторизации. UI знает только его — подмена на реальный бэкенд
/// сводится к одной строке в провайдере.
abstract class AuthRepository {
  /// Запросить код: SMS, письмо или сообщение в Telegram.
  Future<void> requestCode({required AuthMethod method, required String destination});

  /// Проверить код и получить сессию.
  Future<Session> verifyCode({
    required AuthMethod method,
    required String destination,
    required String code,
  });

  /// Ссылка на бота для входа через Telegram.
  Uri telegramLoginUri(String requestId);

  /// Ждём, пока пользователь подтвердит вход в боте.
  Future<String> awaitTelegramApproval(String requestId);
}

/// Заглушка на время, пока нет бэкенда: код всегда 4815.
class MockAuthRepository implements AuthRepository {
  static const demoCode = '4815';

  @override
  Future<void> requestCode({required AuthMethod method, required String destination}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (destination.trim().isEmpty) {
      throw AuthException('Укажите, куда отправить код');
    }
  }

  @override
  Future<Session> verifyCode({
    required AuthMethod method,
    required String destination,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (code != demoCode) throw AuthException('Неверный код');
    return Session(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Токтогулова Айгерим',
      phone: method == AuthMethod.phone ? destination : null,
      email: method == AuthMethod.email ? destination : null,
      telegram: method == AuthMethod.telegram ? destination : null,
      method: method,
    );
  }

  @override
  Uri telegramLoginUri(String requestId) =>
      Uri.parse('https://t.me/elpay_bot?start=$requestId');

  @override
  Future<String> awaitTelegramApproval(String requestId) async {
    // Реальная реализация будет слушать вебхук бота.
    await Future<void>.delayed(const Duration(seconds: 3));
    return '@aigerim';
  }
}
