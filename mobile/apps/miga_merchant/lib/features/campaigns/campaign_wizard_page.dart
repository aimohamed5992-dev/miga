import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/merchant_store.dart';
import '../../core/services.dart';

/// 4-step campaign creation: product → pricing & quantity → duration → review & publish.
class CampaignWizardPage extends StatefulWidget {
  const CampaignWizardPage({super.key, this.initialProduct});
  final Product? initialProduct;

  /// Design review only: `--dart-define=MIGA_WIZARD_STEP=2`.
  static const _reviewStep = int.fromEnvironment('MIGA_WIZARD_STEP');

  @override
  State<CampaignWizardPage> createState() => _CampaignWizardPageState();
}

class _CampaignWizardPageState extends State<CampaignWizardPage> {
  late Product? _product = widget.initialProduct ?? (CampaignWizardPage._reviewStep > 0 ? MerchantData.instance.products.first : null);
  late final _original = TextEditingController(text: _product?.price.toStringAsFixed(0));
  final _price = TextEditingController(text: CampaignWizardPage._reviewStep > 0 ? '55' : null);
  final _target = TextEditingController(text: '500');
  final _maxPer = TextEditingController(text: '10');
  late final _title = TextEditingController(text: _product == null ? null : '${_product!.nameAr} بسعر الجملة');
  final _desc = TextEditingController();
  int _days = 7;
  bool _startNow = true;
  bool _agreed = CampaignWizardPage._reviewStep > 2;

  double get _orig => double.tryParse(_original.text) ?? 0;
  double get _camp => double.tryParse(_price.text) ?? 0;
  int get _tgt => int.tryParse(_target.text) ?? 0;
  int get _discount => _orig <= 0 || _camp <= 0 ? 0 : ((_orig - _camp) / _orig * 100).round();

  /// A live preview built from the form, rendered with the same card customers see.
  Campaign get _preview => Campaign(
    id: 'preview',
    storeId: MerchantData.instance.currentStore.id,
    product: _product ?? MerchantData.instance.products.first,
    titleAr: _title.text,
    originalPrice: _orig,
    campaignPrice: _camp,
    targetQuantity: _tgt == 0 ? 1 : _tgt,
    currentQuantity: 0,
    startDate: DateTime.now(),
    endDate: DateTime.now().add(Duration(days: _days)),
    maxPerCustomer: int.tryParse(_maxPer.text),
  );

