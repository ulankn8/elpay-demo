import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/s.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../bills/bill_row.dart';

/// Просмотр сторисов на весь экран: кадры переключаются сами,
/// тап слева и справа листает, свайп — между сторисами.
class StoryViewerPage extends ConsumerStatefulWidget {
  const StoryViewerPage({super.key, required this.initialIndex});
  final int initialIndex;

  @override
  ConsumerState<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  static const _frameDuration = Duration(seconds: 6);

  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _frameDuration)..addStatusListener(_onFrameEnd);

  late int _story = widget.initialIndex;
  int _frame = 0;

  List<StoryItem> get _stories => ref.read(storiesProvider).value ?? const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFrame());
  }

  @override
  void dispose() {
    _progress.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _startFrame() {
    ref.read(storiesProvider.notifier).markSeen(_stories[_story].id);
    _progress
      ..reset()
      ..forward();
  }

  void _onFrameEnd(AnimationStatus status) {
    if (status == AnimationStatus.completed) _next();
  }

  void _next() {
    final story = _stories[_story];
    if (_frame + 1 < story.frames.length) {
      setState(() => _frame++);
      _startFrame();
    } else if (_story + 1 < _stories.length) {
      _pages.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_frame > 0) {
      setState(() => _frame--);
      _startFrame();
    } else if (_story > 0) {
      _pages.previousPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stories = ref.watch(storiesProvider).value ?? const <StoryItem>[];
    if (stories.isEmpty) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pages,
        itemCount: stories.length,
        onPageChanged: (i) {
          setState(() {
            _story = i;
            _frame = 0;
          });
          _startFrame();
        },
        itemBuilder: (context, i) => _StoryPage(
          story: stories[i],
          frameIndex: i == _story ? _frame : 0,
          progress: _progress,
          onNext: _next,
          onPrev: _prev,
          onHold: (hold) => hold ? _progress.stop() : _progress.forward(),
        ),
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.story,
    required this.frameIndex,
    required this.progress,
    required this.onNext,
    required this.onPrev,
    required this.onHold,
  });

  final StoryItem story;
  final int frameIndex;
  final AnimationController progress;
  final VoidCallback onNext, onPrev;
  final ValueChanged<bool> onHold;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final frame = story.frames[frameIndex];
    final colors = Brand.category[story.cat] ?? Brand.category['market']!;
    final pad = MediaQuery.of(context).padding;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.first, colors.last, Color.lerp(colors.last, Brand.ink, .35)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BigBlobs()),
          // зоны тапа: слева — назад, справа — вперёд
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPrev,
                  onLongPressStart: (_) => onHold(true),
                  onLongPressEnd: (_) => onHold(false),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onNext,
                  onLongPressStart: (_) => onHold(true),
                  onLongPressEnd: (_) => onHold(false),
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            top: pad.top + 12,
            child: Row(
              children: [
                for (var k = 0; k < story.frames.length; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _ProgressBar(
                      progress: progress,
                      state: k < frameIndex
                          ? 1
                          : k == frameIndex
                              ? 0
                              : -1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 14,
            top: pad.top + 28,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(catIcon(story.icon), size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(S.of(context).tr(story.author),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 8),
                Text(story.ago,
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withValues(alpha: .7))),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: pad.top + 130,
            bottom: 140,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(catIcon(story.icon), size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    S.of(context).tr(frame.title),
                    style: const TextStyle(
                      fontSize: 31,
                      height: 1.16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    S.of(context).tr(frame.text),
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: pad.bottom + 22,
            child: Column(
              children: [
                if (frame.ctaLabel != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Brand.ink,
                      ),
                      onPressed: () {
                        final route = frame.ctaRoute;
                        Navigator.of(context).maybePop();
                        if (route != null) context.push(route);
                      },
                      child: Text(frame.ctaLabel!),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${s.storyStep(frameIndex + 1, story.frames.length)} · ${s.storiesMore}',
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.white.withValues(alpha: .72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Полоска кадра: -1 — впереди, 0 — идёт сейчас, 1 — пройдена.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.state});
  final AnimationController progress;
  final int state;

  @override
  Widget build(BuildContext context) {
    final track = Colors.white.withValues(alpha: .38);
    if (state != 0) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: state == 1 ? Colors.white : track,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => LinearProgressIndicator(
          value: progress.value,
          minHeight: 3,
          backgroundColor: track,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    );
  }
}

class _BigBlobs extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * .84, size.height * .17),
        size.width * .38, Paint()..color = Colors.white.withValues(alpha: .18));
    canvas.drawCircle(Offset(size.width * .14, size.height * .55),
        size.width * .28, Paint()..color = Colors.white.withValues(alpha: .12));
    canvas.drawCircle(Offset(size.width * .78, size.height * .76),
        size.width * .18, Paint()..color = Colors.white.withValues(alpha: .1));
  }

  @override
  bool shouldRepaint(_BigBlobs old) => false;
}
