import 'package:flutter/material.dart';

import '../account/merchant_account_page.dart';
import '../campaigns/merchant_campaigns_page.dart';
import '../dashboard/dashboard_page.dart';
import '../orders/merchant_orders_page.dart';
import '../products/products_page.dart';

/// Bottom navigation: Dashboard · Campaigns · Products · Orders · More.
class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key, this.initialTab = 0});
  final int initialTab;

  static final _tabRequests = ValueNotifier<int?>(null);

  /// Orders waiting for the merchant (badge on the orders tab), refreshed by the dashboard.
  static final newOrders = ValueNotifier<int>(0);

  /// Lets any page (even ones pushed above the shell) jump to a tab.
  static void goToTab(BuildContext context, int tab) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _tabRequests.value = tab;
    _tabRequests.value = null;
  }

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    MerchantShell._tabRequests.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    MerchantShell._tabRequests.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final t = MerchantShell._tabRequests.value;
    if (t != null) setState(() => _tab = t);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const MerchantCampaignsPage(),
      const ProductsPage(),
      const MerchantOrdersPage(),
      const MerchantAccountPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))]),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'الرئيسية',
            ),
            const NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'الحملات'),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'المنتجات',
            ),
            NavigationDestination(
              icon: _OrdersIcon(Icons.all_inbox_outlined),
              selectedIcon: _OrdersIcon(Icons.all_inbox_rounded),
              label: 'الطلبات',
            ),
            const NavigationDestination(icon: Icon(Icons.menu_rounded), selectedIcon: Icon(Icons.menu_open_rounded), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}

class _OrdersIcon extends StatelessWidget {
  const _OrdersIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: MerchantShell.newOrders,
    builder: (_, n, __) => Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon)),
  );
}
