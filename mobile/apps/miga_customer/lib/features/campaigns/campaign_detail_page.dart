import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/cart_store.dart';
import '../../core/favorites_store.dart';
import '../../core/services.dart';
import '../shell/customer_shell.dart';
import '../stores/store_detail_page.dart';
import '../stores/store_widgets.dart';

class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({super.key, required this.campaign});
  final Campaign campaign;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  int _qty = 1;
  bool _joining = false;
  CampaignDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The card's summary renders immediately; fresh quantity, description and store arrive from the API.
  Future<void> _load() async {
    try {
      final d = await AppServices.api.catalog.campaign(widget.campaign.id);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  Campaign get c => _detail?.campaign ?? widget.campaign;
  bool get _isActive => c.status == CampaignStatus.active;
  int get _maxQty => [c.maxPerCustomer ?? 99, c.remainingQuantity].reduce((a, b) => a < b ? a : b).clamp(1, 99);

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await CartStore.instance.addCampaign(c, _qty);
    } catch (e) {
      if (mounted) showMigaError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _joining = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: MigaColors.success),
              const SizedBox(width: 10),
              Expanded(child: Text('تمت إضافة $_qty قطعة من الحملة إلى السلة')),
            ],
          ),
          action: SnackBarAction(
            label: 'عرض السلة',
            textColor: MigaColors.primaryLight,
            onPressed: () => CustomerShell.goToTab(context, 2),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = _detail?.store;
    return Scaffold(
      backgroundColor: MigaColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          // Design review: --dart-define=MIGA_SCROLL=900
          controller: ScrollController(initialScrollOffset: const int.fromEnvironment('MIGA_SCROLL').toDouble()),
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor: MigaColors.surface,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: MigaIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              actions: [
                ListenableBuilder(
                  listenable: FavoritesStore.instance,
                  builder: (context, _) {
                    final fav = FavoritesStore.instance.contains(c.id);
                    return MigaIconButton(
                      icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: fav ? MigaColors.primary : MigaColors.textPrimary,
                      onTap: () async {
                        try {
                          final added = await FavoritesStore.instance.toggle(c);
                          if (context.mounted) {
                            showMigaMessage(context, added ? 'أُضيفت للحملات المفضلة' : 'أُزيلت من المفضلة', icon: Icons.favorite_rounded);
                          }
                        } catch (e) {
                          if (context.mounted) showMigaError(context, e);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: MigaColors.surface,
                  padding: const EdgeInsets.fromLTRB(40, 90, 40, 20),
                  child: MigaImageGallery(images: c.product.images, heroTag: 'campaign-${c.id}'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: MigaColors.surface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(MigaRadius.xl)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip.campaign(c.status),
                        const SizedBox(width: 8),
                        DiscountBadge(c.discountPercent),
                        const Spacer(),
                        Icon(Icons.groups_rounded, size: 18, color: MigaColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${c.participantsCount} مشارك', style: t.labelMedium?.copyWith(color: MigaColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(c.product.nameAr, style: t.headlineSmall),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PriceTag(price: c.campaignPrice, originalPrice: c.originalPrice, large: true),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: MigaColors.successSoft, borderRadius: MigaRadius.all(MigaRadius.pill)),
                          child: Text(
                            'وفّر ${MigaFormat.money(c.savingPerUnit)}',
                            style: t.labelMedium?.copyWith(color: MigaColors.success, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList.list(
                children: [
                  _ProgressCard(campaign: c),
                  const SizedBox(height: 12),
                  if (store != null)
                    MigaCard(
                      onTap: () => migaPush(context, StoreDetailPage(store: store)),
                      child: Row(
                        children: [
                          StoreLogo(store: store, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Text(store.nameAr, style: t.titleSmall), const SizedBox(width: 4), const VerifiedBadge()]),
                                Text('تاجر جملة موثّق', style: t.bodySmall),
                              ],
                            ),
                          ),
                          RatingChip(store.rating),
                          const MigaChevron(color: MigaColors.textHint),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const _HowCampaignWorks(),
                  if (c.descriptionAr != null || c.product.descriptionAr != null) ...[
                    const SizedBox(height: 12),
                    MigaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تفاصيل الحملة', style: t.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            c.descriptionAr ?? c.product.descriptionAr!,
                            style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary, height: 1.7),
                          ),
                          const Divider(height: 24),
                          InfoRow('الكمية المطلوبة', '${c.targetQuantity} قطعة'),
                          if (c.maxPerCustomer != null) InfoRow('الحد الأقصى لكل عميل', '${c.maxPerCustomer} قطع'),
                          InfoRow('تاريخ الانتهاء', MigaFormat.date(c.endDate)),
                          const InfoRow('التوصيل', 'بعد اكتمال الحملة'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.lg)),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: MigaColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ضمان ميجا: إذا لم تكتمل الحملة قبل انتهاء الوقت، يُعاد لك المبلغ كاملًا تلقائيًا.',
                            style: t.bodySmall?.copyWith(color: MigaColors.info, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        campaign: c,
        qty: _qty,
        maxQty: _maxQty,
        onQty: (v) => setState(() => _qty = v),
        onJoin: _isActive && !_joining ? _join : null,
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = campaign;
    final (title, color, icon) = switch (c.status) {
      CampaignStatus.completed ||
      CampaignStatus.processing ||
      CampaignStatus.closed => ('اكتملت الحملة! جاري تجهيز الطلبات', MigaColors.success, Icons.celebration_rounded),
      CampaignStatus.failed => ('لم تكتمل الحملة وتم استرداد المبالغ', MigaColors.error, Icons.replay_rounded),
      CampaignStatus.cancelled => ('أُلغيت الحملة', MigaColors.error, Icons.cancel_rounded),
      _ => ('باقي ${c.remainingQuantity} قطعة لاكتمال الحملة', MigaColors.primary, Icons.local_fire_department_rounded),
    };
    return MigaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: t.titleSmall?.copyWith(color: color))),
            ],
          ),
          const SizedBox(height: 14),
          CampaignProgress(current: c.currentQuantity, target: c.targetQuantity),
          const SizedBox(height: 14),
          _AvatarStack(count: c.participantsCount),
          if (c.status == CampaignStatus.active) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20, color: MigaColors.textSecondary),
                const SizedBox(width: 6),
                Text('تنتهي خلال', style: t.titleSmall?.copyWith(color: MigaColors.textSecondary)),
                const Spacer(),
                _LiveCountdown(end: c.endDate),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.count});
  final int count;

  static const _names = ['سارة', 'فهد', 'نورة', 'خالد'];
  static const _colors = [MigaColors.primary, MigaColors.info, MigaColors.success, MigaColors.warning];

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(0, 4);
    return Row(
      children: [
        SizedBox(
          width: 22.0 * shown + 12,
          height: 34,
          child: Stack(
            children: [
              for (var i = 0; i < shown; i++)
                PositionedDirectional(
                  start: i * 22.0,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: _colors[i].withValues(alpha: .15),
                      child: Text(
                        _names[i].characters.first,
                        style: TextStyle(color: _colors[i], fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (count > shown)
          Text('+${count - shown} انضموا', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MigaColors.textSecondary)),
      ],
    );
  }
}

/// Ticking days / hours / minutes / seconds boxes.
class _LiveCountdown extends StatefulWidget {
  const _LiveCountdown({required this.end});
  final DateTime end;

  @override
  State<_LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<_LiveCountdown> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.end.difference(DateTime.now());
    final parts = [(d.inDays, 'يوم'), (d.inHours % 24, 'ساعة'), (d.inMinutes % 60, 'دقيقة'), (d.inSeconds % 60, 'ثانية')];
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (i, p) in parts.indexed) ...[
          Column(
            children: [
              Container(
                width: 36,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: MigaColors.ink, borderRadius: MigaRadius.all(MigaRadius.sm)),
                child: Text(p.$1.clamp(0, 99).toString().padLeft(2, '0'), style: t.titleSmall?.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: 2),
              Text(p.$2, style: t.labelSmall?.copyWith(fontSize: 9)),
            ],
          ),
          if (i < parts.length - 1) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(' : ', style: t.titleSmall)),
        ],
      ],
    );
  }
}

class _HowCampaignWorks extends StatelessWidget {
  const _HowCampaignWorks();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const steps = [
      (Icons.payments_rounded, 'اشترك وادفع', 'احجز كميتك وادفع بأمان'),
      (Icons.donut_large_rounded, 'تكتمل الحملة', 'عند الوصول للعدد المطلوب تُغلق تلقائيًا'),
      (Icons.inventory_2_rounded, 'يجهّز التاجر', 'يستلم التاجر طلبًا مجمّعًا ويجهّزه'),
      (Icons.local_shipping_rounded, 'يوصلك طلبك', 'المندوب يوصّل الطلب لعنوانك'),
    ];
    return MigaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كيف تعمل الحملة؟', style: t.titleMedium),
          const SizedBox(height: 12),
          for (final (i, s) in steps.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(color: MigaColors.primarySoft, shape: BoxShape.circle),
                        child: Icon(s.$1, size: 18, color: MigaColors.primary),
                      ),
                      if (i < steps.length - 1) Expanded(child: Container(width: 2, color: MigaColors.primarySoft)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(s.$2, style: t.titleSmall), Text(s.$3, style: t.bodySmall)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.campaign, required this.qty, required this.maxQty, required this.onQty, required this.onJoin});
  final Campaign campaign;
  final int qty;
  final int maxQty;
  final ValueChanged<int> onQty;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = onJoin != null;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 12),
      decoration: const BoxDecoration(
        color: MigaColors.surface,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child:
          active
              ? Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QuantityStepper(value: qty, max: maxQty, onChanged: onQty, small: true),
                      const SizedBox(height: 2),
                      Text('الحد: $maxQty', style: t.labelSmall),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MigaButton(
                      label: 'انضم للحملة • ${MigaFormat.money(campaign.campaignPrice * qty)}',
                      icon: Icons.group_add_rounded,
                      onPressed: onJoin,
                    ),
                  ),
                ],
              )
              : MigaButton(label: campaign.status == CampaignStatus.failed ? 'انتهت الحملة دون اكتمال' : 'الحملة مغلقة', onPressed: null),
    );
  }
}
