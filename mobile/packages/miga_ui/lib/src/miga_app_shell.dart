import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/miga_colors.dart';
import 'theme/miga_theme.dart';

/// Shared MaterialApp setup for the three apps: Arabic + RTL, theme, status bar.
class MigaAppShell extends StatelessWidget {
  const MigaAppShell({super.key, required this.role, required this.home, this.navigatorKey});
  final MigaRole role;
  final Widget home;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: MigaColors.surface,
      ),
    );
    return MaterialApp(
      title: role.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: MigaTheme.light(role),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}
