import 'package:elpay/admin/data/admin_store.dart';
import 'package:elpay/admin/data/models.dart';
import 'package:elpay/admin/data/samples.dart';
import 'package:elpay/admin/data/seed.dart';
import 'package:elpay/admin/platform/file_io.dart';
import 'package:elpay/admin/state/admin_state.dart';
import 'package:elpay/admin/state/import_wizard.dart';
import 'package:elpay/admin/ui/admin_app.dart';
import 'package:elpay/core/cache/local_store.dart';
import 'package:elpay/core/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final seed = generateSeed();

/// Файлы без браузера: «выбранный» файл и перехваченные скачивания.
class FakeFiles extends FileGateway {
  FakeFiles();
  PickedFile? next;
  final downloads = <String>[];
  @override
  Future<PickedFile?> pick({String accept = ''}) async => next;
  @override
  void download(String name, List<int> bytes, String mime) => downloads.add(name);
  @override
  void Function() listenDrops(void Function(PickedFile) onFile, {void Function(bool)? onOver}) => () {};
}

void main() {
  late AdminStore store;
  late FakeFiles files;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store = AdminStore(store: MemoryLocalStore(), clock: MovableClock(DateTime(2026, 11, 1)).clock, seed: seed);
    files = FakeFiles();
    await tester.pumpWidget(ProviderScope(
      overrides: [adminStoreProvider.overrideWithValue(store), fileGatewayProvider.overrideWithValue(files)],
      child: const AdminApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextField).first, email);
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '4815');
    await tester.pumpAndSettle();
  }

  testWidgets('вход через интерфейс ведёт на обзор, а не остаётся на экране входа', (tester) async {
    // Регрессия: хранилище — один и тот же объект, и Riverpod 3 не оповещал
    // подписчиков; после верного кода роутер не видел сессию.
    await pumpApp(tester);
    expect(find.text('Вход в кабинет службы'), findsOneWidget);
    await signIn(tester, 'jypar@oshvodokanal.kg');
    expect(find.text('Вход в кабинет службы'), findsNothing);
    expect(find.text('Начислено за сентябрь'), findsOneWidget);
    expect(find.text('Требует внимания'), findsOneWidget);
  });

  testWidgets('чужая почта — понятный отказ, админ попадает в свой раздел', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'ivan@gmail.com');
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Доступ выдаёт менеджер ЭлPay'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'a.kadyrov@elpay.kg');
    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '4815');
    await tester.pumpAndSettle();
    expect(find.text('Службы пилота'), findsOneWidget);
  });

  testWidgets('правка в кабинете сразу видна на экране: новый абонент в счётчике', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'jypar@oshvodokanal.kg');
    expect(find.text('12 480'), findsWidgets);
    final container = ProviderScope.containerOf(tester.element(find.byType(AdminApp)));
    await container.read(actionsProvider).run((s) => s.saveSubscriber(
        const Subscriber(account: '31-02261', name: 'Жумабаева Асель', street: 'ул. Курманжан Датка', house: '218'),
        isNew: true));
    await tester.pumpAndSettle();
    expect(find.text('12 481'), findsWidgets, reason: 'боковая панель обязана обновиться после правки');
  });

  testWidgets('импорт через интерфейс: файл → колонки → проверка → загрузка', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'jypar@oshvodokanal.kg');
    final container = ProviderScope.containerOf(tester.element(find.byType(AdminApp)));
    container.read(routerProvider).go('/svc/import');
    await tester.pumpAndSettle();

    files.next = PickedFile('abonenty_primer_1c.csv', sampleSubscribersCsv(store.subscribers));
    await tester.tap(find.text('Выбрать файл'));
    await tester.pumpAndSettle();
    expect(find.text('Кодировка Windows-1251'), findsOneWidget);
    expect(find.text('Разделитель «;»'), findsOneWidget);

    await tester.tap(find.text('Далее: колонки'));
    await tester.pumpAndSettle();
    expect(find.text('Лиц_счет'), findsOneWidget);
    await tester.ensureVisible(find.text('Далее: проверка'));
    await tester.tap(find.text('Далее: проверка'));
    await tester.pumpAndSettle();
    final w = container.read(importWizardProvider);
    expect(w.step, WizardStep.check);
    expect(w.issues, isNotEmpty);

    await tester.tap(find.textContaining('Принять все подсказки'));
    await tester.pumpAndSettle();
    final load = find.textContaining(RegExp(r'^Загрузить \d'));
    await tester.ensureVisible(load);
    await tester.tap(load);
    await tester.pumpAndSettle();
    expect(find.textContaining('Загружено'), findsOneWidget);
    expect(store.imports().first.fileName, 'abonenty_primer_1c.csv');
    expect(store.subscriber('31-09100')?.name, 'Жумабаева Асель');
  });
}
