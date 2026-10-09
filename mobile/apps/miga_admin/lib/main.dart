import 'package:flutter/material.dart';
import 'package:miga_ui/miga_ui.dart';

import 'core/services.dart';
import 'core/session.dart';
import 'features/auth/admin_login_page.dart';
import 'features/shell/admin_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppServices.api.client.onSessionExpired = () => Session.instance.expired(MigaAdminApp.loginPage);
  runApp(const MigaAdminApp());
}

class MigaAdminApp extends StatelessWidget {
  const MigaAdminApp({super.key});

  static Widget _home(BuildContext context) => const AdminShell();

  static Widget loginPage() => const AdminLoginPage(onSignedIn: _home);

  @override
  Widget build(BuildContext context) => MigaAppShell(role: MigaRole.admin, navigatorKey: AppServices.navigatorKey, home: const _Launch());
}

/// Restores the saved session (or the dev sign-in), then opens the dashboard or the login page.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  /// Design review: `--dart-define=MIGA_SCREEN=login` forces the login page.
  static const _reviewScreen = String.fromEnvironment('MIGA_SCREEN');

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final signedIn = _reviewScreen != 'login' && await Session.instance.restore();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MigaIntroFlow.fadeRoute((_) => signedIn ? const AdminShell() : MigaAdminApp.loginPage()));
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: MigaColors.ink, body: Center(child: MigaLogo(size: 96, white: true)));
}
