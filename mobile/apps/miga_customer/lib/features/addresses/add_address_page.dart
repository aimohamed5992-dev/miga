import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/address_store.dart';
import '../../core/services.dart';

/// Address = name + Region → City → District + phone (+ optional details), per the spec.
class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key, this.existing});
  final Address? existing;

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const _presets = [('المنزل', Icons.home_rounded), ('العمل', Icons.work_rounded), ('أخرى', Icons.bookmark_rounded)];

  late final _name = TextEditingController(text: widget.existing?.addressName ?? 'المنزل');
  late final _phone = TextEditingController(text: widget.existing?.phoneNumber.replaceFirst('0', '') ?? '');
  late final _details = TextEditingController(text: widget.existing?.details ?? '');
  Region? _region;
  City? _city;
  District? _district;
  late bool _isDefault = widget.existing?.isDefault ?? AddressStore.instance.items.isEmpty;
  bool _saving = false;
  List<Region> _regions = [];

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await AppServices.api.catalog.regions();
      if (!mounted) return;
      final e = widget.existing;
      setState(() {
        _regions = regions;
        if (e != null) {
          _region = regions.where((r) => r.id == e.regionId).firstOrNull;
          _city = _region?.cities.where((c) => c.id == e.cityId).firstOrNull;
          _district = _city?.districts.where((d) => d.id == e.districtId).firstOrNull;
        }
      });
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _district != null && RegExp(r'^5\d{8}$').hasMatch(_phone.text);

  Future<void> _pickRegion() async {
    final r = await showMigaPicker<Region>(
      context: context,
      title: 'اختر المنطقة',
      items: _regions,
      label: (e) => e.nameAr,
      selected: _region,
      icon: Icons.map_outlined,
    );
    if (r == null || r == _region) return;
    setState(() {
      _region = r;
      _city = null;
      _district = null;
    });
  }

  Future<void> _pickCity() async {
    final c = await showMigaPicker<City>(
      context: context,
      title: 'اختر المدينة',
      items: _region!.cities,
      label: (e) => e.nameAr,
      selected: _city,
      icon: Icons.location_city_rounded,
    );
    if (c == null || c == _city) return;
    setState(() {
      _city = c;
      _district = null;
    });
  }

  Future<void> _pickDistrict() async {
    final d = await showMigaPicker<District>(
      context: context,
      title: 'اختر الحي',
      items: _city!.districts,
      label: (e) => e.nameAr,
      selected: _district,
    );
    if (d != null) setState(() => _district = d);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AddressStore.instance.save(
        id: widget.existing?.id,
        addressName: _name.text.trim(),
        regionId: _region!.id,
        cityId: _city!.id,
        districtId: _district!.id,
        phoneNumber: '0${_phone.text}',
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
        isDefault: _isDefault,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'إضافة عنوان' : 'تعديل العنوان')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Center(child: MigaImage('customer_location.png', width: 150, height: 150, fit: BoxFit.contain)),
          const SizedBox(height: 8),
          Text('اسم العنوان', style: t.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in _presets) ...[
                MigaChoiceChip(
                  icon: p.$2,
                  label: p.$1,
                  selected: _name.text == p.$1,
                  onSelected: () => setState(() => _name.text = p.$1 == 'أخرى' ? '' : p.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          if (!_presets.any((p) => p.$1 == _name.text) || _name.text.isEmpty) ...[
            const SizedBox(height: 10),
            MigaTextField(hint: 'مثال: بيت العائلة', controller: _name, onChanged: (_) => setState(() {})),
          ],
          const SizedBox(height: 18),
          MigaSelectField(label: 'المنطقة', hint: 'اختر المنطقة', value: _region?.nameAr, icon: Icons.map_outlined, onTap: _pickRegion),
          const SizedBox(height: 14),
          MigaSelectField(
            label: 'المدينة',
            hint: _region == null ? 'اختر المنطقة أولًا' : 'اختر المدينة',
            value: _city?.nameAr,
            icon: Icons.location_city_rounded,
            enabled: _region != null,
            onTap: _pickCity,
          ),
          const SizedBox(height: 14),
          MigaSelectField(
            label: 'الحي',
            hint: _city == null ? 'اختر المدينة أولًا' : 'اختر الحي',
            value: _district?.nameAr,
            enabled: _city != null,
            onTap: _pickDistrict,
          ),
          const SizedBox(height: 14),
          MigaPhoneField(controller: _phone, label: 'رقم الجوال للتوصيل', onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          MigaTextField(
            label: 'تفاصيل إضافية (اختياري)',
            hint: 'اسم الشارع، رقم المبنى، علامة مميزة…',
            controller: _details,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: Text('تعيين كعنوان افتراضي', style: t.titleSmall),
          ),
          const SizedBox(height: 12),
          MigaButton(label: 'حفظ العنوان', loading: _saving, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}
