/// Состояние кабинета: хранилище, счётчик правок и действия.
///
/// Экраны читают сводки из [AdminStore] через `ref.admin` и подписаны
/// на [revisionProvider]: любое действие через [AdminActions] увеличивает
/// ревизию, и всё, что от неё зависит, перерисовывается.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_store.dart';
import '../data/models.dart';
import '../platform/file_io.dart' as io;

/// Подменяется в main и в тестах.
final adminStoreProvider = Provider<AdminStore>((ref) => throw UnimplementedError('adminStoreProvider не задан'));

class RevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final revisionProvider = NotifierProvider<RevisionNotifier, int>(RevisionNotifier.new);

/// Хранилище «на чтение» с подпиской на правки.
///
/// Провайдер, который возвращает само хранилище, тут не годится: Riverpod 3
/// оповещает подписчиков, только если значение изменилось, а хранилище —
/// всегда тот же объект. Экран подписывается на ревизию и читает хранилище.
extension AdminWatch on WidgetRef {
  AdminStore get admin {
    watch(revisionProvider);
    return read(adminStoreProvider);
  }
}

/// Кто вошёл. Новая сессия — новый объект, поэтому роутер её замечает.
final sessionProvider = Provider<Staff?>((ref) {
  ref.watch(revisionProvider);
  return ref.read(adminStoreProvider).session;
});

/// Выполнить действие над хранилищем и обновить экраны.
class AdminActions {
  AdminActions(this.ref);
  final Ref ref;

  AdminStore get store => ref.read(adminStoreProvider);

  Future<T> run<T>(Future<T> Function(AdminStore s) action) async {
    final r = await action(store);
    ref.read(revisionProvider.notifier).bump();
    return r;
  }
}

final actionsProvider = Provider<AdminActions>(AdminActions.new);

/// Работа с файлами — подменяется в виджет-тестах.
class FileGateway {
  const FileGateway();
  Future<io.PickedFile?> pick({String accept = ''}) => io.pickFile(accept: accept);
  void download(String name, List<int> bytes, String mime) => io.downloadBytes(name, bytes, mime);
  void Function() listenDrops(void Function(io.PickedFile) onFile, {void Function(bool)? onOver}) =>
      io.listenFileDrops(onFile, onOver: onOver);
}

final fileGatewayProvider = Provider<FileGateway>((ref) => const FileGateway());
