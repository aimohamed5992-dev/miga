// Merchant side of the API: registration, stores, categories, products, campaigns,
// aggregated orders, dashboard and wallet.

import '../enums/enums.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'api_models.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);
StoreStatus _storeStatus(Object? v) =>
    StoreStatus.values.firstWhere((e) => e.value == (v as num).toInt(), orElse: () => StoreStatus.active);
MerchantOrderStatus toMerchantOrderStatus(Object? v) =>
    MerchantOrderStatus.values.firstWhere((e) => e.value == (v as num).toInt(), orElse: () => MerchantOrderStatus.pending);

/// Merchant's own store (any status). [activeCampaigns] holds the store's total campaign count.
Store merchantStoreFromJson(Json j) => Store(
  id: j['id'] as String,
  nameAr: j['nameAr'] as String,
  categoryId: j['storeCategoryId'] as String,
  categoryName: j['categoryName'] as String?,
  descriptionAr: j['descriptionAr'] as String?,
  logo: j['logoUrl'] as String? ?? '',
  cover: j['coverImageUrl'] as String? ?? '',
  status: _storeStatus(j['status']),
  isVerified: j['isVerified'] as bool? ?? false,
  rating: _d(j['rating']),
  productsCount: j['productsCount'] as int? ?? 0,
  activeCampaigns: j['campaignsCount'] as int? ?? 0,
  cityId: j['cityId'] as String?,
  pickupAddress: j['pickupAddress'] as String?,
);

Product merchantProductFromJson(Json j) => Product(
  id: j['id'] as String,
  storeId: j['storeId'] as String,
  categoryId: j['categoryId'] as String,
  categoryName: j['categoryName'] as String?,
  nameAr: j['nameAr'] as String,
  descriptionAr: j['descriptionAr'] as String?,
  price: _d(j['price']),
  stockQuantity: j['stockQuantity'] as int? ?? 0,
  isActive: j['isActive'] as bool? ?? true,
  images: (j['images'] as List).cast<String>(),
  inActiveCampaign: j['inActiveCampaign'] as bool? ?? false,
);

class MerchantCampaignView {
  const MerchantCampaignView(this.campaign, this.collectedAmount, this.merchantOrderId);
  final Campaign campaign;
  final double collectedAmount;
  final String? merchantOrderId;

  factory MerchantCampaignView.fromJson(Json j) => MerchantCampaignView(
    campaignFromJson({...j, 'participantsCount': j['participantsCount']}, descriptionAr: j['descriptionAr'] as String?),
    _d(j['collectedAmount']),
    j['merchantOrderId'] as String?,
  );
}

class Participant {
  const Participant(this.orderId, this.maskedName, this.district, this.quantity, this.amount, this.createdAt);
  final String orderId;
  final String maskedName;
  final String district;
  final int quantity;
  final double amount;
  final DateTime createdAt;

  factory Participant.fromJson(Json j) => Participant(
    j['orderId'] as String,
    j['maskedName'] as String,
    j['district'] as String,
    j['quantity'] as int,
    _d(j['amount']),
    _date(j['createdAt']),
  );
}

class MerchantOrderView {
  const MerchantOrderView({
    required this.id,
    required this.number,
    required this.status,
    required this.createdAt,
    required this.campaignId,
    required this.campaignTitle,
    required this.productName,
    this.imageUrl,
    required this.storeId,
    required this.storeName,
    required this.totalQuantity,
    required this.customersCount,
    required this.totalAmount,
  });
  final String id;
  final String number;
  final MerchantOrderStatus status;
  final DateTime createdAt;
  final String campaignId;
  final String campaignTitle;
  final String productName;
  final String? imageUrl;
  final String storeId;
  final String storeName;
  final int totalQuantity;
  final int customersCount;
  final double totalAmount;

