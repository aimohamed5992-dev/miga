import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import '../../widgets/admin_widgets.dart';
import '../shell/admin_shell.dart';

/// Customers / merchants / drivers: search, status filter, server-paged table, details panel with suspend / reactivate.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.type});

  /// customer · merchant · driver
  final String type;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _q = '';
  String _status = 'all';
  final _table = GlobalKey<AdminTableState<AdminUser>>();

  String get _title => switch (widget.type) {
    'merchant' => 'التجار',
    'driver' => 'المندوبون',
    _ => 'العملاء',
  };

  List<AdminColumn<AdminUser>> get _columns => switch (widget.type) {
    'merchant' => [
      AdminColumn('التاجر', (u) => AdminCell(u.businessName ?? '—', subtitle: u.fullName), flex: 3),
      AdminColumn('الجوال', (u) => Text(localPhone(u.phone), textDirection: TextDirection.ltr)),
      AdminColumn('المتاجر', (u) => Text('${u.storesCount}'), flex: 1),
      AdminColumn('التوثيق', (u) => verificationChip(u.verification)),
      AdminColumn('الحساب', (u) => activeChip(u.isActive)),
      AdminColumn('انضم', (u) => Text(MigaFormat.date(u.createdAt))),
    ],
    'driver' => [
      AdminColumn('المندوب', (u) => AdminCell(u.fullName, subtitle: localPhone(u.phone), ltrSubtitle: true), flex: 3),
      AdminColumn('المدينة / المركبة', (u) => AdminCell(u.city ?? '—', subtitle: _vehicle(u.vehicleType))),
      AdminColumn('توصيلات', (u) => Text('${u.deliveriesCount}'), flex: 1),
      AdminColumn('التقييم', (u) => Text(u.rating?.toStringAsFixed(1) ?? '—'), flex: 1),
      AdminColumn(
        'الحالة',
        (u) =>
            u.isAvailable && u.isActive
                ? const StatusChip('متصل', tone: StatusTone.success, icon: Icons.circle)
                : const StatusChip('غير متصل'),
      ),
      AdminColumn('التوثيق', (u) => verificationChip(u.verification)),
      AdminColumn('الحساب', (u) => activeChip(u.isActive)),
    ],
    _ => [
      AdminColumn('العميل', (u) => AdminCell(u.fullName.isEmpty ? 'بدون اسم' : u.fullName, subtitle: u.email), flex: 3),
      AdminColumn('الجوال', (u) => Text(localPhone(u.phone), textDirection: TextDirection.ltr)),
      AdminColumn('الطلبات', (u) => Text('${u.ordersCount}'), flex: 1),
      AdminColumn('إجمالي المشتريات', (u) => Text(MigaFormat.money(u.totalSpent))),
      AdminColumn('الحساب', (u) => activeChip(u.isActive)),
      AdminColumn('انضم', (u) => Text(MigaFormat.date(u.createdAt))),
    ],
  };

  Future<void> _open(AdminUser u) async {
    if (await openUserPanel(context, u.id) == true) _table.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final roleWithReview = widget.type != 'customer';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPageHeader(
          title: _title,
          subtitle: 'ابحث بالاسم أو رقم الجوال${widget.type == 'merchant' ? ' أو الاسم التجاري' : ''}',
          actions: [AdminSearchField(hint: 'بحث…', onChanged: (v) => setState(() => _q = v))],
        ),
        const SizedBox(height: 16),
        AdminFilters<String>(
          options: [('all', 'الكل'), ('active', 'نشط'), ('suspended', 'موقوف'), if (roleWithReview) ('pending', 'بانتظار التوثيق')],
          value: _status,
          onChanged: (v) => setState(() => _status = v),
        ),
        const SizedBox(height: 16),
        AdminTable<AdminUser>(
          key: _table,
          reloadKey: (widget.type, _q, _status),
          columns: _columns,
          onTap: _open,
          emptyTitle: 'لا يوجد $_title',
          load:
              (page, size) =>
                  AppServices.api.admin.users(type: widget.type, q: _q.isEmpty ? null : _q, status: _status, page: page, pageSize: size),
        ),
      ],
    );
  }

  static String _vehicle(String? t) => switch (t) {
    'car' => 'سيارة',
    'van' => 'فان',
    'truck' => 'شاحنة صغيرة',
    'bike' => 'دراجة نارية',
    _ => t ?? '—',
  };
}

