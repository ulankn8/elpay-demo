import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/connect_rules.dart';
import '../../data/models.dart';
import '../../data/registry_data.dart';
import '../../state/providers.dart';
import '../payments/provider_picker.dart';
import 'candidate_tile.dart';
import 'charges_preview.dart';
import 'confirm_sheet.dart';
import 'connect_args.dart';

/// Подключение счёта — ЕДИНСТВЕННЫЙ вход в мастер на всё приложение.
///
/// Шаги: поиск (по лицевому счёту или по адресу) → разбор найденного →
/// предпросмотр начислений → честный итог. Правил здесь нет: что показать,
/// что отметить и что отправить, решает [ConnectRules] через
/// `ConnectNotifier`, поэтому то же поведение проверяется юнит-тестами.
class ConnectAccountPage extends ConsumerStatefulWidget {
  const ConnectAccountPage({super.key, this.args = const ConnectArgs()});

  /// С чем пришли: поставщик, объект и источник перехода для аналитики.
  final ConnectArgs args;

  @override
  ConsumerState<ConnectAccountPage> createState() => _ConnectAccountPageState();
}

class _ConnectAccountPageState extends ConsumerState<ConnectAccountPage> {
  final _scroll = ScrollController();
  final _account = TextEditingController();
  final _street = TextEditingController();
  final _house = TextEditingController();
  final _flat = TextEditingController();
  String _city = Registry.cities.first;

