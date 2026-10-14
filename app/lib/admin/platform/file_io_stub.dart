import 'file_io.dart';

/// Заглушка для тестов и не-веба: файлы подсовывает тест через провайдер.
Future<PickedFile?> pickFile({String accept = ''}) async => null;

void downloadBytes(String name, List<int> bytes, String mime) {}

/// Подписка на перетаскивание файлов на страницу. Возвращает отписку.
void Function() listenFileDrops(void Function(PickedFile file) onFile, {void Function(bool over)? onOver}) => () {};
