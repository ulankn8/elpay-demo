/// Откуда приложение берёт данные и как себя ведёт в этой сборке.
///
/// Значения приходят из --dart-define, поэтому одна и та же сборка
/// превращается в демо или в боевую без правок кода:
/// `flutter build apk --dart-define=API_BASE_URL=https://api.elpay.kg`
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.useMockData,
    required this.paymentsEnabled,
    required this.realAuthEnabled,
    required this.requestTimeout,
    required this.verboseLogs,
  });

  final String apiBaseUrl;

  /// true — данные берутся из демо-реестра, сеть не нужна.
  final bool useMockData;

  /// Платёжный шлюз не подключён: false — оплата идёт заглушкой.
  final bool paymentsEnabled;

  /// Боевой вход по SMS и Telegram: false — код из демо (4815).
  final bool realAuthEnabled;

  final Duration requestTimeout;
  final bool verboseLogs;

  static const _url = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.elpay.kg/v1');

  /// Конфигурация текущей сборки. Без --dart-define это демо-режим:
  /// сеть не используется, данные берутся из демо-реестра.
  static const AppConfig current = AppConfig(
    apiBaseUrl: _url,
    useMockData: bool.fromEnvironment('USE_MOCK', defaultValue: true),
    paymentsEnabled: bool.fromEnvironment('PAYMENTS_ENABLED'),
    realAuthEnabled: bool.fromEnvironment('REAL_AUTH_ENABLED'),
    requestTimeout: Duration(seconds: int.fromEnvironment('TIMEOUT_S', defaultValue: 20)),
    verboseLogs: bool.fromEnvironment('VERBOSE_LOGS', defaultValue: true),
  );

  bool get isDemo => useMockData;
}