  @override
  void initState() {
    super.initState();
    // Подставляем адрес из профиля — чаще всего искать будут именно его.
    final session = ref.read(sessionProvider);
    final (city, street, house, flat) = Registry.homeAddress;
    _city = session?.city.isNotEmpty == true ? session!.city : city;
    _street.text = street;
    _house.text = house;
    _flat.text = flat;

    // Вход в мастер: состояние сбрасывается, уходит connectStarted(source).
    // Строго после первого кадра: Riverpod 3 запрещает менять провайдер,
    // пока строится дерево, — иначе вместо мастера рисуется ErrorWidget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(connectProvider.notifier).start(
            providerId: widget.args.providerId,
            objectId: widget.args.objectId,
            source: widget.args.source,
          );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _account.dispose();
    _street.dispose();
    _house.dispose();
    _flat.dispose();
    super.dispose();
  }

  // ───────────────────────── действия ─────────────────────────

  /// После ответа прокручиваем к найденному, чтобы форма не закрывала список.
  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Поиск. Формат номера проверяют правила ДО сети: невалидный номер не
  /// тратит запрос, а ошибка садится в errorText поля.
  void _search() {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(connectProvider.notifier);
    final byAddress = ref.read(connectProvider).byAddress;
    final search = byAddress
        ? notifier.searchByAddress(
            city: _city,
            street: _street.text,
            house: _house.text,
            flat: _flat.text,
          )
        : notifier.searchByAccount(_account.text);
    search.then((_) {
      if (mounted) _scrollToResults();
    });
  }

  /// Подключение выбранного. Счета на чужое имя сначала подтверждаем кодом;
  /// закрытая шторка прерывает всю операцию, и ничего не подключается.
  Future<void> _connect() async {
    final s = S.of(context);
    final notifier = ref.read(connectProvider.notifier);
    final before = ref.read(connectProvider);

    // Объект не выбран, а объектов несколько: чипы выбора живут на списке
    // найденного, поэтому возвращаем туда и говорим, чего не хватает.
    if ((before.objectId ?? before.suggestedObjectId) == null) {
      if (before.step == ConnectStep.preview) notifier.backToResults();
      showAppSnack(context, s.chooseObject);
      return;
    }

    for (final view in ref.read(connectProvider).chosen) {
      if (!view.needsConfirm) continue;
      final ok = await openConfirmSheet(context, ref, view);
      if (!mounted || !ok) return;
    }

    final outcome = await notifier.connectChosen();
    if (!mounted) return;
    // Подключилось хоть что-то — notifier сам перевёл мастер на итог,
    // и там видны и подключённые, и непрошедшие. Не подключилось ничего —
    // причину говорим сразу, а не оставляем экран молчать.
    if (outcome.connected.isEmpty) {
      final failure = ref.read(connectProvider).failure;
      showAppSnack(
        context,
        failure == null ? s.errorUnknown : ErrorView.titleFor(context, failure),
      );
    }
  }

  void _done() => context.pushReplacement('/accounts');

  /// Уже подключённый счёт: ведём на его экран, а не создаём дубль.
  void _openConnected(CandidateView view) {
    final key = AccountMask.keyOf(view.candidate.accountNo);
    final accounts = ref.read(accountsProvider).value?.accounts ?? const <ConnectedAccount>[];
    for (final a in accounts) {
      if (a.providerId == view.candidate.providerId && AccountMask.keyOf(a.accountNo) == key) {
        context.push('/accounts/${a.id}');
        return;
      }
    }
    // Счёт подключён на другом устройстве и ещё не доехал в список —
    // показываем общий экран счетов, а не пустую страницу счёта.
    context.push('/accounts');
  }

  Future<void> _confirmOne(CandidateView view) async {
    await openConfirmSheet(context, ref, view);
  }

  /// Выбор поставщика — общей шторкой с поиском: тот же список, что в
  /// оплате по реквизитам, и он приходит из каталога, а не из демо-данных.
  Future<void> _pickProvider() async {
    final picked = await openProviderPicker(
      context,
      ref,
      selectedId: ref.read(connectProvider).providerId,
    );
    if (picked == null || !mounted) return;
    ref.read(connectProvider.notifier).pickProvider(picked.id);
  }

  // ───────────────────────── сборка ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = ref.watch(connectProvider);
    final bills = ref.watch(billsProvider);
    final objects = bills.value?.objects ?? const <PayObject>[];

    // «Подключить ещё счёт» на экране итога возвращает мастер в начало —
    // поле номера не должно хранить прошлый ввод.
    ref.listen(connectProvider, (previous, next) {
      if (previous?.step != ConnectStep.form && next.step == ConnectStep.form) {
        _account.clear();
      }
    });

    final outcome = state.outcome;
    // Заголовок не должен спорить с итогом: «Счёт подключён» при частичном
    // успехе — ровно то вранье, из-за которого упавший счёт и не замечали.
    final doneTitle =
        outcome == null || outcome.isPartial ? s.connectTitle : s.connectedOk;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (state.step) {
          ConnectStep.preview => s.previewTitle,
          ConnectStep.done => doneTitle,
          _ => s.connectTitle,
        }),
        // С предпросмотра «назад» возвращает к найденному, а не закрывает
        // мастер: иначе один промах по стрелке стоит всего ввода.
        leading: state.step == ConnectStep.preview
            ? IconButton(
                tooltip: s.back,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: ref.read(connectProvider.notifier).backToResults,
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: switch (state.step) {
          // Счёт подключается К ОБЪЕКТУ: без объектов мастер бессмысленен,
          // и раньше подключение в этом случае молча выходило из метода.
          _ when bills.hasValue && objects.isEmpty => _noObjects(s),
          ConnectStep.done => ConnectResultView(
              outcome: outcome ?? const ConnectOutcome(),
              onDone: _done,
            ),
          ConnectStep.preview => ChargesPreviewView(
              preview: state.preview ?? ChargesPreview.empty,
              onBack: ref.read(connectProvider.notifier).backToResults,
              onConnect: _connect,
            ),
          _ => _form(s, state, objects),
        },
      ),
    );
  }

  Widget _noObjects(S s) => ListView(
        padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 24),
        children: [
          AppCard(
            child: EmptyState(
              icon: Icons.home_work_outlined,
              title: s.noObjectsTitle,
              lead: s.noObjectsLead,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.push('/objects'),
            child: Text(s.createObjectAction),
          ),
        ],
      );

  Widget _form(S s, ConnectState state, List<PayObject> objects) {
    final showResults = state.step == ConnectStep.results;
    // Ошибку поля показываем под полем; плашку — только когда ошибка
    // не привязана ни к одному полю формы.
    final showErrorView = state.failure != null && state.fieldErrors.isEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
            children: [
              Text(s.connectLead, style: context.t.bodyMedium?.copyWith(height: 1.45)),
              const SizedBox(height: 16),
              _ModeSwitch(
                byAddress: state.byAddress,
                onChanged: (v) => ref.read(connectProvider.notifier).setMode(byAddress: v),
              ),
              const SizedBox(height: 18),
              if (state.byAddress)
                ..._addressForm(s, state)
              else
                ..._accountForm(s, state),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: state.searching ? null : _search,
                child: state.searching
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Brand.onPrimary))
                    : Text(s.searchAction),
              ),
              if (showErrorView) ...[
                const SizedBox(height: 16),
                ErrorView(failure: state.failure!, compact: true, onRetry: _search),
              ],
              if (state.step != ConnectStep.form) ...[
                const SizedBox(height: 22),
                _Results(
                  state: state,
                  objects: objects,
                  onOpenConnected: _openConnected,
                  onConfirm: _confirmOne,
                ),
              ],
            ],
          ),
        ),
        if (showResults && state.selectable.isNotEmpty) _bottomBar(s, state, objects),
      ],
    );
  }

  Widget _bottomBar(S s, ConnectState state, List<PayObject> objects) {
    final notifier = ref.read(connectProvider.notifier);
    final count = state.selected.length;
    final busy = state.connecting;
    final enabled = !busy && count > 0;
    // Объект не выбран, а объектов несколько — говорим об этом рядом с
    // кнопкой, а не отключаем её молча.
    final needObject = (state.objectId ?? state.suggestedObjectId) == null && objects.length > 1;

    return AppBottomBar(
      label: s.selectedOf(count, state.selectable.length),
      amount: state.selectedSum > 0 ? som(state.selectedSum) : null,
      amountSize: 18,
      note: needObject ? Tip(s.chooseObject, tone: ChipTone.warn) : null,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Главное действие — сначала показать, ЧТО будет приходить.
          FilledButton(
            onPressed: enabled ? () => notifier.preview(null) : null,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Brand.onPrimary))
                : Text(s.previewAction),
          ),
          TextButton(
            onPressed: enabled ? _connect : null,
            child: Text(count > 1 ? '${s.connectSelected} · $count' : s.connectOne),
          ),
        ],
      ),
    );
  }

  List<Widget> _accountForm(S s, ConnectState state) {
    final catalog = ref.watch(catalogNowProvider);
    final provider =
        state.providerId == null ? null : catalog.providerById(state.providerId!);
    final cat = ServiceCat.parse(provider?.cat);
    final hint = provider?.mask.hint ?? '';

    return [
      AppCard(
        margin: EdgeInsets.zero,
        child: AppRow(
          leading: CatTile(cat.token, iconOf(cat), size: 42, radius: 12, soft: true),
          title: provider == null ? s.chooseProvider : s.tr(provider.title),
          subtitle: provider == null ? s.providerSearchHint : s.tr(provider.subtitle),
          chevron: true,
          onTap: _pickProvider,
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _account,
        autofocus: provider != null,
        decoration: InputDecoration(
          labelText: provider == null ? s.accountNumber : s.tr(provider.accountLabel),
          hintText: hint.isEmpty ? s.searchAccountHint : hint,
          prefixIcon: const Icon(Icons.tag_rounded),
          errorText: _accountError(s, state, hint),
        ),
        onSubmitted: (_) => _search(),
      ),
      const SizedBox(height: 12),
      Tip(s.findByAccountLead),
    ];
  }

  List<Widget> _addressForm(S s, ConnectState state) {
    // У города нет поля ввода, поэтому его ошибка идёт плашкой под чипами:
    // иначе она не видна нигде и поиск «ничего не делает».
    final cityError = _fieldError(s, state, 'city');
    return [
      Text(s.cityLabel2, style: context.t.labelSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final city in Registry.cities)
            ChoiceChip(
              label: Text(city),
              selected: _city == city,
              showCheckmark: false,
              onSelected: (_) => setState(() => _city = city),
            ),
        ],
      ),
      if (cityError != null) ...[
        const SizedBox(height: 10),
        Tip(cityError, icon: Icons.error_outline_rounded, tone: ChipTone.bad),
      ],
      const SizedBox(height: 14),
      TextField(
        controller: _street,
        decoration: InputDecoration(
          labelText: s.streetLabel,
          errorText: _fieldError(s, state, 'street'),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _house,
              decoration: InputDecoration(
                labelText: s.houseLabel,
                errorText: _fieldError(s, state, 'house'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _flat,
              decoration: InputDecoration(labelText: s.flatLabel),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Tip(s.findByAddressLead),
    ];
  }

  /// Текст ошибки поля. Берётся из failure_text по типу ошибки, а не
  /// из технического сообщения, которое прислал источник.
  String? _fieldError(S s, ConnectState state, String field) {
    if (!state.fieldErrors.containsKey(field)) return null;
    final failure = state.failure;
    if (failure == null) return s.errorValidation;
    return failureFieldText(s, failure, field) ?? failureTitle(s, failure);
  }

  /// У номера счёта есть что подсказать: образец формата поставщика
  /// полезнее общего «проверьте номер».
  String? _accountError(S s, ConnectState state, String maskHint) {
    final text = _fieldError(s, state, ConnectRules.fieldAccountNo);
    if (text == null) return null;
    return maskHint.isEmpty ? text : s.accountNoFormat(maskHint);
  }
}

/// Переключатель способа поиска.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.byAddress, required this.onChanged});
  final bool byAddress;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;

    Widget item(String text, IconData icon, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: Brand.ink.withValues(alpha: .08),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 17,
                      color: selected ? Theme.of(context).colorScheme.onSurface : c.muted),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : c.muted,
                        )),
                  ),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.line2, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          item(s.findByAccount, Icons.tag_rounded, !byAddress, () => onChanged(false)),
          item(s.findByAddress, Icons.place_outlined, byAddress, () => onChanged(true)),
        ],
      ),
    );
  }
}

