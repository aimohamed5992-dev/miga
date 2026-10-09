import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import '../widgets/miga_buttons.dart';

/// "Step 1 of 3" header with segmented progress, used by registration wizards.
class MigaStepHeader extends StatelessWidget {
  const MigaStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
    this.accent = MigaColors.primary,
  });
  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            total,
            (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(color: i < step ? accent : MigaColors.border, borderRadius: MigaRadius.all(MigaRadius.pill)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('الخطوة $step من $total', style: t.labelMedium?.copyWith(color: accent)),
        const SizedBox(height: 4),
        Text(title, style: t.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
        ],
      ],
    );
  }
}

/// Dashed upload box for documents / logos (picker wired with the backend).
class UploadTile extends StatefulWidget {
  const UploadTile({
    super.key,
    required this.label,
    this.hint = 'PNG أو JPG حتى 5MB',
    this.icon = Icons.cloud_upload_outlined,
    this.height = 110,
    this.accent = MigaColors.primary,
    this.onTap,
  });
  final String label;
  final String hint;
  final IconData icon;
  final double height;
  final Color accent;

  /// Real picker/upload. Without it the tile only toggles its "uploaded" look (document placeholders).
  final VoidCallback? onTap;

  @override
  State<UploadTile> createState() => _UploadTileState();
}

class _UploadTileState extends State<UploadTile> {
  bool _uploaded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = _uploaded ? MigaColors.success : widget.accent;
    return InkWell(
      onTap: widget.onTap ?? () => setState(() => _uploaded = !_uploaded),
      borderRadius: MigaRadius.all(MigaRadius.md),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: color.withValues(alpha: .5)),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(color: color.withValues(alpha: .04), borderRadius: MigaRadius.all(MigaRadius.md)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_uploaded ? Icons.check_circle_rounded : widget.icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(_uploaded ? 'تم الرفع ✓' : widget.label, style: t.titleSmall?.copyWith(color: _uploaded ? color : null)),
              Text(_uploaded ? 'اضغط للتغيير' : widget.hint, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(MigaRadius.md)));
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Selectable option card (vehicle type, store category…).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.child,
    this.accent = MigaColors.primary,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: .06) : MigaColors.surface,
        borderRadius: MigaRadius.all(MigaRadius.lg),
        border: Border.all(color: selected ? accent : MigaColors.border, width: selected ? 1.8 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: MigaRadius.all(MigaRadius.lg),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (child != null)
                    Expanded(child: child!)
                  else if (icon != null)
                    Icon(icon, size: 32, color: selected ? accent : MigaColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: selected ? accent : null)),
                ],
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Icon(Icons.check_circle_rounded, color: accent, size: 20).animate().scale(curve: Curves.easeOutBack),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown after merchant / driver registration while the account awaits admin approval.
class PendingReviewPage extends StatelessWidget {
  const PendingReviewPage({
    super.key,
    required this.title,
    required this.message,
    required this.steps,
    required this.onContinue,
    this.accent = MigaColors.primary,
    this.continueLabel = 'تحقق من حالة الطلب',
  });
  final String continueLabel;
  final String title;
  final String message;
  final List<String> steps;
  final VoidCallback onContinue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 150, height: 150, decoration: BoxDecoration(color: MigaColors.warningSoft, shape: BoxShape.circle))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(.92, .92), end: const Offset(1.04, 1.04), duration: 1400.ms),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: MigaColors.warning, shape: BoxShape.circle),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 46),
                  ).animate(onPlay: (c) => c.repeat()).rotate(begin: 0, end: .5, duration: 1600.ms, curve: Curves.easeInOutBack),
                ],
              ),
              const SizedBox(height: 28),
              Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: MigaColors.background, borderRadius: MigaRadius.all(MigaRadius.lg)),
                child: Column(
                  children: [
                    for (final (i, s) in steps.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              i == 0
                                  ? Icons.check_circle_rounded
                                  : (i == 1 ? Icons.timelapse_rounded : Icons.radio_button_unchecked_rounded),
                              color: i == 0 ? MigaColors.success : (i == 1 ? MigaColors.warning : MigaColors.textHint),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s, style: t.bodyMedium?.copyWith(color: i > 1 ? MigaColors.textSecondary : null))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              // Demo shortcut until the admin approval API exists.
              MigaButton(label: continueLabel, icon: Icons.refresh_rounded, color: accent, onPressed: onContinue),
              const SizedBox(height: 10),
              MigaButton(
                label: 'تواصل مع الدعم',
                variant: MigaButtonVariant.text,
                color: accent,
                icon: Icons.support_agent_rounded,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes [page] with the standard slide transition.
Future<T?> migaPush<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Replaces the whole stack with [page] (end of auth).
void migaGoRoot(BuildContext context, Widget page) =>
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);

/// Registration rejected by MIGA: shows the admin's reason and sends the user back to the registration wizard.
class RejectedReviewPage extends StatelessWidget {
  const RejectedReviewPage({
    super.key,
    required this.reason,
    required this.onEdit,
    required this.onCheck,
    this.accent = MigaColors.primary,
  });
  final String reason;
  final VoidCallback onEdit;
  final VoidCallback onCheck;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: MigaColors.errorSoft, shape: BoxShape.circle),
                child: const Icon(Icons.edit_note_rounded, color: MigaColors.error, size: 56),
              ).animate().scale(begin: const Offset(.8, .8), curve: Curves.easeOutBack, duration: 500.ms),
              const SizedBox(height: 28),
              Text('يلزم تعديل بياناتك', style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'راجع فريق ميجا طلبك ولم نتمكن من توثيقه بعد. عدّل البيانات وأعد الإرسال للمراجعة.',
                style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MigaColors.errorSoft,
                  borderRadius: MigaRadius.all(MigaRadius.lg),
                  border: Border.all(color: MigaColors.error.withValues(alpha: .25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سبب الرفض', style: t.labelMedium?.copyWith(color: MigaColors.error)),
                    const SizedBox(height: 4),
                    Text(reason, style: t.titleSmall),
                  ],
                ),
              ),
              const Spacer(),
              MigaButton(label: 'تعديل البيانات وإعادة الإرسال', icon: Icons.edit_rounded, color: accent, onPressed: onEdit),
              const SizedBox(height: 8),
              MigaButton(label: 'تحقق من حالة الطلب', variant: MigaButtonVariant.text, color: accent, onPressed: onCheck),
            ],
          ),
        ),
      ),
    );
  }
}