  factory MerchantOrderView.fromJson(Json j) => MerchantOrderView(
    id: j['id'] as String,
    number: j['number'] as String,
    status: toMerchantOrderStatus(j['status']),
    createdAt: _date(j['createdAt']),
    campaignId: j['campaignId'] as String,
    campaignTitle: j['campaignTitle'] as String,
    productName: j['productName'] as String,
    imageUrl: j['imageUrl'] as String?,
    storeId: j['storeId'] as String,
    storeName: j['storeName'] as String,
    totalQuantity: j['totalQuantity'] as int,
    customersCount: j['customersCount'] as int,
    totalAmount: _d(j['totalAmount']),
  );
}

class DistrictBatch {
  const DistrictBatch(this.district, this.quantity, this.customers);
  final String district;
  final int quantity;
  final int customers;
}

class MerchantDeliveryLine {
  const MerchantDeliveryLine(this.id, this.number, this.status, this.district, this.quantity, this.driverName);
  final String id;
  final String number;
  final DeliveryStatus status;
  final String district;
  final int quantity;
  final String? driverName;
}

class MerchantOrderDetailView {
  const MerchantOrderDetailView({
    required this.order,
    required this.platformFee,
    required this.netAmount,
    required this.pickupCode,
    this.confirmedAt,
    this.readyAt,
    this.completedAt,
    required this.districts,
    required this.deliveries,
  });
  final MerchantOrderView order;
  final double platformFee;
  final double netAmount;
  final String pickupCode;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final List<DistrictBatch> districts;
  final List<MerchantDeliveryLine> deliveries;

  factory MerchantOrderDetailView.fromJson(Json j) => MerchantOrderDetailView(
    order: MerchantOrderView.fromJson(j['order'] as Json),
    platformFee: _d(j['platformFee']),
    netAmount: _d(j['netAmount']),
    pickupCode: j['pickupCode'] as String,
    confirmedAt: _dateOrNull(j['confirmedAt']),
    readyAt: _dateOrNull(j['readyAt']),
    completedAt: _dateOrNull(j['completedAt']),
    districts:
        (j['districts'] as List)
            .cast<Json>()
            .map((d) => DistrictBatch(d['district'] as String, d['quantity'] as int, d['customers'] as int))
            .toList(),
    deliveries:
        (j['deliveries'] as List)
            .cast<Json>()
            .map(
              (d) => MerchantDeliveryLine(
                d['id'] as String,
                d['number'] as String,
                toDeliveryStatus(d['status']),
                d['district'] as String,
                d['quantity'] as int,
                d['driverName'] as String?,
              ),
            )
            .toList(),
  );
}

class MerchantDashboard {
  const MerchantDashboard({
    required this.days,
    required this.weekTotal,
    required this.previousWeekTotal,
    required this.activeCampaigns,
    required this.ordersInProgress,
    required this.participants,
    required this.products,
    required this.ordersNeedingAction,
    required this.activeCampaignList,
  });
  final List<(DateTime, double)> days;
  final double weekTotal;
  final double previousWeekTotal;
  final int activeCampaigns;
  final int ordersInProgress;
  final int participants;
  final int products;
  final List<MerchantOrderView> ordersNeedingAction;
  final List<MerchantCampaignView> activeCampaignList;

  /// Week-over-week change in percent (null when there was nothing last week).
  int? get trendPercent => previousWeekTotal <= 0 ? null : (((weekTotal - previousWeekTotal) / previousWeekTotal) * 100).round();

  factory MerchantDashboard.fromJson(Json j) => MerchantDashboard(
    days: (j['lastSevenDays'] as List).cast<Json>().map((d) => (DateTime.parse(d['date'] as String), _d(d['amount']))).toList(),
    weekTotal: _d(j['weekTotal']),
    previousWeekTotal: _d(j['previousWeekTotal']),
    activeCampaigns: j['activeCampaigns'] as int,
    ordersInProgress: j['ordersInProgress'] as int,
    participants: j['participants'] as int,
    products: j['products'] as int,
    ordersNeedingAction: (j['ordersNeedingAction'] as List).cast<Json>().map(MerchantOrderView.fromJson).toList(),
    activeCampaignList: (j['activeCampaignList'] as List).cast<Json>().map(MerchantCampaignView.fromJson).toList(),
  );
}

