import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Маркет: афиша Оша. Билет покупается в два тапа, QR — на входе.
class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final events = ref.watch(eventsProvider);
    final tickets = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.marketTitle),
        actions: [
          IconButton(
            onPressed: () => context.push('/tickets'),
            icon: Badge(
              isLabelVisible: tickets.isNotEmpty,
              label: Text('${tickets.length}'),
              child: const Icon(Icons.confirmation_number_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
          children: [
            Tip(s.marketLead, icon: Icons.local_activity_outlined),
            const SizedBox(height: 16),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _EventCard(
                  event: e,
                  onTap: () => context.push('/event', extra: e),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});
  final EventItem event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = Brand.category[event.cat] ?? Brand.category['market']!;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 104,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${s.longDateText(event.date)}, ${hhmm(event.date)}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                Text(s.tr(event.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.tr(event.place), style: context.t.titleMedium),
                      const SizedBox(height: 2),
                      Text(s.tr(event.lead), style: context.t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(s.priceFrom, style: context.t.labelSmall),
                    Amount(som(event.price), size: 15),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
