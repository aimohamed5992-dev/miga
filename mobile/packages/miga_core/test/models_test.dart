import 'package:flutter_test/flutter_test.dart';
import 'package:miga_core/miga_core.dart';

void main() {
  final now = DateTime.now();
  Campaign campaign({int current = 73, int target = 100}) => Campaign(
    id: 't',
    storeId: 's1',
    product: MockData.products.first,
    titleAr: 'test',
    originalPrice: 50,
    campaignPrice: 20,
    targetQuantity: target,
    currentQuantity: current,
    startDate: now,
    endDate: now.add(const Duration(days: 1)),
  );

  group('Campaign', () {
    test('progress, remaining and discount follow the spec example (73/100, 20 instead of 50)', () {
      final c = campaign();
      expect(c.progress, closeTo(.73, 1e-9));
      expect(c.remainingQuantity, 27);
      expect(c.discountPercent, 60);
      expect(c.savingPerUnit, 30);
    });

    test('progress is clamped when over-subscribed and safe for zero target', () {
      expect(campaign(current: 120).progress, 1);
      expect(campaign(current: 120).remainingQuantity, 0);
      expect(campaign(target: 0).progress, 0);
    });
  });

  test('CartItem total and order type', () {
    final p = MockData.products.first;
    expect(CartItem(id: 'a', product: p, quantity: 3, unitPrice: 10).total, 30);
    expect(CartItem(id: 'a', product: p, quantity: 1, unitPrice: 10).type, OrderType.product);
    expect(CartItem(id: 'a', product: p, quantity: 1, unitPrice: 10, campaign: campaign()).type, OrderType.campaign);
  });

  test('enum values match the .NET backend', () {
    expect(CampaignStatus.values.map((e) => e.value), [1, 2, 3, 4, 5, 6, 7]);
    expect(DeliveryStatus.delivered.value, 6);
    expect(MerchantOrderStatus.ready.value, 5);
  });

  test('mock data is consistent: every district chain and campaign store resolves', () {
    for (final r in MockData.regions) {
      expect(r.cities, isNotEmpty);
      for (final c in r.cities) {
        expect(c.districts, isNotEmpty);
      }
    }
    for (final c in MockData.campaigns) {
      expect(() => MockData.storeById(c.storeId), returnsNormally);
    }
  });
}
