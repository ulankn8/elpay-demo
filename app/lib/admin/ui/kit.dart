/// Элементы интерфейса кабинета — те же, что в утверждённом концепте
/// (concept/admin): карточки, плитки, чипы, таблица, плашки, шаги мастера.
library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/tokens.dart';

abstract final class K {
  static const side = Color(0xFF0F2A24);
  static const side2 = Color(0xFF163731);
  static const sideInk = Color(0xFFCFE3DC);
  static const sideMuted = Color(0xFF7F9A92);
  static const page = Brand.soft;
  static const font = 'Montserrat';

  static const okBg = Brand.light2, okFg = Brand.p700;
  static const warnBg = Color(0xFFFDF3E0), warnFg = Color(0xFF9A6C12);
  static const badBg = Color(0xFFFCEBE8), badFg = Color(0xFFB03A28);
  static const infoBg = Color(0xFFE8F0FC), infoFg = Color(0xFF2456B0);
}

ThemeData adminTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: K.font,
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.primary, primary: Brand.primary, onPrimary: Brand.onPrimary, surface: Colors.white),
    scaffoldBackgroundColor: K.page,
    visualDensity: VisualDensity.standard,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Brand.ink, displayColor: Brand.ink),
    dividerTheme: const DividerThemeData(color: Brand.line2, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: border(Brand.line),
      enabledBorder: border(Brand.line),
      focusedBorder: border(Brand.primary, 1.6),
      errorBorder: border(Brand.danger),
      focusedErrorBorder: border(Brand.danger, 1.6),
      hintStyle: const TextStyle(color: Brand.muted2, fontSize: 13.5),
      labelStyle: const TextStyle(color: Brand.ink3, fontSize: 13),
      errorStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Brand.onPrimary,
        disabledBackgroundColor: Brand.line,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontFamily: K.font, fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Brand.line),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontFamily: K.font, fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Brand.p700,
        textStyle: const TextStyle(fontFamily: K.font, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Brand.ink),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
  );
}

// ───────────────────────── типографика ─────────────────────────

abstract final class T {
  static const h1 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.3, color: Brand.ink);
  static const h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.2, color: Brand.ink);
  static const h3 = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Brand.ink);
  static const body = TextStyle(fontSize: 13.5, color: Brand.ink2, height: 1.45);
  static const sub = TextStyle(fontSize: 12.5, color: Brand.muted, height: 1.45);
  static const tiny = TextStyle(fontSize: 11, color: Brand.muted2, fontWeight: FontWeight.w600);
  static const th = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Brand.muted, letterSpacing: .4);
  static const td = TextStyle(fontSize: 13, color: Brand.ink);
  static const num = TextStyle(fontSize: 13, color: Brand.ink, fontFeatures: [FontFeature.tabularFigures()]);
}

/// «205» / «1 487 310» с маленьким «сом».
class Money extends StatelessWidget {
  const Money(this.value, {super.key, this.size = 13, this.weight = FontWeight.w600, this.color = Brand.ink, this.unit = true});
  final double value, size;
  final FontWeight weight;
  final Color color;
  final bool unit;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: som(value),
          style: TextStyle(fontSize: size, fontWeight: weight, color: color, letterSpacing: size > 20 ? -.8 : 0),
        ),
        if (unit)
          TextSpan(
            text: ' сом',
            style: TextStyle(fontSize: size * .55 < 10 ? 10 : size * .55, fontWeight: FontWeight.w600, color: Brand.muted),
          ),
      ],
    ),
    maxLines: 1,
    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
  );
}

String pct(double v, {int digits = 1}) => '${(v * 100).toStringAsFixed(digits).replaceAll('.', ',')}%';

String nf(num v) => som(v);

String dt(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}, ${hhmm(d)}';

String periodTitle(int year, int month) => '${monthsNom[month - 1][0].toUpperCase()}${monthsNom[month - 1].substring(1)} $year';

// ───────────────────────── карточки ─────────────────────────

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white, this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: border == null ? null : Border.all(color: border!, width: 1.4),
      boxShadow: const [BoxShadow(color: Color(0x0F1E2A32), blurRadius: 2, offset: Offset(0, 1))],
    ),
    child: child,
  );
}

/// Заголовок карточки: название, справа — действие.
class PanelHead extends StatelessWidget {
  const PanelHead(this.title, {super.key, this.sub, this.trailing});
  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.h2),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(sub!, style: T.sub),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class Kpi extends StatelessWidget {
  const Kpi({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.meter,
    this.meterColor = Brand.primary,
    this.noteColor,
    this.onTap,
    this.accent,
  });
  final String label;
  final Widget value;
  final String? note;
  final double? meter;
  final Color meterColor;
  final Color? noteColor, accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: accent == null ? null : Border.all(color: accent!, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Brand.muted),
            ),
            const SizedBox(height: 6),
            value,
            if (meter != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: meter!.clamp(0, 1), minHeight: 7, color: meterColor, backgroundColor: Brand.line2),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: noteColor ?? Brand.muted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── чипы ─────────────────────────

enum Tone { ok, warn, bad, info, soft }