class WalletTransaction {
  const WalletTransaction(this.type, this.title, this.subtitle, this.amount, this.date);

  /// income · fee · payout
  final String type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
}

class MerchantEarnings {
  const MerchantEarnings({
    required this.available,
    required this.pendingSettlement,
    required this.withdrawnThisMonth,
    this.bankName,
    this.ibanMasked,
    required this.monthly,
    required this.transactions,
  });
  final double available;
  final double pendingSettlement;
  final double withdrawnThisMonth;
  final String? bankName;
  final String? ibanMasked;
  final List<(int year, int month, double amount)> monthly;
  final List<WalletTransaction> transactions;

  factory MerchantEarnings.fromJson(Json j) => MerchantEarnings(
    available: _d(j['available']),
    pendingSettlement: _d(j['pendingSettlement']),
    withdrawnThisMonth: _d(j['withdrawnThisMonth']),
    bankName: j['bankName'] as String?,
    ibanMasked: j['ibanMasked'] as String?,
    monthly: (j['monthly'] as List).cast<Json>().map((m) => (m['year'] as int, m['month'] as int, _d(m['amount']))).toList(),
    transactions:
        (j['transactions'] as List)
            .cast<Json>()
            .map(
              (t) =>
                  WalletTransaction(t['type'] as String, t['title'] as String, t['subtitle'] as String, _d(t['amount']), _date(t['date'])),
            )
            .toList(),
  );
}

/// Registered business details (read-only in the app).
class MerchantBusiness {
  const MerchantBusiness(this._j);
  final Json _j;
  String get ownerName => _j['ownerName'] as String;
  String get phone => _j['phone'] as String;
  String? get businessNameAr => _j['businessNameAr'] as String?;
  String? get businessNameEn => _j['businessNameEn'] as String?;
  String? get commercialRegistrationNumber => _j['commercialRegistrationNumber'] as String?;
  String? get taxNumber => _j['taxNumber'] as String?;
  bool get isVerified => _j['isVerified'] as bool;
  DateTime? get verifiedAt => _dateOrNull(_j['verifiedAt']);
  DateTime get registeredAt => _date(_j['registeredAt']);
  String? get bankName => _j['bankName'] as String?;
  String? get iban => _j['iban'] as String?;
  int get storesCount => _j['storesCount'] as int;
}

class MerchantApi {
  MerchantApi(this._c);
  final ApiClient _c;

  // ---- registration ----

  Future<Account> register({
    required String ownerName,
    required String businessNameAr,
    String? businessNameEn,
    required String commercialRegistrationNumber,
    String? taxNumber,
    required String storeNameAr,
    required String storeCategoryId,
    String? storeDescriptionAr,
    String? storeCityId,
  }) async => Account.fromJson(
    await _c.post('/api/merchant/register', {
          'ownerName': ownerName,
          'businessNameAr': businessNameAr,
          'businessNameEn': businessNameEn,
          'commercialRegistrationNumber': commercialRegistrationNumber,
          'taxNumber': (taxNumber?.isEmpty ?? true) ? null : taxNumber,
          'storeNameAr': storeNameAr,
          'storeCategoryId': storeCategoryId,
          'storeDescriptionAr': storeDescriptionAr,
          'storeCityId': storeCityId,
        })
        as Json,
  );

  Future<String> upload(String folder, String filePath) => _c.uploadImage(folder, filePath);

  // ---- stores ----

  Future<List<Store>> stores() async => ((await _c.get('/api/merchant/stores')) as List).cast<Json>().map(merchantStoreFromJson).toList();

