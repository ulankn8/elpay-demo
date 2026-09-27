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
import 'pay_sheet.dart';
import 'service_row.dart';

/// Аргументы экрана: можно открыть сразу на поставщике, на категории
/// или с уже распознанной квитанции (QR). `connect` — режим подключения счёта.
class NewPaymentArgs {
  const NewPaymentArgs({
    this.categoryId,
    this.providerId,
    this.account,
    this.amount,
    this.connect = false,
  });
  final String? categoryId, providerId, account;
  final double? amount;
  final bool connect;
}

/// Новая оплата: выбор услуги значками → реквизиты и сумма → оплата.
class NewPaymentPage extends ConsumerStatefulWidget {
  const NewPaymentPage({super.key, this.args});
  final NewPaymentArgs? args;

  @override
  ConsumerState<NewPaymentPage> createState() => _NewPaymentPageState();
}

class _NewPaymentPageState extends ConsumerState<NewPaymentPage> {
  late final _account = TextEditingController(text: widget.args?.account ?? '');
  late final _amount = TextEditingController(
      text: widget.args?.amount != null ? som(widget.args!.amount!) : '');

  ProviderItem? _provider;
  String? _objectId;
  late bool _save = widget.args?.connect ?? false;
  String? _accountError, _amountError;

  bool get _connect => widget.args?.connect ?? false;

  @override
  void initState() {
    super.initState();
    final id = widget.args?.providerId;
    if (id != null) {
      _provider = Demo.providerById(id);
      if (_provider?.fixedAmount != null && _amount.text.isEmpty) {
        _amount.text = som(_provider!.fixedAmount!);
      }
    }
  }

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _sum =>
      double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.')) ?? 0;

  void _pick(ProviderItem p) {
    setState(() {
      _provider = p;
      if (p.fixedAmount != null && _amount.text.isEmpty) _amount.text = som(p.fixedAmount!);
    });
  }

  bool _validate({bool needAmount = true}) {
    final s = S.of(context);
    final acc = _account.text.trim();
    setState(() {
      _accountError = acc.length < 4 ? s.accountError : null;
      _amountError = needAmount && (_sum < 1 || _sum > 100000) ? s.amountError : null;
    });
    return _accountError == null && _amountError == null;
  }

  /// Подключить счёт: реквизиты сохраняются, начисление появится в объекте.
  void _connectAccount() {
    if (!_validate(needAmount: false)) return;
    final s = S.of(context);
    final saved = _saveBill();
    if (saved == null) return;
    showAppSnack(context, s.accountAdded);
    Navigator.of(context).pop();
  }

  Bill? _saveBill() {
    final p = _provider;
    final objects = ref.read(billsProvider).value?.objects ?? const <PayObject>[];
    if (p == null || objects.isEmpty) return null;
    final now = DateTime.now();
    final acc = _account.text.trim();
    final bill = Bill(
      id: 'b-${now.millisecondsSinceEpoch}',
      title: p.title,
      subtitle: p.subtitle,
      cat: p.cat,
      amount: _sum > 0 ? _sum : (p.fixedAmount ?? 0),
      objectId: _objectId ?? objects.first.id,
      period: '${monthName(now.month)} ${now.year}',
      due: DateTime(now.year, now.month, 25),
      account: acc,
      requisites: [...p.requisites, ...Demo.bank, Field('Лицевой счёт', acc)],
    );
    ref.read(billsProvider.notifier).addBill(bill);
    return bill;
  }

  void _pay() {
    if (!_validate()) return;
    final p = _provider!;
    final now = DateTime.now();
    if (_save) _saveBill();
    openPaySheet(
      context,
      ref,
      amount: _sum,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final picking = _provider == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(picking
            ? s.whatPaying
            : _connect
                ? s.connectAccount
                : s.newPayment),
      ),
      body: SafeArea(
        top: false,
        child: picking ? _stepServices() : _stepForm(),
      ),
    );
  }

  // ── шаг 1: услуга значками ───────────────────────────────────────
  Widget _stepServices() {
    final s = S.of(context);
    final catId = widget.args?.categoryId;
    final services = catId == null
        ? Demo.quickServices
        : Demo.quickServices
            .where((q) => Demo.providerById(q.providerId)?.categoryId == catId)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 18),
          child: Text(s.whatPayingLead, style: context.t.bodyMedium?.copyWith(height: 1.45)),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 8,
          childAspectRatio: .92,
          children: [
            for (final q in services)
              ServiceIcon(
                service: q,
                size: 62,
                onTap: () {
                  final p = Demo.providerById(q.providerId);
                  if (p != null) _pick(p);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          child: AppRow(
            leading: CatTile('tax', Icons.receipt_long_outlined, soft: true),
            title: s.otherRecipient,
            subtitle: s.otherRecipientLead,
            chevron: true,
            onTap: () {
              final p = Demo.providerById('p-tax');
              if (p != null) _pick(p);
            },
          ),
        ),
      ],
    );
  }

  // ── шаг 2: реквизиты и сумма ─────────────────────────────────────
  Widget _stepForm() {
    final s = S.of(context);
    final p = _provider!;
    final objects = ref.watch(billsProvider).value?.objects ?? const <PayObject>[];
    final objectId = _objectId ?? (objects.isEmpty ? '' : objects.first.id);
    final objectName = objects
        .where((o) => o.id == objectId)
        .map((o) => s.tr(o.name))
        .firstOrNull ??
        '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 20),
            children: [
              AppCard(
                child: AppRow(
                  leading: CatTile(p.cat, catIcon(p.cat), soft: true),
                  title: s.tr(p.title),
                  subtitle: s.tr(p.subtitle),
                  trailing: widget.args?.providerId != null
                      ? null
                      : TextButton(
                          onPressed: () => setState(() => _provider = null),
                          child: Text(s.editWord),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _account,
                decoration: InputDecoration(
                  labelText: s.tr(p.accountLabel),
                  hintText: p.accountHint,
                  errorText: _accountError,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.amountSom,
                  errorText: _amountError,
                ),
              ),
              const SizedBox(height: 16),
              Tip(s.newPaymentHint),
              if (!_connect && objects.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SaveRow(
                  on: _save,
                  title: s.saveAsMine,
                  lead: s.saveAsMineLead(objectName),
                  onTap: () => setState(() => _save = !_save),
                ),
              ],
              if (_save || _connect) ...[
                const SizedBox(height: 14),
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
                        onSelected: (_) => setState(() => _objectId = o.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              Brand.gutter, 12, Brand.gutter, MediaQuery.of(context).padding.bottom + 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: context.c.line2)),
          ),
          child: _connect
              ? FilledButton(onPressed: _connectAccount, child: Text(s.connectAccount))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.toPayShort, style: context.t.titleMedium)),
                        if (_sum > 0)
                          Amount(som(_sum), size: 22)
                        else
                          Text('—',
                              style: context.t.titleLarge?.copyWith(color: context.c.muted2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _pay, child: Text(s.cont)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Строка с галочкой «сохранить как мой счёт».
class _SaveRow extends StatelessWidget {
  const _SaveRow({
    required this.on,
    required this.title,
    required this.lead,
    required this.onTap,
  });
  final bool on;
  final String title, lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? Brand.primary : c.line, width: 1.5),
          color: on ? Brand.light2.withValues(alpha: .5) : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: on ? Brand.primary : Colors.transparent,
                border: Border.all(color: on ? Brand.primary : c.muted2, width: 1.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: on
                  ? const Icon(Icons.check_rounded, size: 16, color: Brand.onPrimary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.t.titleMedium?.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(lead, style: context.t.bodySmall?.copyWith(height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
