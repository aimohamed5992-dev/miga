import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/cart_store.dart';
import '../checkout/checkout_page.dart';
import '../shell/customer_shell.dart';

/// Server cart grouped by store (each store becomes its own order at checkout).
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _cart = CartStore.instance;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await _cart.refresh();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final view = _cart.view;
        return Scaffold(
          appBar: AppBar(
            title: Text('السلة (${view.itemsCount})'),
            actions: [if (!view.isEmpty) TextButton(onPressed: () => _confirmClear(context), child: const Text('إفراغ'))],
          ),
          body:
              _error != null && view.isEmpty
                  ? MigaErrorView(offline: _error is ApiException && (_error as ApiException).isNetwork, onRetry: _refresh)
                  : view.isEmpty
                  ? (_cart.loading
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(
                        image: 'empty_cart.png',
                        title: 'سلتك فارغة',
                        message: 'تصفّح الحملات وانضم لأول حملة لك بسعر الجملة',
                        actionLabel: 'تصفّح الحملات',
                        onAction: () => CustomerShell.goToTab(context, 1),
                      ))
                  : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (view.savings > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: MigaColors.successSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
                            child: Row(
                              children: [
                                const Icon(Icons.savings_rounded, color: MigaColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'أنت توفّر ${MigaFormat.money(view.savings)} بالشراء مع الجماعة 🎉',
                                    style: t.titleSmall?.copyWith(color: MigaColors.success),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: -.2),
                        for (final group in view.stores) ...[_StoreGroup(group: group), const SizedBox(height: 14)],
                      ],
                    ),
                  ),
          bottomNavigationBar:
              view.isEmpty ? null : _CheckoutBar(total: view.total, onCheckout: () => migaPush(context, const CheckoutPage())),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('إفراغ السلة؟'),
            content: const Text('سيتم حذف جميع المنتجات من السلة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('إفراغ', style: TextStyle(color: MigaColors.error))),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await _cart.clear();
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }
}

class _StoreGroup extends StatelessWidget {
  const _StoreGroup({required this.group});
  final CartStoreGroup group;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MigaCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(child: MigaImage(group.storeLogo ?? '', width: 28, height: 28)),
              const SizedBox(width: 8),
              Text(group.storeName, style: t.titleSmall),
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, size: 15, color: MigaColors.info),
              const Spacer(),
              Text('${group.lines.length} منتج', style: t.bodySmall),
            ],
          ),
          const Divider(height: 20),
          for (final (i, line) in group.lines.indexed) ...[_CartRow(line: line), if (i < group.lines.length - 1) const Divider(height: 16)],
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});
  final CartLine line;

  static const _issues = {
    'campaign_ended': 'انتهت الحملة — احذف المنتج من السلة',
    'unavailable': 'المنتج غير متاح حاليًا',
    'price_changed': 'تغيّر السعر',
  };

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showMigaError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cart = CartStore.instance;
    return Dismissible(
      key: ValueKey(line.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _run(context, () => cart.remove(line.id)),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: MigaColors.errorSoft, borderRadius: MigaRadius.all(MigaRadius.md)),
        child: const Icon(Icons.delete_outline_rounded, color: MigaColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MigaImage(line.imageUrl ?? '', width: 78, height: 78, borderRadius: MigaRadius.all(MigaRadius.md)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line.isCampaign)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: StatusChip(
                        'حملة جماعية • ${line.campaignCurrent}/${line.campaignTarget}',
                        tone: StatusTone.brand,
                        icon: Icons.groups_rounded,
                      ),
                    ),
                  Text(line.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  if (line.issue != null) Text(_issues[line.issue] ?? line.issue!, style: t.labelSmall?.copyWith(color: MigaColors.error)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: PriceTag(price: line.unitPrice, originalPrice: line.originalPrice)),
                      QuantityStepper(
                        small: true,
                        value: line.quantity,
                        min: 0,
                        max: line.maxPerCustomer ?? 99,
                        onChanged: (v) => _run(context, () => cart.setQuantity(line.id, v)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.onCheckout});
  final double total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(color: MigaColors.surface, border: Border(top: BorderSide(color: MigaColors.divider))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإجمالي', style: t.bodySmall),
                Text(MigaFormat.money(total), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(child: MigaButton(label: 'إتمام الطلب', icon: Icons.lock_outline_rounded, onPressed: onCheckout)),
          ],
        ),
      ),
    );
  }
}
