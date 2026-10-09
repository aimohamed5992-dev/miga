import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import '../widgets/miga_buttons.dart';
import '../widgets/miga_feedback.dart';
import '../widgets/miga_illustration.dart';
import '../widgets/miga_inputs.dart';

/// Step 1 of auth for every app: enter a Saudi mobile number.
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.role,
    required this.image,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  final MigaRole role;
  final String image;
  final IconData icon;
  final String title;
  final String subtitle;

  /// Receives the full number (+9665XXXXXXXX). Throw [ApiException] to show its message.
  final Future<void> Function(BuildContext context, String phone) onSubmit;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phone = TextEditingController();
  bool _loading = false;

  bool get _valid => RegExp(r'^5\d{8}$').hasMatch(_phone.text);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await widget.onSubmit(context, '+966${_phone.text}');
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = widget.role.accent;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            Center(
              child: MigaIllustration(
                image: widget.image,
                icon: widget.icon,
                accent: accent,
                size: 220,
              ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(.85, .85), curve: Curves.easeOutBack),
            ),
            const SizedBox(height: 28),
            Text(widget.title, style: t.headlineMedium).animate().fadeIn(delay: 150.ms).slideY(begin: .3),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: .3),
            const SizedBox(height: 28),
            MigaPhoneField(controller: _phone, onChanged: (_) => setState(() {})).animate().fadeIn(delay: 350.ms).slideY(begin: .3),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: MigaColors.textHint),
                const SizedBox(width: 6),
                Text('سنرسل لك رمز تحقق مكون من 4 أرقام', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 28),
            MigaButton(label: 'إرسال رمز التحقق', loading: _loading, color: accent, onPressed: _valid ? _submit : null),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: t.bodySmall,
                children: [
                  const TextSpan(text: 'بالمتابعة، أنت توافق على '),
                  TextSpan(
                    text: 'الشروط والأحكام',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                  const TextSpan(text: ' و'),
                  TextSpan(
                    text: 'سياسة الخصوصية',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()..onTap = () {},
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
