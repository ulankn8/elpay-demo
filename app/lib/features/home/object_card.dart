import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';

/// Карточка объекта: сумма к оплате, срок и разбивка по услугам.
class ObjectCard extends StatelessWidget {
  const ObjectCard({
    super.key,
    required this.object,
    required this.bills,
    required this.onPay,
  });

  final PayObject object;
  final List<Bill> bills;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final due = bills.where((b) => !b.paid).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final sum = due.fold<double>(0, (a, b) => a + b.amount);
    final paidCount = bills.length - due.length;
    final deadline = due.isEmpty
        ? null
        : due.map((b) => b.due).reduce((a, b) => a.isBefore(b) ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: object.id == 'o1'
              ? const [Color(0xFF0E3A2C), Color(0xFF12303A), Color(0xFF172A32)]
              : const [Color(0xFF14303C), Color(0xFF1B2A36), Color(0xFF202C33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E3A2C).withValues(alpha: .28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  object.icon == 'users'
                      ? Icons.people_outline_rounded
                      : Icons.home_outlined,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.tr(object.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Text(s.billsCount(bills.length),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .62))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(s.toPay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .62))),
              ),
              if (deadline != null) ...[
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_outlined, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('${s.dueBy} ${s.dayMonthText(deadline)}',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                children: [
                  TextSpan(
                      text: som(sum),
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.1)),
                  TextSpan(
                      text: ' ${s.som}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .7))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(s.paidOf(paidCount, bills.length),
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: .6))),
          if (due.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Breakdown(bills: due, total: sum),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: due.isEmpty ? null : onPay,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(
                      fontFamily: 'Montserrat', fontSize: 15.5, fontWeight: FontWeight.w700)),
              icon: due.isEmpty
                  ? const SizedBox.shrink()
                  : const Icon(Icons.arrow_forward_rounded, size: 19),
              iconAlignment: IconAlignment.end,
              label: Text(due.isEmpty ? s.allPaid : s.payWord),
            ),
          ),
        ],
      ),
    );
  }
}

/// Полоска и легенда: на что уходят деньги по этому объекту.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.bill, required this.color});
  final Bill bill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(s.catName(bill.cat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .82))),
        ),
        const SizedBox(width: 5),
        Text(som(bill.amount),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.bills, required this.total});
  final List<Bill> bills;
  final double total;

  @override
  Widget build(BuildContext context) {
    final shown = bills.take(4).toList();
    final rest = total - shown.fold<double>(0, (a, b) => a + b.amount);

    Color colorOf(Bill b) => (Brand.category[b.cat] ?? Brand.category['city']!).last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 9,
            child: Row(
              children: [
                for (final b in shown)
                  Expanded(
                    flex: (b.amount / total * 1000).round().clamp(12, 1000),
                    child: Container(color: colorOf(b)),
                  ),
                if (rest > 0)
                  Expanded(
                    flex: (rest / total * 1000).round().clamp(12, 1000),
                    child: Container(color: Colors.white.withValues(alpha: .18)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 11),
        // ровно две строки по два пункта — высота карточки предсказуема
        for (var r = 0; r < (shown.length / 2).ceil(); r++) ...[
          if (r > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var k = 0; k < 2; k++) ...[
                if (k > 0) const SizedBox(width: 10),
                Expanded(
                  child: r * 2 + k < shown.length
                      ? _LegendItem(
                          bill: shown[r * 2 + k],
                          color: colorOf(shown[r * 2 + k]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
