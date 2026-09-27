import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Лента сторисов на главной: прямоугольные карточки со свайпом.
class StoriesStrip extends ConsumerWidget {
  const StoriesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider).value ?? const <StoryItem>[];
    if (stories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Brand.gutter),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 11),
        itemBuilder: (context, i) => _StoryCard(
          story: stories[i],
          onTap: () => context.push('/story', extra: i),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onTap});
  final StoryItem story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Brand.category[story.cat] ?? Brand.category['market']!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        padding: story.seen ? EdgeInsets.zero : const EdgeInsets.all(2.5),
        decoration: story.seen
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Brand.primary, width: 2.5),
              ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(story.seen ? 19 : 16),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Brand.ink.withValues(alpha: .13),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BlobPainter()),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var k = 0; k < story.frames.length; k++) ...[
                          if (k > 0) const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: story.seen || k > 0 ? .45 : 1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        story.tag,
                        style: const TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      story.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Color(0x4D000000), blurRadius: 6)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Мягкие круги на фоне — вместо картинок, пока их не рисует дизайнер.
class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .20);
    canvas.drawCircle(Offset(size.width * .82, size.height * .2), size.width * .38, p);
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .74),
      size.width * .26,
      Paint()..color = Colors.white.withValues(alpha: .13),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => false;
}
