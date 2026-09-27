import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../state/providers.dart';

/// Знакомство после входа: имя и адрес — от них зависят счета и уведомления.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});
  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  late final TextEditingController _name;
  final _address = TextEditingController(text: 'ул. Курманжан Датка, 212, кв. 14');
  String _city = 'Ош';
  bool _busy = false;

  static const _cities = ['Ош', 'Бишкек', 'Джалал-Абад', 'Кара-Суу'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(sessionProvider)?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).update(session.copyWith(
          name: _name.text.trim().isEmpty ? session.name : _name.text.trim(),
          address: _address.text.trim(),
          city: _city,
        ));
    await ref.read(prefsProvider).setOnboarded(true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Text(s.setupTitle, style: context.t.headlineMedium),
            const SizedBox(height: 8),
            Text(s.setupLead, style: context.t.bodyMedium?.copyWith(color: c.muted)),
            const SizedBox(height: 24),
            Text(s.nameLabel, style: context.t.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: s.nameHint),
            ),
            const SizedBox(height: 18),
            Text(s.cityLabel, style: context.t.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final city in _cities)
                  ChoiceChip(
                    label: Text(city),
                    selected: _city == city,
                    onSelected: (_) => setState(() => _city = city),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _city == city ? Brand.p700 : c.ink3,
                    ),
                    selectedColor: Brand.light2,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(color: _city == city ? Brand.primary : c.line, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(s.addressLabel, style: context.t.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: InputDecoration(
                hintText: s.addressHint,
                prefixIcon: Icon(Icons.location_on_outlined, color: c.muted2),
              ),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _busy ? null : _finish,
              child: Text(s.finish),
            ),
          ],
        ),
      ),
    );
  }
}
