import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../payments/checkout_sheet.dart';

/// Иконка категории услуги.
IconData catIcon(String cat) => switch (cat) {
      'water' => Icons.water_drop_outlined,
      'power' => Icons.bolt_rounded,
      'trash' => Icons.delete_outline_rounded,
      'gas' => Icons.local_fire_department_outlined,
      'net' => Icons.wifi_rounded,
      'door' => Icons.sensor_door_outlined,
      'mobile' => Icons.smartphone_rounded,
      'kid' => Icons.child_care_rounded,
      'school' => Icons.school_outlined,
      'course' => Icons.menu_book_rounded,
      'tax' => Icons.account_balance_outlined,
      'market' => Icons.confirmation_number_outlined,
      _ => Icons.receipt_long_outlined,
    };

/// Человеческий срок: «просрочено на 2 дня», «осталось 3 дня», «до 25 сент».
({String text, bool overdue, bool soon}) dueLabel(BuildContext context, Bill b) {
  final s = S.of(context);
  final left = b.daysLeft(DateTime.now());
  if (left < 0) {
    final n = -left;
    return (text: '${s.overdue} · $n ${s.daysWord(n)}', overdue: true, soon: false);
  }
  if (left == 0) return (text: s.dueToday, overdue: false, soon: true);
  if (left <= 3) return (text: s.dueInDays(left), overdue: false, soon: true);
  return (text: s.shortDueText(b.due), overdue: false, soon: false);
}

/// Строка счёта: сумма — главное, «Оплатить» мягкая, «Детали» тихая.
class BillRow extends ConsumerWidget {
  const BillRow({super.key, required this.bill, this.showObject});
  final Bill bill;
  final String? showObject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;
    final due = dueLabel(context, bill);

    return InkWell(
      onTap: () => context.push('/bill', extra: bill),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
        child: Row(
          children: [
            CatTile(bill.cat, catIcon(bill.cat)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.tr(bill.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    showObject == null ? due.text : '$showObject · ${due.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.t.bodySmall?.copyWith(
                      color: due.overdue ? c.chipBadFg : c.muted,
                      fontWeight: due.overdue ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Amount(som(bill.amount), size: 16),
                const SizedBox(height: 6),
                _PayPill(onTap: () => openCheckout(context, ref, [bill])),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

class _PayPill extends StatelessWidget {
  const _PayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Brand.primary.withValues(alpha: .16) : Brand.light2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Brand.primary.withValues(alpha: .3), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(s.pay,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: dark ? const Color(0xFF6FE0BB) : Brand.p700)),
        ),
      ),
    );
  }
}
