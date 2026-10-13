import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../accounts/connect_args.dart';
import '../bills/bill_row.dart';
import '../payments/pay_flow.dart';
import '../payments/pay_sheet.dart';

/// Экран объекта: все его счета с галочками. У каждой услуги своя кнопка,
/// внизу — оплата всех выбранных одной суммой.
class ObjectPage extends ConsumerStatefulWidget {
  const ObjectPage({super.key, required this.objectId});
  final String objectId;

  @override
  ConsumerState<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends ConsumerState<ObjectPage> {
  Set<String>? _selected;

  Set<String> _initial(List<Bill> bills) =>
      bills.where((b) => !b.paid && !b.autopay).map((b) => b.id).toSet();

  /// Выбор по умолчанию ставится один раз — но только когда начисления
  /// уже пришли. Раньше `_selected ??= _initial(bills)` срабатывал на
  /// первой сборке, когда репозиторий ещё читал кэш и список был пуст:
  /// после загрузки все галочки оставались снятыми.
  ///
  /// Исчезнувшие начисления из набора вычищаются: после оплаты одного счёта
  /// он уходит из списка (фильтр `!b.paid`), а его id оставался выбранным —
  /// заголовок показывал «Выбрано 4 из 3», и галочка «выбрать все» гасла,
  /// хотя выбрано было действительно всё.
  Set<String> _selection(List<Bill> bills) {
    final current = _selected;
    if (current == null) {
      if (bills.isEmpty) return const <String>{};
      return _selected = _initial(bills);
    }
    final ids = bills.map((b) => b.id).toSet();
    if (current.any((id) => !ids.contains(id))) {
      return _selected = current.intersection(ids);
    }
    return current;
  }

  void _toggle(String id) => setState(() {
        final next = {...?_selected};
        next.contains(id) ? next.remove(id) : next.add(id);
        _selected = next;
      });

  void _setAll(Set<String> ids) => setState(() => _selected = ids);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final objects = ref.watch(objectsProvider);
    final object = objects.where((o) => o.id == widget.objectId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(object == null ? '' : s.tr(object.name))),
      body: SafeArea(
        top: false,
        // Пока начисления грузятся, экран показывает скелет, а не
        // EmptyState «всё оплачено»: раньше эти 250–350 мс выглядели как
        // честный ответ «платить нечего».
        child: AsyncSection<BillsState>(
          value: ref.watch(billsProvider),
          onRetry: () => ref.read(billsProvider.notifier).refresh(),
          skeleton: const Padding(
            padding: EdgeInsets.fromLTRB(Brand.gutter, 12, Brand.gutter, 20),
            child: LoadingRows(count: 4),
          ),
          data: (state) {
            final bills = state.byObject(widget.objectId).where((b) => !b.paid).toList()
              ..sort((a, b) => a.due.compareTo(b.due));
            return _Content(
              object: object,
              bills: bills,
              selected: _selection(bills),
              onToggle: _toggle,
              onSetAll: _setAll,
            );
          },
        ),
      ),
    );
  }
}

/// Содержимое экрана, когда начисления уже есть: шапка объекта, список
/// счетов с галочками и липкая панель с итогом.
class _Content extends ConsumerWidget {
  const _Content({
    required this.object,
    required this.bills,
    required this.selected,
    required this.onToggle,
    required this.onSetAll,
  });

  final PayObject? object;
  final List<Bill> bills;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onSetAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;

