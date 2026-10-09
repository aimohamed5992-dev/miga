import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Aggregated order for the merchant: New → Confirmed → Preparing → Ready (drivers come with the pickup code)
/// → Completed once every delivery has left the warehouse.
class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<MerchantOrderDetailPage> createState() => _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends State<MerchantOrderDetailPage> {
  MerchantOrderDetailView? _d;
  Object? _error;
  bool _busy = false;

  static const _flow = [
    MerchantOrderStatus.sentToMerchant,
    MerchantOrderStatus.confirmed,
    MerchantOrderStatus.preparing,
    MerchantOrderStatus.ready,
    MerchantOrderStatus.completed,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppServices.api.merchant.order(widget.orderId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  MerchantOrderStatus get _status => _d!.order.status;
  int get _stage => _flow.indexOf(_status == MerchantOrderStatus.pending ? MerchantOrderStatus.sentToMerchant : _status);

  (String, IconData, String)? get _nextAction => switch (_status) {
    MerchantOrderStatus.pending ||
    MerchantOrderStatus.sentToMerchant => ('تأكيد استلام الطلب', Icons.check_circle_outline_rounded, 'confirm'),
    MerchantOrderStatus.confirmed => ('بدء التجهيز', Icons.inventory_2_outlined, 'start-preparing'),
    MerchantOrderStatus.preparing => ('الطلب جاهز للاستلام', Icons.task_alt_rounded, 'ready'),
    _ => null,
  };

  Future<void> _advance(String action) async {
    setState(() => _busy = true);
    try {
      final d = await AppServices.api.merchant.advanceOrder(widget.orderId, action);
      if (!mounted) return;
      setState(() => _d = d);
      if (d.order.status == MerchantOrderStatus.ready) showMigaMessage(context, 'تم إشعار المندوبين القريبين بالاستلام');
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _load),
      );
    }
    final d = _d;
    if (d == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final o = d.order;
    const titles = ['وصل الطلب', 'تم التأكيد', 'قيد التجهيز', 'جاهز للاستلام', 'سُلّم للمندوبين'];
    const icons = [
      Icons.all_inbox_rounded,
      Icons.check_rounded,
      Icons.inventory_2_rounded,
      Icons.storefront_rounded,
      Icons.local_shipping_rounded,
    ];
    final action = _nextAction;
    final pickedUp =
        d.deliveries.where((x) => x.status.value >= DeliveryStatus.pickedUp.value && x.status != DeliveryStatus.cancelled).length;

    return Scaffold(
      appBar: AppBar(title: Text('طلب مجمّع #${o.number}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            MigaCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      MigaImage(o.imageUrl ?? '', width: 64, height: 64, borderRadius: MigaRadius.all(MigaRadius.md)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.productName, style: t.titleSmall),
                            Text('حملة: ${o.campaignTitle}', style: t.bodySmall),
                            const SizedBox(height: 4),
                            StatusChip.merchantOrder(o.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: MigaColors.merchantAccent, borderRadius: MigaRadius.all(MigaRadius.md)),
                    child: Row(
                      children: [
                        _Big(value: '${o.totalQuantity}', label: 'إجمالي القطع'),
                        _Big(value: '${o.customersCount}', label: 'عميل'),
                        _Big(value: '${d.districts.length}', label: 'أحياء'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (o.status == MerchantOrderStatus.ready) ...[
              const SizedBox(height: 12),
              // Drivers type this code in their app at pickup — it proves they were at the warehouse.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MigaColors.background,
                  borderRadius: MigaRadius.all(MigaRadius.lg),
                  border: Border.all(color: MigaColors.border),
                ),
                child: Column(
                  children: [
                    Text('رمز الاستلام — أعطه للمندوب ليدخله في تطبيقه', style: t.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      d.pickupCode,
                      style: t.displayMedium?.copyWith(letterSpacing: 8, color: MigaColors.merchantAccent, fontWeight: FontWeight.w800),
                    ),
                    Text('استلم المندوبون $pickedUp من ${d.deliveries.length} توصيلات', style: t.labelMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            MigaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مراحل الطلب', style: t.titleMedium),
                  const SizedBox(height: 14),
                  MigaTimeline(
                    accent: MigaColors.merchantAccent,
                    steps: [
                      for (var i = 0; i < titles.length; i++)
                        TimelineStep(
                          title: titles[i],
                          icon: icons[i],
                          time: switch (i) {
                            0 => MigaFormat.date(o.createdAt),
                            1 when d.confirmedAt != null => MigaFormat.date(d.confirmedAt!),
                            3 when d.readyAt != null => MigaFormat.date(d.readyAt!),
                            4 when d.completedAt != null => MigaFormat.date(d.completedAt!),
                            _ => null,
                          },
                          state:
                              _status == MerchantOrderStatus.completed || i < _stage
                                  ? TimelineState.done
                                  : i == _stage
                                  ? TimelineState.current
                                  : TimelineState.upcoming,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MigaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التوزيع حسب الحي', style: t.titleMedium),
                  Text('جهّز الكميات في دفعات حسب الحي لتسريع التوصيل', style: t.bodySmall),
                  const SizedBox(height: 10),
                  for (final b in d.districts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: MigaColors.textSecondary),
                          const SizedBox(width: 6),
                          SizedBox(width: 70, child: Text(b.district, style: t.bodyMedium)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: MigaRadius.all(MigaRadius.pill),
                              child: LinearProgressIndicator(
                                value: o.totalQuantity == 0 ? 0 : b.quantity / o.totalQuantity,
                                minHeight: 8,
                                color: MigaColors.merchantAccent,
                                backgroundColor: MigaColors.surfaceMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 64,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${b.quantity} قطعة', style: t.labelMedium),
                                Text('${b.customers} عميل', style: t.labelSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MigaCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final (i, x) in d.deliveries.indexed) ...[
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined, color: MigaColors.textSecondary),
                      title: Text('#${x.number} • ${x.district}', style: t.titleSmall),
                      subtitle: Text('${x.quantity} قطعة • ${x.driverName ?? 'بانتظار مندوب'}', style: t.bodySmall),
                      trailing: StatusChip.delivery(x.status),
                    ),
                    if (i < d.deliveries.length - 1) const Divider(indent: 56),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            MigaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المستحقات', style: t.titleMedium),
                  const SizedBox(height: 8),
                  InfoRow('إجمالي المبيعات', MigaFormat.money(o.totalAmount)),
                  InfoRow('عمولة ميجا', '- ${MigaFormat.money(d.platformFee)}', valueColor: MigaColors.error),
                  const Divider(height: 18),
                  InfoRow('صافي المستحق', MigaFormat.money(d.netAmount), bold: true, valueColor: MigaColors.success),
                  Text('يُضاف للمحفظة بعد تسليم جميع الطلبات للعملاء', style: t.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          action == null
              ? null
              : Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
                child: SafeArea(
                  top: false,
                  child: MigaButton(label: action.$1, icon: action.$2, loading: _busy, onPressed: () => _advance(action.$3)),
                ),
              ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(label, style: t.labelSmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}
