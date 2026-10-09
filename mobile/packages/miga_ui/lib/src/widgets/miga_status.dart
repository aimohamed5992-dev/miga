import 'package:flutter/material.dart';
import 'package:miga_core/miga_core.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';

enum StatusTone { neutral, info, warning, success, danger, brand }

extension on StatusTone {
  (Color, Color) get colors => switch (this) {
    StatusTone.neutral => (MigaColors.surfaceMuted, MigaColors.textSecondary),
    StatusTone.info => (MigaColors.infoSoft, MigaColors.info),
    StatusTone.warning => (MigaColors.warningSoft, MigaColors.warning),
    StatusTone.success => (MigaColors.successSoft, MigaColors.success),
    StatusTone.danger => (MigaColors.errorSoft, MigaColors.error),
    StatusTone.brand => (MigaColors.primarySoft, MigaColors.primary),
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = StatusTone.neutral, this.icon});
  final String label;
  final StatusTone tone;
  final IconData? icon;

  factory StatusChip.campaign(CampaignStatus s) => StatusChip(
    s.labelAr,
    tone: switch (s) {
      CampaignStatus.active => StatusTone.brand,
      CampaignStatus.completed || CampaignStatus.closed => StatusTone.success,
      CampaignStatus.processing => StatusTone.info,
      CampaignStatus.failed || CampaignStatus.cancelled => StatusTone.danger,
      CampaignStatus.draft => StatusTone.neutral,
    },
  );

  factory StatusChip.order(CampaignOrderStatus s) => StatusChip(
    s.labelAr,
    tone: switch (s) {
      CampaignOrderStatus.pending => StatusTone.warning,
      CampaignOrderStatus.paid || CampaignOrderStatus.confirmed => StatusTone.brand,
      CampaignOrderStatus.preparing || CampaignOrderStatus.readyForDelivery || CampaignOrderStatus.outForDelivery => StatusTone.info,
      CampaignOrderStatus.delivered => StatusTone.success,
      CampaignOrderStatus.cancelled || CampaignOrderStatus.refunded => StatusTone.danger,
    },
  );

  factory StatusChip.merchantOrder(MerchantOrderStatus s) => StatusChip(
    s.labelAr,
    tone: switch (s) {
      MerchantOrderStatus.pending || MerchantOrderStatus.sentToMerchant => StatusTone.warning,
      MerchantOrderStatus.confirmed || MerchantOrderStatus.preparing => StatusTone.info,
      MerchantOrderStatus.ready => StatusTone.brand,
      MerchantOrderStatus.completed => StatusTone.success,
      MerchantOrderStatus.cancelled => StatusTone.danger,
    },
  );

  factory StatusChip.delivery(DeliveryStatus s) => StatusChip(
    s.labelAr,
    tone: switch (s) {
      DeliveryStatus.pending || DeliveryStatus.assigned => StatusTone.warning,
      DeliveryStatus.driverAccepted || DeliveryStatus.pickedUp => StatusTone.info,
      DeliveryStatus.outForDelivery => StatusTone.brand,
      DeliveryStatus.delivered => StatusTone.success,
      DeliveryStatus.failed || DeliveryStatus.cancelled => StatusTone.danger,
    },
  );

  factory StatusChip.payment(PaymentStatus s) => StatusChip(
    s.labelAr,
    tone: switch (s) {
      PaymentStatus.pending => StatusTone.warning,
      PaymentStatus.paid => StatusTone.success,
      PaymentStatus.refunded || PaymentStatus.partiallyRefunded => StatusTone.info,
      PaymentStatus.failed || PaymentStatus.cancelled => StatusTone.danger,
    },
  );

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: MigaRadius.all(MigaRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ] else ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
