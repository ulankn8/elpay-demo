import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/registry_data.dart';
import '../../state/providers.dart';
import 'candidate_tile.dart';
import 'confirm_sheet.dart';

/// Подключение счёта: ищем по лицевому счёту или по адресу,
/// показываем найденное и подключаем выбранное к объекту.
class ConnectAccountPage extends ConsumerStatefulWidget {
  const ConnectAccountPage({super.key, this.providerId});

  /// Если пришли со значка услуги — ищем только по этому поставщику.
  final String? providerId;

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
  String? _objectId;

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

  void _search() {
    final state = ref.read(connectProvider);
    final notifier = ref.read(connectProvider.notifier);
    FocusScope.of(context).unfocus();

    // После ответа прокручиваем к найденному, чтобы форма не закрывала список.
    void scrollToResults() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }

    if (state.byAddress) {
      notifier
          .search(AccountQuery.byAddress(
            city: _city,
            street: _street.text.trim(),
            house: _house.text.trim(),
            flat: _flat.text.trim(),
          ))
          .then((_) => scrollToResults());
    } else {
      notifier
          .search(AccountQuery.byAccount(
            _account.text.trim(),
            providerId: widget.providerId,
          ))
          .then((_) => scrollToResults());
    }
  }

  Future<void> _connect() async {
    final s = S.of(context);
    final objects = ref.read(billsProvider).value?.objects ?? const <PayObject>[];
    final objectId = _objectId ?? (objects.isEmpty ? '' : objects.first.id);

    // Счета на чужое имя сначала подтверждаем кодом.
    final state = ref.read(connectProvider);
    final needConfirm = state.found
        .where((c) => state.selected.contains(c.id) && c.needsConfirm)
        .toList();
    for (final candidate in needConfirm) {
      final ok = await openConfirmSheet(context, ref, candidate);
      if (!ok) return;
    }

    final count = await ref.read(connectProvider.notifier).connectSelected(objectId);
    if (!mounted) return;
    if (count > 0) {
      showAppSnack(context, s.connectedCount(count));
    } else {
      final failure = ref.read(connectProvider).failure;
      showAppSnack(context, failure == null ? s.errorUnknown : ErrorView.titleFor(context, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = ref.watch(connectProvider);
    final objects = ref.watch(billsProvider).value?.objects ?? const <PayObject>[];
    final objectId = _objectId ?? (objects.isEmpty ? '' : objects.first.id);

    return Scaffold(
      appBar: AppBar(title: Text(s.connectTitle)),
      body: SafeArea(
        top: false,
        child: Column(
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
                    onChanged: (v) {
                      ref.read(connectProvider.notifier).setMode(byAddress: v);
                    },
                  ),
                  const SizedBox(height: 18),
                  if (state.byAddress) ..._addressForm(s) else ..._accountForm(s),
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
                  if (state.failure != null) ...[
                    const SizedBox(height: 16),
                    ErrorView(failure: state.failure!, compact: true, onRetry: _search),
                  ],
                  if (state.step != ConnectStep.form) ...[
                    const SizedBox(height: 22),
                    _Results(
                      state: state,
                      objects: objects,
                      objectId: objectId,
                      onObject: (id) => setState(() => _objectId = id),
                    ),
                  ],
                ],
              ),
            ),
            if (state.step == ConnectStep.results && state.selectable.isNotEmpty)
              _BottomBar(
                count: state.selected.length,
                sum: state.selectedSum,
                busy: state.connecting,
                onPay: _connect,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountForm(S s) => [
        TextField(
          controller: _account,
          autofocus: true,
          decoration: InputDecoration(
            labelText: s.accountNumber,
            hintText: s.searchAccountHint,
            prefixIcon: const Icon(Icons.tag_rounded),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        Tip(s.findByAccountLead),
      ];

  List<Widget> _addressForm(S s) => [
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
        const SizedBox(height: 14),
        TextField(
          controller: _street,
          decoration: InputDecoration(labelText: s.streetLabel),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _house,
                decoration: InputDecoration(labelText: s.houseLabel),
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

/// Найденные счета: выбор галочками и выбор объекта.
class _Results extends ConsumerWidget {
  const _Results({
    required this.state,
    required this.objects,
    required this.objectId,
    required this.onObject,
  });

  final ConnectState state;
  final List<PayObject> objects;
  final String objectId;
  final ValueChanged<String> onObject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    if (state.found.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: s.foundNothing,
          lead: s.foundNothingLead,
        ),
      );
    }

    final notifier = ref.read(connectProvider.notifier);
    final allSelected = state.selected.length == state.selectable.length &&
        state.selectable.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.foundAccounts(state.found.length), style: context.t.titleLarge),
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
              for (var i = 0; i < state.found.length; i++) ...[
                if (i > 0) const RowDivider(indent: 16),
                CandidateTile(
                  candidate: state.found[i],
                  selected: state.selected.contains(state.found[i].id),
                  onToggle: () => notifier.toggle(state.found[i].id),
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
                  onSelected: (_) => onObject(o.id),
                ),
            ],
          ),
        ],
        if (state.step == ConnectStep.done) ...[
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              children: [
                CatTile('paid', Icons.check_rounded, size: 52, radius: 15),
                const SizedBox(height: 10),
                Text(s.connectedCount(state.connected.length),
                    style: context.t.titleLarge),
                const SizedBox(height: 4),
                Text(s.syncOk, style: context.t.bodySmall),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.sum,
    required this.busy,
    required this.onPay,
  });
  final int count;
  final double sum;
  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          Brand.gutter, 12, Brand.gutter, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.c.line2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sum > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: Text(s.chargedTotal, style: context.t.bodyMedium)),
                  Amount(som(sum), size: 18),
                ],
              ),
            ),
          FilledButton(
            onPressed: count == 0 || busy ? null : onPay,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.onPrimary))
                : Text(count > 1 ? '${s.connectSelected} · $count' : s.connectOne),
          ),
        ],
      ),
    );
  }
}
