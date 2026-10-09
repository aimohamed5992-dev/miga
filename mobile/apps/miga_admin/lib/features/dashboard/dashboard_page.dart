import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';
import '../shell/admin_shell.dart';

/// Platform overview: what needs attention now, 30-day money, people, 14-day sales and top stores.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<AdminDashboard> _future = AppServices.api.admin.dashboard();

  void _reload() {
    setState(() => _future = AppServices.api.admin.dashboard());
    AdminShell.refreshCounters.value++;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboard>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
        }
        final d = snap.data;
        if (d == null) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(onRefresh: () async => _reload(), child: _body(context, d));
      },
    );
  }

  Widget _body(BuildContext context, AdminDashboard d) {
    final t = Theme.of(context).textTheme;
    final c = d.counts;
    final name = Session.instance.account?.fullName ?? '';
    final alerts = [
      if (c.pendingReviews > 0)
        _Alert(
          icon: Icons.verified_user_rounded,
          color: MigaColors.warning,
          title: '${c.pendingReviews} طلب توثيق بانتظار المراجعة',
          subtitle: '${c.merchantsPending} تاجر • ${c.driversPending} مندوب',
          section: AdminSection.verifications,
        ),
      if (c.failedDeliveries > 0)
        _Alert(
          icon: Icons.report_problem_rounded,
          color: MigaColors.error,
          title: '${c.failedDeliveries} توصيلة متعثرة',
          subtitle: 'أعد المحاولة أو استرد المبلغ للعميل',
          section: AdminSection.deliveries,
        ),
      if (c.payoutsRequested > 0)
        _Alert(
          icon: Icons.account_balance_rounded,
          color: MigaColors.info,
          title: '${c.payoutsRequested} طلب سحب للتجار',
          subtitle: 'بإجمالي ${MigaFormat.money(c.payoutsRequestedAmount)}',
          section: AdminSection.payouts,
        ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1100 ? 4 : (box.maxWidth >= 640 ? 2 : 1);
        Widget grid(List<Widget> tiles) => GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 112,
          ),
          children: tiles,
        );
        final chart = _SalesChart(days: d.days);
        final top = _TopStores(stores: d.topStores);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'أهلًا بك 👋' : 'أهلًا ${name.split(' ').first} 👋', style: t.headlineSmall),
                      Text('نظرة عامة على منصة ميجا', style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
                    ],
                  ),
                ),
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
            const SizedBox(height: 20),
            if (alerts.isEmpty)
              const _AllClear()
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [for (final a in alerts) SizedBox(width: cols == 1 ? box.maxWidth : 340, child: a)],
              ),
            const SizedBox(height: 24),
            Text('آخر 30 يومًا', style: t.titleMedium),
            const SizedBox(height: 12),
            grid([
              _Kpi(label: 'إجمالي المبيعات', value: MigaFormat.money(c.gmv30d), icon: Icons.payments_rounded, color: MigaColors.primary),
              _Kpi(label: 'عمولة ميجا', value: MigaFormat.money(c.commission30d), icon: Icons.percent_rounded, color: MigaColors.success),
              _Kpi(label: 'حملات اكتملت', value: '${c.campaignsCompleted30d}', icon: Icons.celebration_rounded, color: MigaColors.warning),
              _Kpi(label: 'طلبات اليوم', value: '${c.ordersToday}', icon: Icons.receipt_long_rounded, color: MigaColors.info),
            ]),
            const SizedBox(height: 24),
            Text('المنصة الآن', style: t.titleMedium),
            const SizedBox(height: 12),
            grid([
              _Kpi(
                label: 'حملات نشطة',
                value: '${c.activeCampaigns}',
                icon: Icons.campaign_rounded,
                color: MigaColors.primary,
                section: AdminSection.campaigns,
              ),
              _Kpi(
                label: 'متاجر نشطة',
                value: '${c.activeStores}',
                sub: '${c.merchants} تاجر موثّق',
                icon: Icons.storefront_rounded,
                color: MigaColors.merchantAccent,
                section: AdminSection.merchants,
              ),
              _Kpi(
                label: 'مندوبون متصلون',
                value: '${c.driversOnline}',
                sub: 'من ${c.drivers} مندوب • ${c.deliveriesInProgress} توصيلة جارية',
                icon: Icons.delivery_dining_rounded,
                color: MigaColors.driverAccent,
                section: AdminSection.drivers,
              ),
              _Kpi(
                label: 'العملاء',
                value: '${c.customers}',
                sub: c.suspendedUsers > 0 ? '${c.suspendedUsers} حساب موقوف' : null,
                icon: Icons.people_rounded,
                color: MigaColors.info,
                section: AdminSection.customers,
              ),
            ]),
            const SizedBox(height: 24),
            if (box.maxWidth >= 1100)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(flex: 3, child: chart), const SizedBox(width: 16), Expanded(flex: 2, child: top)],
                ),
              )
            else ...[
              chart,
              const SizedBox(height: 16),
              top,
            ],
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color, this.sub, this.section});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  final AdminSection? section;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      onTap: section == null ? null : () => AdminShell.go(section!),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.md)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (sub != null) Text(sub!, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (section != null) const MigaChevron(color: MigaColors.textHint),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.icon, required this.color, required this.title, required this.subtitle, required this.section});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: MigaRadius.all(MigaRadius.lg),
      child: InkWell(
        borderRadius: MigaRadius.all(MigaRadius.lg),
        onTap: () => AdminShell.go(section),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: MigaRadius.all(MigaRadius.lg), border: Border.all(color: color.withValues(alpha: .3))),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title, style: t.titleSmall), Text(subtitle, style: t.bodySmall)],
                ),
              ),
              Text('عرض', style: t.labelLarge?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: MigaColors.successSoft, borderRadius: MigaRadius.all(MigaRadius.lg)),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, color: MigaColors.success),
          const SizedBox(width: 12),
          Text(
            'لا شيء ينتظرك الآن — لا توثيق معلّق، ولا توصيلات متعثرة، ولا سحوبات.',
            style: t.titleSmall?.copyWith(color: MigaColors.success),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.days});
  final List<(DateTime, double, int)> days;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = days.fold<double>(0, (s, d) => s + d.$2);
    final orders = days.fold<int>(0, (s, d) => s + d.$3);
    return MigaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المبيعات — آخر 14 يومًا', style: t.titleMedium),
          Text('${MigaFormat.money(total)} • $orders طلب مدفوع', style: t.bodySmall),
          const SizedBox(height: 18),
          MigaBarChart(values: [for (final d in days) d.$2], labels: [for (final d in days) '${d.$1.day}/${d.$1.month}'], height: 220),
        ],
      ),
    );
  }
}

class _TopStores extends StatelessWidget {
  const _TopStores({required this.stores});
  final List<(String, double, int)> stores;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final max = stores.isEmpty ? 1.0 : stores.first.$2;
    return MigaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أعلى المتاجر مبيعًا', style: t.titleMedium),
          Text('آخر 14 يومًا', style: t.bodySmall),
          const SizedBox(height: 14),
          if (stores.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('لا مبيعات بعد', style: t.bodySmall)))
          else
            for (final (i, s) in stores.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${i + 1}', style: t.labelLarge?.copyWith(color: MigaColors.textHint)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.$1, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                        Text(MigaFormat.money(s.$2), style: t.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: MigaRadius.all(MigaRadius.pill),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : s.$2 / max,
                        minHeight: 6,
                        color: MigaColors.primary,
                        backgroundColor: MigaColors.surfaceMuted,
                      ),
                    ),
                    Text('${s.$3} طلب', style: t.labelSmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