    final chosen = bills.where((b) => selected.contains(b.id)).toList();
    final sum = chosen.fold<double>(0, (a, b) => a + b.amount);
    final total = bills.fold<double>(0, (a, b) => a + b.amount);
    final deadline = bills.isEmpty
        ? null
        : bills.map((b) => b.due).reduce((a, b) => a.isBefore(b) ? a : b);
    final allSelected = bills.isNotEmpty && selected.length == bills.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
            children: [
              if (object != null)
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CatTile(
                            object!.cat,
                            object!.icon == 'users'
                                ? Icons.people_outline_rounded
                                : Icons.home_outlined,
                            size: 40,
                            radius: 12,
                            soft: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(object!.address,
                                maxLines: 2,
                                style: context.t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600, height: 1.35)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.toPayShort,
                                    style:
                                        context.t.labelSmall?.copyWith(color: c.muted)),
                                const SizedBox(height: 2),
                                Amount(som(total), size: 26),
                              ],
                            ),
                          ),
                          if (deadline != null)
                            AppChip('${s.dueBy} ${s.dayMonthText(deadline)}',
                                tone: ChipTone.warn),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Единственный вход в мастер подключения с объекта:
                      // счёт сразу привязывается к нему, искать FAB на
                      // другом экране не нужно.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push(
                            ConnectArgs(
                              objectId: object!.id,
                              source: ConnectArgs.sourceObject,
                            ).location,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(s.connectAccount),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              if (bills.isEmpty)
                AppCard(
                  child: EmptyState(
                      icon: Icons.check_rounded, title: s.allPaid, lead: s.noBillsLead),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Row(
                    children: [
                      AppCheckbox(
                        on: allSelected,
                        onTap: () => onSetAll(
                          allSelected ? <String>{} : bills.map((b) => b.id).toSet(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          allSelected
                              ? '${s.selectedAll} ${s.billsCount(bills.length)}'
                              : s.selectedOf(selected.length, bills.length),
                          style:
                              context.t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onSetAll(
                          selected.isEmpty
                              ? bills.map((b) => b.id).toSet()
                              : <String>{},
                        ),
                        child: Text(selected.isEmpty ? s.selectAll : s.selectNone),
                      ),
                    ],
                  ),
                ),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < bills.length; i++) ...[
                        if (i > 0) const RowDivider(indent: 16),
                        _ObjectBillRow(
                          bill: bills[i],
                          selected: selected.contains(bills[i].id),
                          onToggle: () => onToggle(bills[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (bills.isNotEmpty)
          AppBottomBar(
            label: s.total,
            amount: som(sum),
            action: FilledButton(
              onPressed: chosen.isEmpty
                  ? null
                  : () => openPaySheet(
                        context,
                        ref,
                        amount: sum,
                        bills: chosen,
                        records: recordsFromBills(chosen),
                      ),
              child: Text('${s.payAllSum} · ${som(sum)} ${s.som}'),
            ),
          ),
      ],
    );
  }
}

/// Строка услуги: галочка, сумма справа, срок и своя кнопка «Оплатить».
class _ObjectBillRow extends StatelessWidget {
  const _ObjectBillRow({
    required this.bill,
    required this.selected,
    required this.onToggle,
  });
  final Bill bill;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final due = dueLabel(context, bill);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppCheckbox(on: selected, onTap: onToggle),
          ),
          const SizedBox(width: 12),
          CatTile(bill.cat, catIcon(bill.cat), size: 42, radius: 12, soft: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(s.tr(bill.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.titleMedium),
                    ),
                    const SizedBox(width: 10),
                    Amount(som(bill.amount), size: 15),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${s.tr(bill.subtitle)} · ${bill.account}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: AppChip(
                        // в списке — короткая форма, подробности на карточке счёта
                        due.overdue ? s.overdue : due.text,
                        tone: due.overdue
                            ? ChipTone.bad
                            : due.soon
                                ? ChipTone.warn
                                : ChipTone.soft,
                      ),
                    ),
                    if (bill.autopay) ...[
                      const SizedBox(width: 6),
                      Flexible(child: AppChip(s.autopayTitle, tone: ChipTone.ok)),
                    ],
                    const SizedBox(width: 10),
                    _PayPill(onTap: () => context.push('/bill', extra: bill)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayPill extends StatelessWidget {
  const _PayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFF6FE0BB) : Brand.p700;
    return Material(
      color: dark ? Brand.primary.withValues(alpha: .16) : Brand.light2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Brand.primary.withValues(alpha: .32), width: 1),
          ),
          child: Text(s.pay,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}
