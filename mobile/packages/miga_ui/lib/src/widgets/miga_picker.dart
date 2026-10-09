import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';

/// Searchable bottom-sheet picker (Region → City → District, categories…).
Future<T?> showMigaPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) label,
  T? selected,
  IconData icon = Icons.location_on_outlined,
  Color accent = MigaColors.primary,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickerSheet<T>(title: title, items: items, label: label, selected: selected, icon: icon, accent: accent),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.label,
    this.selected,
    required this.icon,
    required this.accent,
  });
  final String title;
  final List<T> items;
  final String Function(T) label;
  final T? selected;
  final IconData icon;
  final Color accent;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = widget.items.where((e) => widget.label(e).contains(_q.trim())).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(widget.title, style: t.titleLarge)),
            if (widget.items.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'بحث',
                    prefixIcon: const Icon(Icons.search_rounded, color: MigaColors.textHint),
                    fillColor: MigaColors.background,
                    enabledBorder: OutlineInputBorder(borderRadius: MigaRadius.all(MigaRadius.md), borderSide: BorderSide.none),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(context).bottom + 12),
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final e = shown[i];
                  final sel = e == widget.selected;
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: MigaRadius.all(MigaRadius.md)),
                    tileColor: sel ? widget.accent.withValues(alpha: .06) : null,
                    leading: Icon(widget.icon, color: sel ? widget.accent : MigaColors.textHint),
                    title: Text(widget.label(e), style: t.titleSmall?.copyWith(color: sel ? widget.accent : null)),
                    trailing: sel ? Icon(Icons.check_circle_rounded, color: widget.accent) : null,
                    onTap: () => Navigator.pop(context, e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
