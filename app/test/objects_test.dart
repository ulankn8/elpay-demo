import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/env.dart';

/// Объекты («Дом», «Родители») создаёт и удаляет пользователь, поэтому они
/// часть состояния источника, а не статический демо-набор. Пока запись шла
/// только в кэш, первое же обновление списка возвращало удалённый объект
/// и теряло созданный.
void main() {
  PayObject objectNamed(String id, String name) =>
      PayObject(id: id, name: name, icon: 'house', cat: 'city', address: 'ул. Проверочная, 1');

  test('созданный объект переживает обновление списка', () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    await env.bills.load();
    final created = await env.bills.saveObject(objectNamed('o-new', 'Дача'));
    expect(created.isOk, isTrue, reason: 'объект должен сохраниться');

    final after = await env.bills.load(refresh: true);
    final objects = after.valueOrNull!.objects;
    expect(objects.where((o) => o.id == 'o-new'), hasLength(1),
        reason: 'обновление списка не должно терять созданный объект');
  });

  test('удалённый объект не возвращается после обновления списка', () async {
    final env = makeEnv();
    addTearDown(env.dispose);

    await env.bills.load();
    final gone = await env.bills.removeObject('o1', detachAccounts: true);
    expect(gone.isOk, isTrue);

    final after = await env.bills.load(refresh: true);
    expect(after.valueOrNull!.objects.any((o) => o.id == 'o1'), isFalse,
        reason: 'источник тоже должен знать об удалении');
  });

  test('правка объекта переживает перезапуск приложения', () async {
    final memory = MemoryLocalStore();
    final first = makeEnv(store: memory);
    await first.bills.load();
    await first.bills.saveObject(objectNamed('o-new', 'Дача'));
    first.dispose();

    // Второй экземпляр поверх того же хранилища — это и есть перезапуск.
    final second = makeEnv(store: memory);
    addTearDown(second.dispose);
    final after = await second.bills.load(refresh: true);
    final names = {for (final o in after.valueOrNull!.objects) o.id: o.name};
    expect(names['o-new'], 'Дача');
  });
}