class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.tone = Tone.soft, this.icon});
  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.ok => (K.okBg, K.okFg),
      Tone.warn => (K.warnBg, K.warnFg),
      Tone.bad => (K.badBg, K.badFg),
      Tone.info => (K.infoBg, K.infoFg),
      Tone.soft => (Brand.soft, Brand.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12.5, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка с пояснением: что не так и что сделать.
class Note extends StatelessWidget {
  const Note({super.key, required this.child, this.tone = Tone.info, this.icon, this.action});
  final Widget child;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.ok => (K.okBg, K.okFg),
      Tone.warn => (K.warnBg, const Color(0xFF7A560D)),
      Tone.bad => (K.badBg, const Color(0xFF962F20)),
      Tone.info => (K.infoBg, const Color(0xFF1F4E9C)),
      Tone.soft => (Brand.soft, Brand.ink3),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? (tone == Tone.bad || tone == Tone.warn ? Icons.warning_amber_rounded : Icons.info_outline_rounded), size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12.5, color: fg, height: 1.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  if (action != null) Padding(padding: const EdgeInsets.only(top: 4), child: action!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ссылка-действие внутри плашки: «Разобрать ошибки →».
class LinkAction extends StatelessWidget {
  const LinkAction(this.text, {super.key, required this.onTap, this.color = Brand.p700});
  final String text;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$text →',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
      ),
    ),
  );
}

/// Цветной значок услуги.
class CatIcon extends StatelessWidget {
  const CatIcon(this.cat, {super.key, this.size = 36});
  final String cat;
  final double size;

  static IconData iconOf(String cat) => switch (cat) {
    'water' => Icons.water_drop_outlined,
    'power' => Icons.bolt_rounded,
    'trash' => Icons.delete_outline_rounded,
    'gas' => Icons.local_fire_department_outlined,
    'net' => Icons.wifi_rounded,
    'kid' => Icons.child_care_rounded,
    'school' => Icons.school_outlined,
    _ => Icons.apartment_rounded,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(gradient: Brand.gradient(cat), borderRadius: BorderRadius.circular(size * .28)),
    child: Icon(iconOf(cat), color: Colors.white, size: size * .5),
  );
}

class SoftIcon extends StatelessWidget {
  const SoftIcon(this.icon, {super.key, this.size = 36});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Brand.light2, borderRadius: BorderRadius.circular(size * .28)),
    child: Icon(icon, color: Brand.p700, size: size * .5),
  );
}

// ───────────────────────── фильтры ─────────────────────────

class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, this.count, required this.selected, required this.onTap, this.dot});
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Brand.ink : Colors.white,
    shape: StadiumBorder(side: BorderSide(color: selected ? Brand.ink : Brand.line)),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : Brand.ink3),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                nf(count!),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? Colors.white70 : Brand.muted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class Seg<V> extends StatelessWidget {
  const Seg({super.key, required this.items, required this.value, required this.onChanged});
  final List<(V, String)> items;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, label) in items)
          GestureDetector(
            onTap: () => onChanged(v),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: v == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: v == value ? const [BoxShadow(color: Color(0x1A1E2A32), blurRadius: 3, offset: Offset(0, 1))] : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: v == value ? Brand.ink : Brand.muted),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ───────────────────────── таблица ─────────────────────────

class Col {
  const Col(this.title, {this.flex = 1, this.width, this.right = false});
  final String title;
  final int flex;
  final double? width;
  final bool right;
}

/// Таблица кабинета: шапка, строки, выделение и нажатие на строку.
class Grid extends StatelessWidget {
  const Grid({super.key, required this.cols, required this.rows, this.onTap, this.selected, this.rowColor, this.empty, this.rowHeight = 50});

  final List<Col> cols;
  final List<List<Widget>> rows;
  final void Function(int index)? onTap;
  final bool Function(int index)? selected;
  final Color? Function(int index)? rowColor;
  final Widget? empty;
  final double rowHeight;

  Widget _cell(Col c, Widget child) {
    final aligned = Align(alignment: c.right ? Alignment.centerRight : Alignment.centerLeft, child: child);
    return c.width != null ? SizedBox(width: c.width, child: aligned) : Expanded(flex: c.flex, child: aligned);
  }

