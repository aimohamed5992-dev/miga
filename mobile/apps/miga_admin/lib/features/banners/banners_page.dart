import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';

const _linkTypes = [
  ('none', 'بدون رابط', Icons.link_off_rounded),
  ('campaign', 'حملة', Icons.campaign_rounded),
  ('product', 'منتج', Icons.inventory_2_rounded),
  ('store', 'متجر', Icons.storefront_rounded),
  ('storeCategory', 'قسم متاجر', Icons.category_rounded),
];

String _linkLabel(String type) => _linkTypes.firstWhere((l) => l.$1 == type, orElse: () => _linkTypes.first).$2;

/// Home-screen slides of the customer app: image, copy, what a tap opens, order, active flag and optional schedule.
class BannersPage extends StatefulWidget {
  const BannersPage({super.key});

  @override
  State<BannersPage> createState() => _BannersPageState();
}

class _BannersPageState extends State<BannersPage> {
  late Future<List<AdminBanner>> _future = AppServices.api.admin.banners();

  void _reload() => setState(() => _future = AppServices.api.admin.banners());

  Future<void> _edit([AdminBanner? existing, int nextOrder = 0]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _BannerDialog(existing: existing, nextOrder: nextOrder));
    if (saved == true) _reload();
  }

  Future<void> _delete(AdminBanner b) async {
    final ok = await confirmAction(
      context,
      title: 'حذف البانر',
      message: 'سيختفي "${b.title ?? 'البانر'}" من الصفحة الرئيسية للعملاء فورًا.',
      confirmLabel: 'حذف',
    );
    if (!ok || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.deleteBanner(b.id), 'تم حذف البانر')) _reload();
  }

  Future<void> _save(AdminBanner b, {int? sortOrder, bool? isActive}) => AppServices.api.admin.saveBanner(
    id: b.id,
    imageUrl: b.imageUrl,
    title: b.title,
    subtitle: b.subtitle,
    buttonLabel: b.buttonLabel,
    linkType: b.linkType,
    linkId: b.linkId,
    sortOrder: sortOrder ?? b.sortOrder,
    isActive: isActive ?? b.isActive,
    startsAt: b.startsAt,
    endsAt: b.endsAt,
  );

  /// Swap the order of two neighbours (orders are rewritten 0..n so they stay unique).
  Future<void> _move(List<AdminBanner> items, int i, int delta) async {
    final j = i + delta;
    if (j < 0 || j >= items.length) return;
    final list = [...items];
    final moved = list.removeAt(i);
    list.insert(j, moved);
    await runAction(context, () async {
      for (final (k, b) in list.indexed) {
        if (b.sortOrder != k) await _save(b, sortOrder: k);
      }
    }, 'تم تحديث الترتيب');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: 'البانرات الإعلانية',
          subtitle: 'شرائح الصفحة الرئيسية في تطبيق العميل — اربط كل بانر بحملة أو منتج أو متجر',
          actions: [
            FutureBuilder<List<AdminBanner>>(
              future: _future,
              builder:
                  (context, snap) => MigaButton(
                    label: 'إضافة بانر',
                    icon: Icons.add_photo_alternate_rounded,
                    expanded: false,
                    height: 44,
                    onPressed: () => _edit(null, snap.data?.length ?? 0),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<AdminBanner>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
            }
            final items = snap.data;
            if (items == null) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            if (items.isEmpty) {
              return const SizedBox(
                height: 320,
                child: EmptyState(
                  image: 'empty_orders.png',
                  title: 'لا توجد بانرات',
                  message: 'أضف أول بانر ليظهر في الصفحة الرئيسية للعملاء',
                ),
              );
            }
            return Column(
              children: [
                for (final (i, b) in items.indexed) ...[
                  _BannerRow(
                    banner: b,
                    first: i == 0,
                    last: i == items.length - 1,
                    onEdit: () => _edit(b),
                    onDelete: () => _delete(b),
                    onUp: () => _move(items, i, -1),
                    onDown: () => _move(items, i, 1),
                    onActive:
                        (v) async =>
                            (await runAction(context, () => _save(b, isActive: v), v ? 'البانر ظاهر للعملاء' : 'أُخفي البانر'))
                                ? _reload()
                                : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    required this.banner,
    required this.first,
    required this.last,
    required this.onEdit,
    required this.onDelete,
    required this.onUp,
    required this.onDown,
    required this.onActive,
  });
  final AdminBanner banner;
  final bool first;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = banner;
    final now = DateTime.now();
    final scheduled =
        (b.startsAt != null && b.startsAt!.isAfter(now))
            ? 'يبدأ ${MigaFormat.date(b.startsAt!)}'
            : (b.endsAt != null && b.endsAt!.isBefore(now))
            ? 'انتهى ${MigaFormat.date(b.endsAt!)}'
            : (b.endsAt != null ? 'حتى ${MigaFormat.date(b.endsAt!)}' : null);
    return MigaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Column(
            children: [
              IconButton(tooltip: 'لأعلى', onPressed: first ? null : onUp, icon: const Icon(Icons.keyboard_arrow_up_rounded)),
              IconButton(tooltip: 'لأسفل', onPressed: last ? null : onDown, icon: const Icon(Icons.keyboard_arrow_down_rounded)),
            ],
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: b.isActive ? 1 : .45,
            child: MigaImage(b.imageUrl, width: 220, height: 88, borderRadius: MigaRadius.all(MigaRadius.md)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title ?? 'بدون عنوان', style: t.titleMedium),
                if (b.subtitle != null) Text(b.subtitle!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(
                      b.linkType == 'none' ? 'بدون رابط' : '${_linkLabel(b.linkType)}: ${b.linkTitle ?? '—'}',
                      tone: b.linkType == 'none' ? StatusTone.neutral : StatusTone.info,
                      icon: Icons.link_rounded,
                    ),
                    if (scheduled != null) StatusChip(scheduled, tone: StatusTone.warning, icon: Icons.schedule_rounded),
                  ],
                ),
              ],
            ),
          ),
          Column(children: [Switch(value: b.isActive, onChanged: onActive), Text(b.isActive ? 'ظاهر' : 'مخفي', style: t.labelSmall)]),
          const SizedBox(width: 8),
          IconButton(tooltip: 'تعديل', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: MigaColors.error)),
        ],
      ),
    );
  }
}

