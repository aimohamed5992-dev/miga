import 'package:flutter/material.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';

/// Loads a design image from `miga_ui/assets/images/`.
/// Until the real image is dropped in, a branded placeholder is shown instead
/// so every screen stays usable during the design phase.
class MigaImage extends StatelessWidget {
  const MigaImage(this.name, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.borderRadius, this.placeholderIcon});

  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData? placeholderIcon;

  static String path(String name) => 'packages/miga_ui/assets/images/$name';

  @override
  Widget build(BuildContext context) {
    // Uploaded images come from the API (/uploads/… or absolute URLs); demo names are bundled assets.
    final remote = ApiConfig.imageUrl(name);
    if (remote != null) {
      final net = Image.network(
        remote,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _Placeholder(width: width, height: height, icon: placeholderIcon ?? _guessIcon()),
      );
      return borderRadius == null ? net : ClipRRect(borderRadius: borderRadius!, child: net);
    }
    final image = Image.asset(
      path(name),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _Placeholder(width: width, height: height, icon: placeholderIcon ?? _guessIcon()),
    );
    return borderRadius == null ? image : ClipRRect(borderRadius: borderRadius!, child: image);
  }

  IconData _guessIcon() {
    if (name.startsWith('p_')) return Icons.inventory_2_outlined;
    if (name.startsWith('banner') || name.contains('cover')) return Icons.local_offer_outlined;
    if (name.startsWith('cat_')) return Icons.category_outlined;
    if (name.contains('logo')) return Icons.storefront_outlined;
    if (name.startsWith('empty') || name.startsWith('no_')) return Icons.inbox_outlined;
    if (name.contains('map')) return Icons.map_outlined;
    return Icons.image_outlined;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height, required this.icon});
  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [MigaColors.primarySoft, Color(0xFFF7F2F3)]),
      ),
      child: LayoutBuilder(
        builder: (_, c) {
          final size = (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 80) * .35;
          return Center(child: Icon(icon, size: size.clamp(16, 72), color: MigaColors.primary.withValues(alpha: .45)));
        },
      ),
    );
  }
}

/// The MIGA mark. [white] uses the inverted version for red backgrounds.
class MigaLogo extends StatelessWidget {
  const MigaLogo({super.key, this.size = 64, this.white = false});
  final double size;
  final bool white;

  @override
  Widget build(BuildContext context) => Image.asset(MigaImage.path(white ? 'logo_white.png' : 'logo.png'), width: size, height: size);
}
