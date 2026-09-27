import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 28),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Mark(size: 30),
                        const SizedBox(width: 10),
                        Text(s.appName,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Brand.primary)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _WelcomeArt(),
                    const SizedBox(height: 24),
                    Text(s.welcomeTitle1, style: context.t.headlineMedium),
                    Text(s.welcomeTitle2,
                        style: context.t.headlineMedium?.copyWith(color: Brand.p700)),
                    const SizedBox(height: 10),
                    Text(s.welcomeLead,
                        style: context.t.bodyMedium?.copyWith(color: c.muted)),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: Text(s.start),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/login'),
                        child: Text(s.haveAccount),
                      ),
                    ),
                    Center(
                      child: Text('${s.appName} · ${s.byElbagar}',
                          style: context.t.labelSmall?.copyWith(color: c.muted2)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _MarkPainter(Theme.of(context).colorScheme.onSurface),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ink);
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 240;
    final green = Paint()..color = Brand.primary;
    final dark = Paint()..color = ink;
    RRect r(double x, double y, double w, double h) => RRect.fromRectAndRadius(
      Rect.fromLTWH(x * k, y * k, w * k, h * k),
      Radius.circular(3 * k),
    );
    canvas.drawRRect(r(45, 40, 38, 160), green);
    canvas.drawRRect(r(45, 162, 150, 38), green);
    canvas.drawRRect(r(95, 40, 100, 38), dark);
    canvas.drawRRect(r(95, 101, 100, 38), dark);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ink != ink;
}

/// Карточка «лента счетов» — визуальная метафора «всё в одном месте».
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('power', Icons.bolt_rounded, 'Электросеть', 'до 25 марта', '564,44 сом'),
      ('water', Icons.water_drop_outlined, 'Водоканал', 'до 20 марта', '205 сом'),
      ('kid', Icons.child_care_rounded, 'Садик «Балапан»', 'до 10 марта', '3 500 сом'),
    ];
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Brand.radiusCard + 4),
        border: Border.all(color: c.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: Brand.ink.withValues(alpha: .07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Brand.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Дом · ул. Курманжан Датка, 212',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.muted,
                    ),
                  ),
                ),
                Text(
                  'Март',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.muted2,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.line2),
            _MiniRow(
              cat: items[i].$1,
              icon: items[i].$2,
              title: items[i].$3,
              due: items[i].$4,
              amount: items[i].$5,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 13, 13),
            decoration: BoxDecoration(
              color: c.heroBg,
              borderRadius: BorderRadius.circular(Brand.radiusCard),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'К оплате · 4 счёта',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .62),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '4 449,44 сом',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Brand.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Оплатить всё',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Brand.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.cat,
    required this.icon,
    required this.title,
    required this.due,
    required this.amount,
  });
  final String cat, title, due, amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: Brand.gradient(cat),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  due,
                  style: TextStyle(fontSize: 11.5, color: c.muted2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
