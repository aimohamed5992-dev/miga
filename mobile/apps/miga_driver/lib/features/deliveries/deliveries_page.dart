import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/driver_data.dart';
import '../../core/services.dart';
import '../delivery/delivery_detail_page.dart';

/// "توصيلاتي": in-progress (live from [DriverData]) and history (delivered / failed, from the API).
class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  int _tab = 0;
  Future<List<DriverDelivery>>? _history;

  void _loadHistory() => setState(() => _history = AppServices.api.driver.deliveries(history: true));

  Future<void> _open(DriverDelivery d) async {
    await migaPush(context, DeliveryDetailPage(deliveryId: d.id, initial: d));
    if (_tab == 1) _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final data = DriverData.instance;
    return ListenableBuilder(
      listenable: data,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(title: const Text('توصيلاتي')),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      MigaChoiceChip(
                        label: 'الجارية (${data.active.length})',
                        selected: _tab == 0,
                        onSelected: () => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 8),
                      MigaChoiceChip(
                        label: 'السجل',
                        selected: _tab == 1,
                        onSelected: () {
                          setState(() => _tab = 1);
                          _loadHistory();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _tab == 0
                          ? RefreshIndicator(onRefresh: data.refresh, child: _list(data.active, active: true))
                          : FutureBuilder<List<DriverDelivery>>(
                            future: _history,
                            builder: (context, snap) {
                              if (snap.hasError) {
                                final e = snap.error;
                                return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _loadHistory);
                              }
                              if (!snap.hasData) {
                                return ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: List.generate(4, (_) => const MigaTileSkeleton()),
                                );
                              }
                              return RefreshIndicator(onRefresh: () async => _loadHistory(), child: _list(snap.data!, active: false));
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _list(List<DriverDelivery> items, {required bool active}) {
    final t = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 420,
            child: EmptyState(
              image: active ? 'driver_onb_2.png' : 'empty_orders.png',
              title: active ? 'لا توجد توصيلات جارية' : 'لا يوجد سجل بعد',
              message: 'اقبل طلبًا من الصفحة الرئيسية لتبدأ',
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = items[i];
        final when = d.deliveredAt ?? d.outForDeliveryAt ?? d.pickedUpAt ?? d.acceptedAt;
        return MigaCard(
          onTap: () => _open(d),
          child: Column(
            children: [
              Row(
                children: [
                  Text('#${d.number}', style: t.titleSmall),
                  const SizedBox(width: 8),
                  if (when != null) Text(MigaFormat.timeAgo(when), style: t.bodySmall),
                  const Spacer(),
                  StatusChip.delivery(d.status),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  MigaAvatar(name: d.customerName.isEmpty ? 'ع' : d.customerName, size: 40, color: MigaColors.driverAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.customerName, style: t.titleSmall),
                        Text(
                          '${d.district} • ${d.productName} × ${d.quantity}',
                          style: t.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    MigaFormat.money(d.fee),
                    style: t.titleSmall?.copyWith(
                      color: d.status == DeliveryStatus.delivered ? MigaColors.success : MigaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 50).ms);
      },
    );
  }
}
