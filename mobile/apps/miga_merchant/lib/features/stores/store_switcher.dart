import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import 'store_form_page.dart';

/// Header chip showing the current store; opens a sheet to switch or add stores.
class StoreSwitcher extends StatelessWidget {
  const StoreSwitcher({super.key});

  Future<void> _open(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (c) {
      final data = MerchantData.instance;
      final t = Theme.of(c).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('متاجري', style: t.titleLarge),
              const SizedBox(height: 12),
              for (final s in data.stores)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MigaCard(
                    border: true,
                    onTap: () {
                      Navigator.pop(c);
                      data.switchStore(s.id).catchError((Object e) {
                        if (context.mounted) showMigaError(context, e);
                      });
                    },
                    child: Row(
                      children: [
                        ClipOval(child: MigaImage(s.logo, width: 40, height: 40)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(s.nameAr, style: t.titleSmall), Text(s.categoryName ?? '', style: t.bodySmall)],
                          ),
                        ),
                        if (s.id == data.currentStore.id) const Icon(Icons.check_circle_rounded, color: MigaColors.merchantAccent),
                      ],
                    ),
                  ),
                ),
              MigaButton(
                label: 'إضافة متجر جديد',
                icon: Icons.add_business_rounded,
                variant: MigaButtonVariant.outline,
                onPressed: () {
                  Navigator.pop(c);
                  migaPush(context, const StoreFormPage());
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: MerchantData.instance,
      builder: (context, _) {
        if (!MerchantData.instance.hasStores) return const SizedBox(width: 40, height: 44);
        final s = MerchantData.instance.currentStore;
        return InkWell(
          onTap: () => _open(context),
          borderRadius: MigaRadius.all(MigaRadius.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MigaColors.border)),
                child: ClipOval(child: MigaImage(s.logo, width: 40, height: 40)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المتجر الحالي', style: t.labelSmall),
                    Row(
                      children: [
                        Flexible(child: Text(s.nameAr, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
