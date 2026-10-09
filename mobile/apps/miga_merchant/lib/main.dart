import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'core/services.dart';
import 'core/session.dart';
import 'features/auth/merchant_auth.dart';
import 'features/campaigns/campaign_wizard_page.dart';
import 'features/categories/categories_page.dart';
import 'features/earnings/earnings_page.dart';
import 'features/orders/merchant_order_detail_page.dart';
import 'features/intro/onboarding_pages.dart';
import 'features/products/product_form_page.dart';
import 'features/shell/merchant_shell.dart';
import 'features/stores/store_form_page.dart';
import 'features/stores/stores_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppServices.api.client.onSessionExpired = () => Session.instance.expired(MigaMerchantApp.loginPage);
  // Review screens open directly (no splash), so restore the session first.
  if (MigaMerchantApp._reviewScreen.isNotEmpty && await Session.instance.restore()) {
    final account = Session.instance.account;
    if (account != null) Session.instance.signedIn(account);
  }
  runApp(const MigaMerchantApp());
}

class MigaMerchantApp extends StatelessWidget {
  const MigaMerchantApp({super.key});

  /// Design review: `--dart-define=MIGA_SCREEN=login` opens a screen directly.
  static const _reviewScreen = String.fromEnvironment('MIGA_SCREEN');

  static Widget _home(BuildContext context) => const MerchantShell();

  static Widget loginPage() => const MerchantLoginPage(onAuthenticated: _home);

  /// Splash → onboarding → login (used after logging out, so the app starts over like a fresh install).
  static Widget launchPage() => const _Launch();

  @override
  Widget build(BuildContext context) => MigaAppShell(
    role: MigaRole.merchant,
    navigatorKey: AppServices.navigatorKey,
    home: switch (_reviewScreen) {
      'login' => loginPage(),
      'wizard' => const MerchantRegistrationPage(onApproved: _home),
      'pending' => const MerchantPendingPage(onApproved: _home),
      'home' => const MerchantShell(),
      'campaigns' => const MerchantShell(initialTab: 1),
      'products' => const MerchantShell(initialTab: 2),
      'orders' => const MerchantShell(initialTab: 3),
      'more' => const MerchantShell(initialTab: 4),
      'product_new' => const ProductFormPage(),
      'categories' => const CategoriesPage(),
      'stores' => const StoresPage(),
      'store_new' => const StoreFormPage(),
      'campaign_new' => const CampaignWizardPage(),
      'earnings' => const EarningsPage(),
      'order_detail' => const MerchantOrderDetailPage(orderId: String.fromEnvironment('MIGA_ORDER_ID')),
      'notifications' => MigaNotificationsPage(
        api: AppServices.api.notifications,
        accent: MigaColors.merchantAccent,
        emptyMessage: 'سنخبرك فور اكتمال حملاتك ووصول الطلبات المجمّعة',
      ),
      'gallery' => const DesignGalleryPage(role: MigaRole.merchant),
      _ => const _Launch(),
    },
  );
}

/// Splash while the saved session is restored; then onboarding/login, registration, pending review or the dashboard.
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
    final account = Session.instance.account;
    if (signedIn && account != null) Session.instance.signedIn(account);
    Navigator.of(context).pushReplacement(
      MigaIntroFlow.fadeRoute(
        (c) =>
            signedIn && account != null
                ? merchantNextPage(account, MigaMerchantApp._home)
                : signedIn
                ? const MerchantShell()
                : MigaOnboarding(
                  pages: merchantOnboardingPages,
                  accent: MigaColors.merchantAccent,
                  highlightColor: MigaColors.primary,
                  onDone: () => Navigator.of(c).pushReplacement(MigaIntroFlow.fadeRoute((_) => MigaMerchantApp.loginPage())),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MigaSplash(role: MigaRole.merchant, onFinished: _next);
}