/// Add / edit dialog: image upload, copy, link target (searchable), active flag and optional schedule.
class _BannerDialog extends StatefulWidget {
  const _BannerDialog({this.existing, required this.nextOrder});
  final AdminBanner? existing;
  final int nextOrder;

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  late String? _image = widget.existing?.imageUrl;
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _subtitle = TextEditingController(text: widget.existing?.subtitle);
  late final _button = TextEditingController(text: widget.existing?.buttonLabel ?? 'تسوّق الآن');
  late String _linkType = widget.existing?.linkType ?? 'campaign';
  late String? _linkId = widget.existing?.linkId;
  late String? _linkTitle = widget.existing?.linkTitle;
  late bool _active = widget.existing?.isActive ?? true;
  late DateTime? _startsAt = widget.existing?.startsAt;
  late DateTime? _endsAt = widget.existing?.endsAt;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _button.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await AppServices.api.client.uploadImageBytes('banners', await file.readAsBytes(), file.name);
      if (mounted) setState(() => _image = url);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickTarget() async {
    final picked = await showDialog<(String, String)>(context: context, builder: (_) => _TargetPicker(type: _linkType));
    if (picked == null) return;
    setState(() {
      _linkId = picked.$1;
      _linkTitle = picked.$2;
    });
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: (start ? _startsAt : _endsAt) ?? now,
    );
    if (d != null) setState(() => start ? _startsAt = d : _endsAt = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _save() async {
    if (_image == null) return showMigaError(context, const ApiException(400, 'image_required', 'ارفع صورة البانر'));
    if (_linkType != 'none' && _linkId == null) {
      return showMigaError(context, const ApiException(400, 'link_required', 'اختر العنصر الذي يفتحه البانر'));
    }
    setState(() => _saving = true);
    try {
      await AppServices.api.admin.saveBanner(
        id: widget.existing?.id,
        imageUrl: _image!,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        buttonLabel: _button.text.trim(),
        linkType: _linkType,
        linkId: _linkId,
        sortOrder: widget.existing?.sortOrder ?? widget.nextOrder,
        isActive: _active,
        startsAt: _startsAt,
        endsAt: _endsAt,
      );
      if (mounted) {
        Navigator.pop(context, true);
        showMigaMessage(context, widget.existing == null ? 'أُضيف البانر' : 'تم حفظ البانر');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMigaError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'بانر جديد' : 'تعديل البانر'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _uploading ? null : _pickImage,
                borderRadius: MigaRadius.all(MigaRadius.lg),
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: MigaColors.surfaceMuted,
                    borderRadius: MigaRadius.all(MigaRadius.lg),
                    border: Border.all(color: MigaColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      _uploading
                          ? const Center(child: CircularProgressIndicator())
                          : _image == null
                          ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined, size: 40, color: MigaColors.textSecondary),
                              const SizedBox(height: 6),
                              Text('ارفع صورة البانر', style: t.titleSmall),
                              Text('مقاس مقترح 1600×600 • JPG أو PNG', style: t.bodySmall),
                            ],
                          )
                          : Stack(
                            fit: StackFit.expand,
                            children: [
                              MigaImage(_image!),
                              PositionedDirectional(
                                bottom: 8,
                                start: 8,
                                child: Chip(avatar: const Icon(Icons.photo_camera_outlined, size: 16), label: const Text('تغيير الصورة')),
                              ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 14),
              MigaTextField(label: 'العنوان', hint: 'مثال: أحدث الأجهزة الذكية', controller: _title),
              const SizedBox(height: 10),
              MigaTextField(label: 'النص الفرعي', hint: 'مثال: بأسعار الجملة لفترة محدودة', controller: _subtitle),
              const SizedBox(height: 10),
              MigaTextField(label: 'نص الزر', hint: 'تسوّق الآن', controller: _button),
              const SizedBox(height: 14),
              Text('عند الضغط يفتح', style: t.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label, icon) in _linkTypes)
                    MigaChoiceChip(
                      label: label,
                      icon: icon,
                      selected: _linkType == value,
                      onSelected:
                          () => setState(() {
                            if (_linkType != value) {
                              _linkId = null;
                              _linkTitle = null;
                            }
                            _linkType = value;
                          }),
                    ),
                ],
              ),
              if (_linkType != 'none') ...[
                const SizedBox(height: 10),
                MigaSelectField(
                  label: _linkLabel(_linkType),
                  hint: 'اختر ${_linkLabel(_linkType)}',
                  value: _linkTitle,
                  icon: Icons.link_rounded,
                  onTap: _pickTarget,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: Text(_startsAt == null ? 'يبدأ فورًا' : 'يبدأ ${MigaFormat.date(_startsAt!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event_busy_rounded, size: 18),
                      label: Text(_endsAt == null ? 'بدون نهاية' : 'ينتهي ${MigaFormat.date(_endsAt!)}'),
                    ),
                  ),
                  if (_startsAt != null || _endsAt != null)
                    IconButton(
                      tooltip: 'إلغاء الجدولة',
                      onPressed: () => setState(() => _startsAt = _endsAt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('ظاهر للعملاء'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        MigaButton(label: 'حفظ', expanded: false, height: 42, loading: _saving, onPressed: _uploading ? null : _save),
      ],
    );
  }
}

/// Search-and-pick for the banner target (campaign / product / store via the catalog search; categories listed).
class _TargetPicker extends StatefulWidget {
  const _TargetPicker({required this.type});
  final String type;

  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  List<(String id, String title, String? subtitle, String? image)> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final catalog = AppServices.api.catalog;
      List<(String, String, String?, String?)> rows;
      if (widget.type == 'storeCategory') {
        rows = [for (final c in await catalog.storeCategories()) (c.id, c.nameAr, null, c.image)];
        if (q.isNotEmpty) rows = rows.where((r) => r.$2.contains(q)).toList();
      } else if (q.isEmpty) {
        rows = switch (widget.type) {
          'campaign' => [
            for (final c in (await catalog.campaigns()).items) (c.id, c.titleAr, c.product.storeName ?? c.storeName, c.product.mainImage),
          ],
          'store' => [for (final s in (await catalog.stores()).items) (s.id, s.nameAr, s.categoryName, s.logo)],
          _ => [],
        };
      } else {
        final r = await catalog.search(q);
        rows = switch (widget.type) {
          'campaign' => [for (final c in r.campaigns) (c.id, c.titleAr, c.storeName, c.product.mainImage)],
          'product' => [for (final p in r.products) (p.id, p.nameAr, p.storeName, p.mainImage)],
          'store' => [for (final s in r.stores) (s.id, s.nameAr, s.categoryName, s.logo)],
          _ => [],
        };
      }
      if (mounted) setState(() => _results = rows);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('اختر ${_linkLabel(widget.type)}'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            AdminSearchField(hint: 'ابحث بالاسم…', width: 480, onChanged: _search),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            Expanded(
              child:
                  _results.isEmpty && !_loading
                      ? Center(child: Text(widget.type == 'product' ? 'اكتب اسم المنتج للبحث' : 'لا توجد نتائج', style: t.bodySmall))
                      : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final (id, title, subtitle, image) = _results[i];
                          return ListTile(
                            leading:
                                image == null || image.isEmpty
                                    ? const Icon(Icons.category_rounded)
                                    : MigaImage(image, width: 40, height: 40, borderRadius: MigaRadius.all(MigaRadius.sm)),
                            title: Text(title, style: t.titleSmall),
                            subtitle: subtitle == null ? null : Text(subtitle, style: t.bodySmall),
                            onTap: () => Navigator.pop(context, (id, title)),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))],
    );
  }
}