  /// Ширина, меньше которой колонки начинают налезать друг на друга.
  double get minWidth {
    var w = 40.0;
    for (final c in cols) {
      w += c.width ?? 50.0 * c.flex;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final need = minWidth;
        if (!box.hasBoundedWidth || box.maxWidth >= need) return _table();
        // Узкое окно: таблица сохраняет ширину и прокручивается вбок.
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: need, child: _table()),
          ),
        );
      },
    );
  }

  Widget _table() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Brand.soft2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              for (final c in cols)
                _cell(
                  c,
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(c.title.toUpperCase(), style: T.th, maxLines: 1),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Brand.line),
        if (rows.isEmpty)
          empty ??
              const SizedBox(
                height: 60,
                child: Center(child: Text('Ничего не нашлось', style: T.sub)),
              ),
        for (var i = 0; i < rows.length; i++)
          Material(
            color: selected?.call(i) == true ? const Color(0xFFF2FBF7) : (rowColor?.call(i) ?? Colors.white),
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(i),
              child: Container(
                constraints: BoxConstraints(minHeight: rowHeight),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Brand.line2)),
                ),
                child: Row(
                  children: [
                    for (var j = 0; j < cols.length && j < rows[i].length; j++)
                      _cell(cols[j], Padding(padding: const EdgeInsets.only(right: 10), child: rows[i][j])),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// «1–25 из 12 480» и переключатель страниц.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.total, required this.perPage, required this.onPage});
  final int page, total, perPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = (total / perPage).ceil().clamp(1, 1 << 30);
    final from = total == 0 ? 0 : page * perPage + 1;
    final to = ((page + 1) * perPage).clamp(0, total);
    Widget pg(int p) => InkWell(
      onTap: () => onPage(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 30),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p == page ? Brand.light2 : null, borderRadius: BorderRadius.circular(8)),
        child: Text(
          nf(p + 1),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p == page ? Brand.p700 : Brand.ink3),
        ),
      ),
    );
    final shown = <int>{0, page - 1, page, page + 1, pages - 1}.where((p) => p >= 0 && p < pages).toList()..sort();
    final items = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      if (i > 0 && shown[i] - shown[i - 1] > 1) {
        items.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: T.sub)));
      }
      items.add(pg(shown[i]));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${nf(from)}–${nf(to)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink),
                  ),
                  TextSpan(text: ' из ${nf(total)}'),
                ],
              ),
              style: T.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(onPressed: page > 0 ? () => onPage(page - 1) : null, icon: const Icon(Icons.arrow_back_rounded, size: 18), tooltip: 'Назад'),
          ...items,
          IconButton(onPressed: page < pages - 1 ? () => onPage(page + 1) : null, icon: const Icon(Icons.arrow_forward_rounded, size: 18), tooltip: 'Вперёд'),
        ],
      ),
    );
  }
}

// ───────────────────────── шаги мастера ─────────────────────────

class Steps extends StatelessWidget {
  const Steps({super.key, required this.labels, required this.current});
  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) Container(width: 40, height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 10), color: i <= current ? Brand.primary : Brand.line),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current ? Brand.primary : (i < current ? Brand.light2 : Colors.white),
            border: Border.all(color: i <= current ? Brand.primary : Brand.line, width: 1.5),
          ),
          child: i < current
              ? const Icon(Icons.check_rounded, size: 15, color: Brand.p700)
              : Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == current ? Brand.onPrimary : Brand.muted2),
                ),
        ),
        const SizedBox(width: 9),
        Text(
          labels[i],
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == current ? Brand.ink : (i < current ? Brand.p700 : Brand.muted2)),
        ),
      ],
    ],
  );
}

// ───────────────────────── поля ─────────────────────────

class Field2 extends StatelessWidget {
  const Field2({super.key, required this.label, required this.child, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.ink3),
      ),
      const SizedBox(height: 6),
      child,
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(hint!, style: const TextStyle(fontSize: 11.5, color: Brand.muted)),
        ),
    ],
  );
}

/// Пары «название — значение».
class Kv extends StatelessWidget {
  const Kv(this.items, {super.key, this.labelWidth = 150});
  final List<(String, String)> items;
  final double labelWidth;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (k, v) in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(k, style: const TextStyle(fontSize: 13, color: Brand.muted)),
              ),
              Expanded(
                child: Text(
                  v.isEmpty ? '—' : v,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Brand.ink),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class Empty extends StatelessWidget {
  const Empty({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoftIcon(icon, size: 52),
        const SizedBox(height: 14),
        Text(title, style: T.h2, textAlign: TextAlign.center),
        if (text != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text!, style: T.sub, textAlign: TextAlign.center),
          ),
        if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}

/// Панель справа поверх экрана: карточка абонента, формы.
Future<R?> showSideSheet<R>(BuildContext context, {required WidgetBuilder builder, double width = 560}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: const Color(0x610F1E1A),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 12,
        child: SizedBox(width: width.clamp(0, MediaQuery.sizeOf(ctx).width), height: double.infinity, child: builder(ctx)),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// Каркас выезжающей панели: шапка с закрытием, тело, низ с кнопками.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, this.sub, this.leading, required this.body, this.actions = const []});
  final String title;
  final String? sub;
  final Widget? leading;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Brand.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h1),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(sub!, style: T.sub),
                    ),
                ],
              ),
            ),
            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded), tooltip: 'Закрыть'),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 24), child: body),
      ),
      if (actions.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Brand.line)),
          ),
          child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
        ),
    ],
  );
}

void toast(BuildContext context, String text, {bool bad = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: const TextStyle(fontFamily: K.font, fontWeight: FontWeight.w600),
        ),
        backgroundColor: bad ? Brand.danger : Brand.ink,
        width: 520,
      ),
    );
}

Future<bool> confirm(BuildContext context, {required String title, required String text, String ok = 'Да', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: T.h1),
      content: SizedBox(width: 420, child: Text(text, style: T.body)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Brand.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}
