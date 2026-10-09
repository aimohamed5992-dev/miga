import 'package:flutter/material.dart';

import '../../core/driver_data.dart';
import '../account/driver_account_page.dart';
import '../deliveries/deliveries_page.dart';
import '../earnings/driver_earnings_page.dart';
import '../home/driver_home_page.dart';

/// Bottom navigation: Home · Deliveries · Earnings · Account.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [DriverHomePage(), DeliveriesPage(), DriverEarningsPage(), DriverAccountPage()]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))]),
        child: ListenableBuilder(
          listenable: DriverData.instance,
          builder: (context, _) {
            final active = DriverData.instance.active.length;
            return NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                NavigationDestination(
                  icon: Badge.count(count: active, isLabelVisible: active > 0, child: const Icon(Icons.local_shipping_outlined)),
                  selectedIcon: Badge.count(count: active, isLabelVisible: active > 0, child: const Icon(Icons.local_shipping_rounded)),
                  label: 'توصيلاتي',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'أرباحي',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'حسابي',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
