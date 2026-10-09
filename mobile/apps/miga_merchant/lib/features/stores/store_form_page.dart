import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../../core/services.dart';

/// Create / edit a store: name, category, city + pickup address (drivers in that city collect from there),
/// description, logo and cover (uploaded).
class StoreFormPage extends StatefulWidget {
  const StoreFormPage({super.key, this.existing});
  final Store? existing;

  @override
  State<StoreFormPage> createState() => _StoreFormPageState();
}

class _StoreFormPageState extends State<StoreFormPage> {
  late final _nameAr = TextEditingController(text: widget.existing?.nameAr);
  late final _desc = TextEditingController(text: widget.existing?.descriptionAr);
  late final _pickup = TextEditingController(text: widget.existing?.pickupAddress);
  List<City> _cities = [];
  City? _city;
  late String _logo = widget.existing?.logo ?? '';
  late String _cover = widget.existing?.cover ?? '';
  List<StoreCategory> _categories = [];
  StoreCategory? _category;
  bool _saving = false;
  String? _uploading; // 'logo' | 'cover'

  bool get _valid => _nameAr.text.trim().length >= 2 && _category != null && _city != null && _uploading == null;

  @override
  void initState() {
    super.initState();
    AppServices.api.catalog
        .storeCategories()
        .then((c) {
          if (!mounted) return;
          setState(() {
            _categories = c;
            _category = c.where((x) => x.id == widget.existing?.categoryId).firstOrNull;
          });
        })
        .catchError((Object e) {
          if (mounted) showMigaError(context, e);
        });
    AppServices.api.catalog
        .regions()
        .then((r) {
          if (!mounted) return;
          setState(() {
            _cities = [for (final x in r) ...x.cities];
            _city = _cities.where((c) => c.id == widget.existing?.cityId).firstOrNull;
          });
        })
        .catchError((Object e) {
          if (mounted) showMigaError(context, e);
        });
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _desc.dispose();
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _pick(String which) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: which == 'logo' ? 600 : 1600, imageQuality: 85);
    } catch (_) {
      if (mounted) showMigaMessage(context, 'تعذّر فتح الصور', icon: Icons.no_photography_outlined);
      return;
    }
    if (file == null) return;
    setState(() => _uploading = which);
    try {
      final url = await MerchantData.instance.uploadImage('stores', file.path);
      if (mounted) setState(() => which == 'logo' ? _logo = url : _cover = url);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final e = widget.existing;
    try {
      await MerchantData.instance.saveStore(
        Store(
          id: e?.id ?? '',
          nameAr: _nameAr.text.trim(),
          categoryId: _category!.id,
          logo: _logo,
          cover: _cover,
          descriptionAr: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          cityId: _city!.id,
          pickupAddress: _pickup.text.trim(),
        ),
        isNew: e == null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMigaMessage(context, e == null ? 'تم إنشاء المتجر، وسيظهر للعملاء بعد التحقق' : 'تم حفظ التعديلات');
    } catch (err) {
      if (mounted) showMigaError(context, err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = widget.existing;
    const spinner = Center(child: CircularProgressIndicator(color: MigaColors.merchantAccent));
    return Scaffold(
      appBar: AppBar(title: Text(e == null ? 'متجر جديد' : 'تعديل المتجر')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Cover + logo: tap to upload.
          SizedBox(
            height: 170,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: 30,
                  child:
                      _uploading == 'cover'
                          ? spinner
                          : _cover.isEmpty
                          ? UploadTile(
                            label: 'صورة الغلاف',
                            hint: '1600×900 مقترح',
                            icon: Icons.panorama_outlined,
                            accent: MigaColors.merchantAccent,
                            onTap: () => _pick('cover'),
                          )
                          : Stack(
                            fit: StackFit.expand,
                            children: [
                              MigaImage(_cover, borderRadius: MigaRadius.all(MigaRadius.lg)),
                              PositionedDirectional(
                                top: 8,
                                end: 8,
                                child: MigaIconButton(icon: Icons.photo_camera_outlined, size: 38, onTap: () => _pick('cover')),
                              ),
                            ],
                          ),
                ),
                PositionedDirectional(
                  bottom: 0,
                  start: 16,
                  child: GestureDetector(
                    onTap: () => _pick('logo'),
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: MigaShadows.soft),
                      child:
                          _uploading == 'logo'
                              ? spinner
                              : _logo.isEmpty
                              ? Container(
                                decoration: const BoxDecoration(color: MigaColors.surfaceMuted, shape: BoxShape.circle),
                                child: const Icon(Icons.add_a_photo_outlined, color: MigaColors.textSecondary),
                              )
                              : ClipOval(child: MigaImage(_logo)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          MigaTextField(label: 'اسم المتجر', hint: 'مثال: أسواق الخير', controller: _nameAr, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          MigaSelectField(
            label: 'قسم المتجر',
            hint: _categories.isEmpty ? 'جارٍ التحميل…' : 'اختر القسم',
            value: _category?.nameAr,
            icon: Icons.category_outlined,
            onTap: () async {
              if (_categories.isEmpty) return;
              final c = await showMigaPicker<StoreCategory>(
                context: context,
                title: 'قسم المتجر',
                items: _categories,
                label: (x) => x.nameAr,
                selected: _category,
                icon: Icons.category_outlined,
                accent: MigaColors.merchantAccent,
              );
              if (c != null) setState(() => _category = c);
            },
          ),
          const SizedBox(height: 14),
          MigaSelectField(
            label: 'مدينة المتجر',
            hint: _cities.isEmpty ? 'جارٍ التحميل…' : 'اختر المدينة',
            value: _city?.nameAr,
            icon: Icons.location_city_rounded,
            onTap: () async {
              if (_cities.isEmpty) return;
              final c = await showMigaPicker<City>(
                context: context,
                title: 'مدينة المتجر',
                items: _cities,
                label: (x) => x.nameAr,
                selected: _city,
                icon: Icons.location_city_rounded,
                accent: MigaColors.merchantAccent,
              );
              if (c != null) setState(() => _city = c);
            },
          ),
          const SizedBox(height: 14),
          MigaTextField(
            label: 'عنوان الاستلام (المستودع)',
            hint: 'مثال: حي السلامة، شارع صاري، مستودع 12',
            controller: _pickup,
            prefixIcon: Icons.warehouse_outlined,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('يصل طلب الاستلام للمندوبين في مدينة المتجر فقط', style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(height: 14),
          MigaTextField(label: 'وصف المتجر', hint: 'نبذة تظهر للعملاء في صفحة المتجر', controller: _desc, maxLines: 3),
          const SizedBox(height: 14),
          if (e != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: e.isVerified ? MigaColors.successSoft : MigaColors.warningSoft,
                borderRadius: MigaRadius.all(MigaRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    e.isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                    color: e.isVerified ? MigaColors.success : MigaColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    e.isVerified ? 'متجر موثّق من ميجا' : 'بانتظار التوثيق',
                    style: t.titleSmall?.copyWith(color: e.isVerified ? MigaColors.success : MigaColors.warning),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          MigaButton(label: e == null ? 'إنشاء المتجر' : 'حفظ التعديلات', loading: _saving, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}
