import 'package:flutter/foundation.dart';

/// Аргументы единственного входа в мастер подключения.
///
/// Отдельный файл, а не поля конструктора экрана: его импортируют и
/// `app.dart` (строит аргументы из ссылки), и экраны-источники перехода
/// (строят ссылку), и при этом никто не тянет за собой весь
/// `connect_page.dart`.
///
/// Раньше в мастер вели три расходящиеся ветки — значок услуги уводил на
/// `/new-payment` с флагом `connect: true`, кнопка на экране счетов
/// открывала свою шторку, а сторис вёл в список счетов. Теперь путь один:
/// маршрут `/connect` с этими аргументами в строке запроса.
@immutable
class ConnectArgs {
  const ConnectArgs({this.providerId, this.objectId, this.source = sourceManual});

  /// Маршрут мастера — один на всё приложение.
  static const path = '/connect';

  /// Источники перехода. Значения уходят в аналитику
  /// (`AnalyticsEvent.connectStarted`), поэтому они перечислены здесь,
  /// а не собираются строками по экранам.
  static const sourceManual = 'manual';
  static const sourceHome = 'home';
  static const sourceAccounts = 'accounts';
  static const sourceStory = 'story';
  static const sourceService = 'service';
  static const sourceObject = 'object';

  /// Пришли со значка услуги — ищем только этого поставщика.
  final String? providerId;

  /// Пришли с карточки объекта — он подставлен по умолчанию.
  final String? objectId;

  /// Откуда пришли. Нужен аналитике, а не логике: мастер работает
  /// одинаково для всех источников.
  final String source;

  /// Параметры ссылки: `/connect?provider=p-water&object=o-1&source=story`.
  /// Пустые значения не пишутся — ссылка остаётся читаемой.
  Map<String, String> toQuery() => {
        if (providerId != null && providerId!.isNotEmpty) 'provider': providerId!,
        if (objectId != null && objectId!.isNotEmpty) 'object': objectId!,
        if (source.isNotEmpty && source != sourceManual) 'source': source,
      };

  /// Готовая ссылка для `context.push(...)` — чтобы экраны-источники не
  /// склеивали строку запроса руками и не расходились в названиях ключей.
  String get location {
    final query = toQuery();
    if (query.isEmpty) return path;
    return Uri(path: path, queryParameters: query).toString();
  }

  /// Разбор ссылки. Чужие и пустые параметры игнорируются: прямой вход
  /// по `/connect` обязан открывать форму, а не падать.
  static ConnectArgs fromQuery(Map<String, String> q) {
    String? value(String key) {
      final raw = q[key]?.trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    return ConnectArgs(
      providerId: value('provider'),
      objectId: value('object'),
      source: value('source') ?? sourceManual,
    );
  }

  @override
  String toString() => 'ConnectArgs($source, provider: $providerId, object: $objectId)';
}
