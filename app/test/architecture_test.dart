import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Правила зависимостей слоёв проверяет ТЕСТ, а не абзац в HANDOFF.
///
/// Четыре слоя и одно направление: core ← data ← state ← features.
/// Абзац в документации нарушают через полгода и не замечают; красный тест
/// замечают в ту же минуту.
///
/// ПРАВИЛО ПРО demo_data ТЕПЕРЬ СТРОГОЕ, И ЭТО НАВСЕГДА. Пять экранов
/// в features/payments импортировали `Demo.*` напрямую, и пока это было
/// так, обещание «подмена реализации одной строкой» оставалось неправдой:
/// замена `apiProvider` на них не влияла. Импорты сняты, каталог приходит
/// из `CatalogRepository` — список известных нарушений убран, и вернуть
/// такой импорт теперь нельзя: тест упадёт в ту же минуту.
///
/// Одно правило всё ещё ослаблено списком ([knownRepoImports]) — экраны
/// входа. Это РАТЧЕТ: новое нарушение тест заваливает, а снятие старого
/// проходит молча.
void main() {
  /// Экраны, которые ещё видят репозиторий напрямую, а не через провайдер.
  const knownRepoImports = {
    'lib/features/auth/otp_page.dart',
    'lib/features/auth/login_page.dart',
  };

  /// Что из lib/data экрану видеть МОЖНО.
  ///
  /// Модели и демо-реестр — данные, а не реализация. `connect_rules.dart`
  /// тоже: это чистые правила и их значения (CandidateView, ChargesPreview,
  /// ConnectBlock), которые список найденного и рисует. Отдельное правило
  /// ниже следит за тем, чтобы правила не утащили за собой ни Flutter,
  /// ни Riverpod — иначе такое разрешение было бы дырой.
  const allowedFromData = {
    'lib/data/models.dart',
    'lib/data/registry_data.dart',
    'lib/data/demo_data.dart',
    'lib/data/connect_rules.dart',
  };

  final importLine = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<File> dartFiles(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    return [
      for (final e in d.listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e,
    ];
  }

  String slash(String path) => path.replaceAll(r'\', '/');

  /// Путь импорта → путь внутри пакета ('lib/data/models.dart').
  /// Чужие пакеты и dart: остаются как есть.
  String resolve(String from, String import) {
    if (import.startsWith('package:elpay/')) {
      return 'lib/${import.substring('package:elpay/'.length)}';
    }
    if (import.startsWith('package:') || import.startsWith('dart:')) return import;
    final parts = slash(from).split('/')..removeLast();
    for (final seg in import.split('/')) {
      if (seg == '.' || seg.isEmpty) continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(seg);
    }
    return parts.join('/');
  }

  /// Все импорты файла, приведённые к пути внутри пакета.
  List<String> importsOf(File f) => [
        for (final m in importLine.allMatches(f.readAsStringSync()))
          resolve(f.path, m.group(1)!),
      ];

  /// Файлы слоя, у которых есть импорт из запрещённых каталогов.
  Map<String, List<String>> offenders(String layer, List<String> forbidden) {
    final out = <String, List<String>>{};
    for (final f in dartFiles(layer)) {
      final bad = [
        for (final imp in importsOf(f))
          if (forbidden.any(imp.startsWith)) imp,
      ];
      if (bad.isNotEmpty) out[slash(f.path)] = bad;
    }
    return out;
  }

  test('В каталоге lib вообще есть что проверять', () {
    // Если тест запустили не из корня пакета, остальные правила стали бы
    // зелёными просто потому, что файлов не нашлось.
    expect(dartFiles('lib/core'), isNotEmpty);
    expect(dartFiles('lib/data'), isNotEmpty);
    expect(dartFiles('lib/state'), isNotEmpty);
    expect(dartFiles('lib/features'), isNotEmpty);
  });

  test('lib/core не импортирует data, state и features', () {
    // core — инфраструктура: она не знает ни про модели, ни про экраны,
    // иначе её нельзя вынести в отдельный пакет и переиспользовать.
    expect(
      offenders('lib/core', ['lib/data/', 'lib/state/', 'lib/features/']),
      isEmpty,
    );
  });

  test('lib/data не импортирует features и state', () {
    // Слой данных не знает, кто его читает: ни экрана, ни слоя состояния.
    expect(offenders('lib/data', ['lib/features/', 'lib/state/']), isEmpty);
  });

  test('lib/data не знает ни про виджеты, ни про контейнер', () {
    // Второе обещание того же правила — и до этого теста его проверял
    // только один файл (connect_rules.dart). Запрет по каталогам
    // «lib/features/, lib/state/» package:-импорт не ловит: репозиторий
    // мог взять material.dart и Riverpod напрямую, и слой данных тихо
    // перестал бы быть переносимым и подменяемым.
    //
    // package:flutter/foundation.dart (@immutable) разрешён осознанно:
    // это аннотации, а не интерфейс.
    expect(
      offenders('lib/data', const [
        'package:flutter/material.dart',
        'package:flutter/widgets.dart',
        'package:flutter/cupertino.dart',
        'package:flutter_riverpod',
        'package:riverpod',
      ]),
      isEmpty,
      reason: 'репозиторий не знает ни про экран, ни про провайдеры',
    );
  });

  test('lib/state не импортирует features', () {
    // Третья стрелка направления core ← data ← state ← features: состояние
    // не знает, какой экран его читает, иначе получается круг слоёв,
    // который Dart пропускает молча. До этого теста правила для lib/state
    // не было вовсе — кроме точечной проверки demo_data по четырём файлам.
    expect(offenders('lib/state', ['lib/features/']), isEmpty);
  });

  test('Правила подключения не знают про виджеты и Riverpod', () {
    final imports = importsOf(File('lib/data/connect_rules.dart'));

    // package:flutter/foundation.dart (@immutable) разрешён осознанно:
    // это аннотации, а не интерфейс. Виджеты и контейнер — нет, иначе
    // главный тест фичи снова станет виджет-тестом.
    expect(imports, isNot(contains('package:flutter/material.dart')));
    expect(imports.where((i) => i.contains('riverpod')), isEmpty);
    expect(imports.where((i) => i.startsWith('lib/state/')), isEmpty);
  });

  test('Ни один файл в lib/features не импортирует data/demo_data.dart', () {
    // Строго и без списка исключений: экран не знает, откуда взялся
    // каталог, поэтому источник подменяется одной строкой apiProvider.
    expect(
      offenders('lib/features', ['lib/data/demo_data.dart']),
      isEmpty,
      reason: 'каталог приходит из CatalogRepository, а не из Demo.*',
    );
  });

  test('Состояние тоже не читает demo_data вместо репозитория', () {
    // state/app_state.dart ещё берёт из Demo.* историю, уведомления и
    // прочее, для чего репозитория сознательно не завели (это записанный
    // долг плана). Начисления, счета и каталог там появиться не должны:
    // у них репозитории есть.
    final imports = importsOf(File('lib/state/bills.dart'))
      ..addAll(importsOf(File('lib/state/accounts.dart')))
      ..addAll(importsOf(File('lib/state/catalog.dart')))
      ..addAll(importsOf(File('lib/state/connect.dart')));

    expect(imports, isNot(contains('lib/data/demo_data.dart')));
  });

  test('Ни один экран не импортирует репозиторий напрямую — '
      'barrel-файл providers.dart это не разрешает', () {
    final repos = offenders('lib/features', ['lib/data/']).entries.where((e) {
      final rest = e.value.where((i) => !allowedFromData.contains(i));
      return rest.isNotEmpty;
    }).map((e) => e.key);

    expect(
      repos.toSet().difference(knownRepoImports),
      isEmpty,
      reason: 'репозиторий берут через провайдер: экран о реализации не знает',
    );
  });

  test('Ни один экран не импортирует data/api напрямую', () {
    // Здесь нарушений нет уже сейчас — правило строгое с первого дня.
    expect(offenders('lib/features', ['lib/data/api/']), isEmpty);
  });

  test('Экраны не читают SharedPreferences напрямую', () {
    // Настройки живут в AppPrefs, кэш — в LocalStore. Прямой доступ
    // из экрана обходит и то, и другое.
    expect(offenders('lib/features', ['package:shared_preferences']), isEmpty);
  });
}
