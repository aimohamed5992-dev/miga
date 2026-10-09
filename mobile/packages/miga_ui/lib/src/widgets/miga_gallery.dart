import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_image.dart';

/// "Open this" arrow for list rows. Always points left: in Arabic, forward is to the left, and the stock
/// chevron flips itself in RTL (it would point right).
class MigaChevron extends StatelessWidget {
  const MigaChevron({super.key, this.color = MigaColors.textHint, this.size = 24});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.chevron_left_rounded, color: color, size: size));
}

/// Swipeable product photos with page dots; tap opens a full-screen, zoomable viewer.
class MigaImageGallery extends StatefulWidget {
  const MigaImageGallery({super.key, required this.images, this.fit = BoxFit.contain, this.heroTag});
  final List<String> images;
  final BoxFit fit;
  final String? heroTag;

  @override
  State<MigaImageGallery> createState() => _MigaImageGalleryState();
}

class _MigaImageGalleryState extends State<MigaImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _FullScreenGallery(images: widget.images, initial: _index),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? [''] : widget.images;
    Widget page(int i) => GestureDetector(onTap: images.first.isEmpty ? null : _open, child: MigaImage(images[i], fit: widget.fit));
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => i == 0 && widget.heroTag != null ? Hero(tag: widget.heroTag!, child: page(i)) : page(i),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? MigaColors.primary : MigaColors.ink.withValues(alpha: .2),
                      borderRadius: MigaRadius.all(MigaRadius.pill),
                    ),
                  ),
              ],
            ),
          ),
        if (images.length > 1)
          PositionedDirectional(
            top: 14,
            end: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: MigaColors.ink.withValues(alpha: .55), borderRadius: MigaRadius.all(MigaRadius.pill)),
              child: Text('${_index + 1} / ${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initial});
  final List<String> images;
  final int initial;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: MigaImage(widget.images[i], fit: BoxFit.contain))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'إغلاق',
                ),
                const Spacer(),
                if (widget.images.length > 1)
                  Text('${_index + 1} / ${widget.images.length}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
