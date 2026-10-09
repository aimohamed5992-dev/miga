import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/services.dart';

/// Merchant wallet: available balance (delivered orders minus fees and payouts), monthly sales, transactions,
/// bank account and withdrawals.
class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  late Future<MerchantEarnings> _future = AppServices.api.merchant.earnings();

  static const _monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  void _reload() => setState(() => _future = AppServices.api.merchant.earnings());

  Future<void> _bankAccount(MerchantEarnings e) async {
    final bank = TextEditingController(text: e.bankName);
    final iban = TextEditingController(text: 'SA');
    var saving = false;
    final saved = await showModalBottomSheet<bool>(
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
                      Text('الحساب البنكي', style: Theme.of(c).textTheme.titleLarge),
                      Text('تُحوَّل الأرباح إلى هذا الحساب باسم المنشأة', style: Theme.of(c).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      MigaTextField(
                        label: 'اسم البنك',
                        hint: 'مثال: مصرف الراجحي',
                        controller: bank,
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                      const SizedBox(height: 12),
                      MigaTextField(
                        label: 'رقم الآيبان',
                        hint: 'SA0000000000000000000000',
                        controller: iban,
                        prefixIcon: Icons.credit_card_outlined,
                        keyboardType: TextInputType.visiblePassword,
                      ),
                      const SizedBox(height: 16),
                      MigaButton(
                        label: 'حفظ الحساب',
                        loading: saving,
                        onPressed: () async {
                          set(() => saving = true);
                          try {
                            await AppServices.api.merchant.setBankAccount(bank.text.trim(), iban.text);
                            if (c.mounted) Navigator.pop(c, true);
                          } catch (err) {
                            if (c.mounted) {
                              set(() => saving = false);
                              showMigaError(c, err);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (saved == true && mounted) {
      showMigaMessage(context, 'تم حفظ الحساب البنكي');
      _reload();
    }
  }

  Future<void> _withdraw(MerchantEarnings e) async {
    if (e.ibanMasked == null) return _bankAccount(e);
    final amount = TextEditingController(text: e.available.toStringAsFixed(0));
    var sending = false;
    final done = await showModalBottomSheet<bool>(
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
                      Text('سحب الرصيد', style: Theme.of(c).textTheme.titleLarge),
                      Text('الرصيد المتاح ${MigaFormat.money(e.available)}', style: Theme.of(c).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      MigaTextField(
                        label: 'المبلغ',
                        hint: '0',
                        controller: amount,
                        prefixIcon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      MigaSelectField(
                        label: 'إلى الحساب',
                        hint: '',
                        value: '${e.bankName ?? ''} • ${e.ibanMasked}',
                        icon: Icons.account_balance_outlined,
                      ),
                      const SizedBox(height: 8),
                      Text('يصل المبلغ خلال 1-2 يوم عمل', style: Theme.of(c).textTheme.labelSmall),
                      const SizedBox(height: 16),
                      MigaButton(
                        label: 'تأكيد السحب',
                        loading: sending,
                        onPressed: () async {
                          final v = double.tryParse(amount.text);
                          if (v == null || v <= 0) return;
                          set(() => sending = true);
                          try {
                            await AppServices.api.merchant.requestPayout(v);
                            if (c.mounted) Navigator.pop(c, true);
                          } catch (err) {
                            if (c.mounted) {
                              set(() => sending = false);
                              showMigaError(c, err);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (done == true && mounted) {
      showMigaMessage(context, 'تم إرسال طلب السحب');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة والأرباح')),
      body: FutureBuilder<MerchantEarnings>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            final e = snap.error;
            return MigaErrorView(offline: e is ApiException && e.isNetwork, onRetry: _reload);
          }
          final e = snap.data;
          if (e == null) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(onRefresh: () async => _reload(), child: _body(context, e));
        },
      ),
    );
  }

  Widget _body(BuildContext context, MerchantEarnings e) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B3A5E), MigaColors.merchantAccent],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: MigaRadius.all(MigaRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الرصيد المتاح للسحب', style: t.bodyMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  MigaFormat.money(e.available),
                  style: t.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Pill(label: 'قيد التسوية', value: MigaFormat.money(e.pendingSettlement)),
                  const SizedBox(width: 8),
                  _Pill(label: 'سُحب هذا الشهر', value: MigaFormat.money(e.withdrawnThisMonth)),
                ],
              ),
              const SizedBox(height: 16),
              MigaButton(
                label: e.ibanMasked == null ? 'أضف الحساب البنكي' : 'سحب الرصيد',
                icon: Icons.account_balance_rounded,
                color: Colors.white,
                onPressed: e.ibanMasked != null && e.available <= 0 ? null : () => _withdraw(e),
              ).animate().fadeIn(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MigaCard(
          padding: EdgeInsets.zero,
          child: MenuTile(
            icon: Icons.account_balance_outlined,
            title: e.bankName ?? 'الحساب البنكي',
            subtitle: e.ibanMasked ?? 'لم يُضف بعد — مطلوب لسحب الأرباح',
            trailing: const Icon(Icons.edit_outlined, size: 20, color: MigaColors.textSecondary),
            onTap: () => _bankAccount(e),
          ),
        ),
        const SizedBox(height: 14),
        MigaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المبيعات الشهرية', style: t.titleMedium),
              Text('آخر ${e.monthly.length} أشهر • إجمالي المبيعات', style: t.bodySmall),
              const SizedBox(height: 14),
              MigaBarChart(values: [for (final m in e.monthly) m.$3], labels: [for (final m in e.monthly) _monthNames[m.$2 - 1]]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('آخر العمليات', style: t.titleMedium),
        const SizedBox(height: 10),
        if (e.transactions.isEmpty)
          MigaCard(
            child: Center(
              child: Text('لا توجد عمليات بعد — تظهر الأرباح بعد تسليم أول طلب مجمّع', style: t.bodySmall, textAlign: TextAlign.center),
            ),
          )
        else
          MigaCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, x) in e.transactions.indexed) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: x.amount > 0 ? MigaColors.successSoft : MigaColors.surfaceMuted,
                        borderRadius: MigaRadius.all(MigaRadius.sm),
                      ),
                      child: Icon(
                        switch (x.type) {
                          'income' => Icons.south_west_rounded,
                          'payout' => Icons.account_balance_rounded,
                          _ => Icons.percent_rounded,
                        },
                        color: x.amount > 0 ? MigaColors.success : MigaColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(x.title, style: t.titleSmall),
                    subtitle: Text('${x.subtitle} • ${MigaFormat.date(x.date)}', style: t.bodySmall),
                    trailing: Text(
                      MigaFormat.money(x.amount.abs()),
                      style: t.titleSmall?.copyWith(color: x.amount > 0 ? MigaColors.success : MigaColors.textPrimary),
                    ),
                  ),
                  if (i < e.transactions.length - 1) const Divider(indent: 72),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: MigaRadius.all(MigaRadius.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelSmall?.copyWith(color: Colors.white70)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: t.titleSmall?.copyWith(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}
