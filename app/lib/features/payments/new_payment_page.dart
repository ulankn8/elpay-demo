import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/failure.dart';
import '../../core/format.dart';
import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../accounts/connect_args.dart';
import '../bills/bill_row.dart';
import 'pay_sheet.dart';
import 'provider_picker.dart';
import 'service_row.dart';

/// Аргументы экрана: можно открыть сразу на поставщике, на категории
/// или с уже распознанной квитанции (QR).
///
/// Режима `connect` здесь больше нет: разовая оплата счёт не подключает —
/// подключение живёт в одном месте, в мастере '/connect'. Раньше это была
/// одна из трёх расходящихся веток подключения, и именно в ней
/// `_connectAccount()` молча выходил из метода, если у пользователя не было
/// ни одного объекта: ни снека, ни ошибки, ни подсказки.
class NewPaymentArgs {
  const NewPaymentArgs({
    this.categoryId,
    this.providerId,
    this.account,
    this.amount,
  });
  final String? categoryId, providerId, account;
  final double? amount;
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
  String? _accountError, _amountError;

  @override
  void initState() {
    super.initState();
    final id = widget.args?.providerId;
    // Поставщик берётся из каталога: он читается синхронно, поэтому экран
    // открывается сразу на форме, а не ждёт загрузки.
    if (id != null) _pickSilently(ref.read(catalogNowProvider).providerById(id));
  }

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _sum => double.tryParse(
          _amount.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.')) ??
      0;

  AccountMask get _mask => _provider?.mask ?? AccountMask.any;

  void _pickSilently(ProviderItem? p) {
    if (p == null) return;
    _provider = p;
    if (p.fixedAmount != null && _amount.text.isEmpty) {
      _amount.text = som(p.fixedAmount!);
    }
  }

  void _pick(ProviderItem p) => setState(() {
        _pickSilently(p);
        // Старая ошибка номера относилась к прошлому поставщику: у нового
        // другая маска, и держать её под полем нельзя.
        _accountError = null;
      });

  /// Выбор получателя с поиском — вместо плоской сетки из девяти значков
  /// и захардкоженного 'p-tax' за строкой «другой получатель».
  Future<void> _openPicker({String? categoryId}) async {
    final picked = await openProviderPicker(
      context,
      ref,
      categoryId: categoryId,
      selectedId: _provider?.id,
    );
    if (picked != null && mounted) _pick(picked);
  }

  bool _validate() {
    final s = S.of(context);
    final acc = _account.text.trim();
    // Номер проверяется по маске поставщика, а не по «не короче четырёх»:
    // формат лицевого счёта принадлежит поставщику, и ошибка садится
    // в errorText поля, а не в снек.
    final accFail = _mask.matches(acc)
        ? null
        : AppFailure(FailureKind.validation,
            message: 'номер не прошёл маску', field: 'accountNo', code: _mask.hint);
    setState(() {
      _accountError = accFail == null ? null : failureFieldText(s, accFail, 'accountNo');
      _amountError = _sum < 1 || _sum > 100000 ? s.amountError : null;
    });
    return _accountError == null && _amountError == null;
  }

  void _pay() {
    if (!_validate()) return;
    final p = _provider!;
    // «Сейчас» из clockProvider: в тестах часы стоят, и дата платежа
    // не зависит от дня запуска.
    final now = ref.read(clockProvider)();
    // Номер приводится к каноническому виду поставщика ('3101187' →
    // '31-01187') — в квитанцию и историю уходит он, а не то, как напечатали.
    final acc = _mask.normalize(_account.text);
    _account.text = acc;
    openPaySheet(
      context,
      ref,
      amount: _sum,
      bills: const [],
      records: [
        Payment(
          // id выдаёт IdGen, а не 'np-${millisecondsSinceEpoch}': такие id
          // совпадают в пределах миллисекунды и спорят с серверными.
          id: ref.read(idGenProvider).local('payment'),
          title: p.title,
          cat: p.cat,
          amount: _sum,
          date: now,
          methodId: '',
          receiptNo: '',
          account: acc,
          period: '${monthName(now.month)} ${now.year}',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final catalog = ref.watch(catalogNowProvider);
    final picking = _provider == null;
    return Scaffold(
      appBar: AppBar(title: Text(picking ? s.whatPaying : s.newPayment)),
      body: SafeArea(
        top: false,
        child: picking ? _stepServices(catalog) : _stepForm(),
      ),
    );
  }

  // ── шаг 1: услуга значками ───────────────────────────────────────
  Widget _stepServices(Catalog catalog) {
    final s = S.of(context);
    final catId = widget.args?.categoryId;
    final services = catalog.quickFor(catId);

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
                  final p = catalog.providerById(q.providerId);
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
            onTap: () => _openPicker(categoryId: catId),
          ),
        ),
      ],
    );
  }

  // ── шаг 2: реквизиты и сумма ─────────────────────────────────────
  Widget _stepForm() {
    final s = S.of(context);
    final p = _provider!;

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
                  trailing: TextButton(
                    onPressed: _openPicker,
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
              const SizedBox(height: 18),
              // Вместо галочки «сохранить как мой счёт»: разовая оплата
              // ничего не подключает, а подключение — это мастер '/connect',
              // который найдёт счёт у поставщика и покажет начисления.
              AppCard(
                child: AppRow(
                  leading: CatTile('paid', Icons.bookmark_added_outlined, soft: true),
                  title: s.connectAccount,
                  subtitle: s.connectAccountLead,
                  chevron: true,
                  // source оставлен 'manual': реквизиты пользователь ввёл
                  // руками, отдельного источника 'payment' в ConnectArgs нет.
                  onTap: () => context.push(ConnectArgs(providerId: p.id).location),
                ),
              ),
            ],
          ),
        ),
        // Итог слушает само поле суммы: иначе «К оплате» прямо над кнопкой
        // оплаты показывает сумму, с которой экран открыли (из QR — 205),
        // или «—» при ручном вводе, и обновляется только по «Продолжить».
        // Слушателем перестраивается одна панель, а не весь список формы.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _amount,
          builder: (_, _, _) => AppBottomBar(
            label: s.toPayShort,
            amount: _sum > 0 ? som(_sum) : '—',
            action: FilledButton(onPressed: _pay, child: Text(s.cont)),
          ),
        ),
      ],
    );
  }
}