/// Найденное: что подключим, что уже подключено, что требует кода.
class _Results extends ConsumerWidget {
  const _Results({
    required this.state,
    required this.objects,
    required this.onOpenConnected,
    required this.onConfirm,
  });

  final ConnectState state;
  final List<PayObject> objects;
  final ValueChanged<CandidateView> onOpenConnected;
  final ValueChanged<CandidateView> onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final notifier = ref.read(connectProvider.notifier);

    if (state.views.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: s.foundNothing,
          lead: s.foundNothingLead,
        ),
      );
    }

    final allSelected =
        state.selectable.isNotEmpty && state.selected.length == state.selectable.length;
    final objectId = state.objectId ?? state.suggestedObjectId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.foundAccounts(state.views.length), style: context.t.titleLarge),
            ),
            if (state.selectable.isNotEmpty)
              TextButton(
                onPressed: allSelected ? notifier.selectNone : notifier.selectAll,
                child: Text(allSelected ? s.selectNone : s.selectAll),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < state.views.length; i++) ...[
                if (i > 0) const RowDivider(indent: 16),
                CandidateTile(
                  view: state.views[i],
                  selected: state.selected.contains(state.views[i].id),
                  busy: state.confirming.contains(state.views[i].id),
                  onToggle: state.views[i].selectable
                      ? () => notifier.toggle(state.views[i].id)
                      : null,
                  onTap: _tapOf(state.views[i], notifier),
                ),
              ],
            ],
          ),
        ),
        if (objects.length > 1 && state.selectable.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(s.chooseObject, style: context.t.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final o in objects)
                ChoiceChip(
                  label: Text(s.tr(o.name)),
                  selected: objectId == o.id,
                  showCheckmark: false,
                  onSelected: (_) => notifier.pickObject(o.id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Что делает тап по строке: ведёт на подключённый счёт, просит код
  /// или открывает предпросмотр начислений.
  VoidCallback? _tapOf(CandidateView view, ConnectNotifier notifier) =>
      switch (view.reason) {
        ConnectBlock.alreadyConnected => () => onOpenConnected(view),
        ConnectBlock.needsConfirm => () => onConfirm(view),
        ConnectBlock.closedByProvider => null,
        ConnectBlock.unknownProvider => null,
        null => () => notifier.preview(view),
      };
}
