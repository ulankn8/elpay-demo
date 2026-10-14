import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/tokens.dart';
import '../../data/import_engine.dart';
import '../../data/mapping.dart';
import '../../data/models.dart';
import '../../data/samples.dart';
import '../../data/xlsx.dart';
import '../../state/admin_state.dart';
import '../../state/import_wizard.dart';
import '../kit.dart';
import '../shell.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, this.kind});
  final String? kind;
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  void Function()? _unlisten;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    final k = ImportKind.values.where((x) => x.name == widget.kind).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final w = ref.read(importWizardProvider);
      if (k != null && (w.kind != k || w.step == WizardStep.done)) ref.read(importWizardProvider.notifier).setKind(k);
      if (w.step == WizardStep.done && k == null) ref.read(importWizardProvider.notifier).reset();
    });
    _unlisten = ref
        .read(fileGatewayProvider)
        .listenDrops(
          (f) {
            if (ref.read(importWizardProvider).step == WizardStep.file) ref.read(importWizardProvider.notifier).loadFile(f);
          },
          onOver: (o) {
            if (mounted && o != _over) setState(() => _over = o);
          },
        );
  }

  @override
  void dispose() {
    _unlisten?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(importWizardProvider);
    final stepIndex = switch (w.step) {
      WizardStep.file => 0,
      WizardStep.columns => 1,
      WizardStep.check => 2,
      WizardStep.done => 3,
    };
    return PageBody(
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
          child: Row(
            children: [
              Steps(labels: const ['Файл', 'Колонки', 'Проверка'], current: stepIndex),
              const SizedBox(width: 16),
              // Справа — что поместится: на узком экране подписи сожмутся, а не вылезут.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (w.step == WizardStep.check)
                      const Chip2('Предпросмотр — в реестре пока ничего не изменено', tone: Tone.info, icon: Icons.visibility_outlined),
                    if (w.file != null && w.step != WizardStep.file && w.step != WizardStep.check) _FileBadge(w.file!),
                    TextButton.icon(
                      onPressed: () => context.go('/svc/import/journal'),
                      icon: const Icon(Icons.history_rounded, size: 17),
                      label: const Text('Журнал импортов'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        switch (w.step) {
          WizardStep.file => _FileStep(over: _over),
          WizardStep.columns => const _ColumnsStep(),
          WizardStep.check => const _CheckStep(),
          WizardStep.done => const _DoneStep(),
        },
      ],
    );
  }
}

class _FileBadge extends StatelessWidget {
  const _FileBadge(this.f);
  final LoadedFile f;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
    decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FileType(f.format == 'Excel' ? 'xlsx' : 'csv', size: 30),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text(
              ['${nf(f.table.rows.length)} строк', if (f.encoding.isNotEmpty) f.encoding, if (f.delimiter.isNotEmpty) f.delimiter].join(' · '),
              style: T.tiny,
            ),
          ],
        ),
      ],
    ),
  );
}

class _FileType extends StatelessWidget {
  const _FileType(this.ext, {this.size = 40});
  final String ext;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size * .86,
    height: size,
    alignment: Alignment.bottomCenter,
    padding: EdgeInsets.only(bottom: size * .12),
    decoration: BoxDecoration(color: ext == 'xlsx' ? const Color(0xFF1D7A47) : const Color(0xFF1FA894), borderRadius: BorderRadius.circular(6)),
    child: Text(
      ext,
      style: TextStyle(color: Colors.white, fontSize: size * .24, fontWeight: FontWeight.w700),
    ),
  );
}

// ───────────────────────── шаг 1: файл ─────────────────────────

class _FileStep extends ConsumerWidget {
  const _FileStep({required this.over});
  final bool over;

  Future<void> _pick(WidgetRef ref) async {
    final f = await ref.read(fileGatewayProvider).pick(accept: '.csv,.txt,.xlsx,.xls');
    if (f != null) ref.read(importWizardProvider.notifier).loadFile(f);
  }

