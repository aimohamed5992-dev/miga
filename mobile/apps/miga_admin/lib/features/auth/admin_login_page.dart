import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';

/// Admin sign-in: phone → 4-digit code in one card. Only numbers that are already admins get in.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.onSignedIn});
  final WidgetBuilder onSignedIn;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  OtpSent? _sent;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _phoneValid => RegExp(r'^5\d{8}$').hasMatch(_phone.text);

  Future<void> _sendCode() async {
    if (!_phoneValid || _busy) return;
    setState(() => _busy = true);
    try {
      final sent = await AppServices.api.auth.sendOtp('0${_phone.text}');
      _code.clear();
      setState(() => _sent = sent);
      _startCountdown(sent.resendAfterSeconds);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
    });
  }

  Future<void> _verify() async {
    final sent = _sent;
    if (sent == null || _code.text.length != 4 || _busy) return;
    setState(() => _busy = true);
    try {
      final account = await AppServices.api.auth.verifyOtp(sent.phone, _code.text, UserType.admin);
      Session.instance.signedIn(account);
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: widget.onSignedIn), (_) => false);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _card(context, showLogo: !wide)),
      ),
    );
    return Scaffold(
      backgroundColor: MigaColors.background,
      body: wide ? Row(children: [const Expanded(flex: 5, child: _BrandPanel()), Expanded(flex: 6, child: form)]) : form,
    );
  }

  Widget _card(BuildContext context, {required bool showLogo}) {
    final t = Theme.of(context).textTheme;
    final sent = _sent;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: MigaColors.surface, borderRadius: MigaRadius.all(MigaRadius.xl), boxShadow: MigaShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo) ...[const Center(child: MigaLogo(size: 72)), const SizedBox(height: 16)],
          Text(sent == null ? 'تسجيل دخول الإدارة' : 'أدخل رمز التحقق', style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            sent == null ? 'أدخل رقم الجوال المسجّل كمدير على منصة ميجا' : 'أرسلنا رمزًا من 4 أرقام إلى ${_localPhone(sent.phone)}',
            style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (sent == null) ...[
            MigaPhoneField(controller: _phone, autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: (_) => _sendCode()),
            const SizedBox(height: 20),
            MigaButton(label: 'إرسال الرمز', icon: Icons.sms_outlined, loading: _busy, onPressed: _phoneValid ? _sendCode : null),
          ] else ...[
            MigaTextField(
              label: 'رمز التحقق',
              hint: '• • • •',
              controller: _code,
              autofocus: true,
              prefixIcon: Icons.lock_outline_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              onChanged: (v) {
                setState(() {});
                if (v.length == 4) _verify();
              },
              onSubmitted: (_) => _verify(),
            ),
            if (sent.devCode != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                child: Text('بيئة التطوير — الرمز: ${sent.devCode}', style: t.labelMedium?.copyWith(color: MigaColors.info)),
              ),
            ],
            const SizedBox(height: 20),
            MigaButton(label: 'دخول', icon: Icons.login_rounded, loading: _busy, onPressed: _code.text.length == 4 ? _verify : null),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(onPressed: () => setState(() => _sent = null), child: const Text('تغيير الرقم')),
                const Spacer(),
                TextButton(
                  onPressed: _resendIn > 0 || _busy ? null : _sendCode,
                  child: Text(_resendIn > 0 ? 'إعادة الإرسال بعد $_resendIn ث' : 'إعادة إرسال الرمز'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _localPhone(String e164) => e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const points = [
      (Icons.verified_user_outlined, 'توثيق التجار والمندوبين'),
      (Icons.insights_rounded, 'متابعة المبيعات والعمولات لحظيًا'),
      (Icons.local_shipping_outlined, 'حل التوصيلات المتعثرة واسترداد المبالغ'),
      (Icons.account_balance_outlined, 'تحويل أرباح التجار'),
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2A2A31), MigaColors.ink], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MigaLogo(size: 52, white: true),
              const SizedBox(width: 12),
              Text('ميجا', style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.pill)),
                child: Text('الإدارة', style: t.labelMedium?.copyWith(color: Colors.white)),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'لوحة تحكم منصة\nالشراء الجماعي',
            style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 28),
          for (final (icon, text) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: MigaRadius.all(MigaRadius.md)),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(text, style: t.titleSmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideX(begin: .05),
          const Spacer(),
          Text('© ميجا ${DateTime.now().year}', style: t.labelSmall?.copyWith(color: Colors.white38)),
        ],
      ),
    );
  }
}
