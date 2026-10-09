import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';

/// Customer orders (payment + delivery state) and the merchants' aggregated orders.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _aggregated = false;
  String _status = 'active';
  String _q = '';

  void _switch(bool aggregated) => setState(() {
    _aggregated = aggregated;
    _status = aggregated ? 'open' : 'active';
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: 'الطلبات',
          subtitle: _aggregated ? 'الطلبات المجمّعة التي تصل للتاجر عند اكتمال الحملة' : 'ابحث برقم الطلب أو اسم العميل أو جواله',
          actions: [AdminSearchField(hint: 'بحث…', onChanged: (v) => setState(() => _q = v))],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            AdminFilters<bool>(
              options: const [(false, 'طلبات العملاء'), (true, 'الطلبات المجمّعة')],
              value: _aggregated,
              onChanged: _switch,
            ),
            AdminFilters<String>(
              options:
                  _aggregated
                      ? const [('open', 'قيد التنفيذ'), ('completed', 'مكتملة'), ('all', 'الكل')]
                      : const [('active', 'جارية'), ('delivered', 'مُسلّمة'), ('closed', 'ملغاة / مستردة'), ('all', 'الكل')],
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_aggregated)
          AdminTable<AdminMerchantOrder>(
            reloadKey: ('mo', _status, _q),
            emptyTitle: 'لا توجد طلبات مجمّعة',
            load:
                (page, size) =>
                    AppServices.api.admin.merchantOrders(status: _status, q: _q.isEmpty ? null : _q, page: page, pageSize: size),
            columns: [
              AdminColumn('الطلب', (o) => AdminCell('#${o.number}', subtitle: MigaFormat.date(o.createdAt))),
              AdminColumn('الحملة / المتجر', (o) => AdminCell(o.campaignTitle, subtitle: o.storeName), flex: 3),
              AdminColumn('الكمية', (o) => AdminCell('${o.totalQuantity} قطعة', subtitle: '${o.customersCount} عميل')),
              AdminColumn(
                'القيمة',
                (o) => AdminCell(MigaFormat.money(o.totalAmount), subtitle: 'عمولة ${MigaFormat.money(o.platformFee)}'),
              ),
              AdminColumn(
                'التوصيل',
                (o) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o.delivered} / ${o.deliveries} سُلّمت', style: t.labelMedium),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: MigaRadius.all(MigaRadius.pill),
                        child: LinearProgressIndicator(
                          value: o.deliveries == 0 ? 0 : o.delivered / o.deliveries,
                          minHeight: 6,
                          color: MigaColors.success,
                          backgroundColor: MigaColors.surfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AdminColumn('الحالة', (o) => StatusChip.merchantOrder(o.status)),
            ],
          )
        else
          AdminTable<AdminOrder>(
            reloadKey: ('co', _status, _q),
            emptyTitle: 'لا توجد طلبات',
            load: (page, size) => AppServices.api.admin.orders(status: _status, q: _q.isEmpty ? null : _q, page: page, pageSize: size),
            columns: [
              AdminColumn('الطلب', (o) => AdminCell('#${o.number}', subtitle: MigaFormat.date(o.createdAt))),
              AdminColumn('العميل', (o) => AdminCell(o.customerName, subtitle: localPhone(o.customerPhone), ltrSubtitle: true)),
              AdminColumn('الحملة / المتجر', (o) => AdminCell(o.campaignTitle, subtitle: o.storeName), flex: 3),
              AdminColumn('المبلغ', (o) => AdminCell(MigaFormat.money(o.totalAmount), subtitle: '${o.quantity} قطعة')),
              AdminColumn('الدفع', (o) => o.paymentStatus == null ? const Text('—') : StatusChip.payment(o.paymentStatus!)),
              AdminColumn('التوصيل', (o) => o.deliveryStatus == null ? const Text('—') : StatusChip.delivery(o.deliveryStatus!)),
              AdminColumn('الحالة', (o) => Tooltip(message: o.cancellationReason ?? '', child: StatusChip.order(o.status))),
            ],
          ),
      ],
    );
  }
}
