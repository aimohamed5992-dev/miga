import '../enums/enums.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'api_models.dart';
import 'admin_api.dart';
import 'driver_api.dart';
import 'merchant_api.dart';

/// Typed access to the MIGA API, shared by the three apps. Each app uses the sections for its role.
class MigaApi {
  MigaApi(this.client);
  final ApiClient client;

  late final auth = AuthApi(client);
  late final catalog = CatalogApi(client);
  late final customer = CustomerApi(client);
  late final merchant = MerchantApi(client);
  late final driver = DriverApi(client);
  late final notifications = NotificationsApi(client);
  late final admin = AdminApi(client);
}

/// In-app notifications — same endpoint for customers, merchants and drivers.
class NotificationsApi {
  NotificationsApi(this._c);
  final ApiClient _c;

  Future<List<AppNotification>> list() async =>
      ((await _c.get('/api/notifications')) as List).cast<Json>().map(notificationFromJson).toList();

  Future<int> unreadCount() async => (await list()).where((n) => !n.isRead).length;

  Future<void> markAllRead() => _c.post('/api/notifications/read-all');
}

class AuthApi {
  AuthApi(this._c);
  final ApiClient _c;

  Future<OtpSent> sendOtp(String phone) async {
    final j = await _c.post('/api/auth/send-otp', {'phone': phone}) as Json;
    return OtpSent(j['phone'] as String, j['resendAfterSeconds'] as int, j['devCode'] as String?);
  }

  /// Signs in (creating the account on first use) and stores the tokens.
  Future<Account> verifyOtp(String phone, String code, UserType type) async {
    final j = await _c.post('/api/auth/verify-otp', {'phone': phone, 'code': code, 'userType': type.value}) as Json;
    await _c.saveTokens(j['accessToken'] as String, j['refreshToken'] as String);
    return Account.fromJson(j['account'] as Json);
  }

  Future<Account> me() async => Account.fromJson(await _c.get('/api/auth/me') as Json);

  Future<void> logout() async {
    final refresh = await _c.tokens.read(ApiClient.refreshKey);
    try {
      if (refresh != null) await _c.post('/api/auth/logout', {'refreshToken': refresh});
    } finally {
      await _c.clearTokens();
    }
  }

  Future<Account> completeCustomerProfile(String fullName, {String? email}) async => Account.fromJson(
    await _c.put('/api/customer/profile', {'fullName': fullName, 'email': (email?.isEmpty ?? true) ? null : email}) as Json,
  );
}

/// Public browsing (no sign-in needed).
class CatalogApi {
  CatalogApi(this._c);
  final ApiClient _c;

  Future<AppConfig> config() async => AppConfig.fromJson(await _c.get('/api/config') as Json);

  Future<HomeData> home() async => HomeData.fromJson(await _c.get('/api/home') as Json);

  Future<List<StoreCategory>> storeCategories() async =>
      ((await _c.get('/api/store-categories')) as List).cast<Json>().map(storeCategoryFromJson).toList();

  Future<List<Region>> regions() async => ((await _c.get('/api/regions')) as List).cast<Json>().map(regionFromJson).toList();

