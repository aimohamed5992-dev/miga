import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import 'miga_buttons.dart';
import 'miga_image.dart';

/// Full-screen celebration (account created, payment done, campaign complete…).
class MigaSuccessPage extends StatelessWidget {
  const MigaSuccessPage({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onDone,
    this.image,
    this.accent = MigaColors.success,
    this.secondaryLabel,
    this.onSecondary,
    this.extra,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onDone;
  final String? image;
  final Color accent;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _Confetti(),
                    if (image != null)
                      Image.asset(MigaImage.path(image!), width: 200, height: 200, errorBuilder: (_, __, ___) => _Check(accent: accent))
                    else
                      _Check(accent: accent),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: t.headlineMedium, textAlign: TextAlign.center).animate().fadeIn(delay: 300.ms).slideY(begin: .3),
              const SizedBox(height: 8),
              Text(
                message,
                style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: .3),
              if (extra != null) ...[const SizedBox(height: 24), extra!.animate().fadeIn(delay: 500.ms)],
              const Spacer(),
              MigaButton(label: buttonLabel, onPressed: onDone),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 10),
                MigaButton(label: secondaryLabel!, variant: MigaButtonVariant.text, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(color: accent.withValues(alpha: .1), shape: BoxShape.circle),
      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
      Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: accent.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
      ).animate().scale(delay: 150.ms, duration: 700.ms, curve: Curves.elasticOut),
    ],
  );
}

class _Confetti extends StatelessWidget {
  const _Confetti();

  @override
  Widget build(BuildContext context) {
    const colors = [MigaColors.primary, MigaColors.gold, MigaColors.success, MigaColors.info, MigaColors.primaryLight];
    return Stack(
      children: List.generate(14, (i) {
        final angle = i / 14 * 2 * math.pi;
        final dist = 85.0 + (i % 3) * 14;
        return Align(
          alignment: Alignment.center,
          child: Container(
                width: i.isEven ? 8 : 10,
                height: i.isEven ? 8 : 4,
                decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(i.isEven ? 4 : 1)),
              )
              .animate(delay: 250.ms)
              .move(
                begin: Offset.zero,
                end: Offset(math.cos(angle) * dist, math.sin(angle) * dist),
                duration: 700.ms,
                curve: Curves.easeOutCubic,
              )
              .rotate(end: 1.5, duration: 900.ms)
              .then(delay: 600.ms)
              .fadeOut(duration: 500.ms),
        );
      }),
    );
  }
}
