import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Семейный доступ: кто видит счета и кому разрешено платить.
class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final list = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.familyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invite(context, ref),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: Text(s.invite),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 92),
          children: [
            Tip(s.familyLead),
            const SizedBox(height: 16),
            if (list.isEmpty)
              AppCard(child: EmptyState(icon: Icons.people_outline_rounded, title: s.nothingYet))
            else
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      AppRow(
                        leading: _Avatar(name: list[i].name),
                        title: list[i].name,
                        subtitle: '${s.tr(list[i].role)} · ${list[i].phone}',
                        trailing: AppChip(
                          list[i].canPay ? s.canPay : s.canView,
                          tone: list[i].canPay ? ChipTone.ok : ChipTone.soft,
                        ),
                        chevron: true,
                        onTap: () => _member(context, ref, list[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _member(BuildContext context, WidgetRef ref, FamilyMember m) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final current = ref.read(familyProvider).firstWhere((x) => x.id == m.id,
              orElse: () => m);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(current.name, style: context.t.headlineSmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, left: 2),
                    child: Text('${current.role} · ${current.phone}',
                        style: context.t.bodySmall),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.canPay, style: context.t.titleMedium),
                    subtitle: Text(s.familyLead, style: context.t.bodySmall),
                    value: current.canPay,
                    onChanged: (v) {
                      ref.read(familyProvider.notifier).update(current.copyWith(canPay: v));
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(ctx, s.removeMemberConfirm, s.removeWord);
                      if (ok != true) return;
                      ref.read(familyProvider.notifier).remove(current.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(foregroundColor: Brand.danger),
                    child: Text(s.removeWord),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _invite(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final name = TextEditingController();
    final phone = TextEditingController();
    final role = TextEditingController();
    var canPay = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, left: 2),
                    child: Text(s.inviteMember, style: context.t.headlineSmall),
                  ),
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: s.memberName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: s.memberPhone, prefixText: '+996 ', hintText: s.phoneHint),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: role,
                    decoration: InputDecoration(labelText: s.memberRole),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.canPay, style: context.t.titleMedium),
                    value: canPay,
                    onChanged: (v) => setSheet(() => canPay = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final digits = phone.text.replaceAll(RegExp(r'\D'), '');
                      if (name.text.trim().isEmpty || digits.length < 9) {
                        showAppSnack(ctx, s.phoneError);
                        return;
                      }
                      ref.read(familyProvider.notifier).add(FamilyMember(
                            id: 'f-${DateTime.now().millisecondsSinceEpoch}',
                            name: name.text.trim(),
                            phone: '+996 ${phoneMask(digits)}',
                            role: role.text.trim().isEmpty ? '—' : role.text.trim(),
                            canPay: canPay,
                          ));
                      Navigator.pop(ctx);
                      showAppSnack(context, s.inviteSent);
                    },
                    child: Text(s.invite),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials =
        parts.take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: context.c.soft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: context.c.muted)),
    );
  }
}