  Future<Store> saveStore({
    String? id,
    required String nameAr,
    String? nameEn,
    required String storeCategoryId,
    String? descriptionAr,
    String? logoUrl,
    String? coverImageUrl,
    String? pickupAddress,
    String? cityId,
  }) async {
    // The API replaces every field, so city and pickup address must always be sent (or they are cleared).
    final body = {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'storeCategoryId': storeCategoryId,
      'descriptionAr': descriptionAr,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'pickupAddress': (pickupAddress?.isEmpty ?? true) ? null : pickupAddress,
      'cityId': cityId,
    };
    return merchantStoreFromJson(
      (id == null ? await _c.post('/api/merchant/stores', body) : await _c.put('/api/merchant/stores/$id', body)) as Json,
    );
  }

  Future<Store> setStoreActive(String id, bool active) async =>
      merchantStoreFromJson(await _c.patch('/api/merchant/stores/$id/active', {'active': active}) as Json);

  // ---- categories ----

  Future<List<ProductCategoryNode>> categories(String storeId) async =>
      ((await _c.get('/api/merchant/stores/$storeId/categories')) as List).cast<Json>().map(ProductCategoryNode.fromJson).toList();

  Future<void> saveCategory(String storeId, {String? id, required String nameAr, String? nameEn, String? parentId}) async {
    final body = {'nameAr': nameAr, 'nameEn': nameEn, 'parentCategoryId': parentId};
    id == null
        ? await _c.post('/api/merchant/stores/$storeId/categories', body)
        : await _c.put('/api/merchant/stores/$storeId/categories/$id', body);
  }

  Future<void> deleteCategory(String storeId, String id) => _c.delete('/api/merchant/stores/$storeId/categories/$id');

  // ---- products ----

  Future<List<Product>> products(String storeId) async =>
      PagedResult.fromJson(
        await _c.get('/api/merchant/stores/$storeId/products', query: {'pageSize': 50}) as Json,
        merchantProductFromJson,
      ).items;

  Future<Product> saveProduct(
    String storeId, {
    String? id,
    required String categoryId,
    required String nameAr,
    String? nameEn,
    String? descriptionAr,
    required double price,
    required int stockQuantity,
    required bool isActive,
    required List<String> imageUrls,
  }) async {
    final body = {
      'productCategoryId': categoryId,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'descriptionAr': descriptionAr,
      'price': price,
      'stockQuantity': stockQuantity,
      'isActive': isActive,
      'imageUrls': imageUrls,
    };
    return merchantProductFromJson(
      (id == null
              ? await _c.post('/api/merchant/stores/$storeId/products', body)
              : await _c.put('/api/merchant/stores/$storeId/products/$id', body))
          as Json,
    );
  }

  Future<void> setProductActive(String storeId, String id, bool active) =>
      _c.patch('/api/merchant/stores/$storeId/products/$id/active', {'active': active});

  Future<void> deleteProduct(String storeId, String id) => _c.delete('/api/merchant/stores/$storeId/products/$id');

  // ---- campaigns ----

  /// [tab]: active · done · ended · draft
  Future<List<MerchantCampaignView>> campaigns({String tab = 'active', String? storeId}) async =>
      PagedResult.fromJson(
        await _c.get('/api/merchant/campaigns', query: {'tab': tab, 'storeId': storeId, 'pageSize': 50}) as Json,
        MerchantCampaignView.fromJson,
      ).items;

  Future<MerchantCampaignView> campaign(String id) async =>
      MerchantCampaignView.fromJson(await _c.get('/api/merchant/campaigns/$id') as Json);

  Future<List<Participant>> participants(String id) async =>
      PagedResult.fromJson(
        await _c.get('/api/merchant/campaigns/$id/participants', query: {'pageSize': 50}) as Json,
        Participant.fromJson,
      ).items;

