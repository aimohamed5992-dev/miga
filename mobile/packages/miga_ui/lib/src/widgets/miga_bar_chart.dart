import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_format.dart';

/// Single-series bar chart (daily sales / earnings).
/// Thin bars with 4px rounded tops anchored to the baseline, recessive grid,
/// only the peak is labeled; tap a bar for its value. Time runs in reading direction.
class MigaBarChart extends StatefulWidget {
  const MigaBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = MigaColors.primary,
    this.height = 170,
    this.money = true,
  });
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final bool money;

  @override
  State<MigaBarChart> createState() => _MigaBarChartState();
}

class _MigaBarChartState extends State<MigaBarChart> {
  int? _selected;

  String _fmt(double v) => widget.money ? MigaFormat.money(v) : v.round().toString();

  static String _compact(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final maxV = widget.values.reduce(math.max);
    final niceMax = _niceCeil(maxV);
    final peak = widget.values.indexOf(maxV);
    final shownIndex = _selected ?? peak;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          const axisW = 34.0, labelH = 22.0, topPad = 26.0;
          final plotW = c.maxWidth - axisW;
          final plotH = c.maxHeight - labelH - topPad;
          final n = widget.values.length;
          final slot = plotW / n;
          final barW = math.min(22.0, slot - 2 * 2); // ≥2px surface gap each side

          double xFor(int i) {
            final slotIndex = rtl ? n - 1 - i : i;
            // Axis labels sit on the end side; plot spans the rest.
            final plotStart = rtl ? 0.0 : axisW;
            return plotStart + slotIndex * slot + slot / 2;
          }

          final shownTop = topPad + plotH * (1 - widget.values[shownIndex] / niceMax);
          final tipX = xFor(shownIndex).clamp(50.0, c.maxWidth - 50.0);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              // Hit target = the whole slot column, wider than the bar.
              for (var i = 0; i < n; i++) {
                if ((d.localPosition.dx - xFor(i)).abs() <= slot / 2) return setState(() => _selected = _selected == i ? null : i);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Recessive grid + axis values (muted ink).
                for (final f in [0.0, .5, 1.0])
                  Positioned(
                    left: 0,
                    right: 0,
                    top: topPad + plotH * (1 - f) - 7,
                    child: Row(
                      children: [
                        SizedBox(
                          width: axisW,
                          child: Text(_compact(niceMax * f), style: t.labelSmall?.copyWith(fontSize: 10, color: MigaColors.textHint)),
                        ),
                        Expanded(child: Container(height: 1, color: f == 0 ? MigaColors.border : MigaColors.divider)),
                      ],
                    ),
                  ),
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: xFor(i) - barW / 2,
                    width: barW,
                    bottom: labelH,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: plotH * widget.values[i] / niceMax),
                      duration: Duration(milliseconds: 600 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder:
                          (_, h, __) => AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _selected == null || _selected == i ? 1 : .35,
                            child: Container(
                              height: math.max(h, 2),
                              decoration: BoxDecoration(
                                color: widget.color,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                    ),
                  ),
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: xFor(i) - slot / 2,
                    width: slot,
                    bottom: 0,
                    height: labelH - 4,
                    child: Text(
                      widget.labels[i],
                      textAlign: TextAlign.center,
                      style: t.labelSmall?.copyWith(
                        fontSize: 10,
                        color: i == shownIndex ? MigaColors.textPrimary : MigaColors.textSecondary,
                        fontWeight: i == shownIndex ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                // One label only: the peak by default, or the tapped bar (none while everything is zero).
                if (maxV > 0 || _selected != null)
                  Positioned(
                    left: tipX - 50,
                    width: 100,
                    top: shownTop - 26,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: MigaColors.ink, borderRadius: MigaRadius.all(MigaRadius.sm)),
                        child: Text(
                          _fmt(widget.values[shownIndex]),
                          style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _niceCeil(double v) {
    if (v <= 0) return 1000; // empty data: a neutral money scale instead of 0 / 0.5 / 1
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
      if (v <= m * mag) return m * mag;
    }
    return 10 * mag;
  }
}
