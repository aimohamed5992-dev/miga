import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miga_merchant/features/campaigns/campaign_edit_page.dart';
import 'package:miga_ui/miga_ui.dart';

MerchantCampaignView _view({required int sold, CampaignStatus status = CampaignStatus.active}) => MerchantCampaignView(
  Campaign(
    id: 'c1',
    storeId: 's1',
    product: const Product(id: 'p1', storeId: 's1', categoryId: 'k1', nameAr: 'زيت زيتون', price: 100, images: ['p_oil.jpg']),
    titleAr: 'حملة الزيت',
    originalPrice: 100,
    campaignPrice: 70,
    targetQuantity: 10,
    currentQuantity: sold,
    participantsCount: sold == 0 ? 0 : 2,
    maxPerCustomer: 5,
    startDate: DateTime.now().subtract(const Duration(days: 1)),
    endDate: DateTime.now().add(const Duration(days: 4)),
    status: status,
  ),
  sold * 70,
  null,
);

Future<void> _pump(WidgetTester tester, MerchantCampaignView v) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MigaAppShell(role: MigaRole.merchant, home: CampaignEditPage(view: v)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('running campaign with buyers locks the price and explains the target floor', (tester) async {
    await _pump(tester, _view(sold: 4));
    expect(find.text('تعديل الحملة'), findsOneWidget);
    expect(find.text('السعر مقفل لأن عملاء دفعوا به بالفعل'), findsOneWidget);
    expect(find.text('لا تقل عن المباع: 4 قطعة'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '10'), '4');
    await tester.pump();
    expect(find.text('تساوي المباع: ستكتمل الحملة فور الحفظ'), findsOneWidget);
  });

  testWidgets('draft keeps every field editable', (tester) async {
    await _pump(tester, _view(sold: 0, status: CampaignStatus.draft));
    expect(find.text('تعديل المسودة'), findsOneWidget);
    expect(find.text('السعر مقفل لأن عملاء دفعوا به بالفعل'), findsNothing);
    expect(find.text('حتى 30 يومًا من بدء الحملة'), findsOneWidget);
  });
}
