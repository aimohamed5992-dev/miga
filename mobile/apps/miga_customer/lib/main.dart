import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'core/services.dart';
import 'core/session.dart';
import 'features/addresses/add_address_page.dart';
import 'features/addresses/addresses_page.dart';
import 'features/auth/customer_auth.dart';
import 'features/campaigns/campaigns_page.dart';
import 'features/checkout/checkout_page.dart';
import 'features/checkout/payment_result_pages.dart';
import 'features/intro/onboarding_pages.dart';
import 'features/search/search_page.dart';
import 'features/shell/customer_shell.dart';
import 'features/stores/category_stores_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppServices.api.client.onSessionExpired = () => Session.instance.expired(MigaCustomerApp.loginPage);
  // Review screens open directly (no splash), so restore the session first.
  if (MigaCustomerApp._reviewScreen.isNotEmpty && await Session.instance.restore()) {
    final account = Session.instance.account;
    if (account != null) Session.instance.signedIn(account);
  }
  runApp(const MigaCustomerApp());
}

class MigaCustomerApp extends StatelessWidget {
  const MigaCustomerApp({super.key});

  /// Design review: `--dart-define=MIGA_SCREEN=login` opens a screen directly.
  static const _reviewScreen = String.fromEnvironment('MIGA_SCREEN');

  static Widget _home(BuildContext context) => const CustomerShell();

  static Widget loginPage() => const CustomerLoginPage(onAuthenticated: _home);

  /// Splash → onboarding → login (used after logging out, so the app starts over like a fresh install).
  static Widget launchPage() => const _Launch();

  @override
  Widget build(BuildContext context) => MigaAppShell(
    role: MigaRole.customer,
    navigatorKey: AppServices.navigatorKey,
    home: switch (_reviewScreen) {
      'login' => loginPage(),
      'profile' => const CompleteProfilePage(phone: '+966551234567', onDone: _home),
      'home' => const CustomerShell(),
      'campaigns' => const CustomerShell(initialTab: 1),
      'ending' => const CampaignsPage(initialFilter: CampaignFilter.endingSoon, standalone: true),
      'categories' => const CategoryStoresPage(),
      'search' => const SearchPage(initialQuery: 'أرز'),
      'cart' => const CustomerShell(initialTab: 2),
      'orders' => const CustomerShell(initialTab: 3),
      'account' => const CustomerShell(initialTab: 4),
      'checkout' => const CheckoutPage(),
      'addresses' => const AddressesPage(),
      'add_address' => const AddAddressPage(),
      'pay_success' => const PaymentSuccessPage(amount: 6148, hasCampaign: true, orderNumber: 'MG-1048261'),
      'pay_failed' => PaymentFailedPage(amount: 6148, message: 'تم رفض العملية من البنك', onRetry: () {}),
      'offline' => Scaffold(body: MigaErrorView(onRetry: () {})),
      'notifications' => MigaNotificationsPage(
        api: AppServices.api.notifications,
        accent: MigaColors.primary,
        emptyMessage: 'سنخبرك فور اكتمال حملاتك أو تحديث طلباتك',
      ),
      'gallery' => const DesignGalleryPage(role: MigaRole.customer),
      _ => const _Launch(),
    },
  );
}

/// Splash while the saved session is restored; signed-in users skip onboarding and login.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  final Future<bool> _restored = Session.instance.restore();

  Future<void> _next() async {
    final signedIn = await _restored;
    if (!mounted) return;
    if (signedIn) Session.instance.signedIn(Session.instance.account ?? _offlinePlaceholder);
    Navigator.of(context).pushReplacement(
      MigaIntroFlow.fadeRoute(
        (c) =>
            signedIn
                ? const CustomerShell()
                : MigaOnboarding(
                  pages: customerOnboardingPages,
                  onDone: () => Navigator.of(c).pushReplacement(MigaIntroFlow.fadeRoute((_) => MigaCustomerApp.loginPage())),
                ),
      ),
    );
  }

  // Saved session but the server is unreachable: enter the app; screens show offline states and retry.
  static const _offlinePlaceholder = Account(
    id: '',
    fullName: '',
    phoneNumber: '',
    userType: UserType.customer,
    isProfileComplete: true,
    verificationStatus: 'verified',
  );

  @override
  Widget build(BuildContext context) => MigaSplash(role: MigaRole.customer, onFinished: _next);
}
