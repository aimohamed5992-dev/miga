import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import 'store_detail_page.dart';
import 'store_widgets.dart';

/// Store categories (أقسام المتاجر) with the stores of the selected one.
class CategoryStoresPage extends StatefulWidget {
  const CategoryStoresPage({super.key, this.initialCategoryId});
  final String? initialCategoryId;

  @override
  State<CategoryStoresPage> createState() => _CategoryStoresPageState();
}

class _CategoryStoresPageState extends State<CategoryStoresPage> {
  late String? _categoryId = widget.initialCategoryId;
  final Future<List<StoreCategory>> _categories = AppServices.api.catalog.storeCategories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأقسام والمتاجر')),
      body: Column(
        children: [
          SizedBox(
            height: 108,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              scrollDirection: Axis.horizontal,
              children: [
                _AllBubble(selected: _categoryId == null, onTap: () => setState(() => _categoryId = null)),
                FutureBuilder<List<StoreCategory>>(
                  future: _categories,
                  builder:
                      (context, snap) => Row(
                        children: [
                          for (final c in snap.data ?? const <StoreCategory>[]) ...[
                            const SizedBox(width: 14),
                            CategoryBubble(category: c, selected: _categoryId == c.id, onTap: () => setState(() => _categoryId = c.id)),
                          ],
                        ],
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            // Loaded from the API: skeleton → list → offline/error with retry.
            child: MigaAsync<List<Store>>(
              key: ValueKey(_categoryId),
              load: () async => (await AppServices.api.catalog.stores(categoryId: _categoryId)).items,
              builder:
                  (context, stores) =>
                      stores.isEmpty
                          ? const EmptyState(
                            image: 'empty_campaigns.png',
                            title: 'لا توجد متاجر بعد',
                            message: 'سيتم إضافة متاجر لهذا القسم قريبًا',
                          )
                          : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: stores.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder:
                                (_, i) => StoreCard(
                                  store: stores[i],
                                  onTap: () => migaPush(context, StoreDetailPage(store: stores[i])),
                                ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: .1),
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllBubble extends StatelessWidget {
  const _AllBubble({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: MigaRadius.all(MigaRadius.lg),
    child: SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: selected ? MigaColors.primary : MigaColors.surface,
              shape: BoxShape.circle,
              boxShadow: MigaShadows.card,
            ),
            child: Icon(Icons.apps_rounded, color: selected ? Colors.white : MigaColors.primary, size: 30),
          ),
          const SizedBox(height: 6),
          Text('الكل', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? MigaColors.primary : null)),
        ],
      ),
    ),
  );
}
