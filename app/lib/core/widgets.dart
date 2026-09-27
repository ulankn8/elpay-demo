import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Круглая иконка услуги: цветной градиент из брендбука.
class CatTile extends StatelessWidget {
  const CatTile(this.cat, this.icon, {super.key, this.size = 44, this.soft = false, this.radius = 12});
  final String cat;
  final IconData icon;
  final double size, radius;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final colors = Brand.category[cat] ?? Brand.category['city']!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: soft ? null : Brand.gradient(cat),
        color: soft ? colors.last.withValues(alpha: dark ? .22 : .14) : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon,
          size: size * .5,
          color: soft ? (dark ? colors.first : colors.last) : Colors.white),
    );
  }
}

/// Белая карточка-группа с мягкой тенью — базовый контейнер интерфейса.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap, this.margin});
  final Widget child;
  final EdgeInsets? padding, margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        border: dark ? Border.all(color: c.line2) : null,
        boxShadow: dark
            ? null
            : [BoxShadow(color: Brand.ink.withValues(alpha: .06), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// Строка списка: иконка — заголовок с подписью — хвост.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });

  final Widget? leading, trailing;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.t.titleMedium),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.t.bodySmall?.copyWith(color: subtitleColor ?? c.muted)),
                    ),
                ],
              ),
            ),
            if (trailing != null) const SizedBox(width: 12),
            ?trailing,
            if (chevron)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: c.muted2),
              ),
          ],
        ),
      ),
    );
  }
}

/// Разделитель внутри карточки — как в прототипе, с отступом под иконку.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.indent = 74});
  final double indent;
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, color: context.c.line2);
}

enum ChipTone { soft, ok, warn, bad }

class AppChip extends StatelessWidget {
  const AppChip(this.text, {super.key, this.tone = ChipTone.soft, this.icon});
  final String text;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      ChipTone.ok => (c.chipOkBg, c.chipOkFg),
      ChipTone.warn => (c.chipWarnBg, c.chipWarnFg),
      ChipTone.bad => (c.chipBadBg, c.chipBadFg),
      ChipTone.soft => (c.chipSoftBg, c.chipSoftFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: fg, height: 1.2)),
        ],
      ),
    );
  }
}

/// Сумма с приглушённым «сом».
class Amount extends StatelessWidget {
  const Amount(this.text, {super.key, this.size = 16, this.color});
  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color ?? Theme.of(context).colorScheme.onSurface,
            letterSpacing: -.2,
          ),
          children: [
            TextSpan(text: text),
            TextSpan(
              text: ' сом',
              style: TextStyle(
                fontSize: size * .62,
                fontWeight: FontWeight.w600,
                color: context.c.muted,
              ),
            ),
          ],
        ),
      );
}

/// Заголовок секции: «Счета» + необязательная подпись справа.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.t.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

/// Подсказка-плашка (информационная).
class Tip extends StatelessWidget {
  const Tip(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.tone});
  final String text;
  final IconData icon;
  final ChipTone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      ChipTone.ok => (c.chipOkBg, c.chipOkFg),
      ChipTone.warn => (c.chipWarnBg, c.chipWarnFg),
      ChipTone.bad => (c.chipBadBg, c.chipBadFg),
      _ => (c.tipBg, c.tipFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Brand.radiusRow)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Таблица «ключ — значение» на мягкой подложке.
class KeyValueBox extends StatelessWidget {
  const KeyValueBox(this.rows, {super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Brand.radiusRow)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(rows[i].$1,
                        style: context.t.bodyMedium?.copyWith(color: c.muted)),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(rows[i].$2,
                        textAlign: TextAlign.right,
                        style: context.t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Копируемая строка реквизитов.
class CopyRow extends StatelessWidget {
  const CopyRow(this.label, this.value, {super.key, required this.copiedText});
  final String label, value, copiedText;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$label: $copiedText')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.t.labelSmall?.copyWith(color: c.muted)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: context.t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 18, color: c.muted2),
          ],
        ),
      ),
    );
  }
}

/// Пустое состояние.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.lead});
  final IconData icon;
  final String title;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.soft, shape: BoxShape.circle),
            child: Icon(icon, color: c.muted2, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: context.t.titleMedium),
          if (lead != null) ...[
            const SizedBox(height: 6),
            Text(lead!, textAlign: TextAlign.center, style: context.t.bodySmall),
          ],
        ],
      ),
    );
  }
}

void showAppSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
