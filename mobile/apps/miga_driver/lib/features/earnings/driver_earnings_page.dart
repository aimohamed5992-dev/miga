import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

const _accent = MigaColors.driverAccent;

/// Delivered-fee earnings: this week by day or this month by week, totals, rating and recent deliveries.
class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key});

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  bool _week = true;
  late Future<DriverEarnings> _future = AppServices.api.driver.earnings();

  void _load() => setState(() => _future = AppServices.api.driver.earnings(month: !_week));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أرباحي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                MigaChoiceChip(
                  label: 'هذا الأسبوع',
                  selected: _week,
                  onSelected: () {
                    _week = true;
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                MigaChoiceChip(
                  label: 'هذا الشهر',
                  selected: !_week,
                  onSelected: () {
                    _week = false;
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<DriverEarnings>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  final e = snap.error;
                  return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _load);
                }
                final e = snap.data;
                if (e == null) return const Center(child: CircularProgressIndicator());
                return RefreshIndicator(onRefresh: () async => _load(), child: _body(context, e));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, DriverEarnings e) {
    final t = Theme.of(context).textTheme;
    final avg = e.deliveries == 0 ? 0.0 : e.total / e.deliveries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        MigaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_week ? 'أرباح الأسبوع' : 'أرباح الشهر', style: t.bodySmall),
              Text(MigaFormat.money(e.total), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              MigaBarChart(
                key: ValueKey(_week),
                values: [for (final b in e.buckets) b.$2],
                labels: [for (final b in e.buckets) b.$1],
                color: MigaColors.driverChart,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.38,
          children: [
            StatTile(label: 'توصيلة مكتملة', value: '${e.deliveries}', icon: Icons.check_circle_rounded, color: _accent),
            StatTile(label: 'متوسط التوصيلة', value: MigaFormat.money(avg), icon: Icons.payments_outlined, color: MigaColors.info),
            StatTile(
              label: 'المسافة المقطوعة',
              value: '${e.distanceKm.toStringAsFixed(0)} كم',
              icon: Icons.route_rounded,
              color: MigaColors.warning,
            ),
            StatTile(label: 'التقييم', value: e.rating.toStringAsFixed(1), icon: Icons.star_rounded, color: MigaColors.gold),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [MigaColors.driverChart, _accent], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: MigaRadius.all(MigaRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(Icons.savings_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي أرباحك منذ الانضمام', style: t.bodySmall?.copyWith(color: Colors.white70)),
                    Text(MigaFormat.money(e.lifetimeEarnings), style: t.titleLarge?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('آخر التوصيلات', style: t.titleMedium),
        const SizedBox(height: 10),
        if (e.recent.isEmpty)
          MigaCard(child: Center(child: Text('لا توجد توصيلات مكتملة في هذه الفترة', style: t.bodySmall)))
        else
          MigaCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, d) in e.recent.indexed) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _accent.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.sm)),
                      child: const Icon(Icons.local_shipping_rounded, color: _accent, size: 20),
                    ),
                    title: Text('#${d.number} • ${d.district}', style: t.titleSmall),
                    subtitle: Text(
                      [
                        if (d.distanceKm != null) '${d.distanceKm!.toStringAsFixed(1)} كم',
                        if (d.deliveredAt != null) MigaFormat.timeAgo(d.deliveredAt!),
                      ].join(' • '),
                      style: t.bodySmall,
                    ),
                    trailing: Text(MigaFormat.money(d.fee), style: t.titleSmall?.copyWith(color: MigaColors.success)),
                  ),
                  if (i < e.recent.length - 1) const Divider(indent: 72),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
