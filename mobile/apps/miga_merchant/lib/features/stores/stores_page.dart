import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import 'store_form_page.dart';

/// Merchant → Stores. One merchant can run several stores (e.g. MIGA Fashion, MIGA Home).
class StoresPage extends StatelessWidget {
  const StoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('متاجري')),
      body: ListenableBuilder(
        listenable: data,
        builder:
            (context, _) => RefreshIndicator(
              onRefresh: data.load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                itemCount: data.stores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final s = data.stores[i];
                  final active = data.isStoreActive(s.id);
                  final current = data.hasStores && s.id == data.currentStore.id;
                  final campaigns = s.activeCampaigns;
                  final products = s.productsCount;
                  return MigaCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 110,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColorFiltered(
                                colorFilter: ColorFilter.matrix(active ? _identity : _grayscale),
                                child: MigaImage(s.cover, borderRadius: const BorderRadius.vertical(top: Radius.circular(MigaRadius.lg))),
                              ),
                              PositionedDirectional(
                                top: 10,
                                start: 10,
                                child: StatusChip(
                                  active ? StoreStatus.active.labelAr : StoreStatus.inactive.labelAr,
                                  tone: active ? StatusTone.success : StatusTone.neutral,
                                ),
                              ),
                              if (current)
                                const PositionedDirectional(top: 10, end: 10, child: StatusChip('المتجر الحالي', tone: StatusTone.info)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipOval(child: MigaImage(s.logo, width: 46, height: 46)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(s.nameAr, style: t.titleMedium),
                                            if (s.isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified_rounded, color: MigaColors.info, size: 18),
                                            ],
                                          ],
                                        ),
                                        Text(s.categoryName ?? '', style: t.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: active,
                                    onChanged: (v) async {
                                      try {
                                        await data.setStoreActive(s.id, v);
                                      } catch (e) {
                                        if (context.mounted) showMigaError(context, e);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      runSpacing: 4,
                                      children: [
                                        _Mini(icon: Icons.campaign_outlined, text: '$campaigns حملة'),
                                        _Mini(icon: Icons.inventory_2_outlined, text: '$products منتج'),
                                        _Mini(icon: Icons.star_rounded, text: s.rating.toStringAsFixed(1)),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => migaPush(context, StoreFormPage(existing: s)),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('تعديل'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MigaButton(
          label: 'إضافة متجر جديد',
          icon: Icons.add_business_rounded,
          onPressed: () => migaPush(context, const StoreFormPage()),
        ),
      ),
    );
  }

  static const _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  static const _grayscale = <double>[.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0];
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 14),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: MigaColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}
