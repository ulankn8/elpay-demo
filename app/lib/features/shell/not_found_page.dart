import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../core/widgets.dart';

/// Страница «не туда попали» для `errorBuilder` роутера.
///
/// До неё прямой вход по ссылке на `/bill`, `/receipt`, `/event` или
/// `/object` падал: экран брал данные из `state.extra!` и при пустом
/// `extra` получал исключение прямо в сборке. Теперь нераспознанная и
/// неполная ссылка открывает этот экран, а не роняет приложение.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.location});

  /// Ссылка, по которой пришли. Показывается мелким шрифтом: иначе
  /// пользователь не поймёт, что именно устарело, а поддержка не поймёт,
  /// о какой ссылке речь.
  final String location;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.c;

    return Scaffold(
      appBar: AppBar(title: Text(s.pageNotFound)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Brand.gutter, 8, Brand.gutter, 24),
          children: [
            AppCard(
              child: EmptyState(
                icon: Icons.link_off_rounded,
                title: s.pageNotFound,
                lead: s.pageNotFoundLead,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                location,
                textAlign: TextAlign.center,
                style: context.t.labelSmall?.copyWith(color: c.muted2),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: Text(s.tabHome),
            ),
          ],
        ),
      ),
    );
  }
}
