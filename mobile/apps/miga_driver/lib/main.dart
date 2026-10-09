import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'core/services.dart';
import 'core/session.dart';
import 'features/auth/driver_auth.dart';
import 'features/delivery/delivery_detail_page.dart';
import 'features/intro/onboarding_pages.dart';
import 'features/shell/driver_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppServices.api.client.onSessionExpired = () => Session.instance.expired(MigaDriverApp.loginPage);
  // Review screens open directly (no splash), so restore the session first.
  if (MigaDriverApp._reviewScreen.isNotEmpty && await Session.instance.restore()) {
    final account = Session.instance.account;
    if (account != null) Session.instance.signedIn(account);
  }
  runApp(const MigaDriverApp());
}

class MigaDriverApp extends StatelessWidget {
  const MigaDriverApp({super.key});

  /// Design review: `--dart-define=MIGA_SCREEN=login` opens a screen directly.
  static const _reviewScreen = String.fromEnvironment('MIGA_SCREEN');

  static Widget _home(BuildContext context) => const DriverShell();

  static Widget loginPage() => const DriverLoginPage(onAuthenticated: _home);

  /// Splash → onboarding → login (used after logging out, so the app starts over like a fresh install).
  static Widget launchPage() => const _Launch();

  @override
  Widget build(BuildContext context) => MigaAppShell(
    role: MigaRole.driver,
    navigatorKey: AppServices.navigatorKey,
    home: switch (_reviewScreen) {
      'login' => loginPage(),
      'wizard' => const DriverRegistrationPage(onApproved: _home),
      'pending' => const DriverPendingPage(onApproved: _home),
      'home' => const DriverShell(),
      'deliveries' => const DriverShell(initialTab: 1),
      'earnings' => const DriverShell(initialTab: 2),
      'account' => const DriverShell(initialTab: 3),
      'delivery' => const DeliveryDetailPage(deliveryId: String.fromEnvironment('MIGA_DELIVERY_ID')),
      'notifications' => MigaNotificationsPage(
        api: AppServices.api.notifications,
        accent: MigaColors.driverAccent,
        emptyMessage: 'سنخبرك فور وصول طلبات توصيل جديدة',
      ),
      'gallery' => const DesignGalleryPage(role: MigaRole.driver),
      _ => const _Launch(),
    },
  );
}

/// Splash while the saved session is restored; then onboarding/login, registration, pending review or home.
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
                ? driverNextPage(account, MigaDriverApp._home)
                : signedIn
                ? const DriverShell()
                : MigaOnboarding(
                  pages: driverOnboardingPages,
                  accent: MigaColors.driverAccent,
                  onDone: () => Navigator.of(c).pushReplacement(MigaIntroFlow.fadeRoute((_) => MigaDriverApp.loginPage())),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MigaSplash(role: MigaRole.driver, onFinished: _next);
}
