import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';
import '../shell/admin_shell.dart';

/// All campaigns with progress; a running campaign can be cancelled (every paid customer is refunded).
class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  String _status = 'active';
  String _q = '';
  final _table = GlobalKey<AdminTableState<AdminCampaign>>();

  Future<void> _cancel(AdminCampaign c) async {
    final reason = await askReason(
      context,
      title: 'إلغاء الحملة',
      message:
          'ستُلغى "${c.titleAr}" ويُسترد المبلغ لـ ${c.participants} عميل تلقائيًا، ويصل السبب للتاجر "${c.merchantName}". لا يمكن التراجع.',
      confirmLabel: 'إلغاء الحملة',
      hint: 'سبب الإلغاء (يصل للتاجر)',
      suggestions: const ['مخالفة سياسة التسعير', 'منتج مخالف أو مقلّد', 'بلاغات من العملاء'],
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.cancelCampaign(c.id, reason), 'أُلغيت الحملة واستُرد المبلغ للعملاء')) {
      _table.currentState?.reload();
      AdminShell.refreshCounters.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: 'الحملات',
          subtitle: 'ابحث باسم الحملة أو المتجر أو المنتج',
          actions: [AdminSearchField(hint: 'بحث…', onChanged: (v) => setState(() => _q = v))],
        ),
        const SizedBox(height: 16),
        AdminFilters<String>(
          options: const [('active', 'نشطة'), ('completed', 'مكتملة'), ('ended', 'منتهية / ملغاة'), ('draft', 'مسودات'), ('all', 'الكل')],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 16),
        AdminTable<AdminCampaign>(
          key: _table,
          reloadKey: (_status, _q),
          emptyTitle: 'لا توجد حملات',
          load: (page, size) => AppServices.api.admin.campaigns(status: _status, q: _q.isEmpty ? null : _q, page: page, pageSize: size),
          columns: [
            AdminColumn(
              'الحملة',
              (c) => Row(
                children: [
                  MigaImage(c.imageUrl ?? '', width: 44, height: 44, borderRadius: MigaRadius.all(MigaRadius.sm)),
                  const SizedBox(width: 10),
                  Expanded(child: AdminCell(c.titleAr, subtitle: c.productName)),
                ],
              ),
              flex: 4,
            ),
            AdminColumn('المتجر', (c) => AdminCell(c.storeName, subtitle: c.merchantName), flex: 3),
            AdminColumn(
              'السعر',
              (c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(MigaFormat.money(c.campaignPrice), style: t.titleSmall),
                  Text(
                    MigaFormat.money(c.originalPrice),
                    style: t.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: MigaColors.textHint),
                  ),
                ],
              ),
            ),
            AdminColumn(
              'التقدّم',
              (c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c.currentQuantity} / ${c.targetQuantity} • ${c.participants} عميل', style: t.labelMedium),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: MigaRadius.all(MigaRadius.pill),
                    child: LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 6,
                      color: c.progress >= 1 ? MigaColors.success : MigaColors.primary,
                      backgroundColor: MigaColors.surfaceMuted,
                    ),
                  ),
                ],
              ),
              flex: 3,
            ),
            AdminColumn(
              'المدة',
              (c) => AdminCell(
                c.status == CampaignStatus.active ? 'تنتهي ${MigaFormat.date(c.endDate)}' : MigaFormat.date(c.completedAt ?? c.endDate),
                subtitle: 'بدأت ${MigaFormat.date(c.startDate)}',
              ),
            ),
            AdminColumn('الحالة', (c) => StatusChip.campaign(c.status)),
            AdminColumn(
              '',
              (c) =>
                  c.status == CampaignStatus.active || c.status == CampaignStatus.draft
                      ? IconButton(
                        tooltip: 'إلغاء الحملة واسترداد المبالغ',
                        onPressed: () => _cancel(c),
                        icon: const Icon(Icons.cancel_outlined, color: MigaColors.error),
                      )
                      : const SizedBox.shrink(),
              flex: 1,
            ),
          ],
        ),
      ],
    );
  }
}
