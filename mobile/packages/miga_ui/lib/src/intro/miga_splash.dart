import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import '../widgets/miga_image.dart';

/// Animated splash shared by the three apps.
/// Customer: brand-red gradient + white mark. Merchant / Driver: dark accent gradient + red mark.
class MigaSplash extends StatefulWidget {
  const MigaSplash({super.key, required this.role, required this.onFinished, this.duration = const Duration(milliseconds: 2800)});
  final MigaRole role;
  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<MigaSplash> createState() => _MigaSplashState();
}

class _MigaSplashState extends State<MigaSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  bool get _isCustomer => widget.role == MigaRole.customer;

  Gradient get _gradient => switch (widget.role) {
    MigaRole.customer => MigaColors.primaryGradient,
    MigaRole.merchant => const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF2B3A5E), MigaColors.merchantAccent, Color(0xFF0E1424)],
    ),
    MigaRole.driver => const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF14958B), MigaColors.driverAccent, Color(0xFF073B37)],
    ),
    MigaRole.admin => const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF2A2A31), MigaColors.ink, Color(0xFF050507)],
    ),
  };

  String? get _badge => switch (widget.role) {
    MigaRole.customer => null,
    MigaRole.merchant => 'للتجار',
    MigaRole.driver => 'كابتن',
    MigaRole.admin => 'الإدارة',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: _gradient),
          child: Stack(
            children: [
              // Decorative oversized logo watermark.
              PositionedDirectional(
                bottom: -120,
                start: -120,
                child: Opacity(
                  opacity: .07,
                  child: const MigaLogo(size: 380, white: true),
                ).animate().rotate(begin: -.05, end: 0, duration: 2.seconds, curve: Curves.easeOut),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _ripple,
                            builder: (_, __) => CustomPaint(size: const Size.square(220), painter: _RipplePainter(_ripple.value)),
                          ),
                          Container(
                                width: 128,
                                height: 128,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _isCustomer ? Colors.transparent : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow:
                                      _isCustomer
                                          ? null
                                          : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: .25),
                                              blurRadius: 30,
                                              offset: const Offset(0, 12),
                                            ),
                                          ],
                                ),
                                child: MigaLogo(size: 100, white: _isCustomer),
                              )
                              .animate()
                              .scale(begin: const Offset(.3, .3), duration: 900.ms, curve: Curves.elasticOut)
                              .fadeIn(duration: 300.ms)
                              .then(delay: 200.ms)
                              .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: .5)),
                        ],
                      ),
                    ),
                    Text(
                      'ميجا',
                      style: t.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                    ).animate().fadeIn(delay: 450.ms, duration: 500.ms).slideY(begin: .4, curve: Curves.easeOutCubic),
                    if (_badge != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.pill)),
                        child: Text(_badge!, style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      ).animate().fadeIn(delay: 650.ms).scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack),
                    const SizedBox(height: 10),
                    Text(
                      widget.role.tagline,
                      style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: .85)),
                    ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 40,
                child: const _LoadingDots().animate().fadeIn(delay: 1100.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = 64 + p * (size.width / 2 - 64);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: (1 - p) * .35),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder:
        (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final v = math.sin(((_c.value - i * .18) % 1) * math.pi).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              transform: Matrix4.translationValues(0, -6 * v, 0),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .4 + .6 * v), shape: BoxShape.circle),
            );
          }),
        ),
  );
}
