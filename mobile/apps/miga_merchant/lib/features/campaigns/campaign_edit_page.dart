import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Edit a draft or running campaign. For a running one, what customers already paid for is protected:
/// the price is locked once anyone joined, the target can't go below what's sold (equal to it completes the
/// campaign now), and the per-customer limit can't go below an existing order. Pops the updated view.
class CampaignEditPage extends StatefulWidget {
  const CampaignEditPage({super.key, required this.view});
  final MerchantCampaignView view;

  @override
  State<CampaignEditPage> createState() => _CampaignEditPageState();
}

class _CampaignEditPageState extends State<CampaignEditPage> {
  Campaign get c => widget.view.campaign;
  bool get _draft => c.status == CampaignStatus.draft;
  bool get _priceLocked => !_draft && c.currentQuantity > 0;

  late final _title = TextEditingController(text: c.titleAr);
  late final _desc = TextEditingController(text: c.descriptionAr);
  late final _original = TextEditingController(text: _num(c.originalPrice));
  late final _price = TextEditingController(text: _num(c.campaignPrice));
  late final _target = TextEditingController(text: '${c.targetQuantity}');
  late final _maxPer = TextEditingController(text: c.maxPerCustomer?.toString() ?? '');
  late DateTime _endsAt = c.endDate;
  bool _saving = false;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final x in [_title, _desc, _original, _price, _target, _maxPer]) {
      x.dispose();
    }
    super.dispose();
  }

  int? get _targetValue => int.tryParse(_target.text);
  bool get _completesNow => !_draft && c.currentQuantity > 0 && _targetValue == c.currentQuantity;

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: c.startDate.add(Duration(days: _draft ? 30 : 60)),
      initialDate: _endsAt.isBefore(now) ? now : _endsAt,
      helpText: 'تاريخ انتهاء الحملة',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endsAt), helpText: 'وقت الانتهاء');
    if (time == null) return;
    setState(() => _endsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    final target = _targetValue;
    final maxPer = _maxPer.text.trim().isEmpty ? 0 : int.tryParse(_maxPer.text);
    final original = double.tryParse(_original.text);
    final price = double.tryParse(_price.text);
    String? problem;
    if (_title.text.trim().length < 3) problem = 'عنوان الحملة قصير جدًا';
    if (target == null || target < 2) problem ??= 'الكمية المطلوبة 2 على الأقل';
    if (target != null && target < c.currentQuantity) problem ??= 'لا يمكن أن يقل الهدف عن المباع (${c.currentQuantity})';
    if (maxPer == null) problem ??= 'الحد لكل عميل غير صحيح';
    if (!_priceLocked && (original == null || price == null || price >= original)) problem ??= 'سعر الحملة يجب أن يكون أقل من السعر الأصلي';
    if (problem != null) {
      showMigaError(context, ApiException(400, 'validation_error', problem));
      return;
    }
    if (_completesNow) {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (d) => AlertDialog(
              title: const Text('إكمال الحملة الآن؟'),
              content: Text(
                'الكمية المطلوبة تساوي المباع (${c.currentQuantity} قطعة)، لذا ستكتمل الحملة فورًا ويصلك طلب مجمّع لتجهيزه، '
                'ولن يستطيع عملاء جدد الانضمام.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('رجوع')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('إكمال الحملة')),
              ],
            ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      String? changed(String v, String? old) => v.trim() == (old ?? '').trim() ? null : v.trim();
      final result = await AppServices.api.merchant.editCampaign(
        c.id,
        titleAr: changed(_title.text, c.titleAr),
        descriptionAr: changed(_desc.text, c.descriptionAr),
        originalPrice: _priceLocked || original == c.originalPrice ? null : original,
        campaignPrice: _priceLocked || price == c.campaignPrice ? null : price,
        targetQuantity: target == c.targetQuantity ? null : target,
        maxPerCustomer: maxPer == (c.maxPerCustomer ?? 0) ? null : maxPer,
        endsAt: _endsAt == c.endDate ? null : _endsAt,
      );
      if (!mounted) return;
      final completed = result.campaign.status == CampaignStatus.completed;
      showMigaMessage(context, completed ? 'اكتملت الحملة 🎉 تجد الطلب المجمّع في الطلبات' : 'تم حفظ التعديلات');
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimals = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Scaffold(
      appBar: AppBar(title: Text(_draft ? 'تعديل المسودة' : 'تعديل الحملة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (!_draft)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: MigaColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الحملة نشطة و${c.participantsCount} عميل مشترك (${c.currentQuantity} قطعة). '
                      'سيصل المشتركين إشعار عند تغيير الكمية أو موعد الانتهاء.',
                      style: t.bodySmall?.copyWith(color: MigaColors.info),
                    ),
                  ),
                ],
              ),
            ),
          MigaTextField(label: 'عنوان الحملة', controller: _title, prefixIcon: Icons.campaign_outlined),
          const SizedBox(height: 12),
          MigaTextField(label: 'وصف الحملة', hint: 'اختياري', controller: _desc, maxLines: 3),
          const SizedBox(height: 16),
          Text('السعر', style: t.titleSmall),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MigaTextField(
                  label: 'السعر الأصلي',
                  controller: _original,
                  readOnly: _priceLocked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimals,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MigaTextField(
                  label: 'سعر الحملة',
                  controller: _price,
                  readOnly: _priceLocked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimals,
                ),
              ),
            ],
          ),
          if (_priceLocked)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: MigaColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text('السعر مقفل لأن عملاء دفعوا به بالفعل', style: t.labelSmall)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MigaTextField(
                  label: 'الكمية المطلوبة',
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  prefixIcon: Icons.flag_outlined,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MigaTextField(
                  label: 'الحد لكل عميل',
                  hint: 'بدون حد',
                  controller: _maxPer,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
            ],
          ),
          if (!_draft)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _completesNow ? 'تساوي المباع: ستكتمل الحملة فور الحفظ' : 'لا تقل عن المباع: ${c.currentQuantity} قطعة',
                style: t.labelSmall?.copyWith(color: _completesNow ? MigaColors.success : null),
              ),
            ),
          const SizedBox(height: 16),
          MigaSelectField(
            label: 'موعد انتهاء الحملة',
            hint: '',
            value: '${MigaFormat.date(_endsAt)} • ${TimeOfDay.fromDateTime(_endsAt).format(context)}',
            icon: Icons.event_rounded,
            onTap: _pickEnd,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _draft ? 'حتى 30 يومًا من بدء الحملة' : 'يمكنك التمديد أو التقصير (ساعة على الأقل من الآن، وحتى 60 يومًا إجمالًا)',
              style: t.labelSmall,
            ),
          ),
          const SizedBox(height: 24),
          MigaButton(
            label: 'حفظ التعديلات',
            icon: Icons.save_rounded,
            loading: _saving,
            color: MigaColors.merchantAccent,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