  @override
  void dispose() {
    for (final c in [_original, _price, _target, _maxPer, _title, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickProduct(Product p) => setState(() {
    _product = p;
    _original.text = p.price.toStringAsFixed(0);
    if (_title.text.isEmpty || _title.text.endsWith('بسعر الجملة')) _title.text = '${p.nameAr} بسعر الجملة';
  });

  Future<MerchantCampaignView> _save({required bool publish}) => AppServices.api.merchant.createCampaign(
    storeId: MerchantData.instance.currentStore.id,
    productId: _product!.id,
    titleAr: _title.text.trim(),
    descriptionAr: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    originalPrice: _orig,
    campaignPrice: _camp,
    targetQuantity: _tgt,
    maxQuantityPerCustomer: int.tryParse(_maxPer.text),
    durationDays: _days,
    publish: publish,
  );

  Future<void> _publish(BuildContext context) async {
    if (_product == null || _camp <= 0 || _camp >= _orig || _tgt <= 0 || !_agreed) {
      showMigaError(context, const ApiException(400, 'validation_error', 'أكمل البيانات ووافق على الشروط أولًا'));
      return;
    }
    try {
      await _save(publish: true);
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (c) => MigaSuccessPage(
              image: 'merchant_onb_1.png',
              accent: MigaColors.merchantAccent,
              title: 'تم نشر الحملة 🚀',
              message: 'حملتك الآن ظاهرة لعملاء ميجا. سنرسل لك إشعارًا مع كل مشاركة وعند اكتمال العدد المطلوب.',
              buttonLabel: 'عرض حملاتي',
              onDone: () => Navigator.pop(c),
            ),
      ),
    );
  }

  Future<void> _saveDraft(BuildContext context) async {
    if (_product == null || _title.text.trim().length < 3) {
      showMigaError(context, const ApiException(400, 'validation_error', 'اختر المنتج واكتب عنوان الحملة أولًا'));
      return;
    }
    try {
      await _save(publish: false);
      if (!context.mounted) return;
      Navigator.pop(context);
      showMigaMessage(context, 'تم حفظ الحملة كمسودة');
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = MerchantData.instance;
    return MigaWizard(
      accent: MigaColors.merchantAccent,
      initialStep: CampaignWizardPage._reviewStep.clamp(0, 3),
      finishLabel: 'نشر الحملة',
      onFinish: _publish,
      steps: [
        WizardStep(
          title: 'اختر المنتج',
          subtitle: 'المنتج الذي سيُباع بسعر الجملة',
          builder:
              (_) => Column(
                children: [
                  for (final p in data.products.where((p) => p.isActive))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: _product?.id == p.id ? MigaColors.merchantAccent.withValues(alpha: .05) : MigaColors.surface,
                          borderRadius: MigaRadius.all(MigaRadius.lg),
                          border: Border.all(
                            color: _product?.id == p.id ? MigaColors.merchantAccent : MigaColors.border,
                            width: _product?.id == p.id ? 1.8 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _pickProduct(p),
                          borderRadius: MigaRadius.all(MigaRadius.lg),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                MigaImage(p.mainImage, width: 56, height: 56, borderRadius: MigaRadius.all(MigaRadius.sm)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nameAr, style: t.titleSmall),
                                      Text('${MigaFormat.money(p.price)} • المخزون ${p.stockQuantity}', style: t.bodySmall),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _product?.id == p.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: _product?.id == p.id ? MigaColors.merchantAccent : MigaColors.textHint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        ),
        WizardStep(
          title: 'السعر والكمية',
          subtitle: 'كلما زاد الخصم اكتملت الحملة أسرع',
          builder: (_) {
            final stock = _product?.stockQuantity ?? 0;
            final overStock = _tgt > stock && _product != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _num('السعر الأصلي', _original, decimal: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _num('سعر الحملة', _price, decimal: true)),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _camp >= _orig && _camp > 0 ? MigaColors.errorSoft : MigaColors.primarySoft,
                    borderRadius: MigaRadius.all(MigaRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.percent_rounded, color: _camp >= _orig && _camp > 0 ? MigaColors.error : MigaColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _camp >= _orig && _camp > 0
                              ? 'سعر الحملة يجب أن يكون أقل من السعر الأصلي'
                              : 'خصم $_discount% • توفير ${MigaFormat.money(_orig - _camp)} للقطعة',
                          style: t.titleSmall?.copyWith(color: _camp >= _orig && _camp > 0 ? MigaColors.error : MigaColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _num('الكمية المطلوبة', _target)),
                    const SizedBox(width: 12),
                    Expanded(child: _num('الحد لكل عميل', _maxPer)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  overStock ? '⚠️ الكمية المطلوبة أكبر من المخزون المتاح ($stock)' : 'المخزون المتاح: $stock قطعة',
                  style: t.bodySmall?.copyWith(color: overStock ? MigaColors.warning : null),
                ),
                const SizedBox(height: 16),
                MigaCard(
                  color: MigaColors.background,
                  child: Column(
                    children: [
                      InfoRow('الإيراد عند الاكتمال', MigaFormat.money(_camp * _tgt), bold: true),
                      InfoRow('عمولة ميجا (5%)', '- ${MigaFormat.money(_camp * _tgt * .05)}'),
                      InfoRow('صافي الربح المتوقع', MigaFormat.money(_camp * _tgt * .95), valueColor: MigaColors.success),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        WizardStep(
          title: 'المدة والتفاصيل',
          subtitle: 'إذا لم تكتمل الحملة خلال المدة يُسترد المبلغ للعملاء',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MigaTextField(
                    label: 'عنوان الحملة',
                    hint: 'مثال: أرز بسمتي بسعر الجملة',
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text('بداية الحملة', style: t.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MigaChoiceChip(
                        label: 'فورًا',
                        icon: Icons.bolt_rounded,
                        selected: _startNow,
                        onSelected: () => setState(() => _startNow = true),
                      ),
                      const SizedBox(width: 8),
                      MigaChoiceChip(
                        label: 'جدولة',
                        icon: Icons.event_rounded,
                        selected: !_startNow,
                        onSelected: () => setState(() => _startNow = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('مدة الحملة', style: t.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in [3, 5, 7, 14, 30])
                        MigaChoiceChip(label: '$d أيام', selected: _days == d, onSelected: () => setState(() => _days = d)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: MigaColors.info),
                        const SizedBox(width: 8),
                        Text(
                          'تنتهي في ${MigaFormat.date(DateTime.now().add(Duration(days: _days)))}',
                          style: t.titleSmall?.copyWith(color: MigaColors.info),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MigaTextField(label: 'وصف الحملة (اختياري)', hint: 'لماذا هذا العرض مميز؟', controller: _desc, maxLines: 3),
                ],
              ),
        ),
        WizardStep(
          title: 'مراجعة ونشر',
          subtitle: 'هكذا ستظهر حملتك للعملاء',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: SizedBox(width: 210, child: IgnorePointer(child: CampaignCard(campaign: _preview)))),
                  const SizedBox(height: 16),
                  MigaCard(
                    color: MigaColors.background,
                    child: Column(
                      children: [
                        InfoRow('المنتج', _product?.nameAr ?? '—'),
                        InfoRow('السعر', '${MigaFormat.money(_camp)} بدل ${MigaFormat.money(_orig)}'),
                        InfoRow('الكمية المطلوبة', '$_tgt قطعة'),
                        InfoRow('الحد لكل عميل', '${_maxPer.text} قطع'),
                        InfoRow('المدة', '$_days أيام • ${_startNow ? 'تبدأ فورًا' : 'مجدولة'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: MigaColors.merchantAccent,
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    title: Text('أتعهد بتوفير الكمية وتجهيز الطلب خلال 48 ساعة من اكتمال الحملة', style: t.bodySmall),
                  ),
                  TextButton.icon(
                    onPressed: () => _saveDraft(context),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('حفظ كمسودة'),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _num(String label, TextEditingController c, {bool decimal = false}) => MigaTextField(
    label: label,
    controller: c,
    hint: '0',
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
    onChanged: (_) => setState(() {}),
  );
}
