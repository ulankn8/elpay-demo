import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import 'providers.dart';

const _tag = 'sync';

/// ОДНА точка офлайна: единственное место в приложении, которое реагирует
/// на возвращение сети.
///
/// Без него очередь отложенных операций заполняется и никогда не
/// разгружается: `flushOutbox()` до этого не вызывал никто, то есть
/// подключение, сделанное без сети, пропадало навсегда.
///
/// Включается один раз: `ref.watch(syncWatcherProvider)` в ElPayApp.build.
/// Повтор из очереди идёт с ТЕМ ЖЕ ключом идемпотентности, который лежит
/// в payload элемента, поэтому двойного подключения не будет.
final syncWatcherProvider = Provider<void>((ref) {
  var disposed = false;
  var busy = false;
  ref.onDispose(() => disposed = true);

  Future<void> flush(String reason) async {
    // Две отправки сразу дали бы по две попытки на каждую операцию.
    if (busy || disposed) return;
    busy = true;
    try {
      final sent = await ref.read(accountsRepoProvider).flushOutbox();
      if (disposed || sent == 0) return;
      Log.i(_tag, '$reason: отправлено отложенных операций — $sent');
      // Счета и начисления изменились на той стороне — перечитываем.
      ref.invalidate(accountsProvider);
      ref.invalidate(billsProvider);
    } finally {
      busy = false;
    }
  }

  ref.listen(isOnlineProvider, (previous, next) {
    if (next.value != true) return;
    // Сеть и так была — это не возвращение, разгружать нечего.
    if (previous?.value == true) return;
    flush('сеть вернулась');
  });

  // Прошлый запуск мог закончиться с непустой очередью.
  if (ref.read(connectivityProvider).isOnline) flush('старт приложения');
});

/// Есть ли сеть прямо сейчас — для плашки офлайна без await.
///
/// Поток состояния сети отдаёт только ИЗМЕНЕНИЯ, поэтому до первого
/// переключения берём текущее значение у самой службы.
final onlineNowProvider = Provider<bool>((ref) {
  final changes = ref.watch(isOnlineProvider);
  return changes.value ?? ref.watch(connectivityProvider).isOnline;
});

/// Сколько операций ждёт отправки — для подписи s.offlineQueued.
///
/// Очередь лежит в хранилище и сама об изменениях не сообщает, поэтому
/// значение пересчитывается по двум событиям, которые её и меняют:
/// смена сети и обновление списка счетов.
final pendingOpsProvider = Provider<int>((ref) {
  ref.watch(onlineNowProvider);
  ref.watch(accountsProvider);
  return ref.watch(outboxProvider).length;
});
