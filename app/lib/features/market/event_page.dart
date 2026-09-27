import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../payments/method_picker.dart';
import '../payments/pay_flow.dart';

/// Событие и покупка билета: количество, способ оплаты, оплата.
class EventPage extends ConsumerStatefulWidget {
  const EventPage({super.key, required this.event});
  final EventItem event;

  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  int _count = 1;
  bool _busy = false;

  double get _sum => widget.event.price * _count;

  Future<void> _buy() async {
    final s = S.of(context);
    final e = widget.event;
    setState(() => _busy = true);
    final now = DateTime.now();
    final no = await payAndFinish(
      context,
      ref,
      bills: const [],
      records: [
        Payment(
          id: 'tk-${now.millisecondsSinceEpoch}',
          title: e.title,
          cat: 'market',
          amount: _sum,
          date: now,
          methodId: '',
          receiptNo: '',
          account: e.place,
          period: s.longDateText(e.date),
        ),
      ],
      amount: _sum,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (no == null) return;
    ref.read(ticketsProvider.notifier).add(TicketItem(
          id: 'ticket-${now.millisecondsSinceEpoch}',
          eventId: e.id,
          title: e.title,
          place: e.place,
          date: e.date,
          price: _sum,
          code: 'ELP-${now.millisecondsSinceEpoch % 1000000}',
          seats: _count,
        ));
    showAppSnack(context, s.ticketBought);
    context.pushReplacement('/tickets');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = widget.event;
    final method = methodById(ref, ref.watch(payMethodProvider));

    return Scaffold(
      appBar: AppBar(title: Text(s.buyTicket)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 16),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Column(
                      children: [
                        CatTile(e.cat, Icons.local_activity_outlined, size: 52, radius: 15),
                        const SizedBox(height: 10),
                        Text(s.tr(e.title), textAlign: TextAlign.center, style: context.t.titleLarge),
                        const SizedBox(height: 4),
                        Text(s.tr(e.lead), style: context.t.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  KeyValueBox([
                    (s.paidAt, '${s.longDateText(e.date)}, ${hhmm(e.date)}'),
                    (s.object, s.tr(e.place)),
                    (s.amountLabel, '${som(e.price)} ${s.som}'),
                  ]),
                  SectionTitle(s.ticketCount),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(s.seatsCount(_count), style: context.t.titleMedium),
                        ),
                        IconButton(
                          onPressed: _count > 1 ? () => setState(() => _count--) : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        IconButton(
                          onPressed: _count < 8 ? () => setState(() => _count++) : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                  SectionTitle(s.payMethod),
                  MethodTile(
                    item: method,
                    selected: false,
                    showRadio: false,
                    onTap: () async {
                      await openMethodPicker(context, ref);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  Brand.gutter, 12, Brand.gutter, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: context.c.line2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.total, style: context.t.titleMedium)),
                      Amount(som(_sum), size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _buy,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Brand.onPrimary))
                        : Text('${s.buyTicket} · ${som(_sum)} ${s.som}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
