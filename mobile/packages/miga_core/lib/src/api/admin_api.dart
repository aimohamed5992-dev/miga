// Admin dashboard side of the API: platform numbers, review queue, users, campaigns, orders, deliveries, payouts.

import '../enums/enums.dart';
import 'api_client.dart';
import 'api_models.dart';
import 'merchant_api.dart' show toMerchantOrderStatus;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);
StoreStatus _storeStatus(Object? v) =>
    StoreStatus.values.firstWhere((e) => e.value == (v as num).toInt(), orElse: () => StoreStatus.active);

class AdminCounts {
  const AdminCounts(this._j);
  final Json _j;
  int _i(String k) => (_j[k] as num?)?.toInt() ?? 0;

  int get customers => _i('customers');
  int get merchants => _i('merchants');
  int get merchantsPending => _i('merchantsPending');
  int get drivers => _i('drivers');
  int get driversPending => _i('driversPending');
  int get driversOnline => _i('driversOnline');
  int get suspendedUsers => _i('suspendedUsers');
  int get activeStores => _i('activeStores');
  int get activeCampaigns => _i('activeCampaigns');
  int get campaignsCompleted30d => _i('campaignsCompleted30d');
  int get ordersToday => _i('ordersToday');
  double get gmv30d => _d(_j['gmv30d']);
  double get commission30d => _d(_j['commission30d']);
  int get deliveriesInProgress => _i('deliveriesInProgress');
  int get failedDeliveries => _i('failedDeliveries');
  int get payoutsRequested => _i('payoutsRequested');
  double get payoutsRequestedAmount => _d(_j['payoutsRequestedAmount']);
  int get pendingReviews => merchantsPending + driversPending;
}

class AdminDashboard {
  const AdminDashboard({required this.counts, required this.days, required this.topStores});
  final AdminCounts counts;
  final List<(DateTime date, double gmv, int orders)> days;
  final List<(String storeName, double gmv, int orders)> topStores;

  factory AdminDashboard.fromJson(Json j) => AdminDashboard(
    counts: AdminCounts(j['counts'] as Json),
    days: (j['days'] as List).cast<Json>().map((d) => (_date(d['date']), _d(d['gmv']), d['orders'] as int)).toList(),
    topStores: (j['topStores'] as List).cast<Json>().map((s) => (s['storeName'] as String, _d(s['gmv']), s['orders'] as int)).toList(),
  );
}

/// One merchant or driver registration in the review queue.
class VerificationItem {
  const VerificationItem(this._j);
  final Json _j;

  String get userId => _j['userId'] as String;

  /// merchant · driver
  String get type => _j['type'] as String;
  bool get isMerchant => type == 'merchant';
  String get fullName => _j['fullName'] as String;
  String get phone => _j['phone'] as String;
  DateTime get submittedAt => _date(_j['submittedAt']);

  /// pending · rejected · verified
  String get status => _j['status'] as String;
  String? get rejectionReason => _j['rejectionReason'] as String?;
  DateTime? get reviewedAt => _dateOrNull(_j['reviewedAt']);
  String? get businessNameAr => _j['businessNameAr'] as String?;
  String? get commercialRegistrationNumber => _j['commercialRegistrationNumber'] as String?;
  String? get taxNumber => _j['taxNumber'] as String?;
  String? get storeName => _j['storeName'] as String?;
  String? get storeCategory => _j['storeCategory'] as String?;
  String? get nationalId => _j['nationalId'] as String?;
  String? get city => _j['city'] as String?;
  String? get vehicleType => _j['vehicleType'] as String?;
  String? get vehicleModel => _j['vehicleModel'] as String?;
  String? get plateNumber => _j['plateNumber'] as String?;
  String? get drivingLicenseNumber => _j['drivingLicenseNumber'] as String?;
}

class AdminUser {
  const AdminUser(this._j);
  final Json _j;

  String get id => _j['id'] as String;
  String get fullName => _j['fullName'] as String;
  String get phone => _j['phone'] as String;
  String? get email => _j['email'] as String?;
  UserType get userType => toUserType(_j['userType']);
  bool get isActive => _j['isActive'] as bool;
  DateTime get createdAt => _date(_j['createdAt']);

