import 'package:flutter/material.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_onboarding.dart';
import 'miga_splash.dart';

/// Splash → Onboarding → [next] with smooth fade transitions.
class MigaIntroFlow extends StatelessWidget {
  const MigaIntroFlow({super.key, required this.role, required this.pages, required this.next});
  final MigaRole role;
  final List<OnboardingPageData> pages;
  final WidgetBuilder next;

  /// Design review only: `--dart-define=MIGA_ONB_PAGE=2` opens onboarding on page 3.
  static const _reviewPage = int.fromEnvironment('MIGA_ONB_PAGE');

  static Route<T> fadeRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (c, _, __) => builder(c),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
  );

  @override
  Widget build(BuildContext context) {
    return MigaSplash(
      role: role,
      onFinished:
          () => Navigator.of(context).pushReplacement(
            fadeRoute(
              (onboardingContext) => MigaOnboarding(
                pages: pages,
                accent: role.accent,
                // Merchant navy is too dark to read as a highlight — keep brand red there.
                highlightColor: role == MigaRole.merchant ? MigaColors.primary : null,
                initialPage: _reviewPage.clamp(0, pages.length - 1),
                onDone: () => Navigator.of(onboardingContext).pushReplacement(fadeRoute(next)),
              ),
            ),
          ),
    );
  }
}
