import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miga_driver/features/shell/driver_shell.dart';
import 'package:miga_ui/miga_ui.dart';

void main() {
  testWidgets('splash shows the brand and moves to onboarding', (tester) async {
    await tester.pumpWidget(
      MigaAppShell(
        role: MigaRole.driver,
        home: MigaIntroFlow(
          role: MigaRole.driver,
          pages: const [OnboardingPageData(image: 'x.png', icon: Icons.star, title: 'عنوان', highlight: '', body: 'نص')],
          next: (_) => const SizedBox(),
        ),
      ),
    );
    expect(find.text('ميجا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('عنوان'), findsOneWidget);
  });

  testWidgets('main shell renders', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MigaAppShell(role: MigaRole.driver, home: DriverShell()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('توصيلاتي'), findsWidgets);
    expect(find.text('أرباحي'), findsWidgets);
  });
}
