import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';

/// Product categories of the current store, with Parent → Child support.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = MerchantData.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('تصنيفات المنتجات')),
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final roots = data.rootCategories;
          if (roots.isEmpty) {
            return EmptyState(
              image: 'empty_orders.png',
              title: 'لا توجد تصنيفات',
              message: 'نظّم منتجاتك في تصنيفات ليسهل على العملاء تصفحها',
              actionLabel: 'إضافة تصنيف',
              onAction: () => showCategorySheet(context),
            );
          }
          return RefreshIndicator(
            onRefresh: data.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                Text('${data.currentStore.nameAr} • ${data.categories.length} تصنيف', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                for (final c in roots) ...[_CategoryCard(category: c), const SizedBox(height: 10)],
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MigaButton(label: 'إضافة تصنيف', icon: Icons.create_new_folder_outlined, onPressed: () => showCategorySheet(context)),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    final children = data.childrenOf(category.id);
    return MigaCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: children.isNotEmpty,
          shape: const Border(),
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: MigaColors.merchantAccent.withValues(alpha: .08), borderRadius: MigaRadius.all(MigaRadius.md)),
            child: const Icon(Icons.folder_rounded, color: MigaColors.merchantAccent),
          ),
          title: Text(category.nameAr, style: t.titleSmall),
          subtitle: Text('${data.productsIn(category.id)} منتج • ${children.length} تصنيف فرعي', style: t.bodySmall),
          trailing: _Menu(category: category),
          children: [
            for (final ch in children)
              ListTile(
                contentPadding: const EdgeInsetsDirectional.only(start: 40, end: 8),
                leading: const Icon(Icons.subdirectory_arrow_left_rounded, color: MigaColors.textHint),
                title: Text(ch.nameAr, style: t.bodyMedium),
                subtitle: Text('${data.productsIn(ch.id)} منتج', style: t.labelSmall),
                trailing: _Menu(category: ch),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => showCategorySheet(context, parent: category),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('تصنيف فرعي'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.category});
  final ProductCategory category;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert_rounded, color: MigaColors.textSecondary),
    onSelected: (v) async {
      if (v == 'edit') showCategorySheet(context, existing: category);
      if (v == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text('حذف "${category.nameAr}"؟'),
                content: Text(
                  category.parentId == null ? 'سيتم حذف التصنيفات الفرعية أيضًا. المنتجات لن تُحذف.' : 'المنتجات داخل التصنيف لن تُحذف.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: MigaColors.error))),
                ],
              ),
        );
        if (ok != true) return;
        try {
          await MerchantData.instance.deleteCategory(category.id);
          if (context.mounted) showMigaMessage(context, 'تم حذف التصنيف');
        } catch (e) {
          if (context.mounted) showMigaError(context, e);
        }
      }
    },
    itemBuilder:
        (_) => const [
          PopupMenuItem(value: 'edit', child: Text('تعديل')),
          PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: MigaColors.error))),
        ],
  );
}

/// Add / edit sheet: Arabic name + optional parent.
Future<void> showCategorySheet(BuildContext context, {ProductCategory? existing, ProductCategory? parent}) {
  final data = MerchantData.instance;
  final nameAr = TextEditingController(text: existing?.nameAr);
  String? parentId = existing?.parentId ?? parent?.id;
  var saving = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => StatefulBuilder(
          builder: (c, set) {
            final t = Theme.of(c).textTheme;
            final parents = data.rootCategories.where((p) => p.id != existing?.id).toList();
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'تصنيف جديد' : 'تعديل التصنيف', style: t.titleLarge),
                  const SizedBox(height: 16),
                  MigaTextField(label: 'الاسم (عربي)', hint: 'مثال: أرز وحبوب', controller: nameAr, onChanged: (_) => set(() {})),
                  const SizedBox(height: 12),
                  Text('التصنيف الأب (اختياري)', style: t.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MigaChoiceChip(label: 'بدون (رئيسي)', selected: parentId == null, onSelected: () => set(() => parentId = null)),
                      for (final p in parents)
                        MigaChoiceChip(label: p.nameAr, selected: parentId == p.id, onSelected: () => set(() => parentId = p.id)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  MigaButton(
                    label: 'حفظ',
                    loading: saving,
                    onPressed:
                        nameAr.text.trim().isEmpty
                            ? null
                            : () async {
                              set(() => saving = true);
                              try {
                                await data.saveCategory(
                                  ProductCategory(
                                    id: existing?.id ?? '',
                                    storeId: data.currentStore.id,
                                    nameAr: nameAr.text.trim(),
                                    parentId: parentId,
                                  ),
                                  isNew: existing == null,
                                );
                                if (c.mounted) Navigator.pop(c);
                              } catch (e) {
                                if (c.mounted) {
                                  set(() => saving = false);
                                  showMigaError(c, e);
                                }
                              }
                            },
                  ),
                ],
              ),
            );
          },
        ),
  );
}
