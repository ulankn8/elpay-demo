/// Файлы в браузере: выбрать, перетащить на страницу, скачать.
/// На вебе — настоящий браузерный API, в тестах — заглушка.
library;

export 'file_io_stub.dart' if (dart.library.js_interop) 'file_io_web.dart';

/// Выбранный или перетащенный файл.
class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}
