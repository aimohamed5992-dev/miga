import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';

enum MigaButtonVariant { primary, outline, soft, dark, text }

class MigaButton extends StatelessWidget {
  const MigaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = MigaButtonVariant.primary,
    this.loading = false,
    this.expanded = true,
    this.height = 54,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final MigaButtonVariant variant;
  final bool loading;
  final bool expanded;
  final double height;

  /// Overrides the primary fill (e.g. merchant navy, driver teal).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (variant) {
      MigaButtonVariant.primary => (
        color ?? Theme.of(context).colorScheme.primary,
        (color ?? Colors.black).computeLuminance() > .7 ? MigaColors.ink : Colors.white,
        BorderSide.none,
      ),
      MigaButtonVariant.outline => (
        Colors.transparent,
        color ?? Theme.of(context).colorScheme.primary,
        BorderSide(color: color ?? Theme.of(context).colorScheme.primary, width: 1.4),
      ),
      MigaButtonVariant.soft => (MigaColors.primarySoft, MigaColors.primary, BorderSide.none),
      MigaButtonVariant.dark => (MigaColors.ink, Colors.white, BorderSide.none),
      MigaButtonVariant.text => (Colors.transparent, color ?? Theme.of(context).colorScheme.primary, BorderSide.none),
    };

    final child =
        loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
            : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            );

    return SizedBox(
      width: expanded ? double.infinity : null,
      height: height,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null && variant == MigaButtonVariant.primary ? MigaColors.border : bg,
          foregroundColor: fg,
          disabledForegroundColor: MigaColors.textHint,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: Theme.of(context).textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.md), side: side),
        ),
        child: child,
      ),
    );
  }
}

/// Small round icon button used in app bars and over images.
class MigaIconButton extends StatelessWidget {
  const MigaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badge,
    this.background = MigaColors.surface,
    this.color = MigaColors.textPrimary,
    this.size = 44,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final int? badge;
  final Color background;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, color: color, size: size * .5)),
          ),
        ),
        if (badge != null && badge! > 0)
          PositionedDirectional(
            top: -2,
            end: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: MigaColors.primary,
                borderRadius: MigaRadius.all(MigaRadius.pill),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
