import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';

/// Phone → OTP (real API) → complete profile (first sign-in only) → welcome.
class CustomerLoginPage extends StatelessWidget {
  const CustomerLoginPage({super.key, required this.onAuthenticated});
  final WidgetBuilder onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final api = AppServices.api;
    return PhoneLoginPage(
      role: MigaRole.customer,
      image: 'customer_auth.png',
      icon: Icons.phone_iphone_rounded,
      title: 'مرحبًا بك في ميجا 👋',
      subtitle: 'سجّل دخولك برقم جوالك وابدأ الشراء مع الجماعة',
      onSubmit: (context, phone) async {
        final sent = await api.auth.sendOtp(phone);
        if (!context.mounted) return;
        migaPush(
          context,
          OtpPage(
            phone: sent.phone,
            devCode: sent.devCode,
            onResend: () => api.auth.sendOtp(phone),
            onVerify: (context, code) async {
              final account = await api.auth.verifyOtp(sent.phone, code, UserType.customer);
              Session.instance.signedIn(account);
              if (!context.mounted) return;
              account.isProfileComplete
                  ? migaGoRoot(context, onAuthenticated(context))
                  : migaPush(context, CompleteProfilePage(phone: sent.phone, onDone: onAuthenticated));
            },
          ),
        );
      },
    );
  }
}

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, required this.phone, required this.onDone});
  final String phone;
  final WidgetBuilder onDone;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final account = await AppServices.api.auth.completeCustomerProfile(_name.text.trim(), email: _email.text.trim());
      Session.instance.signedIn(account);
      if (!mounted) return;
      final first = account.fullName.split(' ').first;
      final next = widget.onDone;
      migaGoRoot(
        context,
        Builder(
          builder:
              (successContext) => MigaSuccessPage(
                title: 'أهلًا $first! 🎉',
                message: 'تم إنشاء حسابك بنجاح. تصفّح الحملات النشطة وانضم لأول حملة لك بسعر الجملة.',
                buttonLabel: 'ابدأ التسوق',
                onDone: () => migaGoRoot(successContext, next(successContext)),
              ),
        ),
      );
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      appBar: AppBar(backgroundColor: MigaColors.surface),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('أكمل بياناتك', style: t.headlineMedium),
          const SizedBox(height: 6),
          Text('خطوة أخيرة ونجهّز لك حسابك', style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary)),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(color: MigaColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, size: 56, color: MigaColors.primary),
            ),
          ).animate().scale(curve: Curves.easeOutBack),
          const SizedBox(height: 28),
          MigaTextField(
            label: 'الاسم الكامل',
            hint: 'مثال: محمد العتيبي',
            controller: _name,
            prefixIcon: Icons.person_outline_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          MigaTextField(
            label: 'البريد الإلكتروني (اختياري)',
            hint: 'name@example.com',
            controller: _email,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          MigaTextField(label: 'رقم الجوال', hint: widget.phone, prefixIcon: Icons.verified_rounded, readOnly: true),
          const SizedBox(height: 32),
          MigaButton(label: 'إنشاء الحساب', loading: _loading, onPressed: _name.text.trim().length >= 3 ? _submit : null),
        ],
      ),
    );
  }
}
