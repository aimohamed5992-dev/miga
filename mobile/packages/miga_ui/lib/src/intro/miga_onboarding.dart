import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import '../widgets/miga_illustration.dart';
import '../widgets/miga_image.dart';

/// Small floating card drawn around the onboarding illustration.
class OnboardingBubble {
  const OnboardingBubble({required this.icon, required this.text, required this.alignment, this.color});
  final IconData icon;
  final String text;
  final AlignmentDirectional alignment;
  final Color? color;
}

class OnboardingPageData {
  const OnboardingPageData({
    required this.image,
    required this.icon,
    required this.title,
    required this.highlight,
    required this.body,
    this.bubbles = const [],
  });

  /// Asset name in miga_ui/assets/images (e.g. customer_onb_1.png).
  final String image;

  /// Hero icon drawn when the image isn't available yet.
  final IconData icon;
  final String title;

  /// Word(s) inside [title] painted in the brand color.
  final String highlight;
  final String body;
  final List<OnboardingBubble> bubbles;
}

class MigaOnboarding extends StatefulWidget {
  const MigaOnboarding({
    super.key,
    required this.pages,
    required this.onDone,
    this.accent = MigaColors.primary,
    this.doneLabel = 'ابدأ الآن',
    this.initialPage = 0,
    this.highlightColor,
  });
  final Color? highlightColor;
  final List<OnboardingPageData> pages;
  final int initialPage;
  final VoidCallback onDone;
  final Color accent;
  final String doneLabel;

  @override
  State<MigaOnboarding> createState() => _MigaOnboardingState();
}

class _MigaOnboardingState extends State<MigaOnboarding> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  bool get _isLast => _index == widget.pages.length - 1;

  void _next() {
    if (_isLast) return widget.onDone();
    _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final page = widget.pages[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: MigaColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar: logo + skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    const MigaLogo(size: 34),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: TextButton(
                        onPressed: _isLast ? null : widget.onDone,
                        child: Text('تخطي', style: t.labelLarge?.copyWith(color: MigaColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _Stage(page: widget.pages[i], accent: widget.accent),
                ),
              ),
              // Text block (re-animates on every page change)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 150),
                  child: Column(
                    key: ValueKey(_index),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HighlightedTitle(
                        title: page.title,
                        highlight: page.highlight,
                        accent: widget.highlightColor ?? widget.accent,
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: .25, curve: Curves.easeOutCubic),
                      const SizedBox(height: 12),
                      Text(
                        page.body,
                        textAlign: TextAlign.center,
                        style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary, height: 1.6),
                      ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideY(begin: .25, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
              ),
              // Indicator + next button
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(widget.pages.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? widget.accent : MigaColors.border,
                              borderRadius: MigaRadius.all(MigaRadius.pill),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      _NextButton(
                        progress: (_index + 1) / widget.pages.length,
                        isLast: _isLast,
                        label: widget.doneLabel,
                        accent: widget.accent,
                        onTap: _next,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({required this.title, required this.highlight, required this.accent});
  final String title;
  final String highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.35);
    final i = title.indexOf(highlight);
    if (highlight.isEmpty || i < 0) return Text(title, textAlign: TextAlign.center, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: title.substring(0, i)),
          TextSpan(text: highlight, style: TextStyle(color: accent)),
          TextSpan(text: title.substring(i + highlight.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Illustration stage: soft rings, the image (or a drawn hero icon) and floating bubbles.
class _Stage extends StatelessWidget {
  const _Stage({required this.page, required this.accent});
  final OnboardingPageData page;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth - 40, c.maxHeight - 10).clamp(200.0, 380.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Rings
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .06)),
                ).animate().scale(begin: const Offset(.6, .6), duration: 700.ms, curve: Curves.easeOutBack),
                FractionallySizedBox(
                  widthFactor: .74,
                  heightFactor: .74,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [accent.withValues(alpha: .16), accent.withValues(alpha: .05)]),
                    ),
                  ),
                ).animate().scale(begin: const Offset(.5, .5), delay: 80.ms, duration: 700.ms, curve: Curves.easeOutBack),
                // Image, or drawn hero until the image exists
                FractionallySizedBox(
                      widthFactor: .92,
                      heightFactor: .92,
                      child: Image.asset(
                        MigaImage.path(page.image),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => MigaHeroIcon(icon: page.icon, accent: accent, size: size),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -8, duration: 1800.ms, curve: Curves.easeInOut)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms)
                    .scale(begin: const Offset(.85, .85), curve: Curves.easeOutBack),
                for (final (i, b) in page.bubbles.indexed)
                  Align(
                    alignment: b.alignment,
                    child: _Bubble(bubble: b, accent: accent)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: 0, end: i.isEven ? -6 : 6, duration: (1600 + i * 300).ms, curve: Curves.easeInOut)
                        .animate(delay: (350 + i * 150).ms)
                        .fadeIn(duration: 400.ms)
                        .scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.bubble, required this.accent});
  final OnboardingBubble bubble;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = bubble.color ?? accent;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: MigaRadius.all(MigaRadius.lg), boxShadow: MigaShadows.soft),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: MigaRadius.all(MigaRadius.sm)),
            child: Icon(bubble.icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Text(bubble.text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.progress, required this.isLast, required this.label, required this.accent, required this.onTap});
  final double progress;
  final bool isLast;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
      child:
          isLast
              ? SizedBox(
                key: const ValueKey('done'),
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size(170, 60),
                    shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.pill)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  iconAlignment: IconAlignment.end,
                  label: Text(label),
                ),
              )
              : SizedBox(
                key: const ValueKey('next'),
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder:
                          (_, v, __) => SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: v,
                              strokeWidth: 2.5,
                              color: accent,
                              backgroundColor: MigaColors.border,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                    ),
                    Material(
                      color: accent,
                      shape: const CircleBorder(),
                      elevation: 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTap,
                        child: const SizedBox(width: 56, height: 56, child: Icon(Icons.arrow_forward_rounded, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
