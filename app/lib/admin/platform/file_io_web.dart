import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_io.dart';

Future<PickedFile> _read(web.File f) {
  final done = Completer<PickedFile>();
  final reader = web.FileReader();
  reader.onload = ((web.Event _) {
    final buf = (reader.result! as JSArrayBuffer).toDart;
    done.complete(PickedFile(f.name, buf.asUint8List()));
  }).toJS;
  reader.onerror = ((web.Event _) => done.completeError(StateError('файл не прочитался'))).toJS;
  reader.readAsArrayBuffer(f);
  return done.future;
}

Future<PickedFile?> pickFile({String accept = ''}) {
  final done = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  web.document.body!.append(input);
  void finish(PickedFile? f) {
    if (!done.isCompleted) done.complete(f);
    input.remove();
  }

  input.onchange = ((web.Event _) {
    final f = input.files?.item(0);
    if (f == null) return finish(null);
    _read(f).then(finish, onError: (Object _) => finish(null));
  }).toJS;
  // Пользователь закрыл окно выбора — не ждём вечно.
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}

void downloadBytes(String name, List<int> bytes, String mime) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob([data.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}

void Function() listenFileDrops(void Function(PickedFile file) onFile, {void Function(bool over)? onOver}) {
  final over = ((web.Event e) {
    e.preventDefault();
    onOver?.call(true);
  }).toJS;
  final leave = ((web.Event e) => onOver?.call(false)).toJS;
  final drop = ((web.Event e) {
    e.preventDefault();
    onOver?.call(false);
    final f = (e as web.DragEvent).dataTransfer?.files.item(0);
    if (f != null) _read(f).then(onFile);
  }).toJS;
  web.window.addEventListener('dragover', over);
  web.window.addEventListener('dragleave', leave);
  web.window.addEventListener('drop', drop);
  return () {
    web.window.removeEventListener('dragover', over);
    web.window.removeEventListener('dragleave', leave);
    web.window.removeEventListener('drop', drop);
  };
}
