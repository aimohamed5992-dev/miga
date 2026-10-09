import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/cart_store.dart';

/// Regular (non-campaign) product card with quick add.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});
  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inCampaign = product.activeCampaignId != null;
    return MigaCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MigaImage(product.mainImage, borderRadius: MigaRadius.all(MigaRadius.md)),
                if (inCampaign)
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.sm)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('في حملة', style: t.labelSmall?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(product.nameAr, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(height: 1.3)),
          const Spacer(),
          Row(
            children: [
              Expanded(child: Text(MigaFormat.money(product.price), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Material(
                color: MigaColors.primary,
                borderRadius: MigaRadius.all(MigaRadius.sm),
                child: InkWell(
                  borderRadius: MigaRadius.all(MigaRadius.sm),
                  onTap: () async {
                    try {
                      await CartStore.instance.addProduct(product, 1);
                      if (context.mounted) showMigaMessage(context, 'تمت إضافة ${product.nameAr} للسلة');
                    } catch (e) {
                      if (context.mounted) showMigaError(context, e);
                    }
                  },
                  child: const SizedBox(width: 34, height: 34, child: Icon(Icons.add_rounded, color: Colors.white, size: 20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
