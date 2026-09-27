import 'package:flutter/material.dart';

/// Токены бренда ELBAGAR / ЭлPay.
/// Значения перенесены один в один из утверждённого прототипа.
class Brand {
  static const primary = Color(0xFF1FB886);
  static const p600 = Color(0xFF06A06E);
  static const p700 = Color(0xFF05804F);
  static const onPrimary = Color(0xFF04332B);
  static const light = Color(0xFFDEF3EC);
  static const light2 = Color(0xFFEBF8F2);

  static const ink = Color(0xFF1E2A32);
  static const ink2 = Color(0xFF2A3942);
  static const ink3 = Color(0xFF3C4A55);
  static const muted = Color(0xFF6B7772);
  static const muted2 = Color(0xFF9AA5A0);

  static const line = Color(0xFFE4E8E6);
  static const line2 = Color(0xFFEEF1EF);
  static const bg = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF5F7F6);
  static const soft2 = Color(0xFFF9FAF9);

  static const danger = Color(0xFFE0533F);
  static const warning = Color(0xFFE0A93F);
  static const info = Color(0xFF3F7BE0);

  // Тёмная тема
  static const dBg = Color(0xFF1B252B);
  static const dSoft = Color(0xFF141D22);
  static const dSoft2 = Color(0xFF182228);
  static const dInk = Color(0xFFF2F5F4);
  static const dInk3 = Color(0xFFC2D0CB);
  static const dMuted = Color(0xFF9FB0AA);
  static const dMuted2 = Color(0xFF7F918B);
  static const dLine = Color(0x29DEF3EC);
  static const dLine2 = Color(0x1ADEF3EC);
  static const dP700 = Color(0xFF46DBAB);

  /// Цвета категорий услуг: [начало градиента, конец градиента]
  static const Map<String, List<Color>> category = {
    'water': [Color(0xFF5B9BF0), Color(0xFF3F7BE0)],
    'power': [Color(0xFFF6C453), Color(0xFFE0A93F)],
    'trash': [Color(0xFFFF9A52), Color(0xFFF0643F)],
    'kid': [Color(0xFFFF7DBE), Color(0xFFE0428D)],
    'school': [Color(0xFF8C75FF), Color(0xFF5B45D9)],
    'gas': [Color(0xFFE07A5F), Color(0xFFC0553F)],
    'net': [Color(0xFF8B9BF0), Color(0xFF6B7EE0)],
    'door': [Color(0xFF7A8AA8), Color(0xFF5E6E8C)],
    'course': [Color(0xFFB57BEE), Color(0xFF9B51E0)],
    'tax': [Color(0xFF55636E), Color(0xFF3C4A55)],
    'market': [Color(0xFF46BEDC), Color(0xFF2AA3C7)],
    'city': [Color(0xFF56636D), Color(0xFF1E2A32)],
  };

  static LinearGradient gradient(String cat) {
    final c = category[cat] ?? category['city']!;
    return LinearGradient(
      colors: c,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static const radiusCard = 22.0;
  static const radiusRow = 16.0;
  static const radiusTile = 12.0;
  static const gutter = 20.0;
}

/// Дополнительные цвета, которых нет в ColorScheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.soft,
    required this.soft2,
    required this.line,
    required this.line2,
    required this.muted,
    required this.muted2,
    required this.ink3,
    required this.accent,
    required this.heroBg,
    required this.chipSoftBg,
    required this.chipSoftFg,
    required this.chipOkBg,
    required this.chipOkFg,
    required this.chipWarnBg,
    required this.chipWarnFg,
    required this.chipBadBg,
    required this.chipBadFg,
    required this.tipBg,
    required this.tipFg,
  });

  final Color soft, soft2, line, line2, muted, muted2, ink3, accent, heroBg;
  final Color chipSoftBg, chipSoftFg, chipOkBg, chipOkFg;
  final Color chipWarnBg, chipWarnFg, chipBadBg, chipBadFg, tipBg, tipFg;

  static const light = AppColors(
    soft: Brand.soft,
    soft2: Brand.soft2,
    line: Brand.line,
    line2: Brand.line2,
    muted: Brand.muted,
    muted2: Brand.muted2,
    ink3: Brand.ink3,
    accent: Brand.p700,
    heroBg: Brand.ink,
    chipSoftBg: Brand.line2,
    chipSoftFg: Brand.ink3,
    chipOkBg: Brand.light,
    chipOkFg: Brand.p700,
    chipWarnBg: Color(0xFFFBF0DD),
    chipWarnFg: Color(0xFF8A5C0F),
    chipBadBg: Color(0xFFFBE5E1),
    chipBadFg: Color(0xFFB23A3A),
    tipBg: Color(0xFFE5EDFA),
    tipFg: Color(0xFF2B5BB8),
  );

  static const dark = AppColors(
    soft: Brand.dSoft,
    soft2: Brand.dSoft2,
    line: Brand.dLine,
    line2: Brand.dLine2,
    muted: Brand.dMuted,
    muted2: Brand.dMuted2,
    ink3: Brand.dInk3,
    accent: Brand.dP700,
    heroBg: Color(0xFF0E171C),
    chipSoftBg: Color(0x1ADEF3EC),
    chipSoftFg: Brand.dInk3,
    chipOkBg: Color(0x2E1FB886),
    chipOkFg: Color(0xFF6FE0BB),
    chipWarnBg: Color(0x2EE0A93F),
    chipWarnFg: Color(0xFFF0CE86),
    chipBadBg: Color(0x33E0533F),
    chipBadFg: Color(0xFFF3A797),
    tipBg: Color(0x293F7BE0),
    tipFg: Color(0xFFAFCBF7),
  );

  @override
  AppColors copyWith({Color? soft}) => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors ? (t < 0.5 ? this : other) : this;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
  TextTheme get t => Theme.of(this).textTheme;
}
