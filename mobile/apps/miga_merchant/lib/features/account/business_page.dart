import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Registered business details. Official data changes need re-verification, so they go through merchant support.
class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات النشاط التجاري')),
      body: MigaAsync<MerchantBusiness>(
        load: AppServices.api.merchant.business,
        builder:
            (context, b) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: b.isVerified ? MigaColors.successSoft : MigaColors.warningSoft,
                    borderRadius: MigaRadius.all(MigaRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                        color: b.isVerified ? MigaColors.success : MigaColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        b.isVerified
                            ? 'نشاط موثّق${b.verifiedAt == null ? '' : ' منذ ${MigaFormat.date(b.verifiedAt!)}'}'
                            : 'بانتظار التوثيق',
                        style: t.titleSmall?.copyWith(color: b.isVerified ? MigaColors.success : MigaColors.warning),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                MigaCard(
                  child: Column(
                    children: [
                      InfoRow('المالك', b.ownerName),
                      InfoRow('الجوال', b.phone.startsWith('+966') ? '0${b.phone.substring(4)}' : b.phone),
                      InfoRow('الاسم التجاري', b.businessNameAr ?? '—'),
                      if (b.businessNameEn != null) InfoRow('الاسم بالإنجليزية', b.businessNameEn!),
                      InfoRow('السجل التجاري', b.commercialRegistrationNumber ?? '—'),
                      InfoRow('الرقم الضريبي', b.taxNumber ?? '—'),
                      InfoRow('عدد المتاجر', '${b.storesCount}'),
                      InfoRow('تاريخ التسجيل', MigaFormat.date(b.registeredAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MigaCard(child: Column(children: [InfoRow('البنك', b.bankName ?? 'لم يُضف بعد'), InfoRow('الآيبان', b.iban ?? '—')])),
                const SizedBox(height: 16),
                Text(
                  'لتعديل البيانات الرسمية (السجل التجاري أو الاسم التجاري) تواصل مع دعم التجار، فالتعديل يتطلب إعادة التوثيق. '
                  'الحساب البنكي يُعدَّل من المحفظة.',
                  style: t.bodySmall?.copyWith(height: 1.7),
                ),
                const SizedBox(height: 12),
                MigaButton(
                  label: 'تواصل مع دعم التجار',
                  icon: Icons.support_agent_rounded,
                  variant: MigaButtonVariant.outline,
                  onPressed:
                      () => migaPush(
                        context,
                        MigaSupportPage(
                          title: 'دعم التجار',
                          loadConfig: AppServices.api.catalog.config,
                          faqs: MigaContent.merchantFaqs,
                          accent: MigaColors.merchantAccent,
                        ),
                      ),
                ),
              ],
            ),
      ),
    );
  }
}
