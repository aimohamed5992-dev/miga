import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';
import '../shell/admin_shell.dart';

/// Merchant / driver review queue: everything they submitted, approve, or reject with a reason they will see.
class VerificationsPage extends StatefulWidget {
  const VerificationsPage({super.key});

  @override
  State<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  String _status = 'pending';
  String _type = 'all';
  late Future<List<VerificationItem>> _future = _load();

  Future<List<VerificationItem>> _load() => AppServices.api.admin.verifications(type: _type, status: _status);

  void _reload() {
    setState(() => _future = _load());
    AdminShell.refreshCounters.value++;
  }

  Future<void> _approve(VerificationItem v) async {
    final ok = await confirmAction(
      context,
      title: v.isMerchant ? 'توثيق التاجر' : 'تفعيل المندوب',
      message:
          v.isMerchant
              ? 'سيُوثَّق "${v.businessNameAr ?? v.fullName}" وتظهر متاجره للعملاء فورًا، ويصله إشعار بذلك.'
              : 'سيُفعَّل حساب "${v.fullName}" ويستطيع استقبال طلبات التوصيل في ${v.city ?? 'مدينته'}.',
      confirmLabel: v.isMerchant ? 'توثيق' : 'تفعيل',
    );
    if (!ok || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.verify(v), 'تم ${v.isMerchant ? 'توثيق التاجر' : 'تفعيل المندوب'}')) _reload();
  }

  Future<void> _reject(VerificationItem v) async {
    final reason = await askReason(
      context,
      title: 'رفض الطلب',
      message: 'سيظهر السبب لـ "${v.fullName}" في التطبيق، ويمكنه تعديل بياناته وإعادة الإرسال.',
      confirmLabel: 'رفض الطلب',
      suggestions:
          v.isMerchant
              ? const ['رقم السجل التجاري غير صحيح', 'الاسم التجاري لا يطابق السجل', 'السجل التجاري منتهي']
              : const ['رقم الهوية غير صحيح', 'رخصة القيادة منتهية', 'بيانات المركبة غير مكتملة'],
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.reject(v, reason), 'تم رفض الطلب وإبلاغ المستخدم')) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: 'طلبات التوثيق',
          subtitle: 'راجع بيانات التجار والمندوبين قبل تفعيلهم',
          actions: [
            MigaButton(
              label: 'تحديث',
              icon: Icons.refresh_rounded,
              variant: MigaButtonVariant.outline,
              expanded: false,
              height: 42,
              onPressed: _reload,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            AdminFilters<String>(
              options: const [('pending', 'بانتظار المراجعة'), ('rejected', 'مرفوضة'), ('verified', 'موثّقة')],
              value: _status,
              onChanged:
                  (v) => setState(() {
                    _status = v;
                    _future = _load();
                  }),
            ),
            AdminFilters<String>(
              options: const [('all', 'الكل'), ('merchant', 'التجار'), ('driver', 'المندوبون')],
              value: _type,
              onChanged:
                  (v) => setState(() {
                    _type = v;
                    _future = _load();
                  }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<VerificationItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
            }
            final items = snap.data;
            if (items == null) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            if (items.isEmpty) {
              return SizedBox(
                height: 360,
                child: EmptyState(
                  image: 'empty_orders.png',
                  title: _status == 'pending' ? 'لا توجد طلبات بانتظار المراجعة' : 'لا توجد طلبات',
                  message: _status == 'pending' ? 'ستظهر هنا طلبات التسجيل الجديدة فور إرسالها' : 'جرّب فلترًا آخر',
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1100 ? 2 : 1;
                final w = (box.maxWidth - (cols - 1) * 16) / cols;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final v in items)
                      SizedBox(width: w, child: _VerificationCard(item: v, onApprove: () => _approve(v), onReject: () => _reject(v))),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.item, required this.onApprove, required this.onReject});
  final VerificationItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = item;
    final accent = v.isMerchant ? MigaColors.merchantAccent : MigaColors.driverAccent;
    final fields =
        v.isMerchant
            ? [
              ('الاسم التجاري', v.businessNameAr),
              ('السجل التجاري', v.commercialRegistrationNumber),
              ('الرقم الضريبي', v.taxNumber),
              ('المتجر الأول', v.storeName),
              ('قسم المتجر', v.storeCategory),
            ]
            : [
              ('رقم الهوية', v.nationalId),
              ('مدينة العمل', v.city),
              ('المركبة', [_vehicle(v.vehicleType), v.vehicleModel].whereType<String>().join(' • ')),
              ('رقم اللوحة', v.plateNumber),
              ('رخصة القيادة', v.drivingLicenseNumber),
            ];
    return MigaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MigaAvatar(name: v.fullName.isEmpty ? '؟' : v.fullName, size: 46, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(v.fullName, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        StatusChip(
                          v.isMerchant ? 'تاجر' : 'مندوب',
                          tone: v.isMerchant ? StatusTone.info : StatusTone.success,
                          icon: v.isMerchant ? Icons.storefront_rounded : Icons.delivery_dining_rounded,
                        ),
                      ],
                    ),
                    Text(localPhone(v.phone), style: t.bodySmall, textDirection: TextDirection.ltr),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [Text('أُرسل ${MigaFormat.timeAgo(v.submittedAt)}', style: t.labelSmall), verificationChip(v.status)],
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (final (label, value) in fields)
                SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(label, style: t.labelSmall), Text((value == null || value.isEmpty) ? '—' : value, style: t.titleSmall)],
                  ),
                ),
            ],
          ),
          if (v.status == 'rejected' && v.rejectionReason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: MigaColors.errorSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
              child: Text(
                'سبب الرفض: ${v.rejectionReason}${v.reviewedAt == null ? '' : ' • ${MigaFormat.date(v.reviewedAt!)}'}',
                style: t.bodySmall?.copyWith(color: MigaColors.error),
              ),
            ),
          ],
          if (v.status == 'verified' && v.reviewedAt != null) ...[
            const SizedBox(height: 10),
            Text('وُثّق في ${MigaFormat.date(v.reviewedAt!)}', style: t.labelSmall),
          ],
          if (v.status == 'pending') ...[
            const SizedBox(height: 18),
            Row(
              children: [
                MigaButton(
                  label: 'رفض مع سبب',
                  icon: Icons.block_rounded,
                  variant: MigaButtonVariant.outline,
                  color: MigaColors.error,
                  expanded: false,
                  height: 44,
                  onPressed: onReject,
                ),
                const SizedBox(width: 10),
                MigaButton(
                  label: v.isMerchant ? 'توثيق التاجر' : 'تفعيل المندوب',
                  icon: Icons.verified_rounded,
                  expanded: false,
                  height: 44,
                  onPressed: onApprove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String? _vehicle(String? type) => switch (type) {
    'car' => 'سيارة',
    'van' => 'فان',
    'truck' => 'شاحنة صغيرة',
    'bike' => 'دراجة نارية',
    _ => type,
  };
}