  /// verified · pending · rejected · not_submitted
  String get verification => _j['verification'] as String;
  String? get suspensionReason => _j['suspensionReason'] as String?;
  int get ordersCount => _j['ordersCount'] as int;
  double get totalSpent => _d(_j['totalSpent']);
  String? get businessName => _j['businessName'] as String?;
  int get storesCount => _j['storesCount'] as int;
  String? get city => _j['city'] as String?;
  String? get vehicleType => _j['vehicleType'] as String?;
  int get deliveriesCount => _j['deliveriesCount'] as int;
  bool get isAvailable => _j['isAvailable'] as bool;
  double? get rating => (_j['rating'] as num?)?.toDouble();
}

class AdminStoreRow {
  const AdminStoreRow(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get nameAr => _j['nameAr'] as String;
  StoreStatus get status => _storeStatus(_j['status']);
  bool get isVerified => _j['isVerified'] as bool;
  int get products => _j['products'] as int;
  int get campaigns => _j['campaigns'] as int;
}

class AdminActivity {
  const AdminActivity(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get number => _j['number'] as String;
  String get title => _j['title'] as String;
  double get amount => _d(_j['amount']);

  /// Backend enum name (e.g. Delivered, Completed, OutForDelivery).
  String get status => _j['status'] as String;
  DateTime get date => _date(_j['date']);
}

class AdminUserDetail {
  AdminUserDetail(this._j) : user = AdminUser(_j['user'] as Json);
  final Json _j;
  final AdminUser user;
  int get addresses => _j['addresses'] as int;
  String? get bankName => _j['bankName'] as String?;
  String? get iban => _j['iban'] as String?;
  String? get nationalId => _j['nationalId'] as String?;
  String? get drivingLicenseNumber => _j['drivingLicenseNumber'] as String?;
  String? get vehicleModel => _j['vehicleModel'] as String?;
  String? get plateNumber => _j['plateNumber'] as String?;
  String? get rejectionReason => _j['rejectionReason'] as String?;
  List<AdminStoreRow> get stores => (_j['stores'] as List).cast<Json>().map(AdminStoreRow.new).toList();
  List<AdminActivity> get recent => (_j['recent'] as List).cast<Json>().map(AdminActivity.new).toList();
}

class AdminCampaign {
  const AdminCampaign(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get titleAr => _j['titleAr'] as String;
  String get storeName => _j['storeName'] as String;
  String get merchantName => _j['merchantName'] as String;
  String get productName => _j['productName'] as String;
  String? get imageUrl => _j['imageUrl'] as String?;
  double get originalPrice => _d(_j['originalPrice']);
  double get campaignPrice => _d(_j['campaignPrice']);
  int get targetQuantity => _j['targetQuantity'] as int;
  int get currentQuantity => _j['currentQuantity'] as int;
  int get participants => _j['participants'] as int;
  CampaignStatus get status => toCampaignStatus(_j['status']);
  DateTime get startDate => _date(_j['startDate']);
  DateTime get endDate => _date(_j['endDate']);
  DateTime? get completedAt => _dateOrNull(_j['completedAt']);
  double get progress => targetQuantity == 0 ? 0 : (currentQuantity / targetQuantity).clamp(0, 1).toDouble();
}

class AdminOrder {
  const AdminOrder(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get number => _j['number'] as String;
  String get customerName => _j['customerName'] as String;
  String get customerPhone => _j['customerPhone'] as String;
  String get campaignTitle => _j['campaignTitle'] as String;
  String get storeName => _j['storeName'] as String;
  int get quantity => _j['quantity'] as int;
  double get totalAmount => _d(_j['totalAmount']);
  CampaignOrderStatus get status => toOrderStatus(_j['status']);
  PaymentStatus? get paymentStatus => _j['paymentStatus'] == null ? null : toPaymentStatus(_j['paymentStatus']);
  DeliveryStatus? get deliveryStatus => _j['deliveryStatus'] == null ? null : toDeliveryStatus(_j['deliveryStatus']);
  String? get cancellationReason => _j['cancellationReason'] as String?;
  DateTime get createdAt => _date(_j['createdAt']);
}

class AdminMerchantOrder {
  const AdminMerchantOrder(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get number => _j['number'] as String;
  String get storeName => _j['storeName'] as String;
  String get campaignTitle => _j['campaignTitle'] as String;
  int get totalQuantity => _j['totalQuantity'] as int;
  int get customersCount => _j['customersCount'] as int;
  double get totalAmount => _d(_j['totalAmount']);
  double get platformFee => _d(_j['platformFee']);
  MerchantOrderStatus get status => toMerchantOrderStatus(_j['status']);
  int get deliveries => _j['deliveries'] as int;
  int get delivered => _j['delivered'] as int;
  DateTime get createdAt => _date(_j['createdAt']);
  DateTime? get readyAt => _dateOrNull(_j['readyAt']);
  DateTime? get completedAt => _dateOrNull(_j['completedAt']);
}

class AdminDelivery {
  const AdminDelivery(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get number => _j['number'] as String;
  DeliveryStatus get status => toDeliveryStatus(_j['status']);
  String? get driverName => _j['driverName'] as String?;
  String? get driverPhone => _j['driverPhone'] as String?;
  String get customerName => _j['customerName'] as String;
  String get customerPhone => _j['customerPhone'] as String;
  String get storeName => _j['storeName'] as String;
  String get district => _j['district'] as String;
  String get city => _j['city'] as String;
  String get productName => _j['productName'] as String;
  int get quantity => _j['quantity'] as int;
  double get fee => _d(_j['fee']);
  double get orderAmount => _d(_j['orderAmount']);
  String? get failureReason => _j['failureReason'] as String?;
  String get orderNumber => _j['orderNumber'] as String;
  DateTime get createdAt => _date(_j['createdAt']);
  DateTime? get acceptedAt => _dateOrNull(_j['acceptedAt']);
  DateTime? get deliveredAt => _dateOrNull(_j['deliveredAt']);
}

enum PayoutStatus {
  requested(1, 'قيد التحويل'),
  paid(2, 'تم التحويل'),
  rejected(3, 'مرفوض');

