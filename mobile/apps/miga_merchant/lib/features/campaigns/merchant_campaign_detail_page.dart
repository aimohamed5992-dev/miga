import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';
import 'campaign_edit_page.dart';
import '../orders/merchant_order_detail_page.dart';

/// Campaign performance for the merchant: progress ring, revenue, participants (CampaignOrders).
class MerchantCampaignDetailPage extends StatefulWidget {
  const MerchantCampaignDetailPage({super.key, required this.campaignId});
  final String campaignId;

  @override
  State<MerchantCampaignDetailPage> createState() => _MerchantCampaignDetailPageState();
}

class _MerchantCampaignDetailPageState extends State<MerchantCampaignDetailPage> {
  MerchantCampaignView? _view;
  List<Participant> _participants = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = AppServices.api.merchant;
      final results = await Future.wait([api.campaign(widget.campaignId), api.participants(widget.campaignId)]);
      if (!mounted) return;
      setState(() {
        _view = results[0] as MerchantCampaignView;
        _participants = results[1] as List<Participant>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('إلغاء الحملة؟'),
            content: Text(
              'سيتم استرداد ${MigaFormat.money(_view!.collectedAmount)} لـ ${_view!.campaign.participantsCount} عميل تلقائيًا. قد يؤثر الإلغاء على تقييم متجرك.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('إلغاء الحملة', style: TextStyle(color: MigaColors.error)),
              ),
            ],
          ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AppServices.api.merchant.cancelCampaign(widget.campaignId, 'ألغاها التاجر');
      if (!context.mounted) return;
      Navigator.pop(context);
      showMigaMessage(context, 'تم إلغاء الحملة وجاري استرداد المبالغ');
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  Future<void> _extend(BuildContext context) async {
    final days = await showModalBottomSheet<int>(
      context: context,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تمديد الحملة', style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final d in [1, 2, 3, 7])
                  ListTile(
                    leading: const Icon(Icons.more_time_rounded),
                    title: Text('تمديد $d ${d == 1 ? 'يوم' : 'أيام'}'),
                    onTap: () => Navigator.pop(c, d),
                  ),
              ],
            ),
          ),
    );
    if (days == null || !context.mounted) return;
    try {
      final view = await AppServices.api.merchant.extendCampaign(widget.campaignId, days);
      if (!context.mounted) return;
      setState(() => _view = view);
      showMigaMessage(context, 'تم تمديد الحملة $days أيام وإشعار المشاركين');
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  Future<void> _edit() async {
    final view = _view;
    if (view == null) return;
    final updated = await migaPush<MerchantCampaignView>(context, CampaignEditPage(view: view));
    if (updated != null) await _load();
  }

  Future<void> _publish() async {
    try {
      await AppServices.api.merchant.publishCampaign(widget.campaignId);
      if (!mounted) return;
      showMigaMessage(context, 'نُشرت الحملة وأصبحت ظاهرة للعملاء');
      await _load();
    } catch (e) {
      if (mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _load),
      );
    }
    if (_view == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final c = _view!.campaign;
    final revenue = _view!.collectedAmount;
    final active = c.status == CampaignStatus.active;
    final done = c.status == CampaignStatus.completed || c.status == CampaignStatus.processing || c.status == CampaignStatus.closed;
    final orderId = _view!.merchantOrderId;
    final shown = _participants.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الحملة'),
        actions: [
          if (active || c.status == CampaignStatus.draft) ...[
            IconButton(tooltip: 'تعديل الحملة', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            PopupMenuButton<String>(
              onSelected:
                  (v) => switch (v) {
                    'edit' => _edit(),
                    'extend' => _extend(context),
                    'publish' => _publish(),
                    _ => _cancel(context),
                  },
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('تعديل الحملة')),
                    if (active) const PopupMenuItem(value: 'extend', child: Text('تمديد المدة')),
                    if (!active) const PopupMenuItem(value: 'publish', child: Text('نشر الحملة')),
                    const PopupMenuItem(value: 'cancel', child: Text('إلغاء الحملة', style: TextStyle(color: MigaColors.error))),
                  ],
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            MigaCard(
              child: Row(
                children: [
                  MigaImage(c.product.mainImage, width: 64, height: 64, borderRadius: MigaRadius.all(MigaRadius.md)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.titleAr, style: t.titleSmall),
                        const SizedBox(height: 2),
                        PriceTag(price: c.campaignPrice, originalPrice: c.originalPrice),
                        const SizedBox(height: 4),
                        StatusChip.campaign(c.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MigaCard(
              child: Row(
                children: [
                  _ProgressRing(progress: c.progress, current: c.currentQuantity, target: c.targetQuantity),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          done ? 'اكتملت الحملة 🎉' : (active ? 'باقي ${c.remainingQuantity} قطعة' : 'لم تكتمل الحملة'),
                          style: t.titleMedium?.copyWith(
                            color: done ? MigaColors.success : (active ? MigaColors.textPrimary : MigaColors.error),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (active) CountdownChip(c.timeLeft),
                        if (!active && !done) Text('تم استرداد المبالغ للعملاء تلقائيًا', style: t.bodySmall),
                        if (done) Text('تم إنشاء طلب مجمّع بالكمية الكاملة', style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'إيرادات محصّلة',
                    value: MigaFormat.money(revenue),
                    icon: Icons.payments_rounded,
                    color: MigaColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(label: 'مشارك', value: '${c.participantsCount}', icon: Icons.groups_rounded, color: MigaColors.info),
                ),
              ],
            ),
            if (done && orderId != null) ...[
              const SizedBox(height: 12),
              MigaButton(
                label: 'عرض الطلب المجمّع',
                icon: Icons.all_inbox_rounded,
                onPressed: () => migaPush(context, MerchantOrderDetailPage(orderId: orderId)),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text('المشاركون', style: t.titleMedium),
                const Spacer(),
                Text('${c.participantsCount} عميل • ${c.currentQuantity} قطعة', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            MigaCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < shown; i++) ...[
                    ListTile(
                      leading: MigaAvatar(name: _participants[i].maskedName, size: 40, color: MigaColors.merchantAccent),
                      title: Text(_participants[i].maskedName, style: t.titleSmall),
                      subtitle: Text(
                        'حي ${_participants[i].district} • ${MigaFormat.timeAgo(_participants[i].createdAt)}',
                        style: t.bodySmall,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_participants[i].quantity} قطعة', style: t.titleSmall),
                          Text(MigaFormat.money(_participants[i].amount), style: t.labelSmall),
                        ],
                      ),
                    ),
                    if (i < shown - 1) const Divider(indent: 72),
                  ],
                  if (shown == 0) Padding(padding: const EdgeInsets.all(20), child: Text('لا يوجد مشاركون بعد', style: t.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.current, required this.target});
  final double progress;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = progress >= 1 ? MigaColors.success : MigaColors.primary;
    return SizedBox(
      width: 108,
      height: 108,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder:
            (_, v, __) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: MigaColors.surfaceMuted,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(v * 100).round()}%', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
                    Text('$current/$target', style: t.labelSmall),
                  ],
                ),
              ],
            ),
      ),
    );
  }
}
