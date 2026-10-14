import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../data/models.dart';
import '../state/admin_state.dart';
import 'kit.dart';

/// Вход: рабочая почта → код из письма. Регистрации нет — доступ выдаёт ЭлPay.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _emailError, _codeError;
  Staff? _who;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _send() {
    final r = ref.read(adminStoreProvider).requestCode(_email.text);
    setState(() {
      _emailError = r.failureOrNull?.message;
      _who = r.valueOrNull;
      _codeError = null;
    });
  }

  Future<void> _enter() async {
    setState(() => _busy = true);
    final r = await ref.read(actionsProvider).run((s) => s.signIn(_email.text, _code.text));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeError = r.failureOrNull?.message;
    });
    final s = r.valueOrNull;
    if (s != null) context.go(s.role == Role.admin ? '/adm/orgs' : '/svc/overview');
  }

  void _demo(String email) {
    _email.text = email;
    _send();
    _code.text = '4815';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 980;
    final card = Container(
      width: 440,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Вход в кабинет службы', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.4)),
          const SizedBox(height: 6),
          const Text('Рабочая почта сотрудника — пришлём на неё код', style: T.sub),
          const SizedBox(height: 22),
          Field2(
            label: 'Рабочая почта',
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'имя@служба.kg',
                errorText: _emailError,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18),
                suffixIcon: _who != null ? const Icon(Icons.check_circle_rounded, color: Brand.primary, size: 20) : null,
              ),
              onChanged: (_) {
                if (_who != null || _emailError != null) {
                  setState(() {
                    _who = null;
                    _emailError = null;
                  });
                }
              },
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(height: 14),
          if (_who == null)
            FilledButton(
              onPressed: _send,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Получить код'),
            )
          else ...[
            Note(
              tone: Tone.ok,
              icon: Icons.mark_email_read_outlined,
              child: Text('Код отправлен на ${_who!.email}. ${_who!.name}${_who!.pending ? ', это ваш первый вход' : ''}.'),
            ),
            const SizedBox(height: 14),
            Field2(
              label: 'Код из письма',
              hint: 'В демо код всегда 4815',
              child: TextField(
                controller: _code,
                autofocus: true, // код вводят сразу после «Получить код»
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 8),
                decoration: InputDecoration(counterText: '', errorText: _codeError, hintText: '••••'),
                onChanged: (v) {
                  if (v.length == 4) _enter();
                },
                onSubmitted: (_) => _enter(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _enter,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_busy ? 'Входим…' : 'Войти в кабинет'),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Нет доступа? Напишите менеджеру ЭлPay: Азамат Кадыров, a.kadyrov@elpay.kg', style: T.sub),
          const SizedBox(height: 16),
          const Text('ДЕМО-ВХОД', style: T.th),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('Жыпар · Ошводоканал'), onPressed: () => _demo('jypar@oshvodokanal.kg')),
              ActionChip(label: const Text('Нургуль · первый вход'), onPressed: () => _demo('nurgul@oshvodokanal.kg')),
              ActionChip(label: const Text('Админ ЭлPay'), onPressed: () => _demo('a.kadyrov@elpay.kg')),
            ],
          ),
        ],
      ),
    );

    final pitch = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Эл',
                style: TextStyle(fontWeight: FontWeight.w700, color: Brand.onPrimary, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ЭлPay · Кабинет службы',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 40),
        const Text(
          'Ваши абоненты\nи их оплаты — в одном окне',
          style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -1),
        ),
        const SizedBox(height: 18),
        const Text('Для водоканала, электросети, вывоза мусора, садиков и школ Оша.', style: TextStyle(color: K.sideInk, fontSize: 16, height: 1.5)),
        const SizedBox(height: 32),
        for (final (i, t) in const [
          (Icons.upload_rounded, 'Абоненты и начисления — файлом из 1С, как есть'),
          (Icons.verified_rounded, 'Кто оплатил и сколько — по каждому лицевому, сразу'),
          (Icons.download_rounded, 'Реестр платежей обратно в 1С — каждый день в 18:00'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0x291FB886), borderRadius: BorderRadius.circular(10)),
                  child: Icon(i, color: Brand.primary, size: 19),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    t,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [K.side, Color(0xFF123B31), Color(0xFF0B2420)]),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: wide
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 520, child: pitch),
                      const SizedBox(width: 80),
                      card,
                    ],
                  )
                : card,
          ),
        ),
      ),
    );
  }
}
