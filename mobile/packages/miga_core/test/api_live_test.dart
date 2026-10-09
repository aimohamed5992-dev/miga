// Contract test against a running API (dotnet run --project backend/src/Miga.Api). Skipped when the server is down.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miga_core/miga_core.dart';

void main() {
  const base = 'http://localhost:5296';
  late bool up;

  setUpAll(() async {
    try {
      final r = await HttpClient().getUrl(Uri.parse('$base/api/health')).then((q) => q.close());
      up = r.statusCode == 200;
    } catch (_) {
      up = false;
    }
  });

  MigaApi api() => MigaApi(ApiClient(tokens: MemoryTokenStore(), baseUrl: base));

  test('catalog JSON maps onto the app models', () async {
    if (!up) return markTestSkipped('API not running');
    final a = api();
    final home = await a.catalog.home();
    expect(home.categories, hasLength(6));
    expect(home.latest, isNotEmpty);
    final phone = home.latest.firstWhere((c) => c.titleAr == 'حملة الهاتف الذكي برو');
    expect(phone.discountPercent, 23);
    expect(phone.product.mainImage, 'p_phone.jpg');
    expect(phone.storeName, 'تقنية الجملة');

    final detail = await a.catalog.campaign(phone.id);
    expect(detail.store.nameAr, 'تقنية الجملة');
    expect(detail.campaign.descriptionAr, isNotNull);

    final product = await a.catalog.product(phone.product.id);
    expect(product.activeCampaign?.campaignPrice, lessThanOrEqualTo(2999));

    final regions = await a.catalog.regions();
    expect(regions.first.cities.first.districts, isNotEmpty);
    // Demo campaigns expire over time, so search for a word from one that is live right now.
    final term = home.latest.first.titleAr.split(' ').firstWhere((w) => w.length > 2);
    expect((await a.catalog.search(term)).campaigns, isNotEmpty);
    expect(home.banners, isNotEmpty);
  });

  test('customer: OTP sign-in, address, cart round-trip', () async {
    if (!up) return markTestSkipped('API not running');
    final a = api();
    final phone = '05${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
    final sent = await a.auth.sendOtp(phone);
    expect(sent.devCode, isNotNull);
    final account = await a.auth.verifyOtp(phone, sent.devCode!, UserType.customer);
    expect(account.userType, UserType.customer);

    final me = await a.auth.completeCustomerProfile('عميل الاختبار');
    expect(me.isProfileComplete, isTrue);

    final r = (await a.catalog.regions()).first;
    final c = r.cities.firstWhere((x) => x.nameAr == 'الرياض');
    final address = await a.customer.saveAddress(
      addressName: 'المنزل',
      regionId: r.id,
      cityId: c.id,
      districtId: c.districts.first.id,
      phoneNumber: '0551234567',
    );
    expect(address.isDefault, isTrue);
    expect(address.phoneNumber, '0551234567');

    final camp = (await a.catalog.campaigns(sort: 'biggestDiscount')).items.first;
    final cart = await a.customer.addToCart(camp.product.id, campaignId: camp.id, quantity: 1);
    expect(cart.itemsCount, 1);
    expect(cart.lines.first.isCampaign, isTrue);
    await a.customer.clearCart();

    await expectLater(
      a.auth.verifyOtp(phone, '0000', UserType.customer),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_expired')),
    );
  });

  test('merchant: stores, catalog, campaigns, orders, dashboard, wallet', () async {
    if (!up) return markTestSkipped('API not running');
    final a = api();
    final sent = await a.auth.sendOtp('0511111111');
    await a.auth.verifyOtp(sent.phone, sent.devCode!, UserType.merchant);

    final stores = await a.merchant.stores();
    expect(stores.length, greaterThanOrEqualTo(4));
    final grocery = stores.firstWhere((s) => s.nameAr == 'أسواق الخير');
    expect(grocery.isVerified, isTrue);
    expect(grocery.categoryName, 'بقالة');

    final cats = await a.merchant.categories(grocery.id);
    expect(cats.map((c) => c.nameAr), contains('أرز وحبوب'));
    final products = await a.merchant.products(grocery.id);
    expect(products.any((p) => p.inActiveCampaign), isTrue);

    final campaigns = await a.merchant.campaigns();
    expect(campaigns, isNotEmpty);
    final detail = await a.merchant.campaign(campaigns.first.campaign.id);
    expect(detail.campaign.titleAr, campaigns.first.campaign.titleAr);
    await a.merchant.participants(detail.campaign.id);

    final dash = await a.merchant.dashboard(storeId: grocery.id);
    expect(dash.days, hasLength(7));
    final earnings = await a.merchant.earnings();
    expect(earnings.monthly, hasLength(6));
    await a.merchant.orders('new');
  });

  test('driver: demo driver home, requests, deliveries, earnings', () async {
    if (!up) return markTestSkipped('API not running');
    final a = api();
    final sent = await a.auth.sendOtp('0522222222');
    final account = await a.auth.verifyOtp(sent.phone, sent.devCode!, UserType.driver);
    expect(account.verificationStatus, 'verified');

    final home = await a.driver.home();
    expect(home.isVerified, isTrue);
    expect(home.cityName, 'الرياض');
    expect(home.plateNumber, isNotEmpty);
    await a.driver.requests();
    await a.driver.deliveries();
    final history = await a.driver.deliveries(history: true);
    final week = await a.driver.earnings();
    expect(week.buckets, hasLength(7));
    expect(week.lifetimeEarnings, greaterThanOrEqualTo(week.total));
    if (history.isNotEmpty) expect(history.first.status.value, greaterThanOrEqualTo(DeliveryStatus.delivered.value));
    await expectLater(
      a.driver.pickUp('00000000-0000-0000-0000-000000000000', '1234'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
}
