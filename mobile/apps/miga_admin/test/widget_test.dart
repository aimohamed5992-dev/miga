import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miga_admin/features/auth/admin_login_page.dart';
import 'package:miga_ui/miga_ui.dart';

void main() {
  testWidgets('login shows the phone step first, wide layout has the brand panel', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MigaAppShell(role: MigaRole.admin, home: AdminLoginPage(onSignedIn: (_) => const SizedBox())));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('تسجيل دخول الإدارة'), findsOneWidget);
    expect(find.text('إرسال الرمز'), findsOneWidget);
    expect(find.textContaining('لوحة تحكم منصة'), findsOneWidget);
  });
}
