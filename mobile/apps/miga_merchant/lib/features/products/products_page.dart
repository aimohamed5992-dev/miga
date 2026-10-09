import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../categories/categories_page.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _q = '';
  String? _categoryId;

  static const lowStock = 300;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final roots = data.rootCategories;
        final items =
            data.products.where((p) {
              final inCat =
                  _categoryId == null || p.categoryId == _categoryId || data.childrenOf(_categoryId!).any((c) => c.id == p.categoryId);
              return inCat && p.nameAr.contains(_q.trim());
            }).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text('المنتجات (${data.products.length})'),
            actions: [
              TextButton.icon(
                onPressed: () => migaPush(context, const CategoriesPage()),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text('التصنيفات'),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: MigaSearchBar(hint: 'ابحث في منتجاتك', readOnly: false, onChanged: (v) => setState(() => _q = v)),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    MigaChoiceChip(label: 'الكل', selected: _categoryId == null, onSelected: () => setState(() => _categoryId = null)),
                    for (final c in roots) ...[
                      const SizedBox(width: 8),
                      MigaChoiceChip(label: c.nameAr, selected: _categoryId == c.id, onSelected: () => setState(() => _categoryId = c.id)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child:
                    data.error != null && data.products.isEmpty
                        ? MigaErrorView(offline: data.error is ApiException && (data.error as ApiException).isNetwork, onRetry: data.load)
                        : data.loading && data.products.isEmpty
                        ? ListView(padding: const EdgeInsets.all(20), children: List.generate(5, (_) => const MigaTileSkeleton()))
                        : items.isEmpty
                        ? EmptyState(
                          image: 'empty_orders.png',
                          title: 'لا توجد منتجات',
                          message: 'أضف منتجاتك لتتمكن من إنشاء حملات عليها',
                          actionLabel: 'إضافة منتج',
                          onAction: () => migaPush(context, const ProductFormPage()),
                        )
                        : RefreshIndicator(
                          onRefresh: data.load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final p = items[i];
                              final inCampaign = p.inActiveCampaign;
                              final (stockLabel, stockTone) =
                                  p.stockQuantity == 0
                                      ? ('نفد المخزون', StatusTone.danger)
                                      : p.stockQuantity < lowStock
                                      ? ('مخزون منخفض: ${p.stockQuantity}', StatusTone.warning)
                                      : ('المخزون: ${p.stockQuantity}', StatusTone.neutral);
                              return Opacity(
                                opacity: p.isActive ? 1 : .55,
                                child: MigaCard(
                                  padding: const EdgeInsets.all(10),
                                  onTap: () => migaPush(context, ProductFormPage(existing: p)),
                                  child: Row(
                                    children: [
                                      MigaImage(p.mainImage, width: 76, height: 76, borderRadius: MigaRadius.all(MigaRadius.md)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.nameAr, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text(data.categoryName(p.categoryId), style: t.bodySmall),
                                            const SizedBox(height: 4),
                                            Text(MigaFormat.money(p.price), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                StatusChip(stockLabel, tone: stockTone),
                                                if (inCampaign)
                                                  const StatusChip('في حملة', tone: StatusTone.brand, icon: Icons.campaign_rounded),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: p.isActive,
                                        onChanged: (v) async {
                                          try {
                                            await data.toggleProduct(p, v);
                                          } catch (e) {
                                            if (context.mounted) showMigaError(context, e);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: (i * 40).ms);
                            },
                          ),
                        ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add-product',
            backgroundColor: MigaColors.merchantAccent,
            foregroundColor: Colors.white,
            onPressed: () => migaPush(context, const ProductFormPage()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('منتج جديد'),
          ),
        );
      },
    );
  }
}
