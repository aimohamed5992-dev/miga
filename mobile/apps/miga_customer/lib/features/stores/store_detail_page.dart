import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../campaigns/campaign_detail_page.dart';
import '../products/product_detail_page.dart';
import '../products/product_card.dart';
import 'store_widgets.dart';

class StoreDetailPage extends StatefulWidget {
  const StoreDetailPage({super.key, required this.store});
  final Store store;

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  int _tab = 0;
  String? _productCategory;

  late Store _store = widget.store;
  List<Campaign> _campaigns = [];
  List<Product> _products = [];
  List<ProductCategoryNode> _categories = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = AppServices.api.catalog;
    try {
      final results = await Future.wait([
        api.store(widget.store.id),
        api.campaigns(storeId: widget.store.id, pageSize: 50),
        api.storeProducts(widget.store.id),
        api.storeProductCategories(widget.store.id),
      ]);
      if (!mounted) return;
      setState(() {
        _store = results[0] as Store;
        _campaigns = (results[1] as PagedResult<Campaign>).items;
        _products = (results[2] as PagedResult<Product>).items;
        _categories = results[3] as List<ProductCategoryNode>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _store;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _load),
      );
    }
    final campaigns = _campaigns;
    final products = _products;
    // A main category includes its sub-categories.
    final selected = _categories.where((c) => c.id == _productCategory).firstOrNull;
    final allowed = selected == null ? null : {selected.id, ...selected.children.map((c) => c.id)};
    final shownProducts = products.where((p) => allowed == null || allowed.contains(p.categoryId)).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              stretch: true,
              backgroundColor: MigaColors.surface,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: MigaIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              flexibleSpace: FlexibleSpaceBar(background: MigaImage(s.cover)),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: MigaColors.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StoreLogo(store: s, size: 64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(s.nameAr, style: t.titleLarge),
                                  const SizedBox(width: 6),
                                  if (s.isVerified) const VerifiedBadge(size: 20),
                                ],
                              ),
                              Text(s.categoryName ?? '', style: t.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (s.descriptionAr != null) ...[
                      const SizedBox(height: 12),
                      Text(s.descriptionAr!, style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Stat(value: s.rating.toStringAsFixed(1), label: 'التقييم', icon: Icons.star_rounded, color: MigaColors.gold),
                        _Stat(
                          value: '${s.activeCampaigns}',
                          label: 'حملة نشطة',
                          icon: Icons.local_fire_department_rounded,
                          color: MigaColors.primary,
                        ),
                        _Stat(value: '${s.participants}', label: 'مشارك', icon: Icons.groups_rounded, color: MigaColors.info),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsDelegate(
                tab: _tab,
                onChanged: (i) => setState(() => _tab = i),
                labels: ['الحملات (${campaigns.length})', 'المنتجات (${s.productsCount})'],
              ),
            ),
            if (_tab == 0)
              _loading
                  ? const SliverPadding(padding: EdgeInsets.all(20), sliver: SliverToBoxAdapter(child: MigaTileSkeleton()))
                  : campaigns.isEmpty
                  ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(image: 'empty_campaigns.png', title: 'لا توجد حملات حاليًا'),
                  )
                  : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: campaigns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final c = campaigns[i];
                        return CampaignTile(
                          campaign: c,
                          trailing: c.status == CampaignStatus.active ? CountdownChip(c.timeLeft) : StatusChip.campaign(c.status),
                          onTap: () => migaPush(context, CampaignDetailPage(campaign: c)),
                        );
                      },
                    ),
                  )
            else ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    scrollDirection: Axis.horizontal,
                    children: [
                      MigaChoiceChip(
                        label: 'الكل',
                        selected: _productCategory == null,
                        onSelected: () => setState(() => _productCategory = null),
                      ),
                      for (final c in _categories) ...[
                        const SizedBox(width: 8),
                        MigaChoiceChip(
                          label: c.nameAr,
                          selected: _productCategory == c.id,
                          onSelected: () => setState(() => _productCategory = c.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 262,
                  ),
                  itemCount: shownProducts.length,
                  itemBuilder:
                      (_, i) => ProductCard(
                        product: shownProducts[i],
                        onTap: () => migaPush(context, ProductDetailPage(product: shownProducts[i])),
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon, required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: MigaColors.background, borderRadius: MigaRadius.all(MigaRadius.md)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(icon, size: 18, color: color), const SizedBox(width: 4), Text(value, style: t.titleMedium)],
            ),
            Text(label, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.tab, required this.onChanged, required this.labels});
  final int tab;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: MigaColors.background,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: MigaColors.surfaceMuted, borderRadius: MigaRadius.all(MigaRadius.md)),
        child: Row(
          children: [
            for (final (i, l) in labels.indexed)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == tab ? MigaColors.surface : Colors.transparent,
                      borderRadius: MigaRadius.all(MigaRadius.sm),
                      boxShadow: i == tab ? MigaShadows.card : null,
                    ),
                    child: Text(
                      l,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: i == tab ? MigaColors.primary : MigaColors.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsDelegate old) => old.tab != tab || old.labels != labels;
}
