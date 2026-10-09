import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';
import '../shell/admin_shell.dart';

/// Merchant withdrawals: transfer to the IBAN, then record the bank reference — or reject (the amount returns to the balance).
class PayoutsPage extends StatefulWidget {
  const PayoutsPage({super.key});

  @override
  State<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends State<PayoutsPage> {
  String _status = 'requested';
  final _table = GlobalKey<AdminTableState<AdminPayout>>();

  void _done() {
    _table.currentState?.reload();
    AdminShell.refreshCounters.value++;
  }

  Future<void> _markPaid(AdminPayout p) async {
    final reference = await askReason(
      context,
      title: 'تأكيد التحويل',
      message:
          'حوّل ${MigaFormat.money(p.amount)} إلى ${p.bankName ?? 'حساب التاجر'} — ${p.iban}، ثم أدخل مرجع التحويل البنكي. يصل للتاجر إشعار بالمرجع.',
      confirmLabel: 'تم التحويل',
      hint: 'مرجع التحويل (مثال: TRX-2026-0042)',
      danger: false,
    );
    if (reference == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.payoutPaid(p.id, reference), 'سُجّل التحويل وأُبلغ التاجر')) _done();
  }

  Future<void> _reject(AdminPayout p) async {
    final reason = await askReason(
      context,
      title: 'رفض طلب السحب',
      message: 'يعود ${MigaFormat.money(p.amount)} إلى رصيد "${p.businessName ?? p.merchantName}" المتاح، ويصله السبب.',
      confirmLabel: 'رفض الطلب',
      suggestions: const ['اسم صاحب الحساب لا يطابق السجل التجاري', 'رقم الآيبان غير صحيح', 'الحساب البنكي مغلق'],
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.rejectPayout(p.id, reason), 'رُفض الطلب وأُعيد المبلغ للرصيد')) _done();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AdminPageHeader(title: 'سحوبات التجار', subtitle: 'طلبات تحويل الأرباح إلى الحسابات البنكية — الأقدم أولًا'),
        const SizedBox(height: 16),
        AdminFilters<String>(
          options: const [('requested', 'بانتظار التحويل'), ('paid', 'تم التحويل'), ('rejected', 'مرفوضة'), ('all', 'الكل')],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 16),
        AdminTable<AdminPayout>(
          key: _table,
          reloadKey: _status,
          emptyTitle: _status == 'requested' ? 'لا توجد طلبات سحب حاليًا' : 'لا توجد طلبات',
          emptyMessage: _status == 'requested' ? 'تظهر هنا طلبات التجار فور إرسالها من المحفظة' : 'جرّب فلترًا آخر',
          load: (page, size) => AppServices.api.admin.payouts(status: _status, page: page, pageSize: size),
          columns: [
            AdminColumn('التاجر', (p) => AdminCell(p.businessName ?? p.merchantName, subtitle: p.merchantName), flex: 3),
            AdminColumn('المبلغ', (p) => Text(MigaFormat.money(p.amount), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            AdminColumn(
              'الحساب البنكي',
              (p) => Row(
                children: [
                  Flexible(child: AdminCell(p.bankName ?? '—', subtitle: p.iban, ltrSubtitle: true)),
                  IconButton(
                    tooltip: 'نسخ الآيبان',
                    icon: const Icon(Icons.copy_rounded, size: 16, color: MigaColors.textSecondary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: p.iban));
                      showMigaMessage(context, 'نُسخ الآيبان', icon: Icons.copy_rounded);
                    },
                  ),
                ],
              ),
              flex: 4,
            ),
            AdminColumn('الطلب', (p) => AdminCell(MigaFormat.date(p.createdAt), subtitle: MigaFormat.timeAgo(p.createdAt))),
            AdminColumn(
              'الحالة',
              (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusChip(
                    p.status.labelAr,
                    tone: switch (p.status) {
                      PayoutStatus.paid => StatusTone.success,
                      PayoutStatus.rejected => StatusTone.danger,
                      PayoutStatus.requested => StatusTone.warning,
                    },
                  ),
                  if (p.transferReference != null) Text(p.transferReference!, style: t.labelSmall, textDirection: TextDirection.ltr),
                  if (p.rejectionReason != null)
                    Text(
                      p.rejectionReason!,
                      style: t.labelSmall?.copyWith(color: MigaColors.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            AdminColumn(
              '',
              (p) =>
                  p.status == PayoutStatus.requested
                      ? Wrap(
                        spacing: 4,
                        children: [
                          TextButton(onPressed: () => _markPaid(p), child: const Text('تم التحويل')),
                          TextButton(onPressed: () => _reject(p), child: const Text('رفض', style: TextStyle(color: MigaColors.error))),
                        ],
                      )
                      : Text(p.paidAt != null ? 'حُوّل ${MigaFormat.date(p.paidAt!)}' : '', style: t.labelSmall),
              flex: 3,
            ),
          ],
        ),
      ],
    );
  }
}
