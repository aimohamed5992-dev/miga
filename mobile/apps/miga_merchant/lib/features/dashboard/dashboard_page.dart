import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../campaigns/campaign_wizard_page.dart';
import '../campaigns/merchant_campaign_detail_page.dart';
import '../categories/categories_page.dart';
import '../orders/merchant_order_detail_page.dart';
import '../products/product_form_page.dart';
import '../shell/merchant_shell.dart';
import '../stores/store_switcher.dart';

const _accent = MigaColors.merchantAccent;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _dayNames = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

  final _data = MerchantData.instance;
  Future<MerchantDashboard>? _dashboard;
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _data.addListener(_onStoreChanged);
    _onStoreChanged();
  }

  @override
  void dispose() {
    _data.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Reload when the store switcher changes the current store.
  void _onStoreChanged() {
    if (!_data.hasStores) return;
    final id = _data.currentStore.id;
    if (id == _storeId && _dashboard != null) return;
    setState(() {
      _storeId = id;
      _dashboard = _fetch(id);
    });
  }

  /// Also feeds the "orders" tab badge with the number waiting for the merchant.
  Future<MerchantDashboard> _fetch(String? storeId) => AppServices.api.merchant.dashboard(storeId: storeId).then((d) {
    MerchantShell.newOrders.value = d.ordersNeedingAction.length;
    return d;
  });

  Future<void> _reload() async {
    final next = _fetch(_storeId);
    setState(() => _dashboard = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = Session.instance.account?.fullName.split(' ').first ?? '';
    return Scaffold(
      body: FutureBuilder<MerchantDashboard>(
        future: _dashboard,
        builder: (context, snap) {
          if (snap.hasError || (_data.error != null && !_data.hasStores)) {
            final error = snap.error ?? _data.error!;
            return MigaErrorView(offline: error is ApiException && error.isNetwork, onRetry: () => _data.load().then((_) => _reload()));
          }
          final d = snap.data;
          return RefreshIndicator(
            onRefresh: _reload,
            child: CustomScrollView(
              // Design review: --dart-define=MIGA_SCROLL=700
              controller: ScrollController(initialScrollOffset: const int.fromEnvironment('MIGA_SCROLL').toDouble()),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(child: _data.hasStores ? const StoreSwitcher() : const SizedBox()),
                          MigaNotificationBell(
                            api: AppServices.api.notifications,
                            accent: MigaColors.merchantAccent,
                            emptyMessage: 'سنخبرك فور اكتمال حملاتك ووصول الطلبات المجمّعة',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أهلًا $name 👋', style: t.headlineSmall),
                        Text('إليك ملخص أداء متجرك هذا الأسبوع', style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
                        const SizedBox(height: 16),
                        if (d == null)
                          const MigaTileSkeleton()
                        else
                          _RevenueCard(
                            values: d.days.map((x) => x.$2).toList(),
                            labels: d.days.map((x) => _dayNames[x.$1.weekday - 1]).toList(),
                            total: d.weekTotal,
                            trend: d.trendPercent,
                          ),
                        const SizedBox(height: 12),
                        GridView.count(
                          padding: EdgeInsets.zero,
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.38,
                          children: [
                            StatTile(
                              label: 'حملات نشطة',
                              value: '${d?.activeCampaigns ?? '—'}',
                              icon: Icons.campaign_rounded,
                              color: MigaColors.primary,
                            ),
                            StatTile(
                              label: 'طلبات مجمّعة جارية',
                              value: '${d?.ordersInProgress ?? '—'}',
                              icon: Icons.all_inbox_rounded,
                              color: MigaColors.warning,
                            ),
                            StatTile(
                              label: 'مشاركون في حملاتك',
                              value: '${d?.participants ?? '—'}',
                              icon: Icons.groups_rounded,
                              color: MigaColors.info,
                            ),
                            StatTile(
                              label: 'منتجات',
                              value: '${d?.products ?? '—'}',
                              icon: Icons.inventory_2_rounded,
                              color: MigaColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('إجراءات سريعة', style: t.titleMedium),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _QuickAction(
                              icon: Icons.add_chart_rounded,
                              label: 'حملة جديدة',
                              color: MigaColors.primary,
                              onTap: () => migaPush(context, const CampaignWizardPage()).then((_) => _reload()),
                            ),
                            _QuickAction(
                              icon: Icons.add_box_rounded,
                              label: 'منتج جديد',
                              color: _accent,
                              onTap: () => migaPush(context, const ProductFormPage()),
                            ),
                            _QuickAction(
                              icon: Icons.create_new_folder_rounded,
                              label: 'تصنيف جديد',
                              color: MigaColors.info,
                              onTap: () => migaPush(context, const CategoriesPage()),
                            ),
                            _QuickAction(
                              icon: Icons.local_shipping_rounded,
                              label: 'تسليم طلب',
                              color: MigaColors.success,
                              onTap: () => MerchantShell.goToTab(context, 3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (d != null && d.ordersNeedingAction.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      'طلبات تحتاج إجراء',
                      subtitle: 'حملات اكتملت وتنتظر التجهيز',
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      onAction: () => MerchantShell.goToTab(context, 3),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    sliver: SliverList.separated(
                      itemCount: d.ordersNeedingAction.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OrderTile(order: d.ordersNeedingAction[i], onReturn: _reload),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'الحملات النشطة',
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    onAction: () => MerchantShell.goToTab(context, 1),
                  ),
                ),
                if (d != null && d.activeCampaignList.isEmpty)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child: EmptyState(
                        image: 'empty_campaigns.png',
                        title: 'لا توجد حملات نشطة',
                        message: 'أطلق حملتك الأولى وابدأ البيع بالجملة',
                      ),
                    ),
                  )
                else if (d != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: d.activeCampaignList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final c = d.activeCampaignList[i].campaign;
                        return CampaignTile(
                          campaign: c,
                          trailing: CountdownChip(c.timeLeft),
                          onTap: () => migaPush(context, MerchantCampaignDetailPage(campaignId: c.id)).then((_) => _reload()),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.values, required this.labels, required this.total, this.trend});
  final List<double> values;
  final List<String> labels;
  final double total;
  final int? trend;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مبيعات آخر 7 أيام', style: t.bodySmall),
                    Text(MigaFormat.money(total), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (trend != null)
                StatusChip(
                  '${trend! >= 0 ? '+' : ''}$trend% عن الأسبوع الماضي',
                  tone: trend! >= 0 ? StatusTone.success : StatusTone.warning,
                  icon: trend! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          values.every((v) => v == 0)
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('لا توجد مبيعات هذا الأسبوع بعد', style: t.bodySmall)),
              )
              : MigaBarChart(values: values, labels: labels),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: MigaRadius.all(MigaRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.lg)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onReturn});
  final MerchantOrderView order;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      onTap: () => migaPush(context, MerchantOrderDetailPage(orderId: order.id)).then((_) => onReturn()),
      child: Row(
        children: [
          MigaImage(order.imageUrl ?? '', width: 56, height: 56, borderRadius: MigaRadius.all(MigaRadius.md)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Text('#${order.number}', style: t.titleSmall), const Spacer(), StatusChip.merchantOrder(order.status)]),
                const SizedBox(height: 2),
                Text(order.productName, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${order.totalQuantity} قطعة • ${order.customersCount} عميل • ${MigaFormat.money(order.totalAmount)}',
                  style: t.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
