import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../campaigns/campaign_wizard_page.dart';
import '../shell/merchant_shell.dart';

/// Add / edit product: images (main + gallery), names, category (parent › child), price, stock, description.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.existing});
  final Product? existing;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  late final _nameAr = TextEditingController(text: widget.existing?.nameAr);
  late final _price = TextEditingController(text: widget.existing?.price.toStringAsFixed(0));
  late final _stock = TextEditingController(text: widget.existing?.stockQuantity.toString());
  late final _desc = TextEditingController(text: widget.existing?.descriptionAr);
  late List<String> _images = [...?widget.existing?.images];
  late ProductCategory? _category = MerchantData.instance.categories.where((c) => c.id == widget.existing?.categoryId).firstOrNull;
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;
  bool _uploading = false;

  bool get _valid =>
      _nameAr.text.trim().length >= 3 && _category != null && (double.tryParse(_price.text) ?? 0) > 0 && int.tryParse(_stock.text) != null;

  @override
  void dispose() {
    for (final c in [_nameAr, _price, _stock, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('اختيار من الصور'),
                  onTap: () => Navigator.pop(c, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('التقاط صورة'),
                  onTap: () => Navigator.pop(c, ImageSource.camera),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      if (mounted) {
        showMigaMessage(context, 'تعذّر فتح ${source == ImageSource.camera ? 'الكاميرا' : 'الصور'}', icon: Icons.no_photography_outlined);
      }
      return;
    }
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await MerchantData.instance.uploadImage('products', file.path);
      if (mounted) setState(() => _images = [..._images, url]);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_images.isEmpty) {
      showMigaMessage(context, 'أضف صورة واحدة على الأقل للمنتج', icon: Icons.add_photo_alternate_outlined);
      return;
    }
    setState(() => _saving = true);
    final data = MerchantData.instance;
    final e = widget.existing;
    try {
      await data.saveProduct(
        Product(
          id: e?.id ?? '',
          storeId: data.currentStore.id,
          categoryId: _category!.id,
          nameAr: _nameAr.text.trim(),
          price: double.parse(_price.text),
          images: _images,
          descriptionAr: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          stockQuantity: int.parse(_stock.text),
          isActive: _active,
        ),
        isNew: e == null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMigaMessage(context, e == null ? 'تمت إضافة المنتج' : 'تم حفظ التعديلات');
    } catch (err) {
      if (mounted) showMigaError(context, err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('حذف المنتج؟'),
            content: const Text('لا يمكن حذف منتج مرتبط بحملة نشطة. سيُخفى من المتجر فورًا.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: MigaColors.error))),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      await MerchantData.instance.deleteProduct(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context);
      showMigaMessage(context, 'تم حذف المنتج');
    } catch (err) {
      if (mounted) showMigaError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    final e = widget.existing;
    final inCampaign = e?.inActiveCampaign ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? 'منتج جديد' : 'تعديل المنتج'),
        actions: [
          if (e != null)
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: MigaColors.error), onPressed: inCampaign ? null : _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('صور المنتج', style: t.titleSmall),
          Text('الصورة الأولى هي الصورة الرئيسية • حتى 5 صور', style: t.bodySmall),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              onReorder: (a, b) => setState(() => _images.insert(b > a ? b - 1 : b, _images.removeAt(a))),
              footer: _images.length >= 5 ? null : _AddImageTile(loading: _uploading, onTap: _uploading ? null : _addImage),
              itemBuilder:
                  (_, i) => Padding(
                    key: ValueKey('$i${_images[i]}'),
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Stack(
                      children: [
                        MigaImage(_images[i], width: 104, height: 104, borderRadius: MigaRadius.all(MigaRadius.md)),
                        if (i == 0)
                          PositionedDirectional(
                            bottom: 6,
                            start: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: MigaColors.merchantAccent, borderRadius: MigaRadius.all(MigaRadius.sm)),
                              child: Text('رئيسية', style: t.labelSmall?.copyWith(color: Colors.white)),
                            ),
                          ),
                        PositionedDirectional(
                          top: 4,
                          end: 4,
                          child: InkWell(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 20),
          MigaTextField(label: 'اسم المنتج (عربي)', hint: 'مثال: أرز بسمتي 10 كجم', controller: _nameAr, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          MigaSelectField(
            label: 'التصنيف',
            hint: 'اختر التصنيف',
            value: _category == null ? null : data.categoryPath(_category!),
            icon: Icons.folder_outlined,
            onTap: () async {
              final c = await showMigaPicker<ProductCategory>(
                context: context,
                title: 'تصنيف المنتج',
                items: data.categories,
                label: data.categoryPath,
                selected: _category,
                icon: Icons.folder_outlined,
                accent: MigaColors.merchantAccent,
              );
              if (c != null) setState(() => _category = c);
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MigaTextField(
                  label: 'السعر (ر.س)',
                  hint: '0.00',
                  controller: _price,
                  prefixIcon: Icons.sell_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MigaTextField(
                  label: 'الكمية المتاحة',
                  hint: '0',
                  controller: _stock,
                  prefixIcon: Icons.inventory_2_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MigaTextField(label: 'الوصف', hint: 'المواصفات، الحجم، بلد المنشأ…', controller: _desc, maxLines: 4),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text('المنتج ظاهر للعملاء', style: t.titleSmall),
            subtitle: Text('يمكنك إخفاؤه مؤقتًا دون حذفه', style: t.bodySmall),
          ),
          if (e != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => inCampaign ? MerchantShell.goToTab(context, 1) : migaPush(context, CampaignWizardPage(initialProduct: e)),
              borderRadius: MigaRadius.all(MigaRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: MigaColors.primaryGradient, borderRadius: MigaRadius.all(MigaRadius.lg)),
                child: Row(
                  children: [
                    const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inCampaign ? 'المنتج في حملة نشطة الآن' : 'أطلق حملة شراء جماعي لهذا المنتج',
                            style: t.titleSmall?.copyWith(color: Colors.white),
                          ),
                          Text('بِع كميات أكبر بسعر الجملة', style: t.bodySmall?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const MigaChevron(color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          MigaButton(label: e == null ? 'إضافة المنتج' : 'حفظ التعديلات', loading: _saving, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap, this.loading = false});
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: MigaRadius.all(MigaRadius.md),
    child: Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: MigaColors.merchantAccent.withValues(alpha: .05),
        borderRadius: MigaRadius.all(MigaRadius.md),
        border: Border.all(color: MigaColors.merchantAccent.withValues(alpha: .3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: MigaColors.merchantAccent))
          else
            const Icon(Icons.add_photo_alternate_outlined, color: MigaColors.merchantAccent, size: 30),
          const SizedBox(height: 4),
          Text(loading ? 'جارٍ الرفع…' : 'إضافة صورة', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}