  void _sample(BuildContext context, WidgetRef ref, ImportKind kind, Period? period) {
    final s = ref.read(adminStoreProvider);
    final gw = ref.read(fileGatewayProvider);
    if (kind == ImportKind.subscribers) {
      gw.download('abonenty_primer_1c.csv', sampleSubscribersCsv(s.subscribers), 'text/csv');
    } else {
      final p = period ?? s.openPeriod.next;
      final last = s.openPeriod;
      gw.download(
        'nachisleniya_${p.key}.xlsx',
        sampleChargesXlsx(s.subscribers, p, (a) => s.chargeOf(a, last)),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
    toast(context, 'Пример скачан. Перетащите его сюда или нажмите «Выбрать файл»');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(importWizardProvider);
    final n = ref.read(importWizardProvider.notifier);
    final s = ref.admin;
    final open = s.openPeriod;
    final periods = [open.next, open];

    Widget kindCard(ImportKind k, IconData icon, String title, String text) => Expanded(
      child: Material(
        color: w.kind == k ? Brand.light2 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: w.kind == k ? Brand.primary : Brand.line, width: w.kind == k ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => n.setKind(k),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftIcon(icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: T.h3),
                      const SizedBox(height: 3),
                      Text(text, style: T.sub),
                    ],
                  ),
                ),
                Icon(w.kind == k ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: w.kind == k ? Brand.primary : Brand.muted2),
              ],
            ),
          ),
        ),
      ),
    );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Что загружаем', style: T.h2),
        const SizedBox(height: 10),
        Row(
          children: [
            kindCard(
              ImportKind.subscribers,
              Icons.people_outline_rounded,
              'Абоненты',
              'Реестр: лицевые, ФИО, адреса, жильцы. Новые добавятся, известные обновятся',
            ),
            const SizedBox(width: 12),
            kindCard(ImportKind.charges, Icons.receipt_long_outlined, 'Начисления за период', 'Суммы за месяц по лицевым — их жители увидят в приложении'),
          ],
        ),
        if (w.kind == ImportKind.charges) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Период:', style: T.h3),
              const SizedBox(width: 10),
              Seg<Period>(
                items: [for (final p in periods) (p, '${periodTitle(p.year, p.month)}${p == open ? ' · заменить' : ''}')],
                value: w.period ?? open.next,
                onChanged: n.setPeriod,
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
          decoration: BoxDecoration(
            color: over ? Brand.light2 : const Color(0xFFF7FCFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: over ? Brand.primary : const Color(0xFFBFD9CF), width: 2),
          ),
          child: Column(
            children: [
              const SoftIcon(Icons.upload_file_rounded, size: 64),
              const SizedBox(height: 14),
              Text(over ? 'Отпустите файл' : 'Перетащите файл сюда', style: T.h2),
              const SizedBox(height: 4),
              const Text('CSV из 1С или Excel .xlsx · до 20 МБ · кодировку и разделитель определим сами', style: T.sub, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => _pick(ref), icon: const Icon(Icons.folder_open_rounded, size: 18), label: const Text('Выбрать файл')),
            ],
          ),
        ),
        if (w.error != null) ...[const SizedBox(height: 12), Note(tone: Tone.bad, child: Text(w.error!))],
        if (w.file != null && w.error == null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.line),
            ),
            child: Row(
              children: [
                _FileType(w.file!.format == 'Excel' ? 'xlsx' : 'csv'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.file!.name, style: T.h3),
                      const SizedBox(height: 3),
                      Text('${nf(w.file!.table.rows.length)} строк · ${(w.file!.size / 1024).toStringAsFixed(0)} КБ', style: T.sub),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (w.file!.encoding.isNotEmpty) Chip2('Кодировка ${w.file!.encoding}', tone: Tone.ok, icon: Icons.check_rounded),
                          if (w.file!.delimiter.isNotEmpty) Chip2('Разделитель ${w.file!.delimiter}', tone: Tone.ok, icon: Icons.check_rounded),
                          Chip2(
                            w.file!.table.hasHeader ? 'Первая строка — заголовки' : 'Без заголовков — колонки угадаем',
                            tone: w.file!.table.hasHeader ? Tone.ok : Tone.warn,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(onPressed: n.toColumns, icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Далее: колонки')),
              ],
            ),
          ),
          if (w.file!.warning.isNotEmpty) ...[const SizedBox(height: 10), Note(tone: Tone.warn, icon: Icons.translate_rounded, child: Text(w.file!.warning))],
        ],
      ],
    );

    final right = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Как выгрузить из 1С', style: T.h2),
          const SizedBox(height: 12),
          for (final (i, t)
              in (w.kind == ImportKind.subscribers
                      ? const [
                          'В 1С откройте список лицевых счетов (Справочники → Лицевые счета)',
                          'Отберите нужный участок или весь реестр',
                          'Нажмите «Ещё → Вывести список…» и оставьте колонки как есть',
                          'Сохраните как Excel или CSV — переименовывать колонки не нужно',
                        ]
                      : const [
                          'В 1С сформируйте ведомость начислений за месяц',
                          'В ней нужны лицевой счёт и сумма к оплате — остальное по желанию',
                          'Сохраните как Excel (.xlsx) или CSV',
                          'Загрузите — жители увидят суммы в приложении сразу',
                        ])
                  .indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Brand.light2, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.p700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: T.body)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Попробовать без 1С', style: T.h3),
          const SizedBox(height: 4),
          Text(
            w.kind == ImportKind.subscribers
                ? 'Пример выгрузки в Windows-1251 с «;» — с обновлениями, новыми абонентами и восемью типовыми ошибками'
                : 'Ведомость за ${monthsNom[(w.period ?? open.next).month - 1]} на всех абонентов и две ошибки внутри',
            style: T.sub,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _sample(context, ref, w.kind, w.period),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(w.kind == ImportKind.subscribers ? 'Скачать пример абонентов (CSV)' : 'Скачать пример начислений (Excel)'),
          ),
          if (w.kind == ImportKind.subscribers && s.template(ImportKind.subscribers) != null) ...[
            const SizedBox(height: 14),
            const Note(
              tone: Tone.ok,
              icon: Icons.bookmark_added_outlined,
              child: Text('Сохранён шаблон «1С: Абоненты ОВК» — колонки вашей выгрузки подставятся сами'),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (_, c) => c.maxWidth > 1100
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: right),
              ],
            )
          : Column(children: [left, const SizedBox(height: 16), right]),
    );
  }
}

