import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/failure_text.dart';
import '../../core/l10n/s.dart';
import '../../core/service_cat.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/connect_rules.dart';
import '../../state/providers.dart';

/// Счёт оформлен на другого человека — просим код из квитанции или SMS.
///
/// Возвращает true, если владение подтвердили. false (в том числе при
/// закрытии шторки) ПРЕРЫВАЕТ всю операцию подключения: лучше ничего не
/// подключить, чем подключить половину выбранного молча.
Future<bool> openConfirmSheet(
  BuildContext context,
  WidgetRef ref,
  CandidateView view,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ConfirmSheet(view: view),
  );
  return result ?? false;
}

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.view});
  final CandidateView view;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(connectProvider.notifier)
        .confirm(widget.view.id, _code.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (_) => Navigator.pop(context, true),
      // Неверный код подсвечивает ПОЛЕ, а не показывает снек: пользователь
      // видит ошибку там, где ошибся, и список за шторкой остаётся живым.
      (failure) => setState(() =>
          _error = failureFieldText(s, failure, 'code') ?? failureTitle(s, failure)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = widget.view.candidate;
    final cat = ServiceCat.parse(c.cat);

    return AppSheet(
      title: s.confirmOwnership,
      lead: s.confirmOwnershipLead,
      header: Row(
        children: [
          CatTile(cat.token, iconOf(cat), size: 46, radius: 13, soft: true),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tr(c.providerTitle), style: context.t.titleMedium),
                Text('${c.accountNo} · ${c.holder}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall),
              ],
            ),
          ),
        ],
      ),
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 4,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: s.otpTitle,
            hintText: '4815',
            counterText: '',
            errorText: _error,
            helperText: _busy ? s.checkingAccount : null,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Tip(s.otpDemo),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.onPrimary))
              : Text(s.cont),
        ),
      ],
    );
  }
}
