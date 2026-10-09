import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/address_store.dart';
import 'add_address_page.dart';

/// Saved addresses. With [selecting] it returns the tapped address (used by checkout).
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key, this.selecting = false, this.selectedId});
  final bool selecting;
  final String? selectedId;

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  bool get selecting => widget.selecting;
  String? get selectedId => widget.selectedId;

  @override
  void initState() {
    super.initState();
    AddressStore.instance.load().catchError((Object e) {
      if (mounted) showMigaError(context, e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(selecting ? 'اختر عنوان التوصيل' : 'عناويني')),
      body: ListenableBuilder(
        listenable: AddressStore.instance,
        builder: (context, _) {
          final items = AddressStore.instance.items;
          if (items.isEmpty) {
            return EmptyState(
              image: 'customer_location.png',
              title: 'لا توجد عناوين محفوظة',
              message: 'أضف عنوانك لتصلك الطلبات بسرعة',
              actionLabel: 'إضافة عنوان',
              onAction: () => migaPush(context, const AddAddressPage()),
            );
          }
          return RefreshIndicator(
            onRefresh: AddressStore.instance.load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = items[i];
                final selected = selecting && a.id == selectedId;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: MigaRadius.all(MigaRadius.lg),
                    border: Border.all(color: selected ? MigaColors.primary : Colors.transparent, width: 1.6),
                  ),
                  child: MigaCard(
                    onTap: selecting ? () => Navigator.pop(context, a) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: MigaColors.primarySoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                          child: Icon(
                            a.addressName == 'العمل'
                                ? Icons.work_rounded
                                : (a.addressName == 'المنزل' ? Icons.home_rounded : Icons.bookmark_rounded),
                            color: MigaColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(a.addressName, style: t.titleSmall),
                                  if (a.isDefault) ...[const SizedBox(width: 8), const StatusChip('افتراضي', tone: StatusTone.brand)],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(a.summary, style: t.bodyMedium),
                              if (a.details != null) Text(a.details!, style: t.bodySmall),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: MigaColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(a.phoneNumber, style: t.bodySmall, textDirection: TextDirection.ltr),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (selecting)
                          Icon(
                            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: selected ? MigaColors.primary : MigaColors.textHint,
                          )
                        else
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: MigaColors.textSecondary),
                            onSelected: (v) async {
                              if (v == 'edit') return migaPush(context, AddAddressPage(existing: a));
                              try {
                                if (v == 'default') await AddressStore.instance.makeDefault(a.id);
                                if (v == 'delete') await AddressStore.instance.remove(a.id);
                              } catch (e) {
                                if (context.mounted) showMigaError(context, e);
                              }
                            },
                            itemBuilder:
                                (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                  if (!a.isDefault) const PopupMenuItem(value: 'default', child: Text('تعيين كافتراضي')),
                                  const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: MigaColors.error))),
                                ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MigaButton(
          label: 'إضافة عنوان جديد',
          icon: Icons.add_location_alt_outlined,
          onPressed: () => migaPush(context, const AddAddressPage()),
        ),
      ),
    );
  }
}