  Future<MerchantCampaignView> createCampaign({
    required String storeId,
    required String productId,
    required String titleAr,
    String? descriptionAr,
    double? originalPrice,
    required double campaignPrice,
    required int targetQuantity,
    int? maxQuantityPerCustomer,
    DateTime? startDate,
    required int durationDays,
    required bool publish,
  }) async => MerchantCampaignView.fromJson(
    await _c.post('/api/merchant/campaigns', {
          'storeId': storeId,
          'productId': productId,
          'titleAr': titleAr,
          'descriptionAr': descriptionAr,
          'originalPrice': originalPrice,
          'campaignPrice': campaignPrice,
          'targetQuantity': targetQuantity,
          'maxQuantityPerCustomer': maxQuantityPerCustomer,
          'startDate': startDate?.toUtc().toIso8601String(),
          'durationDays': durationDays,
          'publish': publish,
        })
        as Json,
  );

  Future<MerchantCampaignView> publishCampaign(String id) async =>
      MerchantCampaignView.fromJson(await _c.post('/api/merchant/campaigns/$id/publish') as Json);

  /// Edit a draft or running campaign; only non-null fields are sent. [maxPerCustomer] 0 removes the limit.
  /// The server locks the price once customers joined and completes the campaign if the target drops to what is sold.
  Future<MerchantCampaignView> editCampaign(
    String id, {
    String? titleAr,
    String? descriptionAr,
    double? originalPrice,
    double? campaignPrice,
    int? targetQuantity,
    int? maxPerCustomer,
    DateTime? endsAt,
  }) async => MerchantCampaignView.fromJson(
    await _c.patch('/api/merchant/campaigns/$id', {
          if (titleAr != null) 'titleAr': titleAr,
          if (descriptionAr != null) 'descriptionAr': descriptionAr,
          if (originalPrice != null) 'originalPrice': originalPrice,
          if (campaignPrice != null) 'campaignPrice': campaignPrice,
          if (targetQuantity != null) 'targetQuantity': targetQuantity,
          if (maxPerCustomer != null) 'maxQuantityPerCustomer': maxPerCustomer,
          if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
        })
        as Json,
  );

  Future<MerchantCampaignView> extendCampaign(String id, int days) async =>
      MerchantCampaignView.fromJson(await _c.post('/api/merchant/campaigns/$id/extend', {'days': days}) as Json);

  Future<MerchantCampaignView> cancelCampaign(String id, String reason) async =>
      MerchantCampaignView.fromJson(await _c.post('/api/merchant/campaigns/$id/cancel', {'reason': reason}) as Json);

  // ---- aggregated orders ----

  /// [tab]: new · preparing · ready · done
  Future<List<MerchantOrderView>> orders(String tab) async =>
      PagedResult.fromJson(
        await _c.get('/api/merchant/orders', query: {'tab': tab, 'pageSize': 50}) as Json,
        MerchantOrderView.fromJson,
      ).items;

  Future<MerchantOrderDetailView> order(String id) async =>
      MerchantOrderDetailView.fromJson(await _c.get('/api/merchant/orders/$id') as Json);

  /// [action]: confirm · start-preparing · ready
  Future<MerchantOrderDetailView> advanceOrder(String id, String action) async =>
      MerchantOrderDetailView.fromJson(await _c.post('/api/merchant/orders/$id/$action') as Json);

  // ---- dashboard & wallet ----

  Future<MerchantDashboard> dashboard({String? storeId}) async =>
      MerchantDashboard.fromJson(await _c.get('/api/merchant/dashboard', query: {'storeId': storeId}) as Json);

  Future<MerchantBusiness> business() async => MerchantBusiness(await _c.get('/api/merchant/business') as Json);

  Future<MerchantEarnings> earnings() async => MerchantEarnings.fromJson(await _c.get('/api/merchant/earnings') as Json);

  Future<void> setBankAccount(String bankName, String iban) => _c.put('/api/merchant/bank-account', {'bankName': bankName, 'iban': iban});

  Future<MerchantEarnings> requestPayout(double amount) async =>
      MerchantEarnings.fromJson(await _c.post('/api/merchant/payouts', {'amount': amount}) as Json);
}
