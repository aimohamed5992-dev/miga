import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';

enum TimelineState { done, current, upcoming, failed }

class TimelineStep {
  const TimelineStep({required this.title, this.subtitle, this.time, this.state = TimelineState.upcoming, this.icon});
  final String title;
  final String? subtitle;
  final String? time;
  final TimelineState state;
  final IconData? icon;
}

/// Vertical order-tracking timeline (customer order, driver delivery, merchant order).
class MigaTimeline extends StatelessWidget {
  const MigaTimeline({super.key, required this.steps, this.accent = MigaColors.primary});
  final List<TimelineStep> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    _Dot(step: s, accent: accent),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2.5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: s.state == TimelineState.done ? accent : MigaColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                style: t.titleSmall?.copyWith(
                                  color: switch (s.state) {
                                    TimelineState.upcoming => MigaColors.textHint,
                                    TimelineState.failed => MigaColors.error,
                                    TimelineState.current => accent,
                                    _ => MigaColors.textPrimary,
                                  },
                                ),
                              ),
                            ),
                            if (s.time != null) Text(s.time!, style: t.labelSmall),
                          ],
                        ),
                        if (s.subtitle != null) Text(s.subtitle!, style: t.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.step, required this.accent});
  final TimelineStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (step.state) {
      TimelineState.done => (accent, Colors.white, Icons.check_rounded),
      TimelineState.current => (accent.withValues(alpha: .12), accent, step.icon ?? Icons.more_horiz_rounded),
      TimelineState.failed => (MigaColors.errorSoft, MigaColors.error, Icons.close_rounded),
      TimelineState.upcoming => (MigaColors.surfaceMuted, MigaColors.textHint, step.icon ?? Icons.circle_outlined),
    };
    final dot = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: step.state == TimelineState.current ? Border.all(color: accent, width: 2) : null,
      ),
      child: Icon(icon, size: 17, color: fg),
    );
    return step.state == TimelineState.current
        ? dot
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 900.ms)
        : dot;
  }
}
