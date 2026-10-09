import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';

class MigaTextField extends StatelessWidget {
  const MigaTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.obscure = false,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;

  /// Enter / keyboard "done" (web forms submit on Enter).
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[Text(label!, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 8)],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          obscureText: obscure,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onSubmitted,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: MigaColors.textHint, size: 22),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Saudi mobile number field: fixed +966 prefix, 9 digits starting with 5.
class MigaPhoneField extends StatelessWidget {
  const MigaPhoneField({super.key, this.controller, this.onChanged, this.label = 'رقم الجوال', this.onSubmitted, this.autofocus = false});
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? label;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[Text(label!, style: t.titleSmall), const SizedBox(height: 8)],
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            controller: controller,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            autofocus: autofocus,
            keyboardType: TextInputType.phone,
            style: t.titleMedium?.copyWith(letterSpacing: 1.2),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: InputDecoration(
              hintText: '5X XXX XXXX',
              prefixIcon: Container(
                margin: const EdgeInsetsDirectional.only(start: 12, end: 10),
                padding: const EdgeInsetsDirectional.only(end: 10),
                decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: MigaColors.border))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇸🇦', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text('+966', style: t.titleSmall),
                  ],
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minHeight: 48),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable field that opens a picker (used for Region → City → District).
class MigaSelectField extends StatelessWidget {
  const MigaSelectField({
    super.key,
    required this.label,
    this.value,
    required this.hint,
    this.onTap,
    this.icon = Icons.location_on_outlined,
    this.enabled = true,
  });
  final String label;
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.titleSmall),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1 : .5,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: MigaRadius.all(MigaRadius.md),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: MigaColors.surface,
                borderRadius: MigaRadius.all(MigaRadius.md),
                border: Border.all(color: MigaColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, color: MigaColors.textHint, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value ?? hint,
                      style: t.bodyMedium?.copyWith(color: value == null ? MigaColors.textHint : MigaColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: MigaColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MigaSearchBar extends StatelessWidget {
  const MigaSearchBar({
    super.key,
    this.hint = 'ابحث عن منتج أو حملة أو متجر',
    this.onTap,
    this.readOnly = true,
    this.onChanged,
    this.trailing,
  });
  final String hint;
  final VoidCallback? onTap;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: MigaColors.textHint),
        suffixIcon: trailing,
        enabledBorder: OutlineInputBorder(borderRadius: MigaRadius.all(MigaRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: MigaRadius.all(MigaRadius.md),
          borderSide: const BorderSide(color: MigaColors.primary),
        ),
      ),
    );
  }
}

/// Pill chip for filters / choices. Custom-built: Material's Chip clips the first glyphs of Arabic labels.
class MigaChoiceChip extends StatelessWidget {
  const MigaChoiceChip({super.key, required this.label, required this.selected, required this.onSelected, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final fg = selected ? Colors.white : MigaColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: MigaRadius.all(MigaRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? accent : MigaColors.surface,
            borderRadius: MigaRadius.all(MigaRadius.pill),
            border: Border.all(color: selected ? accent : MigaColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : MigaColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
