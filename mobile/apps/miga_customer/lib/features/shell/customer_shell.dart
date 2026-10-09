import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import '../../core/cart_store.dart';
import '../account/account_page.dart';
import '../campaigns/campaigns_page.dart';
import '../cart/cart_page.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';

/// Bottom navigation: Home · Campaigns · Cart · Orders · Account.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialTab = 0});
  final int initialTab;

  static final _tabRequests = ValueNotifier<int?>(null);

  /// Lets any page (even ones pushed above the shell) jump to a tab, e.g. "View cart".
  static void goToTab(BuildContext context, int tab) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _tabRequests.value = tab;
    _tabRequests.value = null;
  }

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    CustomerShell._tabRequests.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    CustomerShell._tabRequests.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final t = CustomerShell._tabRequests.value;
    if (t != null) _select(t);
  }

  void _select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [const HomePage(), const CampaignsPage(), const CartPage(), const OrdersPage(), const AccountPage()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))]),
        child: ListenableBuilder(
          listenable: CartStore.instance,
          builder:
              (_, __) => NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _select,
                destinations: [
                  const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                  const NavigationDestination(
                    icon: Icon(Icons.local_fire_department_outlined),
                    selectedIcon: Icon(Icons.local_fire_department_rounded),
                    label: 'الحملات',
                  ),
                  NavigationDestination(
                    icon: Badge.count(
                      count: CartStore.instance.count,
                      isLabelVisible: CartStore.instance.count > 0,
                      backgroundColor: MigaColors.primary,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                    selectedIcon: Badge.count(
                      count: CartStore.instance.count,
                      isLabelVisible: CartStore.instance.count > 0,
                      backgroundColor: MigaColors.primary,
                      child: const Icon(Icons.shopping_bag_rounded),
                    ),
                    label: 'السلة',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'طلباتي',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'حسابي',
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
