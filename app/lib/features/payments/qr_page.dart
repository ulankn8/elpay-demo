import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';
import 'payments_page.dart' show NewPaymentArgs;

/// Оплата по QR с бумажной квитанции.
///
/// Камера подключается в сборке для телефона (пакет mobile_scanner);
/// здесь — рамка видоискателя и пример распознанной квитанции,
/// чтобы можно было пройти весь путь оплаты.
class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: context.c.heroBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        title: Text(s.qrPay),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const _Viewfinder(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                s.qrLead,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: .8)),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(Brand.gutter, 0, Brand.gutter, 20),
              child: Column(
                children: [
                  Tip(s.cameraStub, icon: Icons.photo_camera_outlined),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        showAppSnack(context, s.qrFound);
                        context.pushReplacement(
                          '/new-payment',
                          extra: const NewPaymentArgs(
                            providerId: 'p-water',
                            account: '31-01187',
                            amount: 205,
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: Text(s.qrDemoBtn),
                    ),
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

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 236,
        height: 236,
        child: CustomPaint(painter: _FramePainter(), child: const SizedBox.expand()),
      );
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Brand.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 44.0;
    final w = size.width, h = size.height;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), p);
    }

    corner(2, 2, 1, 1);
    corner(w - 2, 2, -1, 1);
    corner(2, h - 2, 1, -1);
    corner(w - 2, h - 2, -1, -1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, w - 4, h - 4), const Radius.circular(20)),
      Paint()
        ..color = Colors.white.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}
