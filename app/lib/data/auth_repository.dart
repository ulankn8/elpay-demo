import '../core/clock.dart';
import '../core/failure.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../core/result.dart';
import 'models.dart';

/// Ошибка входа.
///
/// Теперь это ПОДТИП [AppFailure] с `kind == FailureKind.auth`, а не отдельное
/// исключение: ошибка входа проходит по тем же путям, что остальные ошибки
/// приложения (`guard`, `Result`, `failureTitle`), и экрану не нужно знать
/// про особый тип. Старые `catch (AuthException)` в экранах входа при этом
/// продолжают работать.
class AuthException extends AppFailure {
  const AuthException([String message = 'ошибка входа'])
      : super(FailureKind.auth, message: message);

  @override
  String toString() => message;
}

/// Контракт авторизации. UI знает только его — подмена на реальный бэкенд
/// сводится к одной строке в провайдере.
///
/// ЗАГЛУШКА ОСОЗНАННО: [MockAuthRepository] проверяет демо-код 4815, SMS
/// никуда не уходят. Меняется только форма контракта — методы возвращают
/// [Result], чтобы экраны входа разбирали ошибку так же, как остальное
/// приложение, а не ловили исключение.
///
/// Токенов в [Session] нет и в этой задаче не появится: пока вход —
/// заглушка, это было бы пустое поле, а в день боевого входа токен нельзя
/// держать в SharedPreferences открытым текстом (нужен flutter_secure_storage).
/// Это записанный долг, а не забытая деталь.
abstract class AuthRepository {
  /// Запросить код: SMS, письмо или сообщение в Telegram.
  Future<Result<void>> sendCode({
    required AuthMethod method,
    required String destination,
  });

  /// Проверить код и получить сессию.
  Future<Result<Session>> verify({
    required AuthMethod method,
    required String destination,
    required String code,
  });

  /// Ссылка на бота для входа через Telegram.
  Uri telegramLoginUri(String requestId);

  /// Ждём, пока пользователь подтвердит вход в боте. Ответ — его ник.
  Future<Result<String>> telegramApproval(String requestId);

  // ─────────── переходные обёртки для features/auth ───────────
  // Экраны входа (login_page, otp_page) разбирают исключение, а не Result,
  // и в этом плане у них нет автора. Поэтому старые подписи остаются рядом
  // и бросают [AuthException] — подтип AppFailure. Когда экраны переедут
  // на Result, эти три метода удаляются вместе с ними.

  Future<void> requestCode({
    required AuthMethod method,
    required String destination,
  }) async {
    final failure =
        (await sendCode(method: method, destination: destination)).failureOrNull;
    if (failure != null) throw _asAuth(failure);
  }

  Future<Session> verifyCode({
    required AuthMethod method,
    required String destination,
    required String code,
  }) async =>
      _orThrow(await verify(method: method, destination: destination, code: code));

  Future<String> awaitTelegramApproval(String requestId) async =>
      _orThrow(await telegramApproval(requestId));

  static T _orThrow<T>(Result<T> result) => switch (result) {
        Ok<T>(:final value) => value,
        Fail<T>(:final failure) => throw _asAuth(failure),
      };

  static AuthException _asAuth(AppFailure failure) =>
      failure is AuthException ? failure : AuthException(failure.message);
}

/// Заглушка на время, пока нет бэкенда: код всегда 4815.
class MockAuthRepository extends AuthRepository {
  MockAuthRepository({
    Clock? clock,
    IdGen? ids,
    this.latency = const Duration(milliseconds: 700),
  })  : _clock = clock ?? systemClock,
        _ids = ids ?? DefaultIdGen();

  static const demoCode = '4815';

  /// Сколько «идёт» запрос. В тестах — `Duration.zero`.
  final Duration latency;

  final Clock _clock;
  final IdGen _ids;

  static const _tag = 'auth';

  @override
  Future<Result<void>> sendCode({
    required AuthMethod method,
    required String destination,
  }) async {
    await Future<void>.delayed(latency);
    if (destination.trim().isEmpty) {
      return const Fail<void>(AuthException('Укажите, куда отправить код'));
    }
    Log.i(_tag, 'демо-код $demoCode «отправлен» (${method.name}) в ${_clock()}');
    return const Ok<void>(null);
  }

  @override
  Future<Result<Session>> verify({
    required AuthMethod method,
    required String destination,
    required String code,
  }) async {
    await Future<void>.delayed(latency);
    if (code != demoCode) return const Fail(AuthException('Неверный код'));
    // id сессии берём у IdGen: в UI такие id делались как
    // 'u-${DateTime.now().millisecondsSinceEpoch}' и совпадали при двух
    // нажатиях в одну миллисекунду.
    return Ok(Session(
      id: _ids.local('user'),
      name: 'Токтогулова Айгерим',
      phone: method == AuthMethod.phone ? destination : null,
      email: method == AuthMethod.email ? destination : null,
      telegram: method == AuthMethod.telegram ? destination : null,
      method: method,
    ));
  }

  @override
  Uri telegramLoginUri(String requestId) =>
      Uri.parse('https://t.me/elpay_bot?start=$requestId');

  @override
  Future<Result<String>> telegramApproval(String requestId) async {
    // Реальная реализация будет слушать вебхук бота; здесь — пауза и ник.
    await Future<void>.delayed(const Duration(seconds: 3));
    return const Ok('@aigerim');
  }
}
