import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../shell/customer_shell.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    required this.amount,
    required this.hasCampaign,
    this.orderNumber,
    this.campaignCompleted = false,
    this.partialFailures = const [],
  });
  final double amount;
  final bool hasCampaign;
  final String? orderNumber;
  final bool campaignCompleted;

  /// Lines that couldn't be paid (e.g. campaign filled meanwhile) — shown so nothing fails silently.
  final List<String> partialFailures;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaSuccessPage(
      image: 'customer_payment_success.png',
      title: 'تم الدفع بنجاح!',
      message:
          campaignCompleted
              ? 'كنت من المكمّلين! اكتملت الحملة وسيبدأ التاجر بتجهيز طلبك. 🎉'
              : hasCampaign
              ? 'تم حجز كميتك في الحملة. سنخبرك فور اكتمال العدد المطلوب وبدء تجهيز طلبك.'
              : 'تم استلام طلبك وسيبدأ التاجر بتجهيزه قريبًا.',
      extra: MigaCard(
        color: MigaColors.background,
        child: Column(
          children: [
            if (orderNumber != null) InfoRow('رقم الطلب', orderNumber!),
            InfoRow('المبلغ المدفوع', MigaFormat.money(amount), bold: true),
            for (final f in partialFailures) ...[
              const Divider(height: 18),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: MigaColors.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: t.bodySmall?.copyWith(color: MigaColors.warning))),
                ],
              ),
            ],
            if (hasCampaign && !campaignCompleted) ...[
              const Divider(height: 18),
              Row(
                children: [
                  const Icon(Icons.share_rounded, size: 18, color: MigaColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('شارك الحملة مع أصدقائك لتكتمل أسرع!', style: t.bodySmall?.copyWith(color: MigaColors.primary))),
                ],
              ),
            ],
          ],
        ),
      ),
      buttonLabel: 'تتبع طلبي',
      onDone: () => migaGoRoot(context, const CustomerShell(initialTab: 3)),
      secondaryLabel: 'العودة للرئيسية',
      onSecondary: () => migaGoRoot(context, const CustomerShell()),
    );
  }
}

class PaymentFailedPage extends StatelessWidget {
  const PaymentFailedPage({super.key, required this.amount, required this.onRetry, this.message});
  final double amount;
  final VoidCallback onRetry;

  /// Reason from the API (e.g. declined by the bank, campaign already full).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MigaColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const MigaImage(
                'error_failed.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ).animate().shakeX(hz: 3, amount: 6, duration: 500.ms),
              const SizedBox(height: 24),
              Text('تعذّر إتمام الدفع', style: t.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '${message ?? 'تعذّر إتمام الدفع'}.\nلم يتم خصم أي مبلغ (${MigaFormat.money(amount)}).',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: MigaColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: MigaColors.warningSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: MigaColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'منتجاتك ما زالت في السلة ومحجوزة لمدة 15 دقيقة.',
                        style: t.bodySmall?.copyWith(color: MigaColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              MigaButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
