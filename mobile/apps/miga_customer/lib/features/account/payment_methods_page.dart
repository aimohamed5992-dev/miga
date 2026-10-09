import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../checkout/checkout_page.dart';

/// Payment options accepted at checkout. Card details are never stored in the app — each payment goes through the gateway.
class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('طرق الدفع')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('تختار طريقة الدفع عند تأكيد الطلب. الطرق المتاحة:', style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary)),
          const SizedBox(height: 12),
          MigaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, m) in PaymentMethod.values.indexed) ...[
                  ListTile(
                    leading: Icon(m.icon, color: MigaColors.primary),
                    title: Text(m.label, style: t.titleSmall),
                    subtitle: Text(m.hint, style: t.bodySmall),
                    trailing: const Icon(Icons.check_circle_rounded, color: MigaColors.success, size: 20),
                  ),
                  if (i < PaymentMethod.values.length - 1) const Divider(indent: 64),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: MigaColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لا نحفظ بيانات بطاقتك. تتم كل عملية دفع عبر بوابة دفع آمنة، ويُسترد المبلغ تلقائيًا إن لم تكتمل الحملة.',
                    style: t.bodySmall?.copyWith(color: MigaColors.info),
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
