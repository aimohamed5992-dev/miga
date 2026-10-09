import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

/// Title row of a section page, with optional actions on the end side.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.headlineSmall),
              if (subtitle != null) Text(subtitle!, style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Search box that reports after the admin stops typing (one request per pause, not per key).
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({super.key, required this.hint, required this.onChanged, this.width = 320});
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  final _c = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onChanged(v.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: TextField(
      controller: _c,
      onChanged: _changed,
      onSubmitted: (v) => widget.onChanged(v.trim()),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, color: MigaColors.textHint),
        suffixIcon:
            _c.text.isEmpty
                ? null
                : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _c.clear();
                    _changed('');
                  },
                ),
      ),
    ),
  );
}

/// Horizontal row of filter chips.
class AdminFilters<T> extends StatelessWidget {
  const AdminFilters({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final (v, label) in options) MigaChoiceChip(label: label, selected: v == value, onSelected: () => onChanged(v))],
  );
}

class AdminColumn<T> {
  const AdminColumn(this.label, this.cell, {this.flex = 2});
  final String label;
  final Widget Function(T row) cell;
  final int flex;
}

/// Server-paged table: header, rows (tap → [onTap]), loading / error / empty states and a pager.
/// Change [reloadKey] (e.g. a filter or search term) to start again from page 1.
class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.load,
    required this.columns,
    required this.reloadKey,
    this.onTap,
    this.emptyTitle = 'لا توجد نتائج',
    this.emptyMessage = 'جرّب تغيير الفلتر أو كلمة البحث',
    this.pageSize = 20,
  });
  final Future<PagedResult<T>> Function(int page, int pageSize) load;
  final List<AdminColumn<T>> columns;
  final Object reloadKey;
  final ValueChanged<T>? onTap;
  final String emptyTitle;
  final String emptyMessage;
  final int pageSize;

  @override
  State<AdminTable<T>> createState() => AdminTableState<T>();
}

class AdminTableState<T> extends State<AdminTable<T>> {
  int _page = 1;
  PagedResult<T>? _data;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant AdminTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _page = 1;
      reload();
    }
  }

  /// Reloads the current page (call after an action changed a row).
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final key = widget.reloadKey;
    try {
      final r = await widget.load(_page, widget.pageSize);
      if (mounted && key == widget.reloadKey) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(int page) {
    _page = page;
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = _data;
    Widget body;
    if (_error != null && data == null) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: reload),
      );
    } else if (data == null) {
      body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    } else if (data.items.isEmpty) {
      body = SizedBox(height: 320, child: EmptyState(image: 'empty_orders.png', title: widget.emptyTitle, message: widget.emptyMessage));
    } else {
      body = Column(
        children: [
          for (final (i, row) in data.items.indexed) ...[
            _Row(
              onTap: widget.onTap == null ? null : () => widget.onTap!(row),
              cells: [for (final c in widget.columns) (c.flex, c.cell(row))],
            ),
            if (i < data.items.length - 1) const Divider(height: 1),
          ],
        ],
      );
    }
    final from = data == null || data.items.isEmpty ? 0 : (_page - 1) * widget.pageSize + 1;
    final to = data == null ? 0 : from + data.items.length - 1;
    return MigaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: MigaColors.surfaceMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(MigaRadius.lg)),
            ),
            child: Row(
              children: [
                for (final c in widget.columns)
                  Expanded(flex: c.flex, child: Text(c.label, style: t.labelMedium?.copyWith(color: MigaColors.textSecondary))),
              ],
            ),
          ),
          if (_loading && data != null) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          body,
          if (data != null && data.totalCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: MigaColors.divider))),
              child: Row(
                children: [
                  Text('$from–$to من ${data.totalCount}', style: t.bodySmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'السابق',
                    onPressed: _page > 1 && !_loading ? () => _go(_page - 1) : null,
                    icon: const Directionality(textDirection: TextDirection.ltr, child: Icon(Icons.chevron_right_rounded)),
                  ),
                  Text('صفحة $_page', style: t.labelMedium),
                  IconButton(
                    tooltip: 'التالي',
                    onPressed: data.hasMore && !_loading ? () => _go(_page + 1) : null,
                    icon: const MigaChevron(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.cells, this.onTap});
  final List<(int, Widget)> cells;
  final VoidCallback? onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        color: _hover && widget.onTap != null ? MigaColors.background : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            for (final (flex, cell) in widget.cells)
              Expanded(flex: flex, child: Align(alignment: AlignmentDirectional.centerStart, child: cell)),
          ],
        ),
      ),
    ),
  );
}

/// Two-line cell: bold title + muted subtitle.
class AdminCell extends StatelessWidget {
  const AdminCell(this.title, {super.key, this.subtitle, this.ltrSubtitle = false});
  final String title;
  final String? subtitle;
  final bool ltrSubtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle!,
            style: t.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: ltrSubtitle ? TextDirection.ltr : null,
          ),
      ],
    );
  }
}

/// Asks for a written reason (reject, suspend, cancel, refund). Returns null when dismissed.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String hint = 'اكتب السبب — يظهر للمستخدم',
  List<String> suggestions = const [],
  bool danger = true,
}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, set) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
                      const SizedBox(height: 14),
                      if (suggestions.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in suggestions)
                              ActionChip(
                                label: Text(s),
                                onPressed: () {
                                  c.text = s;
                                  set(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      MigaTextField(hint: hint, controller: c, maxLines: 3, autofocus: true, onChanged: (_) => set(() {})),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                  MigaButton(
                    label: confirmLabel,
                    expanded: false,
                    height: 42,
                    color: danger ? MigaColors.error : null,
                    onPressed: c.text.trim().length < 3 ? null : () => Navigator.pop(ctx, c.text.trim()),
                  ),
                ],
              ),
        ),
  );
}

Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String confirmLabel}) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: SizedBox(width: 420, child: Text(message)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              MigaButton(label: confirmLabel, expanded: false, height: 42, onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
    ) ??
    false;

/// Runs an admin action with an Arabic success message or the API error.
Future<bool> runAction(BuildContext context, Future<void> Function() action, String success) async {
  try {
    await action();
    if (context.mounted) showMigaMessage(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showMigaError(context, e);
    return false;
  }
}

/// Arabic label for a backend enum name (activity rows report statuses as names, e.g. "OutForDelivery").
String statusLabel(String name) {
  final n = name.toLowerCase();
  for (final list in <List<Enum>>[CampaignOrderStatus.values, MerchantOrderStatus.values, DeliveryStatus.values]) {
    for (final e in list) {
      if (e.name.toLowerCase() == n) {
        return switch (e) {
          CampaignOrderStatus s => s.labelAr,
          MerchantOrderStatus s => s.labelAr,
          DeliveryStatus s => s.labelAr,
          _ => name,
        };
      }
    }
  }
  return name;
}

/// Verification pill for merchants / drivers.
StatusChip verificationChip(String v) => switch (v) {
  'verified' => const StatusChip('موثّق', tone: StatusTone.success, icon: Icons.verified_rounded),
  'pending' => const StatusChip('بانتظار المراجعة', tone: StatusTone.warning, icon: Icons.hourglass_top_rounded),
  'rejected' => const StatusChip('مرفوض', tone: StatusTone.danger, icon: Icons.block_rounded),
  _ => const StatusChip('لم يكمل التسجيل'),
};

StatusChip activeChip(bool active) =>
    active
        ? const StatusChip('نشط', tone: StatusTone.success)
        : const StatusChip('موقوف', tone: StatusTone.danger, icon: Icons.block_rounded);

String localPhone(String e164) => e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;