// ───────────────────────── шаг 2: колонки ─────────────────────────

class _ColumnsStep extends ConsumerWidget {
  const _ColumnsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(importWizardProvider);
    final n = ref.read(importWizardProvider.notifier);
    final t = w.file!.table;
    final missing = n.missing;
    final allowed = fieldsFor(w.kind);
    final checks = w.map.where((m) => m.confidence == MapConfidence.check || m.confidence == MapConfidence.guess).length;

    Widget conf(ColumnMap m) => switch (m.confidence) {
      MapConfidence.header => const Chip2('Определено автоматически', tone: Tone.ok, icon: Icons.check_rounded),
      MapConfidence.guess => const Chip2('Угадали по значениям — проверьте', tone: Tone.warn, icon: Icons.help_outline_rounded),
      MapConfidence.check => const Chip2('Проверьте', tone: Tone.warn, icon: Icons.warning_amber_rounded),
      MapConfidence.none => const Chip2('Не загружается'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Note(
          tone: w.templateUsed ? Tone.ok : Tone.info,
          icon: w.templateUsed ? Icons.bookmark_added_outlined : Icons.auto_awesome_outlined,
          child: Text(
            w.templateUsed
                ? 'Шаблон прошлой загрузки подставлен. ${checks == 0 ? 'Все колонки узнаны.' : 'Проверьте помеченные: $checks.'}'
                : t.hasHeader
                ? 'Колонки узнали по названиям. ${checks == 0 ? 'Всё сопоставлено.' : 'Проверьте помеченные: $checks.'}'
                : 'В файле нет заголовков — колонки угадали по значениям. Проверьте каждую.',
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: Grid(
            rowHeight: 62,
            cols: const [
              Col('Колонка в вашем файле', flex: 3),
              Col('', width: 30),
              Col('Поле ЭлPay', width: 240),
              Col('Первые значения из файла', flex: 6),
              Col('Сопоставление', width: 260),
            ],
            rowColor: (i) => w.map[i].confidence == MapConfidence.check || w.map[i].confidence == MapConfidence.guess ? const Color(0xFFFFFBF2) : null,
            rows: [
              for (var i = 0; i < t.width; i++)
                [
                  Text(t.headers[i], style: T.td.copyWith(fontWeight: FontWeight.w700)),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Brand.muted2),
                  DropdownButtonFormField<Field>(
                    initialValue: w.map[i].field,
                    isDense: true,
                    isExpanded: true, // длинное «Адрес одной строкой» сожмётся многоточием
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: [
                      for (final f in allowed)
                        DropdownMenuItem(
                          value: f,
                          child: Text(
                            f.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: f == Field.skip ? Brand.muted : Brand.ink),
                          ),
                        ),
                    ],
                    onChanged: (f) => n.setField(i, f!),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.samples(i).isEmpty ? 'пусто' : t.samples(i).join(' · '),
                        style: T.td.copyWith(color: t.samples(i).isEmpty ? Brand.muted2 : Brand.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (w.map[i].note.isNotEmpty)
                        Text(
                          w.map[i].note,
                          style: const TextStyle(fontSize: 11.5, color: K.warnFg, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  conf(w.map[i]),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Wrap(
            spacing: 28,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (w.kind == ImportKind.subscribers)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Если лицевой уже есть в реестре', style: T.h3),
                    const SizedBox(height: 8),
                    Seg<bool>(items: const [(true, 'Обновить данные'), (false, 'Пропустить строку')], value: w.updateExisting, onChanged: n.setUpdateExisting),
                    const SizedBox(height: 6),
                    const Text('ФИО, адрес и жильцов возьмём из файла. Оплаты и долги не меняются', style: T.sub),
                  ],
                ),
              if (t.hasHeader)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(value: w.saveTemplate, onChanged: (v) => n.setSaveTemplate(v ?? false)),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Запомнить как шаблон', style: T.h3),
                        Text('В следующий раз колонки подставятся сами', style: T.sub),
                      ],
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(onPressed: n.back, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Назад')),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: missing.isEmpty ? '' : 'Не хватает колонок: ${missing.map((f) => f.label).join(', ')}',
                    child: FilledButton.icon(
                      onPressed: missing.isEmpty ? n.check : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Далее: проверка'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          Note(tone: Tone.bad, child: Text('Чтобы загрузить, укажите колонку для: ${missing.map((f) => f.label).join(', ')}.')),
        ],
      ],
    );
  }
}

// ───────────────────────── шаг 3: проверка ─────────────────────────

enum _Tab { errors, created, updated, charges }

class _CheckStep extends ConsumerStatefulWidget {
  const _CheckStep();
  @override
  ConsumerState<_CheckStep> createState() => _CheckStepState();
}

class _CheckStepState extends ConsumerState<_CheckStep> {
  _Tab? _tab;
  IssueKind? _kind;
  int _page = 0;
  static const _per = 10;

  void _downloadErrors(WizardState w) {
    final rows = <List<String>>[
      ['Строка файла', 'Лицевой', 'ФИО', 'Адрес', 'Причина', 'Как исправить'],
      for (final i in w.issues) ['${i.line}', i.account, i.name, i.address, i.kind.label, i.message],
    ];
    ref
        .read(fileGatewayProvider)
        .download(
          'oshibki_${w.file!.name.split('.').first}.xlsx',
          writeXlsx(rows, sheetName: 'Ошибки'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
    toast(context, 'Ошибки выгружены — исправьте их в 1С и загрузите только эти строки');
  }

  Future<void> _enterName(RowIssue i) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ФИО для строки ${i.line}', style: T.h1),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i.account} · ${i.address}', style: T.sub),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Фамилия Имя'),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Вписать')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) ref.read(importWizardProvider.notifier).fixRow(i.index, {Field.name: name});
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(importWizardProvider);
    final n = ref.read(importWizardProvider.notifier);
    final sub = w.subPlan;
    final ch = w.chargePlan;
    final tab = _tab ?? (w.issues.isNotEmpty ? _Tab.errors : (sub != null ? _Tab.created : _Tab.charges));
    final counts = sub?.issueCounts ?? {for (final k in IssueKind.values) k: w.issues.where((i) => i.kind == k).length};
    final issues = [
      for (final i in w.issues)
        if (_kind == null || i.kind == _kind) i,
    ];
    final fixable = w.issues.where((i) => i.fix != null).length;

    Widget tile(String label, Widget value, String note, {Color? accent, Color? noteColor}) => Expanded(
      child: Kpi(label: label, value: value, note: note, accent: accent, noteColor: noteColor),
    );
    Text big(int v, [Color c = Brand.ink]) => Text(
      nf(v),
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.6, color: c),
    );

    final tiles = sub != null
        ? [
            tile('Строк в файле', big(sub.rows), w.file!.encoding.isEmpty ? w.file!.format : '${w.file!.encoding} · ${w.file!.delimiter}'),
            const SizedBox(width: 12),
            tile(
              'Новые абоненты',
              big(sub.created.length, Brand.p700),
              'в реестре станет ${nf(ref.read(adminStoreProvider).subscribers.length + sub.created.length)}',
              noteColor: Brand.p700,
            ),
            const SizedBox(width: 12),
            tile('Обновятся', big(sub.updated.length, Brand.info), 'адрес, ФИО или жильцы', noteColor: Brand.info),
            const SizedBox(width: 12),
            tile('Без изменений', big(sub.unchanged), 'совпали с реестром'),
            const SizedBox(width: 12),
            tile(
              'С ошибкой',
              big(sub.issues.length, sub.issues.isEmpty ? Brand.ink : Brand.danger),
              sub.issues.isEmpty ? 'ошибок нет' : 'не будут загружены сейчас',
              accent: sub.issues.isEmpty ? null : const Color(0xFFF5B3A8),
              noteColor: sub.issues.isEmpty ? null : Brand.danger,
            ),
          ]
        : [
            tile('Строк в файле', big(ch!.rows), w.file!.format),
            const SizedBox(width: 12),
            tile('Загрузится', big(ch.willLoad, Brand.p700), 'за ${periodTitle(ch.period.year, ch.period.month)}', noteColor: Brand.p700),
            const SizedBox(width: 12),
            tile(
              'Сумма начислений',
              Money(ch.total, size: 24, weight: FontWeight.w700),
              ch.replaces > 0 ? 'заменит ${nf(ch.replaces)} загруженных' : 'новый период',
            ),
            const SizedBox(width: 12),
            tile('Без начисления', big(ch.withoutCharge), 'активные абоненты, которых нет в файле'),
            const SizedBox(width: 12),
            tile(
              'С ошибкой',
              big(ch.issues.length, ch.issues.isEmpty ? Brand.ink : Brand.danger),
              ch.issues.isEmpty ? 'ошибок нет' : 'не будут загружены',
              accent: ch.issues.isEmpty ? null : const Color(0xFFF5B3A8),
              noteColor: ch.issues.isEmpty ? null : Brand.danger,
            ),
          ];

    Widget tabBtn(_Tab t, String label, int count) => Padding(
      padding: const EdgeInsets.only(right: 22),
      child: InkWell(
        onTap: () => setState(() {
          _tab = t;
          _page = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tab == t ? Brand.primary : Colors.transparent, width: 2.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tab == t ? Brand.ink : Brand.muted),
              ),
              const SizedBox(width: 7),
              Chip2(nf(count), tone: t == _Tab.errors && count > 0 ? Tone.bad : Tone.soft),
            ],
          ),
        ),
      ),
    );

