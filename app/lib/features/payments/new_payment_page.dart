import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';
import 'method_picker.dart';
import 'pay_flow.dart';
import 'payments_page.dart' show NewPaymentArgs;

/// Новая оплата: получатель → лицевой счёт и сумма → проверка и оплата.
class NewPaymentPage extends ConsumerStatefulWidget {
  const NewPaymentPage({super.key, this.args});
  final NewPaymentArgs? args;

  @override
  ConsumerState<NewPaymentPage> createState() => _NewPaymentPageState();
}

class _NewPaymentPageState extends ConsumerState<NewPaymentPage> {
  late final TextEditingController _search = TextEditingController();
  late final TextEditingController _account = TextEditingController(text: widget.args?.account ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.args?.amount != null ? som(widget.args!.amount!) : '');

  ProviderItem? _provider;
  int _step = 0;
  bool _busy = false;
  String? _accountError, _amountError;

  @override
  void initState() {
    super.initState();
    final id = widget.args?.providerId;
    if (id != null) {
      _provider = Demo.providerById(id);
      if (_provider != null) {
        _step = widget.args?.amount != null ? 2 : 1;
        if (_amount.text.isEmpty && _provider!.fixedAmount != null) {
          _amount.text = som(_provider!.fixedAmount!);
        }
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _sum =>
      double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.')) ?? 0;

  void _pick(ProviderItem p) {
    setState(() {
      _provider = p;
      _step = 1;
      if (p.fixedAmount != null && _amount.text.isEmpty) _amount.text = som(p.fixedAmount!);
    });
  }

  void _check() {
    final s = S.of(context);
    final acc = _account.text.trim();
    setState(() {
      _accountError = acc.length < 4 ? s.accountError : null;
      _amountError = (_sum < 1 || _sum > 100000) ? s.amountError : null;
    });
    if (_accountError == null && _amountError == null) setState(() => _step = 2);
  }

  Future<void> _pay() async {
    final p = _provider!;
    setState(() => _busy = true);
    final now = DateTime.now();
    final no = await payAndFinish(
      context,
      ref,
      bills: const [],
      records: [
        Payment(
          id: 'np-${now.millisecondsSinceEpoch}',
          title: p.title,
          cat: p.cat,
          amount: _sum,
          date: now,
          methodId: '',
          receiptNo: '',
          account: _account.text.trim(),
          period: '${monthName(now.month)} ${now.year}',
        ),
      ],
      amount: _sum,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (no == null) return;
    goSuccess(context, _sum, 1, no);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          0 => s.chooseProvider,
          1 => s.newPayment,
          _ => s.confirmTitle,
        }),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 0 || (widget.args?.providerId != null && _step <= 1)) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (_step) {
          0 => _stepProviders(),
          1 => _stepForm(),
          _ => _stepConfirm(),
        },
      ),
    );
  }

  // ── шаг 1: получатель ────────────────────────────────────────────
  Widget _stepProviders() {
    final s = S.of(context);
    final catId = widget.args?.categoryId;
    final q = _search.text.trim().toLowerCase();
    final list = Demo.providers.where((p) {
      if (catId != null && p.categoryId != catId) return false;
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) || p.subtitle.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 24),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: s.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(icon: Icons.search_off_rounded, title: s.nothingFound)
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  AppRow(
                    leading: CatTile(list[i].cat, catIcon(list[i].cat), soft: true),
                    title: list[i].title,
                    subtitle: list[i].subtitle,
                    chevron: true,
                    onTap: () => _pick(list[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ── шаг 2: счёт и сумма ──────────────────────────────────────────
  Widget _stepForm() {
    final s = S.of(context);
    final p = _provider!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 24),
      children: [
        AppCard(
          child: AppRow(
            leading: CatTile(p.cat, catIcon(p.cat), soft: true),
            title: p.title,
            subtitle: p.subtitle,
            trailing: TextButton(
              onPressed: () => setState(() => _step = 0),
              child: Text(s.editWord),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _account,
          decoration: InputDecoration(
            labelText: p.accountLabel,
            hintText: p.accountHint,
            errorText: _accountError,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: s.amountLabel,
            suffixText: s.som,
            errorText: _amountError,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _check, child: Text(s.checkAccount)),
        const SizedBox(height: 14),
        Tip(s.newPaymentHint),
      ],
    );
  }

  // ── шаг 3: проверка и оплата ─────────────────────────────────────
  Widget _stepConfirm() {
    final s = S.of(context);
    final p = _provider!;
    final method = methodById(ref, ref.watch(payMethodProvider));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 16),
            children: [
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  children: [
                    CatTile(p.cat, catIcon(p.cat), size: 52, radius: 15),
                    const SizedBox(height: 10),
                    Text(p.title, style: context.t.titleLarge),
                    const SizedBox(height: 2),
                    Text('${p.accountLabel} · ${_account.text.trim()}',
                        style: context.t.bodySmall),
                    const SizedBox(height: 14),
                    Amount(som(_sum), size: 30),
                  ],
                ),
              ),
              SectionTitle(s.requisites),
              KeyValueBox([for (final f in p.requisites) (f.label, f.value)]),
              SectionTitle(s.payMethod),
              MethodTile(
                item: method,
                selected: false,
                showRadio: false,
                onTap: () async {
                  await openMethodPicker(context, ref);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
            ],
          ),
        ),
        _BottomBar(
          total: _sum,
          busy: _busy,
          onPay: _pay,
        ),
      ],
    );
  }
}

/// Нижняя панель с итогом и кнопкой оплаты — общая для экранов оплаты.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.total, required this.busy, required this.onPay});
  final double total;
  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(
          Brand.gutter, 12, Brand.gutter, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: c.line2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.total, style: context.t.titleMedium)),
              Amount(som(total), size: 22),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : onPay,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.onPrimary))
                : Text('${s.pay} ${som(total)} ${s.som}'),
          ),
        ],
      ),
    );
  }
}