  /// [sort]: newest · endingSoon · almostComplete · biggestDiscount
  Future<PagedResult<Campaign>> campaigns({
    String sort = 'newest',
    String? storeCategoryId,
    String? storeId,
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async => PagedResult.fromJson(
    await _c.get(
          '/api/campaigns',
          query: {'sort': sort, 'storeCategoryId': storeCategoryId, 'storeId': storeId, 'q': q, 'page': page, 'pageSize': pageSize},
        )
        as Json,
    campaignFromJson,
  );

  Future<CampaignDetail> campaign(String id) async => CampaignDetail.fromJson(await _c.get('/api/campaigns/$id') as Json);

  Future<PagedResult<Store>> stores({String? categoryId, String? q, int page = 1}) async =>
      PagedResult.fromJson(await _c.get('/api/stores', query: {'categoryId': categoryId, 'q': q, 'page': page}) as Json, storeFromJson);

  Future<Store> store(String id) async => storeFromJson(await _c.get('/api/stores/$id') as Json);

  Future<List<ProductCategoryNode>> storeProductCategories(String storeId) async =>
      ((await _c.get('/api/stores/$storeId/categories')) as List).cast<Json>().map(ProductCategoryNode.fromJson).toList();

  Future<PagedResult<Product>> storeProducts(String storeId, {String? categoryId, int page = 1}) async => PagedResult.fromJson(
    await _c.get('/api/stores/$storeId/products', query: {'categoryId': categoryId, 'page': page, 'pageSize': 50}) as Json,
    productSummaryFromJson,
  );

  Future<ProductDetail> product(String id) async => ProductDetail.fromJson(await _c.get('/api/products/$id') as Json);

  Future<SearchData> search(String q) async => SearchData.fromJson(await _c.get('/api/search', query: {'q': q}) as Json);
}

/// Signed-in customer: addresses, cart, checkout, orders (notifications: [NotificationsApi]).
class CustomerApi {
  CustomerApi(this._c);
  final ApiClient _c;

  Future<List<Campaign>> favorites() async =>
      ((await _c.get('/api/customer/favorites')) as List).cast<Json>().map(campaignFromJson).toList();

  Future<void> addFavorite(String campaignId) => _c.put('/api/customer/favorites/$campaignId');

  Future<void> removeFavorite(String campaignId) => _c.delete('/api/customer/favorites/$campaignId');

  Future<List<Address>> addresses() async => ((await _c.get('/api/customer/addresses')) as List).cast<Json>().map(addressFromJson).toList();

  Future<Address> saveAddress({
    String? id,
    required String addressName,
    required String regionId,
    required String cityId,
    required String districtId,
    required String phoneNumber,
    String? details,
    bool isDefault = false,
  }) async {
    final body = {
      'addressName': addressName,
      'regionId': regionId,
      'cityId': cityId,
      'districtId': districtId,
      'phoneNumber': phoneNumber,
      'addressDetails': details,
      'isDefault': isDefault,
    };
    final j = id == null ? await _c.post('/api/customer/addresses', body) : await _c.put('/api/customer/addresses/$id', body);
    return addressFromJson(j as Json);
  }

  Future<void> makeDefaultAddress(String id) => _c.post('/api/customer/addresses/$id/default');
  Future<void> deleteAddress(String id) => _c.delete('/api/customer/addresses/$id');

  Future<CartView> cart() async => CartView.fromJson(await _c.get('/api/customer/cart') as Json);

  Future<CartView> addToCart(String productId, {String? campaignId, int quantity = 1}) async => CartView.fromJson(
    await _c.post('/api/customer/cart/items', {'productId': productId, 'campaignId': campaignId, 'quantity': quantity}) as Json,
  );

  Future<CartView> setCartQuantity(String lineId, int quantity) async =>
      CartView.fromJson(await _c.patch('/api/customer/cart/items/$lineId', {'quantity': quantity}) as Json);

  Future<CartView> removeCartLine(String lineId) async => CartView.fromJson(await _c.delete('/api/customer/cart/items/$lineId') as Json);

  Future<void> clearCart() => _c.delete('/api/customer/cart');

  /// [paymentMethod]: mada · applepay · card · stcpay
  Future<CheckoutOutcome> checkout(String addressId, String paymentMethod) async =>
      CheckoutOutcome.fromJson(await _c.post('/api/customer/checkout', {'addressId': addressId, 'paymentMethod': paymentMethod}) as Json);

  Future<PagedResult<OrderSummary>> orders({bool past = false, int page = 1}) async => PagedResult.fromJson(
    await _c.get('/api/customer/orders', query: {'scope': past ? 'past' : 'current', 'page': page}) as Json,
    OrderSummary.fromJson,
  );

  Future<OrderDetail> order(String id) async => OrderDetail.fromJson(await _c.get('/api/customer/orders/$id') as Json);

  Future<OrderDetail> cancelOrder(String id, String reason) async =>
      OrderDetail.fromJson(await _c.post('/api/customer/orders/$id/cancel', {'reason': reason}) as Json);
}
