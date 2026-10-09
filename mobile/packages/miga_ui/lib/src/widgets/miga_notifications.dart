import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_buttons.dart';
import 'miga_common.dart';
import 'miga_feedback.dart';
import 'miga_format.dart';
import 'miga_states.dart';

/// Notifications list shared by the three apps (GET /api/notifications), with "mark all read".
class MigaNotificationsPage extends StatefulWidget {
  const MigaNotificationsPage({super.key, required this.api, this.accent = MigaColors.primary, required this.emptyMessage});
  final NotificationsApi api;
  final Color accent;
  final String emptyMessage;

  static IconData iconFor(String title) {
    if (title.contains('اكتملت') || title.contains('مكتمل')) return Icons.celebration_rounded;
    if (title.contains('الطريق') || title.contains('توصيل') || title.contains('مندوب')) return Icons.local_shipping_rounded;
    if (title.contains('استرداد') || title.contains('إلغاء') || title.contains('ألغي')) return Icons.replay_rounded;
    if (title.contains('سحب') || title.contains('أرباح') || title.contains('دفع')) return Icons.account_balance_wallet_rounded;
    if (title.contains('طلب')) return Icons.all_inbox_rounded;
    if (title.contains('توثيق') || title.contains('تفعيل')) return Icons.verified_rounded;
    return Icons.notifications_active_rounded;
  }

  @override
  State<MigaNotificationsPage> createState() => _MigaNotificationsPageState();
}

class _MigaNotificationsPageState extends State<MigaNotificationsPage> {
  int _reload = 0;

  Future<void> _readAll() async {
    try {
      await widget.api.markAllRead();
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = widget.accent;
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات'), actions: [TextButton(onPressed: _readAll, child: const Text('قراءة الكل'))]),
      body: MigaAsync<List<AppNotification>>(
        key: ValueKey(_reload),
        load: widget.api.list,
        builder:
            (context, items) =>
                items.isEmpty
                    ? EmptyState(image: 'empty_notifications.png', title: 'لا توجد إشعارات', message: widget.emptyMessage)
                    : RefreshIndicator(
                      onRefresh: () async => setState(() => _reload++),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return MigaCard(
                            color: n.isRead ? MigaColors.surface : Color.alphaBlend(accent.withValues(alpha: .04), MigaColors.surface),
                            border: !n.isRead,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: .1),
                                    borderRadius: MigaRadius.all(MigaRadius.md),
                                  ),
                                  child: Icon(MigaNotificationsPage.iconFor(n.title), color: accent, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(n.title, style: t.titleSmall)),
                                          Text(MigaFormat.timeAgo(n.time), style: t.labelSmall),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(n.body, style: t.bodySmall?.copyWith(height: 1.5)),
                                    ],
                                  ),
                                ),
                                if (!n.isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                  ),
                                ],
                              ],
                            ),
                          ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: -.05);
                        },
                      ),
                    ),
      ),
    );
  }
}

/// Header bell with the unread count; opens [MigaNotificationsPage] and refreshes the count on return.
class MigaNotificationBell extends StatefulWidget {
  const MigaNotificationBell({super.key, required this.api, this.accent = MigaColors.primary, required this.emptyMessage});
  final NotificationsApi api;
  final Color accent;
  final String emptyMessage;

  @override
  State<MigaNotificationBell> createState() => _MigaNotificationBellState();
}

class _MigaNotificationBellState extends State<MigaNotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await widget.api.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // The badge is a hint only; the page shows errors with retry.
    }
  }

  @override
  Widget build(BuildContext context) => MigaIconButton(
    icon: Icons.notifications_none_rounded,
    badge: _unread,
    onTap: () async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MigaNotificationsPage(api: widget.api, accent: widget.accent, emptyMessage: widget.emptyMessage)),
      );
      _refresh();
    },
  );
}
