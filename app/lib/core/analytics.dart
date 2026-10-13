import 'logger.dart';

/// События продукта. Названия — то, что потом увидит аналитик,
/// поэтому они фиксированы здесь, а не собираются строками по коду.
class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.params = const {}]);
  final String name;
  final Map<String, Object?> params;

  static AnalyticsEvent screen(String name) => AnalyticsEvent('screen_view', {'screen': name});

  static AnalyticsEvent connectStarted(String source) =>
      AnalyticsEvent('connect_account_started', {'source': source});
  static AnalyticsEvent connectFound(int count, String method) =>
      AnalyticsEvent('connect_account_found', {'count': count, 'method': method});
  static AnalyticsEvent connectDone(int count) =>
      AnalyticsEvent('connect_account_done', {'count': count});
  static AnalyticsEvent connectFailed(String reason) =>
      AnalyticsEvent('connect_account_failed', {'reason': reason});
  static AnalyticsEvent accountDisconnected(String providerId) =>
      AnalyticsEvent('account_disconnected', {'provider': providerId});

  static AnalyticsEvent payStarted(double amount, int bills) =>
      AnalyticsEvent('payment_started', {'amount': amount, 'bills': bills});
  static AnalyticsEvent payDone(double amount, String method) =>
      AnalyticsEvent('payment_done', {'amount': amount, 'method': method});

  static AnalyticsEvent syncFailed(String reason) =>
      AnalyticsEvent('sync_failed', {'reason': reason});
}

/// Куда уходят события. В бою подставляется реализация поверх Firebase или
/// Amplitude — экраны и репозитории об этом не знают.
abstract class Analytics {
  void track(AnalyticsEvent event);
}

/// Пишет события в лог: видно при отладке, ничего никуда не отправляет.
class DebugAnalytics implements Analytics {
  const DebugAnalytics();

  @override
  void track(AnalyticsEvent event) {
    final params = event.params.isEmpty
        ? ''
        : ' ${event.params.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    Log.i('analytics', '${event.name}$params');
  }
}

/// Ничего не делает — для тестов и для сборок без аналитики.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void track(AnalyticsEvent event) {}
}
