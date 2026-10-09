import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';

const _accent = MigaColors.driverAccent;

const _pendingSteps = ['تم استلام الطلب', 'التحقق من الهوية والرخصة', 'تفعيل الحساب واستقبال الطلبات'];

/// Where a signed-in driver goes: registration wizard → pending review → app.
Widget driverNextPage(Account account, WidgetBuilder onApproved) => switch (account.verificationStatus) {
  'not_submitted' => DriverRegistrationPage(onApproved: onApproved),
  'pending' => DriverPendingPage(onApproved: onApproved),
  'rejected' => DriverRejectedPage(reason: account.rejectionReason ?? '', onApproved: onApproved),
  _ => Builder(builder: onApproved),
};

/// Phone → OTP (real API) → registration (first time) → pending review → home once verified.
class DriverLoginPage extends StatelessWidget {
  const DriverLoginPage({super.key, required this.onAuthenticated});
  final WidgetBuilder onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final api = AppServices.api;
    return PhoneLoginPage(
      role: MigaRole.driver,
      image: 'driver_auth.png',
      icon: Icons.delivery_dining_rounded,
      title: 'أهلًا كابتن 🚚',
      subtitle: 'سجّل دخولك وابدأ استقبال طلبات التوصيل',
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
              final account = await api.auth.verifyOtp(sent.phone, code, UserType.driver);
              Session.instance.signedIn(account);
              if (context.mounted) migaGoRoot(context, driverNextPage(account, onAuthenticated));
            },
          ),
        );
      },
    );
  }
}

/// Waiting for MIGA to verify the documents. "Check status" asks the API.
class DriverPendingPage extends StatelessWidget {
  const DriverPendingPage({super.key, required this.onApproved});
  final WidgetBuilder onApproved;

