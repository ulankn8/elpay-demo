import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../accounts/connect_args.dart';
import '../bills/bill_row.dart';
import 'new_payment_page.dart' show NewPaymentArgs;

/// Круглые значки услуг: быстрый вход в оплату с главной.
///
/// Значки приходят из каталога (`catalogNowProvider`), а не из `Demo.*`:
/// каталог читается синхронно, поэтому лента осталась обычным рядом
/// без переписывания на async.
class ServiceIconsRow extends ConsumerWidget {
  const ServiceIconsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(catalogNowProvider).quickServices;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
        itemCount: services.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => i == services.length
            ? _AllServices(onTap: () => context.push('/new-payment'))
            : ServiceIcon(
                service: services[i],
                onTap: () => openServiceSheet(context, services[i]),
              ),
      ),
    );
  }
}

/// Последний значок ленты — вход в полный список услуг.
class _AllServices extends StatelessWidget {
  const _AllServices({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: c.soft,
                shape: BoxShape.circle,
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Icon(Icons.apps_rounded, size: 25, color: c.muted),
            ),
            const SizedBox(height: 7),
            Text(
              S.of(context).allServices,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceIcon extends StatelessWidget {
  const ServiceIcon({super.key, required this.service, required this.onTap, this.size = 58});
  final QuickService service;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Brand.category[service.cat] ?? Brand.category['city']!;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 8,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: .32),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(catIcon(service.cat), size: size * .43, color: Colors.white),
            ),
            const SizedBox(height: 7),
            Text(
              S.of(context).catName(service.cat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: context.c.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тап по значку услуги: подключить счёт или оплатить разово.
Future<void> openServiceSheet(BuildContext context, QuickService service) {
  final s = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (ctx) => Consumer(
      // Шторке нужен каталог, а не ref экрана: ref экрана мог бы пережить
      // сам экран, пока шторка открыта.
      builder: (_, ref, _) {
        // Поставщик услуги — из каталога, а не из Demo.providerById.
        final provider = ref.watch(catalogNowProvider).providerById(service.providerId);
        return AppSheet(
          header: Row(
            children: [
              CatTile(service.cat, catIcon(service.cat), size: 48, radius: 14),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.catName(service.cat), style: context.t.headlineSmall),
                    if (provider != null)
                      Text('${s.tr(provider.title)} · ${s.tr(provider.subtitle)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          children: [
            BigChoice(
              cat: 'paid',
              icon: Icons.bookmark_added_outlined,
              title: s.connectAccount,
              lead: s.connectAccountLead,
              onTap: () {
                Navigator.pop(ctx);
                // Единственный вход в подключение: ссылка собирается
                // ConnectArgs, а не склеивается строкой, поэтому названия
                // параметров не расходятся с тем, что читает маршрут.
                context.push(ConnectArgs(
                  providerId: service.providerId,
                  source: ConnectArgs.sourceService,
                ).location);
              },
            ),
            const SizedBox(height: 10),
            BigChoice(
              cat: service.cat,
              icon: Icons.bolt_rounded,
              title: s.payOnce,
              lead: s.payOnceLead,
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-payment',
                    extra: NewPaymentArgs(providerId: service.providerId));
              },
            ),
          ],
        );
      },
    ),
  );
}

/// «Новая оплата»: по реквизитам или по QR с квитанции.
Future<void> openNewPaymentSheet(BuildContext context) {
  final s = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (ctx) => AppSheet(
      title: s.newPayment,
      children: [
        const SizedBox(height: 10),
        BigChoice(
          cat: 'power',
          icon: Icons.receipt_long_outlined,
          title: s.byRequisites,
          lead: s.byRequisitesLead,
          onTap: () {
            Navigator.pop(ctx);
            context.push('/new-payment');
          },
        ),
        const SizedBox(height: 10),
        BigChoice(
          cat: 'market',
          icon: Icons.qr_code_scanner_rounded,
          title: s.qrPay,
          lead: s.byQrLead,
          onTap: () {
            Navigator.pop(ctx);
            context.push('/qr');
          },
        ),
      ],
    ),
  );
}

/// Крупная строка выбора в шторке: иконка, заголовок, пояснение, шеврон.
class BigChoice extends StatelessWidget {
  const BigChoice({
    super.key,
    required this.cat,
    required this.icon,
    required this.title,
    required this.lead,
    required this.onTap,
  });
  final String cat, title, lead;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: Row(
          children: [
            CatTile(cat, icon, size: 48, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.t.titleMedium?.copyWith(fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text(lead, style: context.t.bodySmall?.copyWith(height: 1.35)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.muted2),
          ],
        ),
      ),
    );
  }
}
