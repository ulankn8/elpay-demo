/// Мастер импорта: файл → колонки → проверка → загрузка.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/csv.dart';
import '../data/import_engine.dart';
import '../data/mapping.dart';
import '../data/models.dart';
import '../data/text_codec.dart';
import '../data/xlsx.dart';
import '../platform/file_io.dart';
import 'admin_state.dart';

enum WizardStep { file, columns, check, done }

class LoadedFile {
  const LoadedFile({
    required this.name,
    required this.size,
    required this.table,
    required this.format,
    this.encoding = '',
    this.delimiter = '',
    this.warning = '',
  });
  final String name, format, encoding, delimiter;

  /// Что насторожило в самом файле — например, «?» вместо букв.
  final String warning;
  final int size;
  final ParsedTable table;
}

class WizardState {
  const WizardState({
    this.step = WizardStep.file,
    this.kind = ImportKind.subscribers,
    this.period,
    this.file,
    this.error,
    this.map = const [],
    this.templateUsed = false,
    this.saveTemplate = true,
    this.updateExisting = true,
    this.overrides = const {},
    this.subPlan,
    this.chargePlan,
    this.job,
    this.busy = false,
  });

  final WizardStep step;
  final ImportKind kind;
  final Period? period;
  final LoadedFile? file;
  final String? error;
  final List<ColumnMap> map;
  final bool templateUsed, saveTemplate, updateExisting, busy;
  final Map<int, Map<Field, String>> overrides;
  final SubscriberPlan? subPlan;
  final ChargesPlan? chargePlan;
  final ImportJob? job;

  List<RowIssue> get issues => subPlan?.issues ?? chargePlan?.issues ?? const [];
  int get willLoad => subPlan?.willLoad ?? chargePlan?.willLoad ?? 0;
  int get rows => subPlan?.rows ?? chargePlan?.rows ?? 0;

  WizardState copyWith({
    WizardStep? step,
    ImportKind? kind,
    Period? period,
    LoadedFile? file,
    String? error,
    bool clearError = false,
    List<ColumnMap>? map,
    bool? templateUsed,
    bool? saveTemplate,
    bool? updateExisting,
    Map<int, Map<Field, String>>? overrides,
    SubscriberPlan? subPlan,
    ChargesPlan? chargePlan,
    bool clearPlans = false,
    ImportJob? job,
    bool? busy,
  }) =>
      WizardState(
        step: step ?? this.step,
        kind: kind ?? this.kind,
        period: period ?? this.period,
        file: file ?? this.file,
        error: clearError ? null : (error ?? this.error),
        map: map ?? this.map,
        templateUsed: templateUsed ?? this.templateUsed,
        saveTemplate: saveTemplate ?? this.saveTemplate,
        updateExisting: updateExisting ?? this.updateExisting,
        overrides: overrides ?? this.overrides,
        subPlan: clearPlans ? null : (subPlan ?? this.subPlan),
        chargePlan: clearPlans ? null : (chargePlan ?? this.chargePlan),
        job: job ?? this.job,
        busy: busy ?? this.busy,
      );
}

/// Прочитать файл в таблицу: Excel или текст с угадыванием кодировки.
LoadedFile readImportFile(PickedFile f) {
  final lower = f.name.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || looksLikeXlsx(f.bytes) || looksLikeOldXls(f.bytes)) {
    final rows = readXlsx(f.bytes);
    return LoadedFile(name: f.name, size: f.bytes.length, table: toTable(rows), format: 'Excel');
  }
  final text = decodeText(f.bytes);
  final d = detectDelimiter(text.text);
  final table = toTable(parseCsv(text.text, delimiter: d));
  return LoadedFile(
    name: f.name,
    size: f.bytes.length,
    table: table,
    format: 'CSV',
    encoding: text.encoding.label,
    delimiter: delimiterLabel(d),
    warning: lostLettersWarning(table),
  );
}

/// «Т?л?бердиева»: так выглядят кыргызские ү, ө, ң, если 1С сохранила
/// выгрузку в Windows-1251 — этих букв в кодировке нет, и вместо них «?».
/// Восстановить их нельзя, поэтому говорим об этом до загрузки.
String lostLettersWarning(ParsedTable t) {
  final broken = RegExp(r'[А-Яа-яЁё]\?[А-Яа-яЁё?]');
  var n = 0;
  String? example;
  for (final r in t.rows) {
    for (final c in r) {
      if (broken.hasMatch(c)) {
        n++;
        example ??= c;
      }
    }
  }
  if (n == 0) return '';
  return 'В $n ${n % 10 == 1 && n % 100 != 11 ? 'ячейке' : 'ячейках'} вместо букв стоит «?», например «$example». '
      'Так теряются кыргызские ң, ө, ү, когда 1С сохраняет файл в Windows-1251. '
      'Сохраните выгрузку в UTF-8 и загрузите снова — иначе имена попадут в реестр с вопросами.';
}

