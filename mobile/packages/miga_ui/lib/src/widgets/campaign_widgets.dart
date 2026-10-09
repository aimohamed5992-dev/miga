import 'package:flutter/material.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_format.dart';
import 'miga_image.dart';

/// The heart of MIGA: how close a campaign is to its target (e.g. 73/100).
class CampaignProgress extends StatelessWidget {
  const CampaignProgress({super.key, required this.current, required this.target, this.compact = false, this.showLabels = true});
  final int current;
  final int target;
  final bool compact;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final done = p >= 1;
    final color = done ? MigaColors.success : MigaColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabels)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Scales down instead of overflowing on narrow cards / large text settings.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$current',
                            style: (compact ? t.labelMedium : t.titleSmall)?.copyWith(color: color, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' / $target قطعة', style: compact ? t.labelSmall : t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  done ? 'اكتملت ✓' : '${(p * 100).round()}%',
                  style: (compact ? t.labelSmall : t.labelMedium)?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: p),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder:
              (_, v, __) => LayoutBuilder(
                builder:
                    (_, c) => Container(
                      height: compact ? 6 : 10,
                      decoration: BoxDecoration(color: MigaColors.surfaceMuted, borderRadius: MigaRadius.all(MigaRadius.pill)),
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: c.maxWidth * v,
                        decoration: BoxDecoration(
                          borderRadius: MigaRadius.all(MigaRadius.pill),
                          gradient: LinearGradient(
                            colors: done ? [MigaColors.success, const Color(0xFF34C77B)] : [MigaColors.primaryLight, MigaColors.primary],
                          ),
                        ),
                      ),
                    ),
              ),
        ),
      ],
    );
  }
}

/// Campaign price + struck-through original price.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price, this.originalPrice, this.large = false});
  final double price;
  final double? originalPrice;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          MigaFormat.money(price),
          style: (large ? t.headlineSmall : t.titleMedium)?.copyWith(color: MigaColors.primary, fontWeight: FontWeight.w800),
        ),
        if (originalPrice != null && originalPrice! > price)
          Text(
            MigaFormat.money(originalPrice!),
            style: (large ? t.bodyMedium : t.labelSmall)?.copyWith(
              color: MigaColors.textHint,
              decoration: TextDecoration.lineThrough,
              decorationColor: MigaColors.textHint,
            ),
          ),
      ],
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge(this.percent, {super.key});
  final int percent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.sm)),
    child: Text('-$percent%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

class CountdownChip extends StatelessWidget {
  const CountdownChip(this.timeLeft, {super.key, this.dark = false});
  final Duration timeLeft;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final urgent = timeLeft.inHours < 24;
    final fg = dark ? Colors.white : (urgent ? MigaColors.error : MigaColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: .55) : (urgent ? MigaColors.errorSoft : MigaColors.surfaceMuted),
        borderRadius: MigaRadius.all(MigaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(MigaFormat.countdown(timeLeft), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Vertical campaign card for grids / horizontal lists.
class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign, this.onTap, this.width});
  final Campaign campaign;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = campaign;
    return SizedBox(
      width: width,
      child: Material(
        color: MigaColors.surface,
        borderRadius: MigaRadius.all(MigaRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: MigaRadius.all(MigaRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(tag: 'campaign-${c.id}', child: MigaImage(c.product.mainImage, borderRadius: MigaRadius.all(MigaRadius.md))),
                      PositionedDirectional(top: 8, start: 8, child: DiscountBadge(c.discountPercent)),
                      PositionedDirectional(bottom: 8, start: 8, child: CountdownChip(c.timeLeft, dark: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(c.product.nameAr, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(height: 1.3)),
                const SizedBox(height: 6),
                PriceTag(price: c.campaignPrice, originalPrice: c.originalPrice),
                const SizedBox(height: 8),
                CampaignProgress(current: c.currentQuantity, target: c.targetQuantity, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal campaign tile for lists.
class CampaignTile extends StatelessWidget {
  const CampaignTile({super.key, required this.campaign, this.onTap, this.trailing});
  final Campaign campaign;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = campaign;
    return Material(
      color: MigaColors.surface,
      borderRadius: MigaRadius.all(MigaRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: MigaRadius.all(MigaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              MigaImage(c.product.mainImage, width: 92, height: 92, borderRadius: MigaRadius.all(MigaRadius.md)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.product.nameAr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall)),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 4),
                    PriceTag(price: c.campaignPrice, originalPrice: c.originalPrice),
                    const SizedBox(height: 8),
                    CampaignProgress(current: c.currentQuantity, target: c.targetQuantity, compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.small = false});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = small ? 30.0 : 40.0;
    Widget btn(IconData i, bool enabled, VoidCallback f) => Material(
      color: enabled ? MigaColors.primarySoft : MigaColors.surfaceMuted,
      borderRadius: MigaRadius.all(MigaRadius.sm),
      child: InkWell(
        onTap: enabled ? f : null,
        borderRadius: MigaRadius.all(MigaRadius.sm),
        child: SizedBox(width: s, height: s, child: Icon(i, size: s * .5, color: enabled ? MigaColors.primary : MigaColors.textHint)),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.add_rounded, value < max, () => onChanged(value + 1)),
        SizedBox(
          width: small ? 32 : 44,
          child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        btn(Icons.remove_rounded, value > min, () => onChanged(value - 1)),
      ],
    );
  }
}
