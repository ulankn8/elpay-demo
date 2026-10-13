import 'dart:async';

import '../logger.dart';

/// Знает, есть ли сеть. Отдельный контракт, чтобы приложение можно было
/// перевести в офлайн в демо и в тестах, не трогая экраны.
///
/// В боевой сборке сюда подставится реализация поверх connectivity_plus
/// плюс проверка доступности API.
abstract class ConnectivityService {
  bool get isOnline;
  Stream<bool> get changes;
  Future<bool> refresh();
  void dispose();
}

/// Сеть всегда есть — режим по умолчанию для демо и тестов.
class AlwaysOnline implements ConnectivityService {
  const AlwaysOnline();

  @override
  bool get isOnline => true;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> refresh() async => true;

  @override
  void dispose() {}
}

/// Состояние сети переключается вручную — так показывают офлайн-сценарий
/// на демонстрации и так его проверяют тесты.
class ManualConnectivity implements ConnectivityService {
  ManualConnectivity({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> refresh() async => online;

  /// Включить или выключить сеть вручную.
  void setOnline(bool value) {
    if (online == value) return;
    online = value;
    Log.i('net', value ? 'сеть появилась' : 'сеть пропала');
    _controller.add(value);
  }

  void toggle() => setOnline(!online);

  @override
  void dispose() => _controller.close();
}