class ImportWizard extends Notifier<WizardState> {
  @override
  WizardState build() => const WizardState();

  void reset({ImportKind? kind, Period? period}) =>
      state = WizardState(kind: kind ?? state.kind, period: period ?? _defaultPeriod(kind ?? state.kind));

  Period? _defaultPeriod(ImportKind k) =>
      k == ImportKind.charges ? ref.read(adminStoreProvider).openPeriod.next : null;

  void setKind(ImportKind k) {
    state = WizardState(kind: k, period: _defaultPeriod(k));
  }

  void setPeriod(Period p) => state = state.copyWith(period: p, clearPlans: true);

  /// Файл выбран или перетащен: читаем и сразу сопоставляем колонки.
  void loadFile(PickedFile f) {
    try {
      final loaded = readImportFile(f);
      if (loaded.table.rows.isEmpty) {
        state = state.copyWith(error: 'В файле нет строк с данными', file: loaded);
        return;
      }
      final store = ref.read(adminStoreProvider);
      final tpl = store.template(state.kind);
      final map = autoMap(loaded.table, state.kind, template: tpl);
      final used = tpl != null && loaded.table.hasHeader && loaded.table.headers.any(tpl.containsKey);
      state = WizardState(
        kind: state.kind,
        period: state.period ?? _defaultPeriod(state.kind),
        file: loaded,
        map: map,
        templateUsed: used,
        updateExisting: state.updateExisting,
      );
    } on SheetReadException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: 'Файл не прочитался: $e');
    }
  }

  void toColumns() => state = state.copyWith(step: WizardStep.columns);
  void back() => state = state.copyWith(
        step: switch (state.step) {
          WizardStep.check => WizardStep.columns,
          WizardStep.columns => WizardStep.file,
          _ => WizardStep.file,
        },
      );

  void setField(int col, Field f) {
    final next = [...state.map];
    // Одно поле — одна колонка: прежнюю колонку с этим полем отпускаем.
    if (f != Field.skip) {
      for (var i = 0; i < next.length; i++) {
        if (i != col && next[i].field == f) next[i] = const ColumnMap(Field.skip, MapConfidence.none);
      }
    }
    next[col] = next[col].withField(f);
    state = state.copyWith(map: next, clearPlans: true);
  }

  void setSaveTemplate(bool v) => state = state.copyWith(saveTemplate: v);
  void setUpdateExisting(bool v) => state = state.copyWith(updateExisting: v, clearPlans: true);

  List<Field> get missing => missingRequired(state.map, state.kind);

  /// Проверка: строим план, ничего не записывая.
  void check() {
    final store = ref.read(adminStoreProvider);
    final f = state.file!;
    if (state.kind == ImportKind.subscribers) {
      final plan = planSubscribers(
        table: f.table,
        map: state.map,
        existing: store.subscribers,
        now: store.now(),
        overrides: state.overrides,
        updateExisting: state.updateExisting,
      );
      state = state.copyWith(step: WizardStep.check, subPlan: plan);
    } else {
      final p = state.period ?? store.openPeriod.next;
      final loaded = store.periods().where((x) => x.period == p).firstOrNull?.count ?? 0;
      final plan = planCharges(
        table: f.table,
        map: state.map,
        subscribers: store.subscribers,
        period: p,
        alreadyLoaded: loaded,
        overrides: state.overrides,
      );
      state = state.copyWith(step: WizardStep.check, chargePlan: plan, period: p);
    }
  }

  /// «Исправить на это» и вписанное ФИО: правка строки и новый план.
  void fixRow(int index, Map<Field, String> values) {
    final o = {...state.overrides};
    o[index] = {...?o[index], ...values};
    state = state.copyWith(overrides: o);
    check();
  }

  /// Принять все готовые правки разом.
  void fixAll() {
    final o = {...state.overrides};
    for (final i in state.issues) {
      if (i.fix != null) o[i.index] = {...?o[i.index], ...i.fix!};
    }
    state = state.copyWith(overrides: o);
    check();
  }

  Future<void> apply() async {
    final f = state.file!;
    state = state.copyWith(busy: true);
    final actions = ref.read(actionsProvider);
    if (state.saveTemplate && f.table.hasHeader) {
      await actions.run((s) => s.saveTemplate(state.kind, templateOf(f.table, state.map)));
    }
    final job = state.kind == ImportKind.subscribers
        ? await actions.run((s) => s.applySubscribers(state.subPlan!, fileName: f.name))
        : await actions.run((s) => s.applyCharges(state.chargePlan!, fileName: f.name));
    state = state.copyWith(step: WizardStep.done, job: job, busy: false);
  }
}

final importWizardProvider = NotifierProvider<ImportWizard, WizardState>(ImportWizard.new);
