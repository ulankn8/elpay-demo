import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Мои билеты: QR показывают на входе, билет можно вернуть.
class TicketsPage extends ConsumerWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final list = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.myTickets)),
      body: SafeArea(
        top: false,
        child: list.isEmpty
            ? EmptyState(
                icon: Icons.confirmation_number_outlined,
                title: s.ticketsEmpty,
                lead: s.marketLead,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 28),
                children: [
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TicketCard(ticket: t),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket});
  final TicketItem ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.tr(ticket.title), style: context.t.titleLarge),
                    const SizedBox(height: 3),
                    Text(s.tr(ticket.place), style: context.t.bodySmall),
                    const SizedBox(height: 3),
                    Text('${s.longDateText(ticket.date)}, ${hhmm(ticket.date)}',
                        style: context.t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              AppChip(
                ticket.used ? s.ticketUsed : s.seatsCount(ticket.seats),
                tone: ticket.used ? ChipTone.soft : ChipTone.ok,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: ticket.used ? .35 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Brand.radiusRow),
                border: Border.all(color: c.line),
              ),
              child: QrImageView(
                data: 'ELPAY:TICKET:${ticket.code}:${ticket.eventId}',
                size: 168,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Brand.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Brand.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(ticket.code,
              style: context.t.titleMedium?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(ticket.used ? s.ticketUsed : s.showQr, style: context.t.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ticket.used
                      ? null
                      : () {
                          ref.read(ticketsProvider.notifier).markUsed(ticket.id);
                          showAppSnack(context, s.ticketUsed);
                        },
                  child: Text(s.ready),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: ticket.used
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                              context, s.ticketReturnConfirm, s.ticketReturn);
                          if (ok != true) return;
                          ref.read(walletProvider.notifier).topUp(ticket.price);
                          ref.read(ticketsProvider.notifier).remove(ticket.id);
                          if (context.mounted) showAppSnack(context, s.ticketReturned);
                        },
                  child: Text(s.ticketReturn),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