  const PayoutStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

class AdminPayout {
  const AdminPayout(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get merchantUserId => _j['merchantUserId'] as String;
  String get merchantName => _j['merchantName'] as String;
  String? get businessName => _j['businessName'] as String?;
  String? get bankName => _j['bankName'] as String?;
  String get iban => _j['iban'] as String;
  double get amount => _d(_j['amount']);
  PayoutStatus get status => PayoutStatus.values.firstWhere((s) => s.value == _j['status'], orElse: () => PayoutStatus.requested);
  DateTime get createdAt => _date(_j['createdAt']);
  DateTime? get paidAt => _dateOrNull(_j['paidAt']);
  String? get transferReference => _j['transferReference'] as String?;
  String? get rejectionReason => _j['rejectionReason'] as String?;
}

class AdminBanner {
  const AdminBanner(this._j);
  final Json _j;
  String get id => _j['id'] as String;
  String get imageUrl => _j['imageUrl'] as String;
  String? get title => _j['titleAr'] as String?;
  String? get subtitle => _j['subtitleAr'] as String?;
  String? get buttonLabel => _j['buttonLabelAr'] as String?;

  /// none · campaign · product · store · storeCategory
  String get linkType => _j['linkType'] as String;
  String? get linkId => _j['linkId'] as String?;
  String? get linkTitle => _j['linkTitle'] as String?;
  int get sortOrder => _j['sortOrder'] as int;
  bool get isActive => _j['isActive'] as bool;
  DateTime? get startsAt => _dateOrNull(_j['startsAt']);
  DateTime? get endsAt => _dateOrNull(_j['endsAt']);
}

class AdminApi {
  AdminApi(this._c);
  final ApiClient _c;

  // ---- home banners ----

  Future<List<AdminBanner>> banners() async => ((await _c.get('/api/admin/banners')) as List).cast<Json>().map(AdminBanner.new).toList();

