import 'package:flutter/material.dart';

import 'miga_image.dart';

/// Gradient rounded tile with a big icon — stands in for an illustration until its image exists.
class MigaHeroIcon extends StatelessWidget {
  const MigaHeroIcon({super.key, required this.icon, required this.accent, required this.size});
  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final box = size * .42;
    return Center(
      child: Transform.rotate(
        angle: -.08,
        child: Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(box * .28),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color.lerp(accent, Colors.white, .15)!, accent, Color.lerp(accent, Colors.black, .25)!],
            ),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 16))],
          ),
          child: Icon(icon, color: Colors.white, size: box * .5),
        ),
      ),
    );
  }
}

/// An illustration image from assets, falling back to [MigaHeroIcon], on soft accent rings.
class MigaIllustration extends StatelessWidget {
  const MigaIllustration({super.key, required this.image, required this.icon, required this.accent, this.size = 220});
  final String image;
  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .06))),
          FractionallySizedBox(
            widthFactor: .72,
            heightFactor: .72,
            child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .1))),
          ),
          Image.asset(
            MigaImage.path(image),
            width: size * .95,
            height: size * .95,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => MigaHeroIcon(icon: icon, accent: accent, size: size),
          ),
        ],
      ),
    );
  }
}
