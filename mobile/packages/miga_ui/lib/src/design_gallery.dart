import 'package:flutter/material.dart';
import 'package:miga_core/miga_core.dart';

import 'theme/miga_colors.dart';
import 'theme/miga_theme.dart';
import 'widgets/campaign_widgets.dart';
import 'widgets/miga_buttons.dart';
import 'widgets/miga_common.dart';
import 'widgets/miga_image.dart';
import 'widgets/miga_inputs.dart';
import 'widgets/miga_status.dart';

/// Design-system preview shown by every app until its real screens land (step 3+).
class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({super.key, required this.role});
  final MigaRole role;

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  int _qty = 2;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final campaign = MockData.campaigns.first;

    Widget title(String s) => Padding(padding: const EdgeInsets.only(top: 28, bottom: 12), child: Text(s, style: t.titleLarge));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [const MigaLogo(size: 30), const SizedBox(width: 8), Text(widget.role.appName)],
        ),
      ),
      body: ListView(
        // Lets screenshots start mid-page: --dart-define=GALLERY_OFFSET=900
        controller: ScrollController(initialScrollOffset: const int.fromEnvironment('GALLERY_OFFSET').toDouble()),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: MigaColors.primaryGradient,
              borderRadius: MigaRadius.all(MigaRadius.xl),
              boxShadow: MigaShadows.glow(),
            ),
            child: Row(
              children: [
                const MigaLogo(size: 56, white: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نظام تصميم ميجا', style: t.titleLarge?.copyWith(color: Colors.white)),
                      Text(widget.role.tagline, style: t.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          title('الألوان'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                const [
                      ('Primary', MigaColors.primary),
                      ('Dark', MigaColors.primaryDark),
                      ('Soft', MigaColors.primarySoft),
                      ('Ink', MigaColors.ink),
                      ('Success', MigaColors.success),
                      ('Warning', MigaColors.warning),
                      ('Info', MigaColors.info),
                      ('Merchant', MigaColors.merchantAccent),
                      ('Driver', MigaColors.driverAccent),
                    ]
                    .map(
                      (e) => Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: e.$2,
                              borderRadius: MigaRadius.all(MigaRadius.md),
                              border: Border.all(color: MigaColors.border),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(e.$1, style: t.labelSmall),
                        ],
                      ),
                    )
                    .toList(),
          ),
          title('الخطوط — Tajawal'),
          Text('عنوان رئيسي كبير', style: t.headlineLarge),
          Text('عنوان قسم', style: t.titleLarge),
          Text('نص أساسي لوصف المنتج والحملة بسعر الجملة.', style: t.bodyLarge),
          Text('نص ثانوي صغير', style: t.bodySmall),
          title('الأزرار'),
          MigaButton(
            label: 'انضم للحملة',
            icon: Icons.groups_rounded,
            loading: _loading,
            onPressed: () async {
              setState(() => _loading = true);
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) setState(() => _loading = false);
            },
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: MigaButton(label: 'إلغاء', variant: MigaButtonVariant.outline, onPressed: _noop)),
              SizedBox(width: 10),
              Expanded(child: MigaButton(label: 'حفظ', variant: MigaButtonVariant.soft, onPressed: _noop)),
            ],
          ),
          const SizedBox(height: 10),
          const MigaButton(label: 'زر معطل'),
          title('الحقول'),
          const MigaPhoneField(),
          const SizedBox(height: 14),
          const MigaTextField(label: 'اسم العنوان', hint: 'مثال: المنزل', prefixIcon: Icons.bookmark_border_rounded),
          const SizedBox(height: 14),
          const MigaSelectField(label: 'المنطقة', hint: 'اختر المنطقة', value: 'منطقة الرياض'),
          const SizedBox(height: 14),
          const MigaSearchBar(),
          title('الحالات'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip.campaign(CampaignStatus.active),
              StatusChip.campaign(CampaignStatus.completed),
              StatusChip.campaign(CampaignStatus.failed),
              StatusChip.order(CampaignOrderStatus.pending),
              StatusChip.order(CampaignOrderStatus.outForDelivery),
              StatusChip.merchantOrder(MerchantOrderStatus.ready),
              StatusChip.delivery(DeliveryStatus.pickedUp),
              StatusChip.payment(PaymentStatus.refunded),
            ],
          ),
          title('تقدم الحملة'),
          MigaCard(child: CampaignProgress(current: campaign.currentQuantity, target: campaign.targetQuantity)),
          const SizedBox(height: 10),
          const MigaCard(child: CampaignProgress(current: 300, target: 300)),
          title('بطاقات الحملات'),
          SizedBox(
            height: 330,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => CampaignCard(campaign: MockData.activeCampaigns[i], width: 180),
            ),
          ),
          const SizedBox(height: 12),
          CampaignTile(campaign: MockData.campaigns[2], trailing: CountdownChip(MockData.campaigns[2].timeLeft)),
          title('الكمية والسعر'),
          MigaCard(
            child: Row(
              children: [
                PriceTag(price: campaign.campaignPrice * _qty, originalPrice: campaign.originalPrice * _qty, large: true),
                const Spacer(),
                QuantityStepper(value: _qty, max: campaign.maxPerCustomer ?? 99, onChanged: (v) => setState(() => _qty = v)),
              ],
            ),
          ),
          title('مؤشرات'),
          const Row(
            children: [
              Expanded(child: StatTile(label: 'مبيعات اليوم', value: '12,450', icon: Icons.payments_outlined, trend: '+12%')),
              SizedBox(width: 10),
              Expanded(child: StatTile(label: 'حملات نشطة', value: '8', icon: Icons.campaign_outlined, color: MigaColors.info)),
            ],
          ),
          title('عناصر أخرى'),
          MigaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const MigaAvatar(name: 'محمد العتيبي'),
                  title: const Text('محمد العتيبي'),
                  subtitle: const Text('0551234567'),
                  trailing: MigaIconButton(
                    icon: Icons.notifications_none_rounded,
                    badge: 3,
                    background: MigaColors.surfaceMuted,
                    onTap: () {},
                  ),
                ),
                const Divider(),
                const MenuTile(icon: Icons.location_on_outlined, title: 'عناويني', subtitle: '2 عنوان محفوظ'),
                const MenuTile(icon: Icons.logout_rounded, title: 'تسجيل الخروج', danger: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const MigaCard(
            child: Column(
              children: [
                InfoRow('المجموع الفرعي', '5,998 ر.س'),
                InfoRow('التوصيل', 'مجاني', valueColor: MigaColors.success),
                Divider(height: 20),
                InfoRow('الإجمالي', '5,998 ر.س', bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            height: 320,
            child: MigaCard(child: EmptyState(image: 'empty_cart.png', title: 'سلتك فارغة', message: 'تصفح الحملات وانضم لأول حملة لك')),
          ),
        ],
      ),
    );
  }
}

void _noop() {}
