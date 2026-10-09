import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/cart_store.dart';
import '../../core/services.dart';
import '../campaigns/campaign_detail_page.dart';
import '../stores/store_detail_page.dart';
import '../stores/store_widgets.dart';

/// Regular product (Product order type). Promotes the group campaign when one exists.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});
  final Product product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _qty = 1;
  ProductDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppServices.api.catalog.product(widget.product.id);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = _detail?.product ?? widget.product;
    // StoreDetailPage loads the full store itself; a stub with id + name is enough to open it.
    final store = Store(id: p.storeId, nameAr: p.storeName ?? '', categoryId: '', logo: '', cover: '');
    final campaign = _detail?.activeCampaign;
    final inStock = p.stockQuantity > 0;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: MigaColors.surface,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: MigaIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: MigaColors.surface,
                  padding: const EdgeInsets.fromLTRB(40, 90, 40, 16),
                  child: MigaImageGallery(images: p.images),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList.list(
                children: [
                  Text(p.categoryName ?? '', style: t.labelMedium?.copyWith(color: MigaColors.primary)),
                  const SizedBox(height: 4),
                  Text(p.nameAr, style: t.headlineSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(MigaFormat.money(p.price), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      StatusChip(inStock ? 'متوفر' : 'نفد المخزون', tone: inStock ? StatusTone.success : StatusTone.danger),
                    ],
                  ),
                  if (campaign != null) ...[
                    const SizedBox(height: 16),
                    // Upsell: same product cheaper through group buying.
                    InkWell(
                      onTap: () => migaPush(context, CampaignDetailPage(campaign: campaign)),
                      borderRadius: MigaRadius.all(MigaRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: MigaColors.primaryGradient,
                          borderRadius: MigaRadius.all(MigaRadius.lg),
                          boxShadow: MigaShadows.glow(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded, color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اشترِه بـ ${MigaFormat.money(campaign.campaignPrice)} مع الجماعة!',
                                    style: t.titleSmall?.copyWith(color: Colors.white),
                                  ),
                                  Text(
                                    'وفّر ${campaign.discountPercent}% • باقي ${campaign.remainingQuantity} قطعة لاكتمال الحملة',
                                    style: t.bodySmall?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            const MigaChevron(color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  MigaCard(
                    onTap: () => migaPush(context, StoreDetailPage(store: store)),
                    child: Row(
                      children: [
                        StoreLogo(store: store, size: 42),
                        const SizedBox(width: 12),
                        Expanded(child: Text(store.nameAr, style: t.titleSmall)),
                        const MigaChevron(color: MigaColors.textHint),
                      ],
                    ),
                  ),
                  if (p.descriptionAr != null) ...[
                    const SizedBox(height: 16),
                    Text('الوصف', style: t.titleMedium),
                    const SizedBox(height: 6),
                    Text(p.descriptionAr!, style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary, height: 1.7)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          color: MigaColors.surface,
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
        ),
        child: Row(
          children: [
            QuantityStepper(value: _qty, max: p.stockQuantity.clamp(1, 99), onChanged: (v) => setState(() => _qty = v), small: true),
            const SizedBox(width: 12),
            Expanded(
              child: MigaButton(
                label: 'أضف للسلة • ${MigaFormat.money(p.price * _qty)}',
                variant: MigaButtonVariant.dark,
                icon: Icons.shopping_bag_outlined,
                onPressed:
                    inStock
                        ? () async {
                          try {
                            await CartStore.instance.addProduct(p, _qty);
                            if (context.mounted) showMigaMessage(context, 'تمت إضافة $_qty إلى السلة');
                          } catch (e) {
                            if (context.mounted) showMigaError(context, e);
                          }
                        }
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
