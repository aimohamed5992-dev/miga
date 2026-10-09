import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../shell/customer_shell.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tab = 0;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: MigaColors.primary,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: MigaColors.surface,
                  side: const BorderSide(color: MigaColors.border),
                ),
                segments: const [ButtonSegment(value: 0, label: Text('الحالية')), ButtonSegment(value: 1, label: Text('السابقة'))],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: MigaAsync<List<OrderSummary>>(
              key: ValueKey('$_tab-$_reload'),
              load: () async => (await AppServices.api.customer.orders(past: _tab == 1)).items,
              builder:
                  (context, orders) =>
                      orders.isEmpty
                          ? EmptyState(
                            image: 'empty_orders.png',
                            title: _tab == 0 ? 'لا توجد طلبات حالية' : 'لا توجد طلبات سابقة',
                            message: 'انضم لحملة وتابع طلبك من هنا',
                            actionLabel: 'تصفّح الحملات',
                            onAction: () => CustomerShell.goToTab(context, 1),
                          )
                          : RefreshIndicator(
                            onRefresh: () async => setState(() => _reload++),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder:
                                  (_, i) => OrderCard(
                                    order: orders[i],
                                    onChanged: () => setState(() => _reload++),
                                  ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: .08),
                            ),
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onChanged});
  final OrderSummary order;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = order;
    final waiting = o.campaignStatus == CampaignStatus.active && o.status == CampaignOrderStatus.paid;
    return MigaCard(
      onTap: () async {
        await migaPush(context, OrderDetailPage(orderId: o.id));
        onChanged?.call();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${o.number}', style: t.titleSmall),
              const SizedBox(width: 8),
              Text(MigaFormat.date(o.createdAt), style: t.bodySmall),
              const Spacer(),
              StatusChip.order(o.status),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              MigaImage(o.imageUrl ?? '', width: 64, height: 64, borderRadius: MigaRadius.all(MigaRadius.md)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.productName, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('الكمية: ${o.quantity} • ${o.storeName}', style: t.bodySmall),
                    const SizedBox(height: 4),
                    Text(MigaFormat.money(o.totalAmount), style: t.titleSmall?.copyWith(color: MigaColors.primary)),
                  ],
                ),
              ),
              const MigaChevron(color: MigaColors.textHint),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: MigaColors.background, borderRadius: MigaRadius.all(MigaRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بانتظار اكتمال الحملة • باقي ${o.remaining} قطعة', style: t.labelMedium?.copyWith(color: MigaColors.primary)),
                  const SizedBox(height: 6),
                  CampaignProgress(current: o.campaignCurrent, target: o.campaignTarget, compact: true, showLabels: false),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
