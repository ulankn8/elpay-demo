import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Личные данные: имя, почта, номер телефона.
/// Смену номера подтверждаем кодом — как при входе.
class PersonalPage extends ConsumerStatefulWidget {
  const PersonalPage({super.key});

  @override
  ConsumerState<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends ConsumerState<PersonalPage> {
  late final _name = TextEditingController(text: ref.read(sessionProvider)?.name ?? '');
  late final _email = TextEditingController(text: ref.read(sessionProvider)?.email ?? '');
  late final _address = TextEditingController(text: ref.read(sessionProvider)?.address ?? '');
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final s = S.of(context);
    final email = _email.text.trim();
    if (email.isNotEmpty && !isValidEmail(email)) {
      setState(() => _emailError = s.emailError);
      return;
    }
    setState(() => _emailError = null);
    final session = ref.read(sessionProvider);
    if (session == null) return;
    ref.read(sessionProvider.notifier).update(session.copyWith(
          name: _name.text.trim(),
          email: email.isEmpty ? null : email,
          address: _address.text.trim(),
        ));
    showAppSnack(context, s.saved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.personalData)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.nameFull),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: s.emailLabel,
                hintText: s.emailHint,
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: s.addressLabel),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: AppRow(
                leading: CatTile('power', Icons.smartphone_rounded, soft: true),
                title: session?.phone ?? '—',
                subtitle: s.phoneChangeLead,
                trailing: TextButton(
                  onPressed: () => _changePhone(context),
                  child: Text(s.phoneChange),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _save, child: Text(s.save)),
          ],
        ),
      ),
    );
  }

  void _changePhone(BuildContext context) {
    final s = S.of(context);
    final phone = TextEditingController();
    final code = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(s.phoneChange, style: context.t.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 2),
                  child: Text(s.phoneChangeLead, style: context.t.bodySmall),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: s.phoneLabel,
                    prefixText: '+996 ',
                    hintText: s.phoneHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.otpTitle, hintText: '4815'),
                ),
                const SizedBox(height: 10),
                Tip(s.otpDemo),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final digits = phone.text.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 9) {
                      showAppSnack(ctx, s.phoneError);
                      return;
                    }
                    if (code.text.trim() != '4815') {
                      showAppSnack(ctx, s.otpWrong);
                      return;
                    }
                    final session = ref.read(sessionProvider);
                    if (session != null) {
                      ref.read(sessionProvider.notifier).update(
                            session.copyWith(phone: '+996 ${phoneMask(digits)}'),
                          );
                    }
                    Navigator.pop(ctx);
                    showAppSnack(context, s.saved);
                  },
                  child: Text(s.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
