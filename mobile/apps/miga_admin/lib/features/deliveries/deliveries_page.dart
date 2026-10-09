import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';
import '../shell/admin_shell.dart';

/// Deliveries by state. Failed ones are resolved here: retry with the same driver, or refund the customer.
class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  String _status = 'failed';
  String _q = '';
  final _table = GlobalKey<AdminTableState<AdminDelivery>>();

  void _done() {
    _table.currentState?.reload();
    AdminShell.refreshCounters.value++;
  }

  Future<void> _retry(AdminDelivery d) async {
    final note = await askReason(
      context,
      title: 'إعادة محاولة التوصيل',
      message: 'تعود التوصيلة ${d.number} للمندوب ${d.driverName ?? ''} (البضاعة معه) ليعيد التوصيل، ويصله إشعار مع ملاحظتك.',
      confirmLabel: 'إعادة المحاولة',
      hint: 'ملاحظة للمندوب (مثال: العميل متاح بعد المغرب)',
      suggestions: const ['تم التواصل مع العميل وهو متاح الآن', 'العميل متاح بعد المغرب', 'تم تصحيح العنوان مع العميل'],
      danger: false,
    );
    if (note == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.retryDelivery(d.id, note: note), 'أُعيدت التوصيلة للمندوب')) _done();
  }

  Future<void> _refund(AdminDelivery d) async {
    final reason = await askReason(
      context,
      title: 'استرداد المبلغ للعميل',
      message:
          'ستُلغى التوصيلة ويُسترد ${MigaFormat.money(d.orderAmount)} لـ ${d.customerName}. يُخصم المبلغ (وعمولته) من مستحقات التاجر. لا يمكن التراجع.',
      confirmLabel: 'استرداد المبلغ',
      hint: 'سبب الاسترداد',
      suggestions: const ['تعذّر الوصول للعميل', 'العميل ألغى الطلب', 'المنتج تالف'],
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.refundDelivery(d.id, reason), 'تم الاسترداد وإبلاغ العميل والتاجر')) _done();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: 'التوصيلات',
          subtitle: 'ابحث برقم التوصيلة أو الطلب أو اسم العميل أو المندوب',
          actions: [AdminSearchField(hint: 'بحث…', onChanged: (v) => setState(() => _q = v))],
        ),
        const SizedBox(height: 16),
        AdminFilters<String>(
          options: const [
            ('failed', 'متعثرة'),
            ('in_progress', 'جارية'),
            ('waiting', 'بانتظار مندوب'),
            ('delivered', 'مُسلّمة'),
            ('all', 'الكل'),
          ],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 16),
        AdminTable<AdminDelivery>(
          key: _table,
          reloadKey: (_status, _q),
          emptyTitle: _status == 'failed' ? 'لا توجد توصيلات متعثرة 🎉' : 'لا توجد توصيلات',
          emptyMessage: _status == 'failed' ? 'كل التوصيلات تسير بشكل طبيعي' : 'جرّب فلترًا آخر',
          load: (page, size) => AppServices.api.admin.deliveries(status: _status, q: _q.isEmpty ? null : _q, page: page, pageSize: size),
          columns: [
            AdminColumn('التوصيلة', (d) => AdminCell('#${d.number}', subtitle: 'طلب ${d.orderNumber}')),
            AdminColumn('العميل', (d) => AdminCell(d.customerName, subtitle: '${d.district}، ${d.city}')),
            AdminColumn('المنتج / المتجر', (d) => AdminCell('${d.productName} × ${d.quantity}', subtitle: d.storeName), flex: 3),
            AdminColumn(
              'المندوب',
              (d) =>
                  d.driverName == null
                      ? Text('لم يُسند', style: t.bodySmall)
                      : AdminCell(d.driverName!, subtitle: localPhone(d.driverPhone ?? ''), ltrSubtitle: true),
            ),
            AdminColumn(
              'الحالة',
              (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusChip.delivery(d.status),
                  if (d.failureReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      d.failureReason!,
                      style: t.labelSmall?.copyWith(color: MigaColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            AdminColumn(
              '',
              (d) =>
                  d.status == DeliveryStatus.failed
                      ? Wrap(
                        spacing: 4,
                        children: [
                          TextButton(onPressed: () => _retry(d), child: const Text('إعادة المحاولة')),
                          TextButton(onPressed: () => _refund(d), child: const Text('استرداد', style: TextStyle(color: MigaColors.error))),
                        ],
                      )
                      : Text(d.deliveredAt != null ? 'سُلّمت ${MigaFormat.date(d.deliveredAt!)}' : '', style: t.labelSmall),
              flex: 3,
            ),
          ],
        ),
      ],
    );
  }
}