  Future<AdminBanner> saveBanner({
    String? id,
    required String imageUrl,
    String? title,
    String? subtitle,
    String? buttonLabel,
    required String linkType,
    String? linkId,
    required int sortOrder,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final body = {
      'imageUrl': imageUrl,
      'titleAr': title,
      'subtitleAr': subtitle,
      'buttonLabelAr': buttonLabel,
      'linkType': linkType,
      'linkId': linkType == 'none' ? null : linkId,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'startsAt': startsAt?.toUtc().toIso8601String(),
      'endsAt': endsAt?.toUtc().toIso8601String(),
    };
    return AdminBanner((id == null ? await _c.post('/api/admin/banners', body) : await _c.put('/api/admin/banners/$id', body)) as Json);
  }

  Future<void> deleteBanner(String id) => _c.delete('/api/admin/banners/$id');

  Future<AdminDashboard> dashboard() async => AdminDashboard.fromJson(await _c.get('/api/admin/dashboard') as Json);

  // ---- review queue ----

  /// [type]: merchant · driver · all — [status]: pending · rejected · verified
  Future<List<VerificationItem>> verifications({String type = 'all', String status = 'pending'}) async =>
      ((await _c.get('/api/admin/verifications', query: {'type': type, 'status': status})) as List)
          .cast<Json>()
          .map(VerificationItem.new)
          .toList();

  Future<void> verify(VerificationItem item) => _c.post('/api/admin/${item.isMerchant ? 'merchants' : 'drivers'}/${item.userId}/verify');

  Future<void> reject(VerificationItem item, String reason) =>
      _c.post('/api/admin/${item.isMerchant ? 'merchants' : 'drivers'}/${item.userId}/reject', {'reason': reason});

  // ---- users ----

  /// [type]: customer · merchant · driver — [status]: all · active · suspended · pending
  Future<PagedResult<AdminUser>> users({required String type, String? q, String status = 'all', int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _c.get('/api/admin/users', query: {'type': type, 'q': q, 'status': status, 'page': page, 'pageSize': pageSize}) as Json,
        AdminUser.new,
      );

  Future<AdminUserDetail> user(String id) async => AdminUserDetail(await _c.get('/api/admin/users/$id') as Json);

  Future<void> setActive(String id, bool active, {String? reason}) =>
      _c.patch('/api/admin/users/$id/active', {'active': active, 'reason': reason});

  // ---- campaigns & orders ----

  Future<PagedResult<AdminCampaign>> campaigns({String status = 'active', String? q, int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _c.get('/api/admin/campaigns', query: {'status': status, 'q': q, 'page': page, 'pageSize': pageSize}) as Json,
        AdminCampaign.new,
      );

  Future<void> cancelCampaign(String id, String reason) => _c.post('/api/admin/campaigns/$id/cancel', {'reason': reason});

  Future<PagedResult<AdminOrder>> orders({String status = 'active', String? q, int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _c.get('/api/admin/orders', query: {'status': status, 'q': q, 'page': page, 'pageSize': pageSize}) as Json,
        AdminOrder.new,
      );

  Future<PagedResult<AdminMerchantOrder>> merchantOrders({String status = 'open', String? q, int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _c.get('/api/admin/merchant-orders', query: {'status': status, 'q': q, 'page': page, 'pageSize': pageSize}) as Json,
        AdminMerchantOrder.new,
      );

  // ---- deliveries ----

  Future<PagedResult<AdminDelivery>> deliveries({String status = 'failed', String? q, int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        await _c.get('/api/admin/deliveries', query: {'status': status, 'q': q, 'page': page, 'pageSize': pageSize}) as Json,
        AdminDelivery.new,
      );

  Future<void> retryDelivery(String id, {String? note}) => _c.post('/api/admin/deliveries/$id/retry', {'note': note});

  Future<void> refundDelivery(String id, String reason) => _c.post('/api/admin/deliveries/$id/refund', {'reason': reason});

  // ---- payouts ----

  Future<PagedResult<AdminPayout>> payouts({String status = 'requested', int page = 1, int pageSize = 20}) async => PagedResult.fromJson(
    await _c.get('/api/admin/payouts', query: {'status': status, 'page': page, 'pageSize': pageSize}) as Json,
    AdminPayout.new,
  );

  Future<void> payoutPaid(String id, String reference) => _c.post('/api/admin/payouts/$id/paid', {'reference': reference});

  Future<void> rejectPayout(String id, String reason) => _c.post('/api/admin/payouts/$id/reject', {'reason': reason});
}
