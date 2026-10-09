import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/driver_data.dart';
import '../../core/services.dart';
import 'route_map.dart';

const _accent = MigaColors.driverAccent;

/// One customer delivery after the driver accepted it:
/// pick up with the merchant's code → start → deliver with the customer's code (or report a failure).
class DeliveryDetailPage extends StatefulWidget {
  const DeliveryDetailPage({super.key, required this.deliveryId, this.initial});
  final String deliveryId;
  final DriverDelivery? initial;

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  late DriverDelivery? _d = widget.initial;
  Object? _error;
  bool _busy = false;

  static const _flow = [DeliveryStatus.driverAccepted, DeliveryStatus.pickedUp, DeliveryStatus.outForDelivery, DeliveryStatus.delivered];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppServices.api.driver.delivery(widget.deliveryId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<bool> _run(Future<DriverDelivery> Function(DriverApi api) call) async {
    setState(() => _busy = true);
    try {
      final d = await DriverData.instance.step(call);
      if (mounted) setState(() => _d = d);
      return true;
    } catch (e) {
      if (mounted) showMigaError(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks for a 4-digit code; the sheet stays open on a wrong code so the driver can retry.
  Future<void> _codeSheet({
    required String title,
    required String hint,
    required String buttonLabel,
    required IconData icon,
    required Future<DriverDelivery> Function(DriverApi api, String code) call,
    VoidCallback? onDone,
  }) async {
    final code = TextEditingController();
    var sending = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, set) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: Theme.of(c).textTheme.titleLarge),
                      Text(hint, style: Theme.of(c).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      MigaTextField(
                        label: 'الرمز',
                        hint: '4 أرقام',
                        controller: code,
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        onChanged: (_) => set(() {}),
                      ),
                      const SizedBox(height: 16),
                      MigaButton(
                        label: buttonLabel,
                        icon: icon,
                        loading: sending,
                        onPressed:
                            code.text.length < 4
                                ? null
                                : () async {
                                  set(() => sending = true);
                                  try {
                                    final d = await DriverData.instance.step((api) => call(api, code.text));
                                    if (mounted) setState(() => _d = d);
                                    if (c.mounted) Navigator.pop(c, true);
                                  } catch (e) {
                                    if (c.mounted) {
                                      set(() => sending = false);
                                      showMigaError(c, e);
                                    }
                                  }
                                },
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (ok == true) onDone?.call();
  }

  void _pickUp() => _codeSheet(
    title: 'الاستلام من التاجر',
    hint: 'اطلب من التاجر رمز الاستلام الظاهر في تطبيقه وأدخله هنا',
    buttonLabel: 'تأكيد الاستلام',
    icon: Icons.inventory_2_rounded,
    call: (api, code) => api.pickUp(widget.deliveryId, code),
    onDone: () => showMigaMessage(context, 'تم استلام الطلب — ابدأ التوصيل عندما تكون جاهزًا'),
  );

  void _deliver() => _codeSheet(
    title: 'تأكيد التسليم',
    hint: 'اطلب من العميل رمز التسليم الظاهر في تفاصيل طلبه',
    buttonLabel: 'تأكيد التسليم',
    icon: Icons.verified_rounded,
    call: (api, code) => api.deliver(widget.deliveryId, code),
    onDone: () {
      final fee = _d?.fee ?? 0;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (c) => MigaSuccessPage(
                image: 'driver_delivered.png',
                accent: _accent,
                title: 'تم التسليم بنجاح!',
                message: 'أحسنت يا كابتن 👏 تمت إضافة ${MigaFormat.money(fee)} إلى أرباحك.',
                buttonLabel: 'العودة للطلبات',
                onDone: () => Navigator.pop(c),
              ),
        ),
      );
    },
  );

  Future<void> _fail() async {
    const reasons = ['العميل لا يرد', 'العنوان غير صحيح', 'العميل رفض الاستلام', 'المنتج تالف'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('سبب تعذّر التسليم', style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final r in reasons)
                  ListTile(
                    leading: const Icon(Icons.report_outlined, color: MigaColors.error),
                    title: Text(r),
                    onTap: () => Navigator.pop(c, r),
                  ),
              ],
            ),
          ),
    );
    if (reason != null) await _run((api) => api.fail(widget.deliveryId, reason));
  }

  Future<void> _release() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('إلغاء قبول الطلب؟'),
            content: const Text('سيعود الطلب لقائمة الطلبات ليستلمه مندوب آخر.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('رجوع')),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('إلغاء القبول', style: TextStyle(color: MigaColors.error)),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await DriverData.instance.release(widget.deliveryId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMigaError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            _error != null
                ? MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _load)
                : const Center(child: CircularProgressIndicator()),
      );
    }
    final t = Theme.of(context).textTheme;
    final status = d.status;
    final stage = _flow.indexOf(status);
    final toCustomer = stage >= 1;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: MigaColors.surface,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: MigaIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              title: Text('#${d.number}'),
              flexibleSpace: FlexibleSpaceBar(
                background: RouteMap(
                  height: 320,
                  borderRadius: BorderRadius.zero,
                  progress: switch (status) {
                    DeliveryStatus.pickedUp => .5,
                    DeliveryStatus.outForDelivery => .75,
                    DeliveryStatus.delivered => 1,
                    _ => 0,
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList.list(
                children: [
                  if (status == DeliveryStatus.failed)
                    _Banner(
                      icon: Icons.error_outline_rounded,
                      color: MigaColors.error,
                      text: 'تعذّر التسليم${d.failureReason == null ? '' : ' (${d.failureReason})'} — سيتواصل الدعم مع العميل',
                    )
                  else
                    _StageBar(stage: stage),
                  if (status == DeliveryStatus.driverAccepted) ...[
                    const SizedBox(height: 10),
                    const _Banner(
                      icon: Icons.pin_outlined,
                      color: MigaColors.merchantAccent,
                      text: 'عند وصولك للتاجر اطلب منه رمز الاستلام وأدخله لتأكيد استلام الطلب',
                    ),
                  ],
                  const SizedBox(height: 14),
                  _StopCard(
                    label: 'الاستلام من',
                    icon: Icons.storefront_rounded,
                    color: MigaColors.merchantAccent,
                    title: d.storeName,
                    subtitle: d.pickupAddress ?? '—',
                    done: toCustomer,
                    trailing: [
                      if (d.storePhone != null)
                        _Round(icon: Icons.phone_rounded, color: MigaColors.merchantAccent, onTap: () => migaCall(context, d.storePhone)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StopCard(
                    label: 'التسليم إلى',
                    icon: Icons.location_on_rounded,
                    color: MigaColors.primary,
                    title: d.customerName,
                    subtitle: '${d.addressName} • ${d.fullAddress}',
                    done: status == DeliveryStatus.delivered,
                    trailing: [
                      _Round(icon: Icons.phone_rounded, color: MigaColors.success, onTap: () => migaCall(context, d.customerPhone)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MigaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('محتوى الطلب', style: t.titleMedium),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            MigaImage(d.imageUrl ?? '', width: 52, height: 52, borderRadius: MigaRadius.all(MigaRadius.sm)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(d.productName, style: t.titleSmall)),
                            Text('× ${d.quantity}', style: t.titleMedium),
                          ],
                        ),
                        const Divider(height: 22),
                        InfoRow('طريقة الدفع', 'مدفوع مسبقًا — لا تحصيل', valueColor: MigaColors.success, icon: Icons.verified_rounded),
                        InfoRow('أجرة التوصيل', MigaFormat.money(d.fee), icon: Icons.payments_outlined),
                        if (d.distanceKm != null) InfoRow('المسافة', '${d.distanceKm!.toStringAsFixed(1)} كم', icon: Icons.route_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _actionBar(status),
    );
  }

  Widget? _actionBar(DeliveryStatus status) {
    final (String label, IconData icon, VoidCallback onTap)? main = switch (status) {
      DeliveryStatus.driverAccepted => ('إدخال رمز الاستلام', Icons.pin_rounded, _pickUp),
      DeliveryStatus.pickedUp => ('بدء التوصيل', Icons.local_shipping_rounded, () => _run((api) => api.start(widget.deliveryId))),
      DeliveryStatus.outForDelivery => ('تأكيد التسليم', Icons.verified_rounded, _deliver),
      _ => null,
    };
    if (main == null) return null;
    final secondary = switch (status) {
      DeliveryStatus.driverAccepted => ('إلغاء القبول', MigaColors.textSecondary, _release),
      DeliveryStatus.outForDelivery => ('تعذّر التسليم', MigaColors.error, _fail),
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (secondary != null) ...[
              Expanded(
                flex: 2,
                child: MigaButton(
                  label: secondary.$1,
                  variant: MigaButtonVariant.outline,
                  color: secondary.$2,
                  onPressed: _busy ? null : secondary.$3,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(flex: 3, child: MigaButton(label: main.$1, icon: main.$2, loading: _busy, onPressed: main.$3)),
          ],
        ),
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const labels = ['قبول', 'الاستلام', 'في الطريق', 'التسليم'];
    const icons = [Icons.check_rounded, Icons.storefront_rounded, Icons.local_shipping_rounded, Icons.home_rounded];
    // stage: 0 accepted, 1 picked up, 2 on the way, 3 delivered → steps up to and including `stage` are done.
    final current = stage + 1;
    return MigaCard(
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: i < current ? _accent : (i == current ? _accent.withValues(alpha: .12) : MigaColors.surfaceMuted),
                    shape: BoxShape.circle,
                    border: i == current ? Border.all(color: _accent, width: 2) : null,
                  ),
                  child: Icon(
                    i < current ? Icons.check_rounded : icons[i],
                    size: 18,
                    color: i < current ? Colors.white : (i == current ? _accent : MigaColors.textHint),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: t.labelSmall?.copyWith(color: i <= current ? MigaColors.textPrimary : MigaColors.textHint)),
              ],
            ),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: i < current - 1 ? _accent : MigaColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.done = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> trailing;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.md)),
            child: Icon(done ? Icons.check_circle_rounded : icon, color: done ? MigaColors.success : color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(label, style: t.labelSmall), Text(title, style: t.titleSmall), Text(subtitle, style: t.bodySmall)],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      MigaIconButton(icon: icon, size: 40, background: color.withValues(alpha: .1), color: color, onTap: onTap);
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: MigaRadius.all(MigaRadius.md)),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color))),
      ],
    ),
  );
}
