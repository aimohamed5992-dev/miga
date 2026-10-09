import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

/// Static map preview with the route store → customer drawn on top.
/// Swapped for Google Maps / Mapbox when the backend provides coordinates.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, this.height = 220, this.progress = .35, this.borderRadius});
  final double height;

  /// Where the driver marker sits along the route (0 = not picked up yet → no marker, 1 = customer).
  final double progress;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? MigaRadius.all(MigaRadius.lg),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, height);
            final path = _route(size);
            final metric = path.computeMetrics().first;
            final car = metric.getTangentForOffset(metric.length * progress.clamp(0, 1))!.position;
            final start = metric.getTangentForOffset(0)!.position;
            final end = metric.getTangentForOffset(metric.length)!.position;
            return Stack(
              children: [
                const Positioned.fill(child: MigaImage('map_placeholder.jpg')),
                Positioned.fill(child: CustomPaint(painter: _RoutePainter(path, progress))),
                _pin(start, Icons.storefront_rounded, MigaColors.merchantAccent),
                _pin(end, Icons.home_rounded, MigaColors.primary),
                if (progress > 0)
                  Positioned(
                    left: car.dx - 18,
                    top: car.dy - 18,
                    child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: MigaColors.driverAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: MigaShadows.glow(MigaColors.driverAccent),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 900.ms),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pin(Offset at, IconData icon, Color color) => Positioned(
    left: at.dx - 17,
    top: at.dy - 40,
    child: Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: MigaShadows.soft,
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        Container(width: 3, height: 8, color: color),
      ],
    ),
  );

  static Path _route(Size s) =>
      Path()
        ..moveTo(s.width * .18, s.height * .86)
        ..lineTo(s.width * .18, s.height * .64)
        ..lineTo(s.width * .48, s.height * .64)
        ..lineTo(s.width * .48, s.height * .46)
        ..lineTo(s.width * .8, s.height * .46);
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.path, this.progress);
  final Path path;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final base =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    // Remaining route (soft) then travelled part (solid).
    canvas.drawPath(path, base..color = MigaColors.driverAccent.withValues(alpha: .3));
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      base
        ..color = MigaColors.driverAccent
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), [MigaColors.driverChart, MigaColors.driverAccent]),
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.progress != progress;
}