/// Slides the user's details in from the side. Returns true when the account changed.
Future<bool?> openUserPanel(BuildContext context, String userId) async {
  final changed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => Align(alignment: AlignmentDirectional.centerEnd, child: UserDetailPanel(userId: userId)),
    transitionBuilder:
        (ctx, a, __, child) => SlideTransition(
          position: Tween(
            begin: Offset(Directionality.of(ctx) == TextDirection.rtl ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
  );
  if (changed == true) AdminShell.refreshCounters.value++;
  return changed;
}

/// Side panel: profile, role details (stores, bank, vehicle), recent activity and suspend / reactivate.
/// Pops `true` when the account changed so the table reloads.
class UserDetailPanel extends StatefulWidget {
  const UserDetailPanel({super.key, required this.userId});
  final String userId;

  @override
  State<UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends State<UserDetailPanel> {
  late Future<AdminUserDetail> _future = AppServices.api.admin.user(widget.userId);
  bool _changed = false;

  void _reload() => setState(() => _future = AppServices.api.admin.user(widget.userId));

  Future<void> _suspend(AdminUser u) async {
    final reason = await askReason(
      context,
      title: 'إيقاف الحساب',
      message:
          'سيُسجَّل خروج "${u.fullName}" فورًا ولن يستطيع الدخول.'
          '${u.userType == UserType.merchant
              ? ' ستختفي متاجره من التطبيق.'
              : u.userType == UserType.driver
              ? ' سيُحوَّل إلى غير متصل.'
              : ''}',
      confirmLabel: 'إيقاف الحساب',
      hint: 'سبب الإيقاف (يظهر للإدارة فقط)',
      suggestions: const ['إساءة استخدام المنصة', 'بلاغات متكررة من العملاء', 'مخالفة شروط الاستخدام'],
    );
    if (reason == null || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.setActive(u.id, false, reason: reason), 'تم إيقاف الحساب')) {
      _changed = true;
      _reload();
    }
  }

  Future<void> _reactivate(AdminUser u) async {
    final ok = await confirmAction(
      context,
      title: 'إعادة تفعيل الحساب',
      message: 'سيستطيع "${u.fullName}" استخدام ميجا من جديد ويصله إشعار بذلك.',
      confirmLabel: 'إعادة التفعيل',
    );
    if (!ok || !mounted) return;
    if (await runAction(context, () => AppServices.api.admin.setActive(u.id, true), 'تمت إعادة تفعيل الحساب')) {
      _changed = true;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 560.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Material(
        color: MigaColors.background,
        elevation: 12,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: FutureBuilder<AdminUserDetail>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                final e = snap.error;
                return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
              }
              final d = snap.data;
              if (d == null) return const Center(child: CircularProgressIndicator());
              return _content(context, d);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AdminUserDetail d) {
    final t = Theme.of(context).textTheme;
    final u = d.user;
    final accent = switch (u.userType) {
      UserType.merchant => MigaColors.merchantAccent,
      UserType.driver => MigaColors.driverAccent,
      _ => MigaColors.primary,
    };
    final info = <(String, String?)>[
      ('الجوال', localPhone(u.phone)),
      if (u.email != null) ('البريد', u.email),
      ('تاريخ الانضمام', MigaFormat.date(u.createdAt)),
      if (u.userType == UserType.customer) ...[
        ('العناوين', '${d.addresses}'),
        ('الطلبات', '${u.ordersCount}'),
        ('إجمالي المشتريات', MigaFormat.money(u.totalSpent)),
      ],
      if (u.userType == UserType.merchant) ...[('الاسم التجاري', u.businessName), ('البنك', d.bankName), ('الآيبان', d.iban)],
      if (u.userType == UserType.driver) ...[
        ('رقم الهوية', d.nationalId),
        ('رخصة القيادة', d.drivingLicenseNumber),
        ('المدينة', u.city),
        ('المركبة', [d.vehicleModel, d.plateNumber].whereType<String>().join(' • ')),
        ('توصيلات مكتملة', '${u.deliveriesCount}'),
        ('التقييم', u.rating?.toStringAsFixed(1)),
      ],
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          color: MigaColors.surface,
          child: Row(
            children: [
              MigaAvatar(name: u.fullName.isEmpty ? '؟' : u.fullName, size: 52, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.fullName.isEmpty ? 'بدون اسم' : u.fullName, style: t.titleLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusChip(u.userType.labelAr, tone: StatusTone.info),
                        activeChip(u.isActive),
                        if (u.userType != UserType.customer) verificationChip(u.verification),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(_changed), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!u.isActive && u.suspensionReason != null)
                _Banner(color: MigaColors.error, icon: Icons.block_rounded, text: 'موقوف: ${u.suspensionReason}'),
              if (d.rejectionReason != null && u.verification == 'rejected')
                _Banner(color: MigaColors.warning, icon: Icons.edit_note_rounded, text: 'رُفض التسجيل: ${d.rejectionReason}'),
              if (u.verification == 'pending' && u.userType != UserType.customer)
                _Banner(
                  color: MigaColors.info,
                  icon: Icons.hourglass_top_rounded,
                  text: 'بانتظار التوثيق — راجعه من صفحة طلبات التوثيق',
                  action: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(_changed);
                      AdminShell.go(AdminSection.verifications);
                    },
                    child: const Text('فتح'),
                  ),
                ),
              MigaCard(
                child: Column(
                  children: [
                    for (final (label, value) in info)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 140, child: Text(label, style: t.bodySmall)),
                            Expanded(
                              // Numbers (phone, IBAN) are LTR runs but stay aligned with the other values.
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  (value == null || value.isEmpty) ? '—' : value,
                                  style: t.titleSmall,
                                  textDirection: label == 'الجوال' || label == 'الآيبان' ? TextDirection.ltr : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (d.stores.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('المتاجر (${d.stores.length})', style: t.titleMedium),
                const SizedBox(height: 8),
                MigaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final s in d.stores)
                        ListTile(
                          leading: const Icon(Icons.storefront_rounded, color: MigaColors.merchantAccent),
                          title: Text(s.nameAr, style: t.titleSmall),
                          subtitle: Text('${s.products} منتج • ${s.campaigns} حملة', style: t.bodySmall),
                          trailing: StatusChip(
                            s.status.labelAr,
                            tone:
                                s.status == StoreStatus.active
                                    ? StatusTone.success
                                    : (s.status == StoreStatus.suspended ? StatusTone.danger : StatusTone.neutral),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(switch (u.userType) {
                UserType.merchant => 'آخر الطلبات المجمّعة',
                UserType.driver => 'آخر التوصيلات',
                _ => 'آخر الطلبات',
              }, style: t.titleMedium),
              const SizedBox(height: 8),
              if (d.recent.isEmpty)
                MigaCard(child: Center(child: Text('لا يوجد نشاط بعد', style: t.bodySmall)))
              else
                MigaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, a) in d.recent.indexed) ...[
                        ListTile(
                          dense: true,
                          title: Text(a.title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${a.number} • ${MigaFormat.date(a.date)} • ${statusLabel(a.status)}', style: t.bodySmall),
                          trailing: Text(MigaFormat.money(a.amount), style: t.titleSmall),
                        ),
                        if (i < d.recent.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (u.userType != UserType.admin)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
            child:
                u.isActive
                    ? MigaButton(
                      label: 'إيقاف الحساب',
                      icon: Icons.block_rounded,
                      variant: MigaButtonVariant.outline,
                      color: MigaColors.error,
                      height: 46,
                      onPressed: () => _suspend(u),
                    )
                    : MigaButton(label: 'إعادة تفعيل الحساب', icon: Icons.lock_open_rounded, height: 46, onPressed: () => _reactivate(u)),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text, this.action});
  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: MigaRadius.all(MigaRadius.md)),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color))),
        if (action != null) action!,
      ],
    ),
  );
}
