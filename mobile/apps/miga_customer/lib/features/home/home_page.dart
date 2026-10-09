import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/address_store.dart';
import '../../core/services.dart';
import '../addresses/add_address_page.dart';
import '../campaigns/campaign_detail_page.dart';
import '../campaigns/campaigns_page.dart';
import '../products/product_detail_page.dart';
import '../search/search_page.dart';
import '../stores/category_stores_page.dart';
import '../stores/store_detail_page.dart';
import '../stores/store_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> _home = AppServices.api.catalog.home();

  Future<void> _reload() async {
    final next = AppServices.api.catalog.home();
    setState(() => _home = next);
    await next;
  }

  void _openCampaign(BuildContext context, Campaign c) => migaPush(context, CampaignDetailPage(campaign: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<HomeData>(
        future: _home,
        builder: (context, snap) {
          if (snap.hasError) {
            return MigaErrorView(offline: snap.error is ApiException && (snap.error as ApiException).isNetwork, onRetry: _reload);
          }
          final home = snap.data;
          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              // Design review: --dart-define=MIGA_SCROLL=900
              controller: ScrollController(initialScrollOffset: const int.fromEnvironment('MIGA_SCROLL').toDouble()),
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: MigaSearchBar(
                      onTap: () => migaPush(context, const SearchPage()),
                      trailing: const Icon(Icons.tune_rounded, color: MigaColors.textSecondary),
                    ),
                  ),
                ),
                if (home == null || home.banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child:
                        home == null
                            ? const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16), child: MigaTileSkeleton())
                            : _BannerCarousel(banners: home.banners),
                  ),
                const SliverToBoxAdapter(child: _HowItWorks()),
                if (home == null)
                  const SliverPadding(
                    padding: EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(child: Column(children: [MigaTileSkeleton(), SizedBox(height: 10), MigaTileSkeleton()])),
                  )
                else ...[
                  SliverToBoxAdapter(child: SectionHeader('الأقسام', onAction: () => migaPush(context, const CategoryStoresPage()))),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 112,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        scrollDirection: Axis.horizontal,
                        itemCount: home.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final c = home.categories[i];
                          return CategoryBubble(category: c, onTap: () => migaPush(context, CategoryStoresPage(initialCategoryId: c.id)));
                        },
                      ),
                    ),
                  ),
                  if (home.endingSoon.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        'تنتهي قريبًا ⏰',
                        subtitle: 'الحق عليها قبل انتهاء الوقت',
                        onAction: () => migaPush(context, const CampaignsPage(initialFilter: CampaignFilter.endingSoon, standalone: true)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 318,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          scrollDirection: Axis.horizontal,
                          itemCount: home.endingSoon.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder:
                              (_, i) => CampaignCard(
                                campaign: home.endingSoon[i],
                                width: 176,
                                onTap: () => _openCampaign(context, home.endingSoon[i]),
                              ),
                        ),
                      ),
                    ),
                  ],
                  if (home.almostComplete.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        'قاربت على الاكتمال 🔥',
                        subtitle: 'انضم الآن وكن من المكملين',
                        onAction:
                            () => migaPush(context, const CampaignsPage(initialFilter: CampaignFilter.almostComplete, standalone: true)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverList.separated(
                        itemCount: home.almostComplete.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder:
                            (_, i) => CampaignTile(
                              campaign: home.almostComplete[i],
                              trailing: Text(
                                'باقي ${home.almostComplete[i].remainingQuantity}',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(color: MigaColors.primary, fontWeight: FontWeight.w800),
                              ),
                              onTap: () => _openCampaign(context, home.almostComplete[i]),
                            ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: SectionHeader('متاجر مميزة', onAction: () => migaPush(context, const CategoryStoresPage()))),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 178,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        scrollDirection: Axis.horizontal,
                        itemCount: home.featuredStores.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final s = home.featuredStores[i];
                          return StoreCard(store: s, width: 250, onTap: () => migaPush(context, StoreDetailPage(store: s)));
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader('كل الحملات', onAction: () => migaPush(context, const CampaignsPage(standalone: true))),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 300,
                      ),
                      itemCount: home.latest.length,
                      itemBuilder: (_, i) => CampaignCard(campaign: home.latest[i], onTap: () => _openCampaign(context, home.latest[i])),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  Future<void> _pickAddress(BuildContext context) => showModalBottomSheet(
    context: context,
    builder:
        (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التوصيل إلى', style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final a in AddressStore.instance.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MigaCard(
                      border: true,
                      onTap: () async {
                        Navigator.pop(c);
                        if (!a.isDefault) {
                          try {
                            await AddressStore.instance.makeDefault(a.id);
                          } catch (e) {
                            if (context.mounted) showMigaError(context, e);
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Icon(a.isDefault ? Icons.home_rounded : Icons.work_rounded, color: MigaColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.addressName, style: Theme.of(c).textTheme.titleSmall),
                                Text(a.summary, style: Theme.of(c).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (a.isDefault) const Icon(Icons.check_circle_rounded, color: MigaColors.primary),
                        ],
                      ),
                    ),
                  ),
                MigaButton(
                  label: 'إضافة عنوان جديد',
                  icon: Icons.add_location_alt_outlined,
                  variant: MigaButtonVariant.soft,
                  onPressed: () {
                    Navigator.pop(c);
                    migaPush(context, const AddAddressPage());
                  },
                ),
              ],
            ),
          ),
        ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: AddressStore.instance, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final address = AddressStore.instance.defaultAddress;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            const MigaLogo(size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => address == null ? migaPush(context, const AddAddressPage()) : _pickAddress(context),
                borderRadius: MigaRadius.all(MigaRadius.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('التوصيل إلى', style: t.labelSmall),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address == null ? 'أضف عنوان التوصيل' : '${address.addressName} - ${address.districtName}',
                            style: t.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: MigaColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            MigaNotificationBell(api: AppServices.api.notifications, emptyMessage: 'سنخبرك فور اكتمال حملاتك أو تحديث طلباتك'),
          ],
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});
  final List<HomeBanner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: .9);
  int _index = 0;
  Timer? _timer;
  bool _opening = false;

  List<HomeBanner> get _banners => widget.banners;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || _banners.length < 2) return;
      _controller.animateToPage((_index + 1) % _banners.length, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Opens what the admin linked the slide to (the detail pages need the full object, so it's fetched first).
  Future<void> _open(HomeBanner b) async {
    final id = b.linkId;
    if (id == null || b.linkType == 'none' || _opening) return;
    setState(() => _opening = true);
    try {
      final api = AppServices.api.catalog;
      final Widget page = switch (b.linkType) {
        'campaign' => CampaignDetailPage(campaign: (await api.campaign(id)).campaign),
        'product' => ProductDetailPage(product: (await api.product(id)).product),
        'store' => StoreDetailPage(store: await api.store(id)),
        'storeCategory' => CategoryStoresPage(initialCategoryId: id),
        _ => const SizedBox.shrink(),
      };
      if (mounted) migaPush(context, page);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final b = _banners[i];
              final bundled = !b.imageUrl.startsWith('/') && !b.imageUrl.startsWith('http');
              final hasText = b.title != null || b.subtitle != null;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () => _open(b),
                  child: ClipRRect(
                    borderRadius: MigaRadius.all(MigaRadius.xl),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Bundled banners keep their subject on the right; mirror so it sits on the left in RTL and leaves
                        // room for text. Uploaded banners are shown as the admin designed them.
                        bundled ? Transform.flip(flipX: true, child: MigaImage(b.imageUrl)) : MigaImage(b.imageUrl),
                        if (hasText)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [Color(0xE6FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
                                stops: [0, .45, .75],
                              ),
                            ),
                          ),
                        if (hasText)
                          Padding(
                            padding: const EdgeInsets.all(18),
                            // Fixed-height banner: shrink the copy rather than overflow with large text settings.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.sm)),
                                    child: Text('عرض جماعي', style: t.labelSmall?.copyWith(color: Colors.white)),
                                  ),
                                  const SizedBox(height: 8),
                                  if (b.title != null) Text(b.title!, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  if (b.subtitle != null)
                                    SizedBox(
                                      width: 170,
                                      child: Text(b.subtitle!, style: t.bodySmall?.copyWith(color: MigaColors.textPrimary)),
                                    ),
                                  if (b.linkType != 'none') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: MigaColors.ink, borderRadius: MigaRadius.all(MigaRadius.pill)),
                                      child: Text(b.buttonLabel ?? 'تسوّق الآن', style: t.labelSmall?.copyWith(color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (_opening && i == _index)
                          const ColoredBox(color: Color(0x33FFFFFF), child: Center(child: CircularProgressIndicator())),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (_banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? MigaColors.primary : MigaColors.border,
                  borderRadius: MigaRadius.all(MigaRadius.pill),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const steps = [
      (Icons.group_add_rounded, 'انضم وادفع'),
      (Icons.donut_large_rounded, 'تكتمل الحملة'),
      (Icons.local_shipping_rounded, 'يوصلك الطلب'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: MigaColors.primarySoft, borderRadius: MigaRadius.all(MigaRadius.lg)),
        child: Row(
          children: [
            for (final (i, s) in steps.indexed) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(s.$1, color: MigaColors.primary, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(s.$2, style: t.labelSmall?.copyWith(color: MigaColors.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (i < steps.length - 1) const Icon(Icons.arrow_forward_rounded, size: 16, color: MigaColors.primaryLight),
            ],
          ],
        ),
      ),
    );
  }
}