  @override
  Widget build(BuildContext context) {
    return PendingReviewPage(
      accent: _accent,
      title: 'جاري مراجعة طلبك',
      message: 'نراجع مستنداتك الآن، وعادةً لا يستغرق ذلك أكثر من 24 ساعة. سنبلغك فور تفعيل حسابك.',
      steps: _pendingSteps,
      onContinue: () async {
        try {
          await Session.instance.refresh();
          final account = Session.instance.account!;
          if (!context.mounted) return;
          if (account.verificationStatus == 'verified') {
            Session.instance.signedIn(account);
            migaGoRoot(context, onApproved(context));
          } else if (account.verificationStatus == 'rejected') {
            migaGoRoot(context, DriverRejectedPage(reason: account.rejectionReason ?? '', onApproved: onApproved));
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

enum _Vehicle {
  car('سيارة', Icons.directions_car_rounded),
  van('فان', Icons.airport_shuttle_rounded),
  truck('شاحنة صغيرة', Icons.local_shipping_rounded),
  bike('دراجة نارية', Icons.two_wheeler_rounded);

  const _Vehicle(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Registration rejected by an admin: shows the reason; the wizard resubmits to the same profile.
class DriverRejectedPage extends StatelessWidget {
  const DriverRejectedPage({super.key, required this.reason, required this.onApproved});
  final String reason;
  final WidgetBuilder onApproved;

  @override
  Widget build(BuildContext context) => RejectedReviewPage(
    reason: reason,
    accent: _accent,
    onEdit: () => migaPush(context, DriverRegistrationPage(onApproved: onApproved)),
    onCheck: () async {
      try {
        await Session.instance.refresh();
        final account = Session.instance.account!;
        if (!context.mounted) return;
        if (account.verificationStatus == 'rejected') {
          showMigaMessage(context, 'عدّل البيانات وأعد الإرسال ليُراجع طلبك من جديد', icon: Icons.edit_note_rounded);
        } else {
          if (account.verificationStatus == 'verified') Session.instance.signedIn(account);
          migaGoRoot(context, driverNextPage(account, onApproved));
        }
      } catch (e) {
        if (context.mounted) showMigaError(context, e);
      }
    },
  );
}

class DriverRegistrationPage extends StatefulWidget {
  const DriverRegistrationPage({super.key, required this.onApproved});
  final WidgetBuilder onApproved;

  /// Design review only: `--dart-define=MIGA_WIZARD_STEP=1`.
  static const _reviewStep = int.fromEnvironment('MIGA_WIZARD_STEP');

  @override
  State<DriverRegistrationPage> createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _plate = TextEditingController();
  final _model = TextEditingController();
  _Vehicle _vehicle = _Vehicle.van;
  List<City> _cities = [];
  City? _city;

  @override
  void initState() {
    super.initState();
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
    for (final c in [_name, _nationalId, _plate, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCity() async {
    if (_cities.isEmpty) return;
    final picked = await showMigaPicker<City>(
      context: context,
      title: 'مدينة العمل',
      items: _cities,
      label: (c) => c.nameAr,
      selected: _city,
      icon: Icons.location_city_rounded,
      accent: _accent,
    );
    if (picked != null) setState(() => _city = picked);
  }

  Future<void> _submit(BuildContext context) async {
    String? missing;
    if (_name.text.trim().length < 3) missing = 'الاسم الكامل';
    if (!RegExp(r'^[12]\d{9}$').hasMatch(_nationalId.text)) missing ??= 'رقم الهوية / الإقامة (10 أرقام يبدأ بـ 1 أو 2)';
    if (_city == null) missing ??= 'مدينة العمل';
    if (_plate.text.trim().length < 3) missing ??= 'رقم اللوحة';
    if (missing != null) {
      showMigaError(context, ApiException(400, 'validation_error', 'أكمل: $missing'));
      return;
    }
    try {
      final account = await AppServices.api.driver.register(
        fullName: _name.text.trim(),
        nationalId: _nationalId.text,
        cityId: _city!.id,
        vehicleType: _vehicle.name,
        vehiclePlateNumber: _plate.text.trim(),
        vehicleModel: _model.text.trim(),
      );
      Session.instance.signedIn(account);
      if (context.mounted) migaGoRoot(context, DriverPendingPage(onApproved: widget.onApproved));
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaWizard(
      accent: _accent,
      initialStep: DriverRegistrationPage._reviewStep.clamp(0, 2),
      finishLabel: 'إرسال للمراجعة',
      onFinish: _submit,
      steps: [
        WizardStep(
          title: 'البيانات الشخصية',
          subtitle: 'تأكد من مطابقتها لبيانات الهوية',
          builder:
              (_) => Column(
                children: [
                  MigaTextField(label: 'الاسم الكامل', hint: 'كما في الهوية', controller: _name, prefixIcon: Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'رقم الهوية / الإقامة',
                    hint: '10 أرقام',
                    controller: _nationalId,
                    prefixIcon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  ),
                  const SizedBox(height: 16),
                  MigaSelectField(
                    label: 'مدينة العمل',
                    hint: _cities.isEmpty ? 'جارٍ التحميل…' : 'اختر المدينة',
                    value: _city?.nameAr,
                    onTap: _pickCity,
                  ),
                ],
              ),
        ),
        WizardStep(
          title: 'بيانات المركبة',
          subtitle: 'اختر نوع المركبة التي ستوصل بها الطلبات',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      for (final v in _Vehicle.values)
                        ChoiceCard(
                          label: v.label,
                          icon: v.icon,
                          accent: _accent,
                          selected: _vehicle == v,
                          onTap: () => setState(() => _vehicle = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  MigaTextField(label: 'رقم اللوحة', hint: 'مثال: أ ب ج 1234', controller: _plate, prefixIcon: Icons.pin_outlined),
                  const SizedBox(height: 16),
                  MigaTextField(
                    label: 'موديل المركبة',
                    hint: 'مثال: تويوتا هايس 2022',
                    controller: _model,
                    prefixIcon: Icons.directions_car_outlined,
                  ),
                ],
              ),
        ),
        WizardStep(
          title: 'المستندات المطلوبة',
          subtitle: 'صور واضحة وسارية المفعول',
          builder:
              (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('صورة الهوية / الإقامة', style: t.titleSmall),
                  const SizedBox(height: 8),
                  const UploadTile(label: 'رفع الهوية', icon: Icons.badge_outlined, accent: _accent),
                  const SizedBox(height: 16),
                  Text('رخصة القيادة', style: t.titleSmall),
                  const SizedBox(height: 8),
                  const UploadTile(label: 'رفع الرخصة', icon: Icons.credit_card_rounded, accent: _accent),
                  const SizedBox(height: 16),
                  Text('استمارة المركبة', style: t.titleSmall),
                  const SizedBox(height: 8),
                  const UploadTile(label: 'رفع الاستمارة', icon: Icons.description_outlined, accent: _accent),
                  const SizedBox(height: 16),
                  Text('صورة شخصية', style: t.titleSmall),
                  const SizedBox(height: 8),
                  const UploadTile(
                    label: 'التقاط صورة',
                    hint: 'بخلفية فاتحة وبدون نظارة شمسية',
                    icon: Icons.photo_camera_front_outlined,
                    accent: _accent,
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

/// Display name / icon for the vehicle type stored on the driver profile.
String vehicleLabel(String? type) => _Vehicle.values.where((v) => v.name == type).firstOrNull?.label ?? 'مركبة';
IconData vehicleIcon(String? type) => _Vehicle.values.where((v) => v.name == type).firstOrNull?.icon ?? Icons.local_shipping_rounded;

/// Vehicle types offered at registration and in the profile editor: (type, label, icon).
List<(String, String, IconData)> get vehicleOptions => [for (final v in _Vehicle.values) (v.name, v.label, v.icon)];
