import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import '../widgets/miga_buttons.dart';
import '../widgets/miga_feedback.dart';

/// Step 2 of auth: 4-digit code with resend countdown.
class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.phone,
    required this.onVerify,
    this.onResend,
    this.devCode,
    this.accent = MigaColors.primary,
    this.length = 4,
  });
  final String phone;
  final Color accent;
  final int length;

  /// Verifies [code] and navigates on success. Throw [ApiException] to show its message under the boxes.
  final Future<void> Function(BuildContext context, String code) onVerify;
  final Future<void> Function()? onResend;

  /// Development builds only: the API returns the code so testers don't need SMS.
  final String? devCode;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _seconds = 60;
  bool _loading = false;
  bool _error = false;
  String _errorMessage = 'الرمز غير صحيح، حاول مرة أخرى';

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) return t.cancel();
      setState(() => _seconds--);
    });
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await widget.onVerify(context, _code.text);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _errorMessage = e is ApiException ? e.message : 'حدث خطأ، حاول مرة أخرى';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await widget.onResend?.call();
      _code.clear();
      _startTimer();
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final complete = _code.text.length == widget.length;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      appBar: AppBar(backgroundColor: MigaColors.surface),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.accent.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.lg)),
                child: Icon(Icons.sms_outlined, color: widget.accent, size: 34),
              ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
            ),
            const SizedBox(height: 24),
            Text('أدخل رمز التحقق', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary),
                children: [
                  const TextSpan(text: 'أرسلنا رمزًا مكوّنًا من 4 أرقام إلى\n'),
                  TextSpan(text: widget.phone, style: t.titleMedium?.copyWith(color: MigaColors.textPrimary, letterSpacing: .5)),
                ],
              ),
              textDirection: TextDirection.rtl,
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
              icon: Icon(Icons.edit_outlined, size: 16, color: widget.accent),
              label: Text('تغيير الرقم', style: t.labelMedium?.copyWith(color: widget.accent)),
            ),
            const SizedBox(height: 20),
            _OtpBoxes(
              controller: _code,
              focus: _focus,
              length: widget.length,
              accent: widget.accent,
              error: _error,
              onChanged: (v) {
                setState(() => _error = false);
                if (v.length == widget.length) _verify();
              },
            ),
            if (widget.devCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('بيئة التطوير — الرمز: ${widget.devCode}', style: t.labelMedium?.copyWith(color: MigaColors.info)),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child:
                  _error
                      ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: MigaColors.error),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_errorMessage, style: t.bodyMedium?.copyWith(color: MigaColors.error))),
                          ],
                        ),
                      )
                      : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 28),
            MigaButton(label: 'تحقق', loading: _loading, color: widget.accent, onPressed: complete ? _verify : null),
            const SizedBox(height: 20),
            Center(
              child:
                  _seconds > 0
                      ? Text.rich(
                        TextSpan(
                          style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary),
                          children: [
                            const TextSpan(text: 'إعادة الإرسال بعد '),
                            TextSpan(
                              text: '00:${_seconds.toString().padLeft(2, '0')}',
                              style: TextStyle(color: widget.accent, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      )
                      : TextButton(onPressed: _resend, child: Text('إعادة إرسال الرمز', style: TextStyle(color: widget.accent))),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controller,
    required this.focus,
    required this.length,
    required this.accent,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final int length;
  final Color accent;
  final bool error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final boxes = Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Invisible field that owns the keyboard / paste / SMS autofill.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
              onChanged: onChanged,
            ),
          ),
          GestureDetector(
            onTap: focus.requestFocus,
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, focus]),
              builder: (_, __) {
                final text = controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(length, (i) {
                    final filled = i < text.length;
                    final active = focus.hasFocus && (i == text.length || (i == length - 1 && text.length == length));
                    final border =
                        error
                            ? MigaColors.error
                            : active
                            ? accent
                            : filled
                            ? accent.withValues(alpha: .4)
                            : MigaColors.border;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 68,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: error ? MigaColors.errorSoft : (filled ? accent.withValues(alpha: .05) : MigaColors.background),
                        borderRadius: MigaRadius.all(MigaRadius.lg),
                        border: Border.all(color: border, width: active || error ? 2 : 1.2),
                      ),
                      child:
                          filled
                              ? Text(
                                text[i],
                                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                              ).animate().scale(begin: const Offset(.5, .5), duration: 180.ms, curve: Curves.easeOutBack)
                              : active
                              ? Container(
                                width: 2,
                                height: 26,
                                color: accent,
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 500.ms)
                              : null,
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
    return error ? boxes.animate(key: const ValueKey('shake')).shakeX(hz: 5, amount: 6, duration: 400.ms) : boxes;
  }
}
