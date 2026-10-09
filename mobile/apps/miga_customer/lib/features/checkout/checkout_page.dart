import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/address_store.dart';
import '../../core/cart_store.dart';
import '../../core/services.dart';
import '../addresses/add_address_page.dart';
import '../addresses/addresses_page.dart';
import 'payment_result_pages.dart';

enum PaymentMethod {
  mada('mada', 'مدى', Icons.credit_card_rounded, 'بطاقة مدى البنكية'),
  applePay('applepay', 'Apple Pay', Icons.apple_rounded, 'ادفع بلمسة'),
  card('card', 'بطاقة ائتمانية', Icons.credit_score_rounded, 'Visa / Mastercard'),
  stcPay('stcpay', 'STC Pay', Icons.account_balance_wallet_rounded, 'محفظة رقمية');

  const PaymentMethod(this.code, this.label, this.icon, this.hint);
  final String code;
  final String label;
  final IconData icon;
  final String hint;
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  /// Demo / QA: `--dart-define=MIGA_PAY_FAIL=true` sends the gateway's always-declined test method.
  static const _demoFail = bool.fromEnvironment('MIGA_PAY_FAIL');

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Address? _address;
  PaymentMethod _method = PaymentMethod.mada;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _address = AddressStore.instance.defaultAddress;
    if (!AddressStore.instance.loaded) {
      AddressStore.instance
          .load()
          .then((_) {
            if (mounted) setState(() => _address ??= AddressStore.instance.defaultAddress);
          })
          .catchError((Object e) {
            if (mounted) showMigaError(context, e);
          });
    }
  }

  Future<void> _changeAddress() async {
    final a = await migaPush<Address>(context, AddressesPage(selecting: true, selectedId: _address?.id));
    if (a != null) setState(() => _address = a);
  }

  /// Only campaign lines are charged in this release; regular product lines stay in the cart.
  Iterable<CartLine> get _payable => CartStore.instance.view.lines.where((l) => l.isCampaign && l.issue == null);

  double get _total => _payable.fold(0, (s, l) => s + l.lineTotal);

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final outcome = await AppServices.api.customer.checkout(_address!.id, CheckoutPage._demoFail ? 'test_fail' : _method.code);
      await CartStore.instance.refresh();
      if (!mounted) return;
      final ok = outcome.lines.where((l) => l.success).toList();
      final failed = outcome.lines.where((l) => !l.success && l.code != 'product_orders_unsupported').toList();
      if (ok.isEmpty) {
        migaPush(
          context,
          PaymentFailedPage(
            amount: _total,
            message: failed.isEmpty ? 'لا توجد منتجات حملات قابلة للدفع في السلة' : failed.first.message ?? 'تعذّر إتمام الدفع',
            onRetry: () => Navigator.pop(context),
          ),
        );
        return;
      }
      migaGoRoot(
        context,
        PaymentSuccessPage(
          amount: outcome.totalCharged,
          hasCampaign: true,
          orderNumber: ok.first.orderNumber,
          campaignCompleted: ok.any((l) => l.campaignCompleted),
          partialFailures: failed.map((f) => f.message ?? '').where((m) => m.isNotEmpty).toList(),
        ),
      );
    } catch (e) {
      if (mounted) showMigaError(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final view = CartStore.instance.view;
    final regular = view.lines.where((l) => !l.isCampaign).length;
    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _Section(
            title: 'عنوان التوصيل',
            action: _address == null ? null : TextButton(onPressed: _changeAddress, child: const Text('تغيير')),
            child:
                _address == null
                    ? MigaButton(
                      label: 'إضافة عنوان',
                      icon: Icons.add_location_alt_outlined,
                      variant: MigaButtonVariant.soft,
                      onPressed: () async {
                        await migaPush(context, const AddAddressPage());
                        setState(() => _address = AddressStore.instance.defaultAddress);
                      },
                    )
                    : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: MigaColors.primarySoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                          child: const Icon(Icons.location_on_rounded, color: MigaColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_address!.addressName, style: t.titleSmall),
                              Text(_address!.summary, style: t.bodySmall),
                              Text(_address!.phoneNumber, style: t.bodySmall, textDirection: TextDirection.ltr),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
          for (final (i, group) in view.stores.indexed)
            _Section(
              title: 'الطلب ${i + 1} • ${group.storeName}',
              child: Column(
                children: [
                  for (final line in group.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: line.isCampaign && line.issue == null ? 1 : .5,
                        child: Row(
                          children: [
                            MigaImage(line.imageUrl ?? '', width: 48, height: 48, borderRadius: MigaRadius.all(MigaRadius.sm)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.productName, style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    line.isCampaign ? 'حملة • يُشحن بعد اكتمال الحملة' : 'منتج خارج الحملات • غير متاح للدفع حاليًا',
                                    style: t.labelSmall?.copyWith(color: line.isCampaign ? MigaColors.primary : MigaColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text('×${line.quantity}', style: t.bodySmall),
                            const SizedBox(width: 10),
                            Text(MigaFormat.money(line.lineTotal), style: t.titleSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _Section(
            title: 'طريقة الدفع',
            child: Column(
              children: [
                for (final m in PaymentMethod.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() => _method = m),
                      borderRadius: MigaRadius.all(MigaRadius.md),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: m == _method ? MigaColors.primarySoft : MigaColors.background,
                          borderRadius: MigaRadius.all(MigaRadius.md),
                          border: Border.all(color: m == _method ? MigaColors.primary : Colors.transparent, width: 1.4),
                        ),
                        child: Row(
                          children: [
                            Icon(m.icon, color: m == _method ? MigaColors.primary : MigaColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [Text(m.label, style: t.titleSmall), Text(m.hint, style: t.labelSmall)],
                              ),
                            ),
                            Icon(
                              m == _method ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: m == _method ? MigaColors.primary : MigaColors.textHint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'ملخص الدفع',
            child: Column(
              children: [
                InfoRow('منتجات الحملات', MigaFormat.money(_total)),
                const InfoRow('التوصيل', 'مجاني', valueColor: MigaColors.success),
                if (view.savings > 0) InfoRow('توفيرك من الحملات', '- ${MigaFormat.money(view.savings)}', valueColor: MigaColors.success),
                const Divider(height: 20),
                InfoRow('الإجمالي', MigaFormat.money(_total), bold: true),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: MigaColors.infoSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: MigaColors.info, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'منتجات الحملات تُشحن بعد اكتمال العدد المطلوب. إذا لم تكتمل الحملة يُعاد مبلغها إلى وسيلة الدفع تلقائيًا.'
                    '${regular > 0 ? '\nالمنتجات خارج الحملات ستبقى في السلة.' : ''}',
                    style: t.bodySmall?.copyWith(color: MigaColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
        child: SafeArea(
          top: false,
          child: MigaButton(
            label: 'ادفع ${MigaFormat.money(_total)}',
            icon: _method.icon,
            loading: _paying,
            onPressed: _address == null || _payable.isEmpty ? null : _pay,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: MigaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (action != null) action!]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
