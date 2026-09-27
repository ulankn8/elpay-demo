import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/auth_repository.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Вход: телефон (OTP), почта (OTP) и Telegram.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  AuthMethod _method = AuthMethod.phone;
  final _phone = TextEditingController(text: '555 12 34 56');
  final _email = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _tgWaiting = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _destination => switch (_method) {
        AuthMethod.phone => '+996 ${phoneMask(_phone.text)}',
        AuthMethod.email => _email.text.trim(),
        AuthMethod.telegram => '@elpay_bot',
      };

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _error = null);
    if (_method == AuthMethod.phone &&
        _phone.text.replaceAll(RegExp(r'\D'), '').length != 9) {
      setState(() => _error = s.phoneError);
      return;
    }
    if (_method == AuthMethod.email && !isValidEmail(_email.text)) {
      setState(() => _error = s.emailError);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepoProvider)
          .requestCode(method: _method, destination: _destination);
      if (!mounted) return;
      context.push('/otp', extra: (_method, _destination));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _telegram() async {
    final s = S.of(context);
    final repo = ref.read(authRepoProvider);
    final requestId = 'req-${DateTime.now().millisecondsSinceEpoch}';
    final uri = repo.telegramLoginUri(requestId);
    setState(() => _tgWaiting = true);
    // Ссылку открывает бот-клиент; в этой сборке показываем её и ждём подтверждения.
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (mounted) showAppSnack(context, s.telegramWait);
    try {
      final handle = await repo.awaitTelegramApproval(requestId);
      if (!mounted) return;
      setState(() => _tgWaiting = false);
      context.push('/otp', extra: (AuthMethod.telegram, handle));
    } catch (_) {
      if (mounted) setState(() => _tgWaiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.loginTitle, style: context.t.headlineMedium),
            const SizedBox(height: 8),
            Text(s.loginLead, style: context.t.bodyMedium?.copyWith(color: c.muted)),
            const SizedBox(height: 22),
            _MethodSwitch(
              method: _method,
              onChanged: (m) => setState(() {
                _method = m;
                _error = null;
              }),
            ),
            const SizedBox(height: 22),
            if (_method == AuthMethod.phone) ...[
              _Label(s.phoneLabel),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofocus: true,
                onChanged: (v) {
                  final masked = phoneMask(v);
                  if (masked != v) {
                    _phone.value = TextEditingValue(
                      text: masked,
                      selection: TextSelection.collapsed(offset: masked.length),
                    );
                  }
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: s.phoneHint,
                  errorText: _error,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
                    child: Text('+996',
                        style: context.t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
              ),
            ] else if (_method == AuthMethod.email) ...[
              _Label(s.emailLabel),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: s.emailHint,
                  errorText: _error,
                  prefixIcon: Icon(Icons.mail_outline_rounded, color: c.muted2),
                ),
              ),
            ] else ...[
              Tip(s.telegramLead, icon: Icons.telegram_rounded),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2AABEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@elpay_bot', style: context.t.titleMedium),
                          Text(_tgWaiting ? s.telegramWait : 't.me/elpay_bot',
                              style: context.t.bodySmall),
                        ],
                      ),
                    ),
                    if (_tgWaiting)
                      const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy || _tgWaiting
                  ? null
                  : (_method == AuthMethod.telegram ? _telegram : _submit),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.onPrimary))
                  : Text(_method == AuthMethod.telegram ? s.openTelegram : s.getCode),
            ),
            const SizedBox(height: 14),
            Text(s.agreement,
                textAlign: TextAlign.center,
                style: context.t.labelSmall?.copyWith(color: c.muted2, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: context.t.labelMedium),
      );
}

class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({required this.method, required this.onChanged});
  final AuthMethod method;
  final ValueChanged<AuthMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    final items = [
      (AuthMethod.phone, s.byPhone, Icons.smartphone_rounded),
      (AuthMethod.email, s.byEmail, Icons.mail_outline_rounded),
      (AuthMethod.telegram, s.byTelegram, Icons.send_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.line2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final (m, label, icon) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 42,
                  decoration: BoxDecoration(
                    color: m == method
                        ? Theme.of(context).colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: m == method
                        ? [
                            BoxShadow(
                                color: Brand.ink.withValues(alpha: .08),
                                blurRadius: 10,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 16,
                          color: m == method ? Theme.of(context).colorScheme.onSurface : c.muted),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: m == method
                                ? Theme.of(context).colorScheme.onSurface
                                : c.muted,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
