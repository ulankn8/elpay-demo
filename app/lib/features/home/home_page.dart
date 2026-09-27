import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../payments/service_row.dart';
import '../stories/stories_strip.dart';
import 'object_card.dart';

/// Главная: сторисы, карточки объектов, «Новая оплата» и значки услуг.
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
          data: (state) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Brand.gutter, 4, Brand.gutter, 12),
                child: _Header(
                  name: session?.firstName ?? '',
                  address: session?.address ?? '',
                ),
              ),
              const StoriesStrip(),
              const SizedBox(height: 18),
              if (state.objects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.home_outlined,
                      title: s.nothingYet,
                      lead: s.objectsLead,
                    ),
                  ),
                )
              else
                _ObjectCarousel(state: state),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
                child: OutlinedButton.icon(
                  onPressed: () => openNewPaymentSheet(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 21),
                  label: Text(s.newPayment),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textStyle: const TextStyle(
                        fontFamily: 'Montserrat', fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const ServiceIconsRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.address});
  final String name, address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final c = context.c;
    final unread = ref.watch(unreadNoticesProvider);

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
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              if (address.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: c.muted),
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
        IconButton(
          onPressed: () => context.push('/notices'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}

class _ObjectCarousel extends StatefulWidget {
  const _ObjectCarousel({required this.state});
  final BillsState state;

  @override
  State<_ObjectCarousel> createState() => _ObjectCarouselState();
}

class _ObjectCarouselState extends State<_ObjectCarousel> {
  final _controller = PageController(viewportFraction: .93);
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
          height: 322,
          child: PageView.builder(
            controller: _controller,
            itemCount: objects.length,
            padEnds: false,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.fromLTRB(Brand.gutter, 0, i == objects.length - 1 ? Brand.gutter : 8, 0),
              child: ObjectCard(
                object: objects[i],
                bills: widget.state.byObject(objects[i].id),
                onPay: () => context.push('/object', extra: objects[i].id),
              ),
            ),
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
