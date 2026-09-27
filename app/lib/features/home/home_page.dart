import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';
import '../payments/checkout_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final session = ref.watch(sessionProvider);
    final billsAsync = ref.watch(billsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: billsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (state) {
            final unpaid = state.unpaid;
            return ListView(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 28),
              children: [
                _Header(name: session?.firstName ?? '', address: session?.address ?? ''),
                const SizedBox(height: 16),
                if (state.objects.isNotEmpty)
                  _ObjectCarousel(state: state, onPayAll: (obj) {
                    final list = state.byObject(obj.id).where((b) => !b.paid).toList();
                    if (list.isNotEmpty) openCheckout(context, ref, list);
                  }),
                const SizedBox(height: 18),
                if (unpaid.isEmpty)
                  AppCard(
                    child: EmptyState(
                      icon: Icons.check_rounded,
                      title: s.allPaid,
                      lead: s.noBillsLead,
                    ),
                  )
                else ...[
                  SectionTitle(s.billsTitle,
                      trailing: Text(s.billsCount(unpaid.length), style: context.t.labelSmall)),
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < unpaid.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          BillRow(bill: unpaid[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => openCheckout(context, ref, unpaid),
                    child: Text('${s.payAll} · ${som(state.dueTotal)} ${s.som}'),
                  ),
                ],
                const SizedBox(height: 18),
                Tip(s.paymentsStub, icon: Icons.construction_rounded, tone: ChipTone.warn),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.address});
  final String name, address;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Brand.primary, Brand.p600]),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? 'ЭП' : name.characters.take(2).toString().toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Brand.onPrimary, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.hello(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (address.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: c.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.bodySmall),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadNoticesProvider);
            return IconButton(
              onPressed: () => context.push('/notices'),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ObjectCarousel extends StatefulWidget {
  const _ObjectCarousel({required this.state, required this.onPayAll});
  final BillsState state;
  final void Function(PayObject) onPayAll;

  @override
  State<_ObjectCarousel> createState() => _ObjectCarouselState();
}

class _ObjectCarouselState extends State<_ObjectCarousel> {
  final _controller = PageController(viewportFraction: .92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final objects = widget.state.objects;
    return Column(
      children: [
        SizedBox(
          height: 236,
          child: PageView.builder(
            controller: _controller,
            itemCount: objects.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final obj = objects[i];
              return Padding(
                padding: EdgeInsets.only(right: i == objects.length - 1 ? 0 : 10),
                child: _ObjectCard(
                  object: obj,
                  bills: widget.state.byObject(obj.id),
                  onPayAll: () => widget.onPayAll(obj),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < objects.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? Brand.primary : context.c.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({required this.object, required this.bills, required this.onPayAll});
  final PayObject object;
  final List<Bill> bills;
  final VoidCallback onPayAll;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final due = bills.where((b) => !b.paid).toList();
    final sum = due.fold<double>(0, (a, b) => a + b.amount);
    final paidCount = bills.length - due.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.c.heroBg,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        boxShadow: [
          BoxShadow(
              color: Brand.ink.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 12)),
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
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.home_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(S.of(context).tr(object.name),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Text(s.billsCount(bills.length),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .65))),
            ],
          ),
          const Spacer(),
          Text(s.toPay,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .65))),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
              children: [
                TextSpan(
                    text: som(sum),
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -.8)),
                TextSpan(
                    text: ' ${s.som}',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .7))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('${s.billsCount(bills.length)} · ${s.paidOf(paidCount, bills.length)}',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .65))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: due.isEmpty ? null : onPayAll,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(due.isEmpty ? s.allPaid : s.payAll),
            ),
          ),
        ],
      ),
    );
  }
}
