import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';

const _accent = MigaColors.merchantAccent;

/// Where a signed-in merchant goes: registration wizard → pending review → app.
Widget merchantNextPage(Account account, WidgetBuilder onApproved) => switch (account.verificationStatus) {
  'not_submitted' => MerchantRegistrationPage(onApproved: onApproved),
  'pending' => MerchantPendingPage(onApproved: onApproved),
  'rejected' => MerchantRejectedPage(reason: account.rejectionReason ?? '', onApproved: onApproved),
  _ => Builder(builder: onApproved),
};

/// Phone → OTP (real API) → registration (first time) → pending review → dashboard once verified.
class MerchantLoginPage extends StatelessWidget {
  const MerchantLoginPage({super.key, required this.onAuthenticated});
  final WidgetBuilder onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final api = AppServices.api;
    return PhoneLoginPage(
      role: MigaRole.merchant,
      image: 'merchant_auth.png',
      icon: Icons.storefront_rounded,
      title: 'أهلًا بك يا شريكنا 🤝',
      subtitle: 'سجّل دخولك لإدارة متاجرك وحملاتك على ميجا',
      onSubmit: (context, phone) async {
        final sent = await api.auth.sendOtp(phone);
        if (!context.mounted) return;
        migaPush(
          context,
          OtpPage(
            phone: sent.phone,
            devCode: sent.devCode,
            accent: _accent,
            onResend: () => api.auth.sendOtp(phone),
            onVerify: (context, code) async {
              final account = await api.auth.verifyOtp(sent.phone, code, UserType.merchant);
              Session.instance.signedIn(account);
              if (context.mounted) migaGoRoot(context, merchantNextPage(account, onAuthenticated));
            },
          ),
        );
      },
    );
  }
}

/// Waiting for MIGA to verify the commercial registration. "Check status" asks the API.
class MerchantPendingPage extends StatelessWidget {
  const MerchantPendingPage({super.key, required this.onApproved});
  final WidgetBuilder onApproved;

  @override
  Widget build(BuildContext context) {
    return PendingReviewPage(
      accent: _accent,
      title: 'طلبك قيد المراجعة',
      message: 'استلمنا بيانات نشاطك التجاري وسيتم التحقق منها خلال 24 ساعة. سنرسل لك إشعارًا فور التفعيل.',
      steps: const ['تم استلام الطلب', 'التحقق من السجل التجاري', 'تفعيل المتجر والبدء بالحملات'],
      onContinue: () async {
        try {
          await Session.instance.refresh();
          final account = Session.instance.account!;
          if (!context.mounted) return;
          if (account.verificationStatus == 'verified') {
            Session.instance.signedIn(account);
            migaGoRoot(context, onApproved(context));
          } else if (account.verificationStatus == 'rejected') {
            migaGoRoot(context, MerchantRejectedPage(reason: account.rejectionReason ?? '', onApproved: onApproved));
          } else {
            showMigaMessage(context, 'ما زال طلبك قيد المراجعة', icon: Icons.hourglass_top_rounded);
          }
        } catch (e) {
          if (context.mounted) showMigaError(context, e);
        }
      },
    );
  }
}

/// Registration rejected by an admin: shows the reason; the wizard resubmits to the same profile.
class MerchantRejectedPage extends StatelessWidget {
  const MerchantRejectedPage({super.key, required this.reason, required this.onApproved});
  final String reason;
  final WidgetBuilder onApproved;

  @override
  Widget build(BuildContext context) => RejectedReviewPage(
    reason: reason,
    accent: _accent,
    onEdit: () => migaPush(context, MerchantRegistrationPage(onApproved: onApproved)),
    onCheck: () async {
      try {
        await Session.instance.refresh();
        final account = Session.instance.account!;
        if (!context.mounted) return;
        if (account.verificationStatus == 'rejected') {
          showMigaMessage(context, 'عدّل البيانات وأعد الإرسال ليُراجع طلبك من جديد', icon: Icons.edit_note_rounded);
        } else {
          if (account.verificationStatus == 'verified') Session.instance.signedIn(account);
          migaGoRoot(context, merchantNextPage(account, onApproved));
        }
      } catch (e) {
        if (context.mounted) showMigaError(context, e);
      }
    },
  );
}

class MerchantRegistrationPage extends StatefulWidget {
  const MerchantRegistrationPage({super.key, required this.onApproved});
  final WidgetBuilder onApproved;

  /// Design review only: `--dart-define=MIGA_WIZARD_STEP=1`.
  static const _reviewStep = int.fromEnvironment('MIGA_WIZARD_STEP');

  @override
  State<MerchantRegistrationPage> createState() => _MerchantRegistrationPageState();
}

class _MerchantRegistrationPageState extends State<MerchantRegistrationPage> {
  final _owner = TextEditingController();
  final _businessAr = TextEditingController();
  final _businessEn = TextEditingController();
  final _cr = TextEditingController();
  final _tax = TextEditingController();
  final _storeName = TextEditingController();
  final _storeDesc = TextEditingController();
  List<StoreCategory> _categories = [];
  String? _categoryId;
  List<City> _cities = [];
  City? _city;

