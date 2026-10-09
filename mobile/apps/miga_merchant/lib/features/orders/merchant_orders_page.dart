import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import 'merchant_order_detail_page.dart';

/// Aggregated orders (MerchantOrder) — one per completed campaign.
class MerchantOrdersPage extends StatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  State<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends State<MerchantOrdersPage> {
  int _tab = 0;
  int _reload = 0;

  static const _tabs = [('new', 'جديدة'), ('preparing', 'قيد التجهيز'), ('ready', 'جاهزة'), ('done', 'مكتملة')];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات المجمّعة')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, tab) in _tabs.indexed) ...[
                  Center(child: MigaChoiceChip(label: tab.$2, selected: i == _tab, onSelected: () => setState(() => _tab = i))),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: MigaAsync<List<MerchantOrderView>>(
              key: ValueKey('$_tab-$_reload'),
              load: () => AppServices.api.merchant.orders(_tabs[_tab].$1),
              builder:
                  (context, items) =>
                      items.isEmpty
                          ? const EmptyState(
                            image: 'merchant_order_ready.png',
                            title: 'لا توجد طلبات هنا',
                            message: 'عند اكتمال أي حملة يصلك طلب مجمّع واحد بالكمية الكاملة',
                          )
                          : RefreshIndicator(
                            onRefresh: () async => setState(() => _reload++),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder:
                                  (_, i) => _OrderCard(
                                    order: items[i],
                                    onReturn: () => setState(() => _reload++),
                                  ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: .06),
                            ),
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onReturn});
  final MerchantOrderView order;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = order;
    return MigaCard(
      onTap: () => migaPush(context, MerchantOrderDetailPage(orderId: o.id)).then((_) => onReturn()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${o.number}', style: t.titleSmall),
              const SizedBox(width: 8),
              Text(MigaFormat.timeAgo(o.createdAt), style: t.bodySmall),
              const Spacer(),
              StatusChip.merchantOrder(o.status),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              MigaImage(o.imageUrl ?? '', width: 60, height: 60, borderRadius: MigaRadius.all(MigaRadius.md)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.productName, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(o.storeName, style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Fig(value: '${o.totalQuantity}', label: 'قطعة'),
              _Fig(value: '${o.customersCount}', label: 'عميل'),
              _Fig(value: MigaFormat.money(o.totalAmount), label: 'الإجمالي'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: MigaColors.background, borderRadius: MigaRadius.all(MigaRadius.md)),
        child: Column(children: [FittedBox(child: Text(value, style: t.titleSmall)), Text(label, style: t.labelSmall)]),
      ),
    );
  }
}
