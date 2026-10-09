import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Merchant reports from live data: 6-month sales, campaign success rate, and best campaigns by revenue.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _Report {
  const _Report(this.earnings, this.done, this.ended, this.active);
  final MerchantEarnings earnings;
  final List<MerchantCampaignView> done;
  final List<MerchantCampaignView> ended;
  final List<MerchantCampaignView> active;
}

class _ReportsPageState extends State<ReportsPage> {
  static const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  late Future<_Report> _future = _load();

  Future<_Report> _load() async {
    final api = AppServices.api.merchant;
    final r = await Future.wait([api.earnings(), api.campaigns(tab: 'done'), api.campaigns(tab: 'ended'), api.campaigns(tab: 'active')]);
    return _Report(
      r[0] as MerchantEarnings,
      r[1] as List<MerchantCampaignView>,
      r[2] as List<MerchantCampaignView>,
      r[3] as List<MerchantCampaignView>,
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير')),
    body: FutureBuilder<_Report>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
        }
        final r = snap.data;
        if (r == null) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(onRefresh: _reload, child: _body(context, r));
      },
    ),
  );

  Widget _body(BuildContext context, _Report r) {
    final t = Theme.of(context).textTheme;
    final sales6 = r.earnings.monthly.fold<double>(0, (s, m) => s + m.$3);
    final decided = r.done.length + r.ended.length;
    final success = decided == 0 ? null : r.done.length / decided;
    final revenue = r.done.fold<double>(0, (s, c) => s + c.collectedAmount);
    final avg = r.done.isEmpty ? 0.0 : revenue / r.done.length;
    final top = [...r.done]..sort((a, b) => b.collectedAmount.compareTo(a.collectedAmount));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            _Kpi(label: 'مبيعات 6 أشهر', value: MigaFormat.money(sales6), icon: Icons.payments_rounded, color: MigaColors.merchantAccent),
            const SizedBox(width: 10),
            _Kpi(
              label: 'نجاح الحملات',
              value: success == null ? '—' : '${(success * 100).round()}%',
              icon: Icons.emoji_events_rounded,
              color: MigaColors.success,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Kpi(label: 'حملات نشطة', value: '${r.active.length}', icon: Icons.campaign_rounded, color: MigaColors.primary),
            const SizedBox(width: 10),
            _Kpi(label: 'متوسط الحملة المكتملة', value: MigaFormat.money(avg), icon: Icons.analytics_rounded, color: MigaColors.info),
          ],
        ),
        const SizedBox(height: 14),
        MigaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المبيعات الشهرية', style: t.titleMedium),
              Text('آخر ${r.earnings.monthly.length} أشهر', style: t.bodySmall),
              const SizedBox(height: 14),
              MigaBarChart(
                values: [for (final m in r.earnings.monthly) m.$3],
                labels: [for (final m in r.earnings.monthly) _months[m.$2 - 1]],
                color: MigaColors.merchantAccent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        MigaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نتائج الحملات', style: t.titleMedium),
              const SizedBox(height: 10),
              InfoRow('اكتملت', '${r.done.length}', valueColor: MigaColors.success),
              InfoRow('انتهت دون اكتمال / أُلغيت', '${r.ended.length}', valueColor: MigaColors.error),
              InfoRow('جارية الآن', '${r.active.length}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('أعلى الحملات إيرادًا', style: t.titleMedium),
        const SizedBox(height: 10),
        if (top.isEmpty)
          MigaCard(child: Center(child: Text('ستظهر هنا حملاتك المكتملة', style: t.bodySmall)))
        else
          MigaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, c) in top.take(5).indexed) ...[
                  ListTile(
                    leading: MigaImage(c.campaign.product.mainImage, width: 44, height: 44, borderRadius: MigaRadius.all(MigaRadius.sm)),
                    title: Text(c.campaign.titleAr, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${c.campaign.currentQuantity} قطعة • ${c.campaign.participantsCount} عميل', style: t.bodySmall),
                    trailing: Text(MigaFormat.money(c.collectedAmount), style: t.titleSmall),
                  ),
                  if (i < top.take(5).length - 1) const Divider(indent: 72),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: MigaCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.sm)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
