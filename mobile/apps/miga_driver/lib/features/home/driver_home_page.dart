import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/driver_data.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../delivery/delivery_detail_page.dart';
import '../delivery/route_map.dart';

const _accent = MigaColors.driverAccent;

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = DriverData.instance;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final requests = data.requests;
        final active = data.active;
        final home = data.home;
        final name = Session.instance.account?.fullName ?? '';
        if (home == null) {
          return Scaffold(
            body:
                data.error != null
                    ? MigaErrorView(offline: data.error is ApiException && (data.error as ApiException).isNetwork, onRetry: data.load)
                    : const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: data.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Design review: --dart-define=MIGA_SCROLL=600
              controller: ScrollController(initialScrollOffset: const int.fromEnvironment('MIGA_SCROLL').toDouble()),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          MigaAvatar(name: name.isEmpty ? 'ك' : name, color: _accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('أهلًا كابتن ${name.split(' ').first}', style: t.titleMedium),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: MigaColors.gold),
                                    Text(' ${home.rating.toStringAsFixed(1)} • ${home.cityName ?? ''}', style: t.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          MigaNotificationBell(
                            api: AppServices.api.notifications,
                            accent: _accent,
                            emptyMessage: 'سنخبرك فور وصول طلبات توصيل جديدة',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _OnlineCard(
                      online: data.online,
                      onChanged: (v) async {
                        try {
                          await data.setOnline(v);
                        } catch (e) {
                          if (context.mounted) showMigaError(context, e);
                        }
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        _Today(icon: Icons.payments_rounded, value: MigaFormat.money(home.todayEarnings), label: 'دخل اليوم'),
                        _Today(icon: Icons.check_circle_rounded, value: '${home.todayDeliveries}', label: 'توصيلة'),
                        _Today(icon: Icons.route_rounded, value: '${home.todayDistanceKm.toStringAsFixed(0)} كم', label: 'مسافة'),
                      ],
                    ),
                  ),
                ),
                if (!data.online)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      image: 'driver_onb_1.png',
                      title: 'أنت غير متصل',
                      message: 'فعّل حالتك لتبدأ باستقبال طلبات التوصيل القريبة منك',
                    ),
                  )
                else ...[
                  if (active.isNotEmpty) ...[
                    SliverToBoxAdapter(child: SectionHeader('توصيلة جارية', padding: const EdgeInsets.fromLTRB(20, 22, 20, 0))),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: MigaCard(
                          padding: EdgeInsets.zero,
                          onTap: () => migaPush(context, DeliveryDetailPage(deliveryId: active.first.id, initial: active.first)),
                          child: Column(
                            children: [
                              RouteMap(
                                height: 150,
                                progress: active.first.status == DeliveryStatus.driverAccepted ? .25 : .6,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(MigaRadius.lg)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(active.first.customerName, style: t.titleSmall),
                                          Text(active.first.fullAddress, style: t.bodySmall),
                                          if (active.length > 1) Text('+ ${active.length - 1} توصيلات أخرى', style: t.labelSmall),
                                        ],
                                      ),
                                    ),
                                    StatusChip.delivery(active.first.status),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      'طلبات جديدة (${requests.length})',
                      subtitle: 'طلبات حملات مكتملة في ${home.cityName ?? 'مدينتك'}',
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    ),
                  ),
                  if (requests.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: EmptyState(
                          image: 'empty_orders.png',
                          title: 'لا توجد طلبات حاليًا',
                          message: 'سنرسل لك إشعارًا فور وصول طلب جديد',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      sliver: SliverList.separated(
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder:
                            (_, i) => _RequestCard(
                              key: ValueKey(requests[i].id),
                              request: requests[i],
                            ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: .08),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.online, required this.onChanged});
  final bool online;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            online
                ? const LinearGradient(colors: [MigaColors.driverChart, _accent], begin: Alignment.topRight, end: Alignment.bottomLeft)
                : null,
        color: online ? null : MigaColors.ink,
        borderRadius: MigaRadius.all(MigaRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), shape: BoxShape.circle),
            child: Icon(online ? Icons.wifi_tethering_rounded : Icons.portable_wifi_off_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'أنت متصل الآن' : 'أنت غير متصل', style: t.titleMedium?.copyWith(color: Colors.white)),
                Text(online ? 'تستقبل طلبات التوصيل القريبة' : 'لن تصلك طلبات جديدة', style: t.bodySmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.15,
            child: Switch(
              value: online,
              onChanged: onChanged,
              trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? Colors.white.withValues(alpha: .35) : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: MigaColors.surface, borderRadius: MigaRadius.all(MigaRadius.lg)),
        child: Column(
          children: [
            Icon(icon, color: _accent, size: 22),
            const SizedBox(height: 4),
            FittedBox(child: Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            Text(label, style: t.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({super.key, required this.request});
  final DeliveryRequest request;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      final d = await DriverData.instance.accept(widget.request.id);
      if (mounted) migaPush(context, DeliveryDetailPage(deliveryId: d.id, initial: d));
    } catch (e) {
      if (!mounted) return;
      showMigaError(context, e);
      DriverData.instance.refresh(); // e.g. another driver took it first
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.request;
    return MigaCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: MigaColors.successSoft, borderRadius: MigaRadius.all(MigaRadius.pill)),
                child: Text(MigaFormat.money(r.fee), style: t.titleSmall?.copyWith(color: MigaColors.success, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              if (r.distanceKm != null) Text('${r.distanceKm!.toStringAsFixed(1)} كم', style: t.labelMedium),
              const Spacer(),
              Text('#${r.number}', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          _Stop(
            icon: Icons.storefront_rounded,
            color: MigaColors.merchantAccent,
            title: r.storeName,
            subtitle: r.pickupAddress ?? '—',
            line: true,
          ),
          _Stop(icon: Icons.location_on_rounded, color: MigaColors.primary, title: 'حي ${r.district}', subtitle: r.city),
          const SizedBox(height: 4),
          Row(
            children: [
              MigaImage(r.imageUrl ?? '', width: 28, height: 28, borderRadius: MigaRadius.all(6)),
              const SizedBox(width: 8),
              Expanded(child: Text('${r.productName} × ${r.quantity}', style: t.bodySmall, overflow: TextOverflow.ellipsis)),
              const StatusChip('مدفوع مسبقًا', tone: StatusTone.success, icon: Icons.verified_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: MigaButton(
                  label: 'تخطي',
                  variant: MigaButtonVariant.outline,
                  color: MigaColors.textSecondary,
                  height: 46,
                  onPressed: _accepting ? null : () => DriverData.instance.decline(r),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: MigaButton(label: 'قبول الطلب', icon: Icons.check_rounded, height: 46, loading: _accepting, onPressed: _accept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.color, required this.title, required this.subtitle, this.line = false});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(icon, size: 20, color: color),
              if (line) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: MigaColors.border)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title, style: t.titleSmall), Text(subtitle, style: t.bodySmall)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
