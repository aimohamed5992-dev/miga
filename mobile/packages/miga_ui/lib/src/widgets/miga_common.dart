import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_buttons.dart';
import 'miga_gallery.dart';
import 'miga_image.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel = 'عرض الكل',
    this.onAction,
    this.padding = MigaSpacing.page,
  });
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: t.titleLarge), if (subtitle != null) Text(subtitle!, style: t.bodySmall)],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: Text(actionLabel, style: t.labelMedium?.copyWith(color: MigaColors.primary)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.image, required this.title, this.message, this.actionLabel, this.onAction});
  final String image;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MigaImage(image, width: 200, height: 200, fit: BoxFit.contain, borderRadius: MigaRadius.all(100)),
            const SizedBox(height: 24),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary), textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[const SizedBox(height: 24), MigaButton(label: actionLabel!, onPressed: onAction, expanded: false)],
          ],
        ),
      ),
    );
  }
}

class MigaAvatar extends StatelessWidget {
  const MigaAvatar({super.key, required this.name, this.size = 44, this.color = MigaColors.primary});
  final String name;
  final double size;
  final Color color;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    // Skip the Arabic article: "سعود الحربي" → "س ح".
    String first(String w) => (w.startsWith('ال') && w.length > 3 ? w.substring(2) : w).characters.first;
    return parts.length == 1 ? first(parts.first) : '${first(parts.first)} ${first(parts.last)}';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
    child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * .32)),
  );
}

/// White rounded container used for most content blocks.
class MigaCard extends StatelessWidget {
  const MigaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = MigaColors.surface,
    this.border = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: MigaRadius.all(MigaRadius.lg),
      side: border ? const BorderSide(color: MigaColors.border) : BorderSide.none,
    ),
    child: InkWell(onTap: onTap, borderRadius: MigaRadius.all(MigaRadius.lg), child: Padding(padding: padding, child: child)),
  );
}

/// Label / value row (order summaries, details).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueColor, this.icon});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: MigaColors.textSecondary), const SizedBox(width: 8)],
          Text(label, style: bold ? t.titleSmall : t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: (bold ? t.titleMedium : t.bodyMedium)?.copyWith(
                color: valueColor,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI tile for merchant / driver dashboards.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color = MigaColors.primary, this.trend});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.sm)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (trend != null) Text(trend!, style: t.labelSmall?.copyWith(color: MigaColors.success, fontWeight: FontWeight.w800)),
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.bottomStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), Text(label, style: t.bodySmall)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile used in settings / profile menus.
class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = danger ? MigaColors.error : MigaColors.textPrimary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: danger ? MigaColors.errorSoft : MigaColors.surfaceMuted,
          borderRadius: MigaRadius.all(MigaRadius.sm),
        ),
        child: Icon(icon, size: 20, color: danger ? MigaColors.error : MigaColors.textPrimary),
      ),
      title: Text(title, style: t.titleSmall?.copyWith(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: t.bodySmall),
      trailing: trailing ?? (danger ? null : const MigaChevron()),
    );
  }
}
