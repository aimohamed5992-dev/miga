import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

class CategoryBubble extends StatelessWidget {
  const CategoryBubble({super.key, required this.category, this.onTap, this.selected = false});
  final StoreCategory category;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: MigaRadius.all(MigaRadius.lg),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? MigaColors.primarySoft : MigaColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? MigaColors.primary : Colors.transparent, width: 1.6),
                boxShadow: MigaShadows.card,
              ),
              child: MigaImage(category.image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(
              category.nameAr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? MigaColors.primary : null),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, required this.store, this.size = 48});
  final Store store;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: MigaShadows.card),
    child: ClipOval(child: MigaImage(store.logo)),
  );
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(Icons.verified_rounded, size: size, color: MigaColors.info);
}

class RatingChip extends StatelessWidget {
  const RatingChip(this.rating, {super.key});
  final double rating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, size: 16, color: MigaColors.gold),
      const SizedBox(width: 2),
      Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

/// Cover + logo store card.
class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, this.onTap, this.width});
  final Store store;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final campaigns = store.activeCampaigns;
    return SizedBox(
      width: width,
      child: MigaCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 86,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  MigaImage(store.cover, borderRadius: const BorderRadius.vertical(top: Radius.circular(MigaRadius.lg))),
                  if (campaigns > 0)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.pill)),
                        child: Text('$campaigns حملات نشطة', style: t.labelSmall?.copyWith(color: Colors.white)),
                      ),
                    ),
                  PositionedDirectional(bottom: -22, start: 12, child: StoreLogo(store: store, size: 48)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 26, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(store.nameAr, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                      if (store.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge()],
                      const Spacer(),
                      RatingChip(store.rating),
                    ],
                  ),
                  Text(store.categoryName ?? '', style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
