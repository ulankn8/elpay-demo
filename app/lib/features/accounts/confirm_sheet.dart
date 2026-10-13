import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/failure.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Счёт оформлен на другого человека — просим код из квитанции.
/// Возвращает true, если подтвердили.
Future<bool> openConfirmSheet(
  BuildContext context,
  WidgetRef ref,
  AccountCandidate candidate,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ConfirmSheet(candidate: candidate),
  );
  return result ?? false;
}

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.candidate});
  final AccountCandidate candidate;

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
        .confirm(widget.candidate.id, _code.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (_) => Navigator.pop(context, true),
      (failure) => setState(() => _error = failure.kind == FailureKind.validation
          ? s.otpWrong
          : ErrorView.titleFor(context, failure)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = widget.candidate;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 6, Brand.gutter, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CatTile(c.cat, catIcon(c.cat), size: 46, radius: 13, soft: true),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.of(context).tr(c.providerTitle),
                            style: context.t.titleMedium),
                        Text('${c.accountNo} · ${c.holder}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(s.confirmOwnership, style: context.t.headlineSmall),
              const SizedBox(height: 6),
              Text(s.confirmOwnershipLead, style: context.t.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: s.otpTitle,
                  hintText: '4815',
                  counterText: '',
                  errorText: _error,
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Brand.onPrimary))
                    : Text(s.cont),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
