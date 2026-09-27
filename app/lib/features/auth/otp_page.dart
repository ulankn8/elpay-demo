import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../data/auth_repository.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, required this.method, required this.destination});
  final AuthMethod method;
  final String destination;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = 59;
  bool _checking = false;
  bool _ok = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final session = await ref.read(authRepoProvider).verifyCode(
            method: widget.method,
            destination: widget.destination,
            code: code,
          );
      if (!mounted) return;
      setState(() => _ok = true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await ref.read(sessionProvider.notifier).signIn(session);
      if (!mounted) return;
      final prefs = ref.read(prefsProvider);
      if (prefs.onboarded) {
        context.go('/home');
      } else {
        context.go('/setup');
      }
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _error = S.of(context).otpWrong;
        _checking = false;
        _ctrl.clear();
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final value = _ctrl.text;
    final sent = switch (widget.method) {
      AuthMethod.email => s.otpSentEmail(widget.destination),
      AuthMethod.telegram => '${s.byTelegram}: ${widget.destination}',
      AuthMethod.phone => s.otpSentPhone(widget.destination),
    };

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 20),
                children: [
                  Text(s.otpTitle, textAlign: TextAlign.center, style: context.t.headlineMedium),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(sent,
                            textAlign: TextAlign.center,
                            style: context.t.bodyMedium?.copyWith(color: c.muted)),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6)),
                        child: Text(s.otpChange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: 0,
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) {
                                setState(() {});
                                if (v.length == 4) _verify(v);
                              },
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _focus.requestFocus(),
                            child: Row(
                              children: [
                                for (var i = 0; i < 4; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: _Cell(
                                      char: i < value.length ? value[i] : '',
                                      active: value.length == i && !_ok,
                                      ok: _ok,
                                      error: _error != null,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: _Status(
                      checking: _checking && !_ok,
                      ok: _ok,
                      error: _error,
                      left: _left,
                      onResend: () {
                        _startTimer();
                        ref.read(authRepoProvider).requestCode(
                            method: widget.method, destination: widget.destination);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 0, Brand.gutter, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(Brand.radiusRow),
                onTap: () {
                  _ctrl.text = MockAuthRepository.demoCode;
                  setState(() {});
                  _verify(_ctrl.text);
                },
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: c.soft, borderRadius: BorderRadius.circular(Brand.radiusRow)),
                  child: Row(
                    children: [
                      Icon(
                          widget.method == AuthMethod.email
                              ? Icons.mail_outline_rounded
                              : widget.method == AuthMethod.telegram
                                  ? Icons.send_rounded
                                  : Icons.smartphone_rounded,
                          color: c.ink3),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.otpDemo, style: context.t.bodyLarge)),
                      Text(s.otpPaste,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: c.accent, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.char, required this.active, required this.ok, required this.error});
  final String char;
  final bool active, ok, error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final border = error
        ? Brand.danger
        : ok
            ? Brand.primary
            : active
                ? Brand.primary
                : c.line;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 72,
      decoration: BoxDecoration(
        color: ok ? c.chipOkBg : c.soft2,
        borderRadius: BorderRadius.circular(Brand.radiusRow),
        border: Border.all(color: border, width: 1.5),
        boxShadow: active
            ? [BoxShadow(color: Brand.primary.withValues(alpha: .14), blurRadius: 0, spreadRadius: 4)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(char,
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: ok ? Brand.p700 : Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.checking,
    required this.ok,
    required this.error,
    required this.left,
    required this.onResend,
  });
  final bool checking, ok;
  final String? error;
  final int left;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    if (ok) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Brand.primary, size: 20),
          const SizedBox(width: 8),
          Text(s.otpOk, style: TextStyle(fontWeight: FontWeight.w600, color: c.accent)),
        ],
      );
    }
    if (checking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
          const SizedBox(width: 10),
          Text(s.otpChecking, style: context.t.bodyMedium?.copyWith(color: c.muted)),
        ],
      );
    }
    if (error != null) {
      return Text(error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600));
    }
    if (left > 0) {
      return Text(s.otpResendIn('0:${left.toString().padLeft(2, '0')}'),
          style: context.t.bodyMedium?.copyWith(color: c.muted));
    }
    return TextButton(onPressed: onResend, child: Text(s.otpResend));
  }
}