    Widget body;
    if (tab == _Tab.errors) {
      final shown = issues.skip(_page * _per).take(_per).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'Все причины',
                        count: w.issues.length,
                        selected: _kind == null,
                        onTap: () => setState(() {
                          _kind = null;
                          _page = 0;
                        }),
                      ),
                      for (final k in IssueKind.values)
                        if ((counts[k] ?? 0) > 0)
                          FilterPill(
                            label: k.label,
                            count: counts[k],
                            selected: _kind == k,
                            onTap: () => setState(() {
                              _kind = k;
                              _page = 0;
                            }),
                          ),
                    ],
                  ),
                ),
                if (fixable > 0) ...[
                  FilledButton.tonalIcon(
                    onPressed: n.fixAll,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                    label: Text('Принять все подсказки · $fixable'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => _downloadErrors(w),
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Скачать ошибки в Excel'),
                ),
              ],
            ),
          ),
          Grid(
            rowHeight: 56,
            cols: const [
              Col('Строка', width: 64),
              Col('Лицевой', width: 100),
              Col('ФИО', flex: 3),
              Col('Адрес в файле', flex: 3),
              Col('Причина', width: 180),
              Col('Как исправить', flex: 6),
            ],
            empty: const Empty(icon: Icons.check_circle_outline, title: 'Ошибок нет', text: 'Все строки готовы к загрузке'),
            rows: [
              for (final i in shown)
                [
                  Text(nf(i.line), style: T.num.copyWith(color: Brand.muted)),
                  Text(i.account.isEmpty ? '—' : i.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    i.name.isEmpty ? 'пусто' : i.name,
                    style: T.td.copyWith(color: i.name.isEmpty ? Brand.muted2 : Brand.ink, fontStyle: i.name.isEmpty ? FontStyle.italic : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    i.address.isEmpty ? '—' : i.address,
                    style: T.td.copyWith(color: Brand.ink2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Chip2(i.kind.label, tone: i.kind == IssueKind.duplicate || i.kind == IssueKind.emptyName ? Tone.bad : Tone.warn),
                  Row(
                    children: [
                      Expanded(
                        child: Text(i.message, style: T.td, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      if (i.fix != null)
                        FilledButton.tonal(onPressed: () => n.fixRow(i.index, i.fix!), child: Text(i.fixLabel ?? 'Исправить'))
                      else if (i.kind == IssueKind.emptyName)
                        OutlinedButton.icon(onPressed: () => _enterName(i), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Вписать ФИО')),
                    ],
                  ),
                ],
            ],
          ),
          Pager(page: _page, total: issues.length, perPage: _per, onPage: (p) => setState(() => _page = p)),
        ],
      );
    } else if (tab == _Tab.created) {
      final list = sub!.created;
      final shown = list.skip(_page * _per).take(_per).toList();
      body = Column(
        children: [
          Grid(
            cols: const [
              Col('Лицевой', width: 110),
              Col('ФИО', flex: 3),
              Col('Адрес', flex: 4),
              Col('Жильцов', width: 90, right: true),
              Col('Телефон', flex: 2),
            ],
            empty: const Empty(icon: Icons.person_outline, title: 'Новых абонентов нет'),
            rows: [
              for (final s in shown)
                [
                  Text(s.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                  Text(s.name, style: T.td),
                  Text(s.address, style: T.td),
                  Text('${s.residents}', style: T.num),
                  Text(s.phone.isEmpty ? '—' : s.phone, style: T.td),
                ],
            ],
          ),
          Pager(page: _page, total: list.length, perPage: _per, onPage: (p) => setState(() => _page = p)),
        ],
      );
    } else if (tab == _Tab.updated) {
      final list = sub!.updated;
      final shown = list.skip(_page * _per).take(_per).toList();
      body = Column(
        children: [
          Grid(
            cols: const [Col('Лицевой', width: 110), Col('ФИО', flex: 3), Col('Что изменится', flex: 6)],
            empty: const Empty(icon: Icons.sync_alt, title: 'Изменений нет'),
            rows: [
              for (final c in shown)
                [
                  Text(c.after.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                  Text(c.after.name, style: T.td),
                  Text(c.fields.join(' · '), style: T.td.copyWith(color: Brand.info)),
                ],
            ],
          ),
          Pager(page: _page, total: list.length, perPage: _per, onPage: (p) => setState(() => _page = p)),
        ],
      );
    } else {
      final list = ch!.charges;
      final subs = ref.read(adminStoreProvider).subscribers;
      final shown = list.skip(_page * _per).take(_per).toList();
      body = Column(
        children: [
          Grid(
            cols: const [Col('Лицевой', width: 110), Col('ФИО', flex: 3), Col('Как посчитано', flex: 3), Col('Сумма', width: 120, right: true)],
            rows: [
              for (final c in shown)
                [
                  Text(c.account, style: T.num.copyWith(fontWeight: FontWeight.w700)),
                  Text(subs[c.account]?.name ?? '', style: T.td),
                  Text(c.calc, style: T.td.copyWith(color: Brand.muted)),
                  Money(c.amount),
                ],
            ],
          ),
          Pager(page: _page, total: list.length, perPage: _per, onPage: (p) => setState(() => _page = p)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    tabBtn(_Tab.errors, 'Ошибки', w.issues.length),
                    if (sub != null) ...[tabBtn(_Tab.created, 'Новые', sub.created.length), tabBtn(_Tab.updated, 'Изменения', sub.updated.length)],
                    if (ch != null) tabBtn(_Tab.charges, 'Начисления', ch.charges.length),
                  ],
                ),
              ),
              const Divider(height: 1, color: Brand.line),
              body,
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            children: [
              const SoftIcon(Icons.schedule_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.issues.isEmpty ? 'Всё готово к загрузке' : 'Строки с ошибками можно дозагрузить потом — остальные не ждут', style: T.h3),
                    const SizedBox(height: 2),
                    Text(
                      sub != null
                          ? 'Загрузка запишется в журнал. Отменить её можно в течение суток. Оплаты и долги абонентов не трогаем'
                          : 'Жители увидят начисления за ${monthsNom[ch!.period.month - 1]} в приложении сразу после загрузки',
                      style: T.sub,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(onPressed: n.back, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Назад')),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: w.willLoad == 0 || w.busy ? null : n.apply,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.upload_rounded, size: 19),
                label: Text(w.busy ? 'Загружаем…' : 'Загрузить ${nf(w.willLoad)} ${plural(w.willLoad, 'строку', 'строки', 'строк')}'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── итог ─────────────────────────

class _DoneStep extends ConsumerWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(importWizardProvider);
    final s = ref.admin;
    final job = s.imports().firstWhere((j) => j.id == w.job!.id, orElse: () => w.job!);
    final loaded = job.kind == ImportKind.subscribers ? job.created + job.updated + job.unchanged : job.created;
    final rolled = job.status == ImportStatus.rolledBack;
    final n = ref.read(importWizardProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.all(28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: rolled ? null : const LinearGradient(colors: [Color(0xFF3FD9A8), Brand.primary]),
                  color: rolled ? Brand.soft : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(rolled ? Icons.undo_rounded : Icons.check_rounded, color: rolled ? Brand.muted : Colors.white, size: 34),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rolled
                          ? 'Импорт отменён — реестр как до загрузки'
                          : 'Загружено ${nf(loaded)} ${plural(loaded, 'строка', 'строки', 'строк')} из ${nf(job.rows)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.5),
                    ),
                    const SizedBox(height: 6),
                    Text('${job.fileName} · ${dt(job.at)} · ${job.by}', style: T.sub),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (job.kind == ImportKind.subscribers) ...[
                          Chip2('+${nf(job.created)} новых', tone: Tone.ok),
                          Chip2('${nf(job.updated)} обновлено', tone: Tone.info),
                          Chip2('${nf(job.unchanged)} без изменений'),
                        ] else ...[
                          Chip2('${nf(job.created)} начислений', tone: Tone.ok),
                          Chip2('${som(job.total)} сом за ${periodTitle(job.period!.year, job.period!.month)}', tone: Tone.info),
                        ],
                        if (job.errors > 0)
                          Chip2(
                            '${nf(job.errors)} ${plural(job.errors, 'строка с ошибкой не загружена', 'строки с ошибкой не загружены', 'строк с ошибкой не загружены')}',
                            tone: Tone.bad,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go(job.kind == ImportKind.subscribers ? '/svc/subscribers?f=fresh' : '/svc/charges'),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: Text(job.kind == ImportKind.subscribers ? 'Открыть новых абонентов' : 'К начислениям'),
                        ),
                        if (job.errors > 0 && w.issues.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () {
                              final rows = <List<String>>[
                                ['Строка файла', 'Лицевой', 'ФИО', 'Адрес', 'Причина', 'Как исправить'],
                                for (final i in w.issues) ['${i.line}', i.account, i.name, i.address, i.kind.label, i.message],
                              ];
                              ref
                                  .read(fileGatewayProvider)
                                  .download(
                                    'oshibki_${job.fileName.split('.').first}.xlsx',
                                    writeXlsx(rows),
                                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                                  );
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text('Скачать ${nf(job.errors)} ${plural(job.errors, 'ошибку', 'ошибки', 'ошибок')} в Excel'),
                          ),
                        OutlinedButton.icon(onPressed: () => n.reset(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Новая загрузка')),
                        if (job.canRollback(s.now()))
                          TextButton.icon(
                            onPressed: () async {
                              final ok = await confirm(
                                context,
                                title: 'Отменить импорт?',
                                text: 'Новые абоненты из этого файла удалятся, обновлённые вернутся к прежним данным. Отменить можно в течение суток.',
                                ok: 'Отменить импорт',
                                danger: true,
                              );
                              if (!ok) return;
                              final r = await ref.read(actionsProvider).run((st) => st.rollback(job.id));
                              if (context.mounted) toast(context, r.isOk ? 'Импорт отменён' : r.failureOrNull!.message, bad: r.isFail);
                            },
                            style: TextButton.styleFrom(foregroundColor: Brand.danger),
                            icon: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Отменить импорт · доступно сутки'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
