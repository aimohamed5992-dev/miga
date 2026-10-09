import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import '../widgets/miga_buttons.dart';
import 'auth_widgets.dart';

class WizardStep {
  const WizardStep({required this.title, this.subtitle, required this.builder});
  final String title;
  final String? subtitle;
  final WidgetBuilder builder;
}

/// Multi-step form: segmented header, animated step body, back / next bar.
class MigaWizard extends StatefulWidget {
  const MigaWizard({
    super.key,
    required this.steps,
    required this.onFinish,
    this.accent = MigaColors.primary,
    this.finishLabel = 'إرسال الطلب',
    this.initialStep = 0,
  });
  final List<WizardStep> steps;
  final Future<void> Function(BuildContext context) onFinish;
  final Color accent;
  final String finishLabel;
  final int initialStep;

  @override
  State<MigaWizard> createState() => _MigaWizardState();
}

class _MigaWizardState extends State<MigaWizard> {
  late int _step = widget.initialStep;
  bool _loading = false;

  bool get _isLast => _step == widget.steps.length - 1;

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_isLast) return setState(() => _step++);
    setState(() => _loading = true);
    await widget.onFinish(context);
    if (mounted) setState(() => _loading = false);
  }

  void _back() => _step == 0 ? Navigator.of(context).maybePop() : setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final s = widget.steps[_step];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: MigaColors.surface,
        appBar: AppBar(
          backgroundColor: MigaColors.surface,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: MigaStepHeader(
                step: _step + 1,
                total: widget.steps.length,
                title: s.title,
                subtitle: s.subtitle,
                accent: widget.accent,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ListView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [s.builder(context).animate().fadeIn(duration: 300.ms).slideX(begin: -.06, curve: Curves.easeOutCubic)],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 12),
              decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      flex: 2,
                      child: MigaButton(label: 'السابق', variant: MigaButtonVariant.outline, color: widget.accent, onPressed: _back),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: MigaButton(
                      label: _isLast ? widget.finishLabel : 'التالي',
                      loading: _loading,
                      color: widget.accent,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