  @override
  void initState() {
    super.initState();
    AppServices.api.catalog
        .storeCategories()
        .then((c) {
          if (!mounted) return;
          setState(() {
            _categories = c;
            _categoryId = c.firstOrNull?.id;
          });
        })
        .catchError((Object e) {
          if (mounted) showMigaError(context, e);
        });
    AppServices.api.catalog
        .regions()
        .then((r) {
          if (mounted) setState(() => _cities = [for (final x in r) ...x.cities]);
        })
        .catchError((Object e) {
          if (mounted) showMigaError(context, e);
        });
  }

  @override
  void dispose() {
    for (final c in [_owner, _businessAr, _businessEn, _cr, _tax, _storeName, _storeDesc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    String? missing;
    if (_owner.text.trim().length < 3) missing = 'اسم المالك';
    if (_businessAr.text.trim().length < 2) missing ??= 'الاسم التجاري';
    if (!RegExp(r'^\d{10}$').hasMatch(_cr.text)) missing ??= 'رقم السجل التجاري (10 أرقام)';
    if (_storeName.text.trim().length < 2) missing ??= 'اسم المتجر';
    if (_categoryId == null) missing ??= 'قسم المتجر';
    if (_city == null) missing ??= 'مدينة المتجر';
    if (missing != null) {
      showMigaError(context, ApiException(400, 'validation_error', 'أكمل: $missing'));
      return;
    }
    try {
      final account = await AppServices.api.merchant.register(
        ownerName: _owner.text.trim(),
        businessNameAr: _businessAr.text.trim(),
        businessNameEn: _businessEn.text.trim().isEmpty ? null : _businessEn.text.trim(),
        commercialRegistrationNumber: _cr.text,
        taxNumber: _tax.text,
        storeNameAr: _storeName.text.trim(),
        storeCategoryId: _categoryId!,
        storeDescriptionAr: _storeDesc.text.trim().isEmpty ? null : _storeDesc.text.trim(),
        storeCityId: _city!.id,
      );
      Session.instance.signedIn(account);
      if (context.mounted) migaGoRoot(context, MerchantPendingPage(onApproved: widget.onApproved));
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return MigaWizard(
      accent: _accent,
      initialStep: MerchantRegistrationPage._reviewStep.clamp(0, 2),
      finishLabel: 'إرسال للمراجعة',
      onFinish: _submit,
      steps: [
        WizardStep(
          title: 'بيانات النشاط التجاري',
          subtitle: 'هذه البيانات تظهر في الفواتير ويتم التحقق منها',
          builder:
              (_) => Column(
                children: [
                  MigaTextField(label: 'اسم المالك', hint: 'الاسم الكامل', controller: _owner, prefixIcon: Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'الاسم التجاري (عربي)',
                    hint: 'مثال: مؤسسة الخير للتجارة',
                    controller: _businessAr,
                    prefixIcon: Icons.business_rounded,
                  ),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'الاسم التجاري (إنجليزي)',
                    hint: 'Al Khair Trading Est.',
                    controller: _businessEn,
                    prefixIcon: Icons.translate_rounded,
                  ),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'رقم السجل التجاري',
                    hint: '10 أرقام',
                    controller: _cr,
                    prefixIcon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [...digits, LengthLimitingTextInputFormatter(10)],
                  ),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'الرقم الضريبي (اختياري)',
                    hint: '15 رقمًا',
                    controller: _tax,
                    prefixIcon: Icons.receipt_long_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [...digits, LengthLimitingTextInputFormatter(15)],
                  ),
                ],
              ),
        ),
        WizardStep(
          title: 'أنشئ متجرك الأول',
          subtitle: 'يمكنك إضافة متاجر أخرى لاحقًا من لوحة التحكم',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MigaTextField(
                    label: 'اسم المتجر',
                    hint: 'مثال: أسواق الخير',
                    controller: _storeName,
                    prefixIcon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 16),
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
                        accent: _accent,
                      );
                      if (c != null) setState(() => _city = c);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('قسم المتجر', style: t.titleSmall),
                  const SizedBox(height: 10),
                  if (_categories.isEmpty) const Center(child: CircularProgressIndicator()),
                  GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .9,
                    children: [
                      for (final c in _categories)
                        ChoiceCard(
                          label: c.nameAr,
                          accent: _accent,
                          selected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                          child: MigaImage(c.image, fit: BoxFit.contain, borderRadius: MigaRadius.all(MigaRadius.sm)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  MigaTextField(label: 'وصف المتجر', hint: 'اكتب نبذة قصيرة عن منتجاتك', controller: _storeDesc, maxLines: 3),
                ],
              ),
        ),
        WizardStep(
          title: 'المستندات',
          subtitle: 'ارفع صورة السجل التجاري — يمكنك إضافة الشعار والغلاف لاحقًا من صفحة المتجر',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السجل التجاري', style: t.titleSmall),
                  const SizedBox(height: 8),
                  const UploadTile(
                    label: 'رفع السجل التجاري',
                    hint: 'PDF أو صورة واضحة',
                    icon: Icons.description_outlined,
                    accent: _accent,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: MigaColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'بياناتك محمية ولن تُستخدم إلا للتحقق من نشاطك التجاري.',
                            style: t.bodySmall?.copyWith(color: MigaColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}
