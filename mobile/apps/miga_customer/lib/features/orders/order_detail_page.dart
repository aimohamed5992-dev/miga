import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Live order tracking: Paid → Campaign complete → Preparing → Out for delivery → Delivered (or refunded).
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<OrderDetail> _order = AppServices.api.customer.order(widget.orderId);

  Future<void> _reload() async {
    final next = AppServices.api.customer.order(widget.orderId);
    setState(() => _order = next);
    await next;
  }

  static const _flow = [
    CampaignOrderStatus.paid,
    CampaignOrderStatus.confirmed,
    CampaignOrderStatus.preparing,
    CampaignOrderStatus.outForDelivery,
    CampaignOrderStatus.delivered,
  ];

  List<TimelineStep> _steps(OrderDetail d) {
    final o = d.order;
    if (o.status == CampaignOrderStatus.refunded || o.status == CampaignOrderStatus.cancelled) {
      return [
        TimelineStep(
          title: 'تم الدفع',
          subtitle: MigaFormat.money(o.totalAmount),
          time: MigaFormat.date(o.createdAt),
          state: TimelineState.done,
        ),
        TimelineStep(
          title:
              o.campaignStatus == CampaignStatus.failed
                  ? 'لم تكتمل الحملة'
                  : (o.campaignStatus == CampaignStatus.cancelled ? 'ألغى التاجر الحملة' : 'تم إلغاء الطلب'),
          subtitle: d.cancellationReason,
          state: TimelineState.failed,
        ),
        TimelineStep(
          title: 'تم استرداد المبلغ',
          subtitle: 'إلى وسيلة الدفع الأصلية خلال 3-5 أيام عمل',
          time: d.refundedAt == null ? null : MigaFormat.date(d.refundedAt!),
          state: TimelineState.done,
        ),
      ];
    }
    // readyForDelivery shows as "preparing" (the merchant has it ready, waiting for a driver).
    final status = o.status == CampaignOrderStatus.readyForDelivery ? CampaignOrderStatus.preparing : o.status;
    final current = o.campaignStatus == CampaignStatus.active ? 1 : _flow.indexOf(status).clamp(0, _flow.length - 1);
    const titles = ['تم الدفع وحجز الكمية', 'اكتمال الحملة', 'يجهّز التاجر طلبك', 'مع المندوب في الطريق', 'تم التسليم'];
    const icons = [
      Icons.payments_rounded,
      Icons.groups_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
      Icons.home_rounded,
    ];
    final subs = [
      MigaFormat.money(o.totalAmount),
      o.campaignStatus == CampaignStatus.active
          ? '${o.campaignCurrent} من ${o.campaignTarget} قطعة • ${MigaFormat.countdown(o.campaignEndDate.difference(DateTime.now()))}'
          : 'وصلت الحملة للعدد المطلوب 🎉',
      'تجهيز الطلب المجمّع وتسليمه للمندوب',
      'المندوب في طريقه لعنوانك',
      d.addressSummary,
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        TimelineStep(
          title: titles[i],
          subtitle: i <= current ? subs[i] : null,
          time: i == 0 ? MigaFormat.date(o.createdAt) : (i == 4 && d.deliveredAt != null ? MigaFormat.date(d.deliveredAt!) : null),
          icon: icons[i],
          state:
              o.status == CampaignOrderStatus.delivered || i < current
                  ? TimelineState.done
                  : i == current
                  ? TimelineState.current
                  : TimelineState.upcoming,
        ),
    ];
  }

  Future<void> _cancel(OrderDetail d) async {
    const reasons = ['غيّرت رأيي', 'وجدت سعرًا أفضل', 'الحملة تأخرت في الاكتمال', 'سبب آخر'];
    String? reason;
    var missingReason = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, set) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إلغاء الطلب', style: Theme.of(c).textTheme.titleLarge),
                        Text('سيتم استرداد ${MigaFormat.money(d.order.totalAmount)} كاملًا.', style: Theme.of(c).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        for (final r in reasons)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: r,
                            groupValue: reason,
                            activeColor: MigaColors.primary,
                            title: Text(r),
                            onChanged:
                                (v) => set(() {
                                  reason = v;
                                  missingReason = false;
                                }),
                          ),
                        if (missingReason)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'اختر سبب الإلغاء أولًا',
                              style: Theme.of(c).textTheme.labelMedium?.copyWith(color: MigaColors.error),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Always tappable: a greyed-out button with no hint looked broken.
                        MigaButton(
                          label: 'تأكيد الإلغاء',
                          color: MigaColors.error,
                          onPressed: () => reason == null ? set(() => missingReason = true) : Navigator.pop(c, true),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (ok != true || !mounted) return;
    try {
      // Keep the current screen until the server answers, so a refusal shows as a message, not an error page.
      final updated = await AppServices.api.customer.cancelOrder(d.order.id, reason!);
      if (!mounted) return;
      setState(() => _order = Future.value(updated));
      showMigaMessage(context, 'تم إلغاء الطلب وسيتم استرداد المبلغ');
    } catch (e) {
      if (mounted) showMigaError(context, e);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<OrderDetail>(
      future: _order,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: MigaErrorView(offline: snap.error is ApiException && (snap.error as ApiException).isNetwork, onRetry: _reload),
          );
        }
        final d = snap.data;
        if (d == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        final o = d.order;
        final inDelivery = o.status == CampaignOrderStatus.outForDelivery;
        return Scaffold(
          appBar: AppBar(title: Text('طلب #${o.number}')),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                MigaCard(
                  child: Row(
                    children: [
                      MigaImage(o.imageUrl ?? '', width: 70, height: 70, borderRadius: MigaRadius.all(MigaRadius.md)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.productName, style: t.titleSmall),
                            Text('${o.storeName} • الكمية ${o.quantity}', style: t.bodySmall),
                            const SizedBox(height: 6),
                            StatusChip.order(o.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (inDelivery && d.deliveryCode != null) ...[
                  const SizedBox(height: 12),
                  // The driver asks for this code to complete the hand-over.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: MigaColors.primaryGradient, borderRadius: MigaRadius.all(MigaRadius.lg)),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('رمز التسليم — أعطه للمندوب عند الاستلام', style: t.titleSmall?.copyWith(color: Colors.white)),
                        ),
                        Text(
                          d.deliveryCode!,
                          style: t.headlineMedium?.copyWith(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MigaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('حالة الطلب', style: t.titleMedium), const SizedBox(height: 14), MigaTimeline(steps: _steps(d))],
                  ),
                ),
                if (d.driverName != null && (inDelivery || o.status == CampaignOrderStatus.delivered)) ...[
                  const SizedBox(height: 12),
                  MigaCard(
                    child: Row(
                      children: [
                        MigaAvatar(name: d.driverName!, color: MigaColors.driverAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(d.driverName!, style: t.titleSmall), Text('مندوب ميجا', style: t.bodySmall)],
                          ),
                        ),
                        if (inDelivery && d.driverPhone != null)
                          MigaIconButton(
                            icon: Icons.phone_rounded,
                            background: MigaColors.success,
                            color: Colors.white,
                            onTap: () => migaCall(context, d.driverPhone),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MigaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('عنوان التوصيل', style: t.titleMedium),
                      const SizedBox(height: 8),
                      InfoRow(d.addressName, d.addressSummary, icon: Icons.location_on_outlined),
                      InfoRow('الجوال', d.addressPhone, icon: Icons.phone_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MigaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('الدفع', style: t.titleMedium),
                          const Spacer(),
                          if (d.paymentStatus != null) StatusChip.payment(d.paymentStatus!),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow('سعر القطعة', MigaFormat.money(d.unitPrice)),
                      InfoRow('الكمية', '${o.quantity}'),
                      if (o.status != CampaignOrderStatus.refunded && o.status != CampaignOrderStatus.cancelled)
                        InfoRow('التوفير', MigaFormat.money(d.savings), valueColor: MigaColors.success),
                      const Divider(height: 18),
                      InfoRow('الإجمالي', MigaFormat.money(o.totalAmount), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (d.canCancel)
                  MigaButton(
                    label: 'إلغاء الطلب',
                    variant: MigaButtonVariant.outline,
                    color: MigaColors.error,
                    onPressed: () => _cancel(d),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
