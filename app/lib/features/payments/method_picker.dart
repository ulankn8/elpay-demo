import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Способ оплаты по id — с актуальным балансом кошелька.
PayMethodItem methodById(WidgetRef ref, String id) {
  final item = Demo.methods.firstWhere(
    (m) => m.id == id,
    orElse: () => Demo.methods.first,
  );
  if (!item.isWallet) return item;
  return PayMethodItem(
    id: item.id,
    title: item.title,
    subtitle: item.subtitle,
    badge: item.badge,
    isWallet: true,
    balance: ref.read(walletProvider),
  );
}

/// Шторка выбора способа оплаты — одна на все экраны оплаты.
Future<void> openMethodPicker(BuildContext context, WidgetRef ref) {
  final s = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: Consumer(
        builder: (ctx, ref2, _) {
          final selected = ref2.watch(payMethodProvider);
          final wallet = ref2.watch(walletProvider);
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 2),
                child: Text(s.payMethod, style: context.t.headlineSmall),
              ),
              for (final m in Demo.methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MethodTile(
                    item: m.isWallet
                        ? PayMethodItem(
                            id: m.id,
                            title: m.title,
                            subtitle: m.subtitle,
                            badge: m.badge,
                            isWallet: true,
                            balance: wallet)
                        : m,
                    selected: selected == m.id,
                    onTap: () {
                      ref2.read(payMethodProvider.notifier).select(m.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// Плитка способа оплаты: бейдж банка, название, баланс или подпись.
class MethodTile extends StatelessWidget {
  const MethodTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.showRadio = true,
  });
  final PayMethodItem item;
  final bool selected, showRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(Brand.radiusRow),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Brand.light2.withValues(alpha: .6) : Colors.transparent,
          border: Border.all(color: selected ? Brand.primary : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(Brand.radiusRow),
        ),
        child: Row(
          children: [
            MethodBadge(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tr(item.title), style: context.t.titleMedium),
                  Text(
                    item.isWallet
                        ? '${s.walletBalance} ${som(item.balance ?? 0)} ${s.som}'
                        : s.tr(item.subtitle),
                    style: context.t.bodySmall,
                  ),
                ],
              ),
            ),
            if (showRadio)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? Brand.primary : c.muted2,
                      width: selected ? 7 : 1.5),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.item});
  final PayMethodItem item;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          color: item.isWallet ? Brand.p700 : context.c.heroBg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(item.badge,
            style: const TextStyle(
                fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}
