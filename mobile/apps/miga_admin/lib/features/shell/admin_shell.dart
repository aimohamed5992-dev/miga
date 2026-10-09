import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../core/session.dart';
import '../../main.dart';
import '../banners/banners_page.dart';
import '../campaigns/campaigns_page.dart';
import '../dashboard/dashboard_page.dart';
import '../deliveries/deliveries_page.dart';
import '../orders/orders_page.dart';
import '../payouts/payouts_page.dart';
import '../users/users_page.dart';
import '../verifications/verifications_page.dart';

enum AdminSection {
  dashboard('الرئيسية', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  verifications('طلبات التوثيق', Icons.verified_user_outlined, Icons.verified_user_rounded),
  customers('العملاء', Icons.people_outline_rounded, Icons.people_rounded),
  merchants('التجار', Icons.storefront_outlined, Icons.storefront_rounded),
  drivers('المندوبون', Icons.delivery_dining_outlined, Icons.delivery_dining_rounded),
  campaigns('الحملات', Icons.campaign_outlined, Icons.campaign_rounded),
  orders('الطلبات', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  deliveries('التوصيلات', Icons.local_shipping_outlined, Icons.local_shipping_rounded),
  payouts('سحوبات التجار', Icons.account_balance_outlined, Icons.account_balance_rounded),
  banners('البانرات الإعلانية', Icons.view_carousel_outlined, Icons.view_carousel_rounded);

  const AdminSection(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Sidebar layout (drawer under 1000 px). Counters in the menu come from the dashboard summary, refreshed every minute.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initial = AdminSection.dashboard});
  final AdminSection initial;

  static final _requests = ValueNotifier<AdminSection?>(null);

  /// Any page can jump to another section (e.g. a dashboard alert → the review queue).
  static void go(AdminSection s) {
    _requests.value = s;
    _requests.value = null;
  }

  /// Pages call this after an action that changes the counters (verify, refund, payout…).
  static final refreshCounters = ValueNotifier<int>(0);

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AdminSection _section = widget.initial == AdminSection.dashboard ? fromUrl() : widget.initial;
  AdminCounts? _counts;
  Timer? _poll;
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    AdminShell._requests.addListener(_onRequest);
    AdminShell.refreshCounters.addListener(_loadCounts);
    _loadCounts();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _loadCounts());
    // Deep link: ?user=<id> opens that account's panel on load.
    final user = Uri.base.queryParameters['user'];
    if (user != null) WidgetsBinding.instance.addPostFrameCallback((_) => openUserPanel(context, user));
  }

  /// `?section=merchants` etc. opens a section directly (bookmarks, links in messages).
  static AdminSection fromUrl() =>
      AdminSection.values.where((s) => s.name == Uri.base.queryParameters['section']).firstOrNull ?? AdminSection.dashboard;

  @override
  void dispose() {
    _poll?.cancel();
    AdminShell._requests.removeListener(_onRequest);
    AdminShell.refreshCounters.removeListener(_loadCounts);
    super.dispose();
  }

  void _onRequest() {
    final s = AdminShell._requests.value;
    if (s != null) _select(s);
  }

  void _select(AdminSection s) {
    setState(() => _section = s);
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  Future<void> _loadCounts() async {
    try {
      final d = await AppServices.api.admin.dashboard();
      if (mounted) setState(() => _counts = d.counts);
    } catch (_) {
      // Counters are hints; each page shows its own errors.
    }
  }

  int _badge(AdminSection s) => switch (s) {
    AdminSection.verifications => _counts?.pendingReviews ?? 0,
    AdminSection.deliveries => _counts?.failedDeliveries ?? 0,
    AdminSection.payouts => _counts?.payoutsRequested ?? 0,
    _ => 0,
  };

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل تريد تسجيل الخروج من لوحة الإدارة؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج', style: TextStyle(color: MigaColors.error))),
            ],
          ),
    );
    if (ok != true) return;
    await Session.instance.signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => MigaAdminApp.loginPage()), (_) => false);
  }

  Widget _page() => switch (_section) {
    AdminSection.dashboard => const DashboardPage(),
    AdminSection.verifications => const VerificationsPage(),
    AdminSection.customers => const UsersPage(type: 'customer'),
    AdminSection.merchants => const UsersPage(type: 'merchant'),
    AdminSection.drivers => const UsersPage(type: 'driver'),
    AdminSection.campaigns => const CampaignsPage(),
    AdminSection.orders => const OrdersPage(),
    AdminSection.deliveries => const DeliveriesPage(),
    AdminSection.payouts => const PayoutsPage(),
    AdminSection.banners => const BannersPage(),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final sidebar = _Sidebar(section: _section, badge: _badge, onSelect: _select, onLogout: _logout);
    return Scaffold(
      key: _scaffold,
      backgroundColor: MigaColors.background,
      drawer: wide ? null : Drawer(width: 280, child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 264, child: sidebar),
          Expanded(
            child: Column(
              children: [
                _TopBar(section: _section, onMenu: wide ? null : () => _scaffold.currentState?.openDrawer()),
                Expanded(child: KeyedSubtree(key: ValueKey(_section), child: _page())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section, required this.badge, required this.onSelect, required this.onLogout});
  final AdminSection section;
  final int Function(AdminSection) badge;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final account = Session.instance.account;
    Widget group(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(title, style: t.labelSmall?.copyWith(color: Colors.white38, letterSpacing: .5)),
    );
    Widget item(AdminSection s) {
      final selected = s == section;
      final n = badge(s);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected ? Colors.white.withValues(alpha: .1) : Colors.transparent,
          borderRadius: MigaRadius.all(MigaRadius.md),
          child: InkWell(
            borderRadius: MigaRadius.all(MigaRadius.md),
            onTap: () => onSelect(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(selected ? s.selectedIcon : s.icon, size: 20, color: selected ? Colors.white : Colors.white60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.label,
                      style: t.titleSmall?.copyWith(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (n > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.pill)),
                      child: Text('$n', style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: MigaColors.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Row(
                children: [
                  const MigaLogo(size: 38, white: true),
                  const SizedBox(width: 10),
                  Text('ميجا', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: MigaColors.primary, borderRadius: MigaRadius.all(MigaRadius.pill)),
                    child: Text('الإدارة', style: t.labelSmall?.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  group('عام'),
                  item(AdminSection.dashboard),
                  item(AdminSection.verifications),
                  group('المستخدمون'),
                  item(AdminSection.customers),
                  item(AdminSection.merchants),
                  item(AdminSection.drivers),
                  group('العمليات'),
                  item(AdminSection.campaigns),
                  item(AdminSection.orders),
                  item(AdminSection.deliveries),
                  item(AdminSection.payouts),
                  group('التسويق'),
                  item(AdminSection.banners),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  MigaAvatar(name: (account?.fullName.isNotEmpty ?? false) ? account!.fullName : 'مدير', size: 38, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (account?.fullName.isNotEmpty ?? false) ? account!.fullName : 'مدير ميجا',
                          style: t.titleSmall?.copyWith(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          account?.phoneNumber ?? '',
                          style: t.labelSmall?.copyWith(color: Colors.white54),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'تسجيل الخروج', onPressed: onLogout, icon: const Icon(Icons.logout_rounded, color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section, this.onMenu});
  final AdminSection section;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: MigaColors.surface, border: Border(bottom: BorderSide(color: MigaColors.divider))),
      child: Row(
        children: [
          if (onMenu != null) ...[IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)), const SizedBox(width: 4)],
          Icon(section.selectedIcon, color: MigaColors.primary),
          const SizedBox(width: 10),
          Text(section.label, style: t.titleLarge),
          const Spacer(),
          Text(MigaFormat.date(DateTime.now()), style: t.bodySmall),
        ],
      ),
    );
  }
}
