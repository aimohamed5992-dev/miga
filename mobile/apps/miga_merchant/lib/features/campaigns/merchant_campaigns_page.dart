import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import 'campaign_wizard_page.dart';
import 'merchant_campaign_detail_page.dart';

enum _Tab {
  active('active', 'نشطة'),
  done('done', 'مكتملة'),
  ended('ended', 'منتهية'),
  draft('draft', 'مسودات');

  const _Tab(this.api, this.label);
  final String api;
  final String label;
}

class MerchantCampaignsPage extends StatefulWidget {
  const MerchantCampaignsPage({super.key});

  @override
  State<MerchantCampaignsPage> createState() => _MerchantCampaignsPageState();
}

class _MerchantCampaignsPageState extends State<MerchantCampaignsPage> {
  _Tab _tab = _Tab.active;
  int _reload = 0;

  Future<void> _create() async {
    await migaPush(context, const CampaignWizardPage());
    if (mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حملاتي')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in _Tab.values) ...[
                  Center(child: MigaChoiceChip(label: tab.label, selected: tab == _tab, onSelected: () => setState(() => _tab = tab))),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: MigaAsync<List<MerchantCampaignView>>(
              key: ValueKey('${_tab.api}-$_reload'),
              load: () => AppServices.api.merchant.campaigns(tab: _tab.api),
              builder:
                  (context, items) =>
                      items.isEmpty
                          ? EmptyState(
                            image: 'empty_campaigns.png',
                            title: 'لا توجد حملات ${_tab.label}',
                            message: 'أطلق حملة شراء جماعي وبِع كميات أكبر',
                            actionLabel: 'حملة جديدة',
                            onAction: _create,
                          )
                          : RefreshIndicator(
                            onRefresh: () async => setState(() => _reload++),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder:
                                  (_, i) => MerchantCampaignCard(
                                    view: items[i],
                                    onReturn: () => setState(() => _reload++),
                                  ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: .06),
                            ),
                          ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-campaign',
        backgroundColor: MigaColors.primary,
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.rocket_launch_rounded),
        label: const Text('حملة جديدة'),
      ),
    );
  }
}

class MerchantCampaignCard extends StatelessWidget {
  const MerchantCampaignCard({super.key, required this.view, this.onReturn});
  final MerchantCampaignView view;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = view.campaign;
    return MigaCard(
      onTap: () => migaPush(context, MerchantCampaignDetailPage(campaignId: c.id)).then((_) => onReturn?.call()),
      child: Column(
        children: [
          Row(
            children: [
              MigaImage(c.product.mainImage, width: 64, height: 64, borderRadius: MigaRadius.all(MigaRadius.md)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.titleAr, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        StatusChip.campaign(c.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    PriceTag(price: c.campaignPrice, originalPrice: c.originalPrice),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CampaignProgress(current: c.currentQuantity, target: c.targetQuantity, compact: true),
          const SizedBox(height: 10),
          Row(
            children: [
              _Meta(icon: Icons.groups_rounded, text: '${c.participantsCount} مشارك'),
              _Meta(icon: Icons.payments_outlined, text: MigaFormat.money(view.collectedAmount)),
              const Spacer(),
              if (c.status == CampaignStatus.active) CountdownChip(c.timeLeft),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 14),
    child: Row(
      children: [
        Icon(icon, size: 16, color: MigaColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}
