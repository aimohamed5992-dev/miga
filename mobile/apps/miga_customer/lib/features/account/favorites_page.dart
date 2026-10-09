import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/favorites_store.dart';
import '../campaigns/campaign_detail_page.dart';

/// Campaigns the customer saved with the heart on the campaign page.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<Campaign>> _future = FavoritesStore.instance.load();

  Future<void> _reload() async {
    final next = FavoritesStore.instance.load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الحملات المفضلة')),
    body: FutureBuilder<List<Campaign>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
        }
        if (!snap.hasData) return ListView(padding: const EdgeInsets.all(20), children: List.generate(3, (_) => const MigaTileSkeleton()));
        return ListenableBuilder(
          listenable: FavoritesStore.instance,
          builder: (context, _) {
            final items = FavoritesStore.instance.items;
            return RefreshIndicator(
              onRefresh: _reload,
              child:
                  items.isEmpty
                      ? ListView(
                        children: const [
                          SizedBox(
                            height: 480,
                            child: EmptyState(
                              image: 'empty_orders.png',
                              title: 'لا توجد حملات مفضلة',
                              message: 'اضغط على القلب في صفحة أي حملة لتجدها هنا',
                            ),
                          ),
                        ],
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder:
                            (context, i) => Stack(
                              children: [
                                CampaignCard(campaign: items[i], onTap: () => migaPush(context, CampaignDetailPage(campaign: items[i]))),
                                PositionedDirectional(
                                  top: 10,
                                  end: 10,
                                  child: MigaIconButton(
                                    icon: Icons.favorite_rounded,
                                    color: MigaColors.primary,
                                    size: 38,
                                    onTap: () async {
                                      try {
                                        await FavoritesStore.instance.toggle(items[i]);
                                      } catch (e) {
                                        if (context.mounted) showMigaError(context, e);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                      ),
            );
          },
        );
      },
    ),
  );
}
