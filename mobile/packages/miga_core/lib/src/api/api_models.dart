// JSON → app models for the MIGA API. Ids are GUID strings; enums travel as their backend int values.

import '../enums/enums.dart';
import '../models/models.dart';

typedef Json = Map<String, dynamic>;

T _enum<T extends Enum>(List<T> values, Object? v, int Function(T) valueOf) =>
    values.firstWhere((e) => valueOf(e) == (v as num).toInt(), orElse: () => values.first);

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

CampaignStatus toCampaignStatus(Object? v) => _enum(CampaignStatus.values, v, (e) => e.value);
CampaignOrderStatus toOrderStatus(Object? v) => _enum(CampaignOrderStatus.values, v, (e) => e.value);
PaymentStatus toPaymentStatus(Object? v) => _enum(PaymentStatus.values, v, (e) => e.value);
DeliveryStatus toDeliveryStatus(Object? v) => _enum(DeliveryStatus.values, v, (e) => e.value);
UserType toUserType(Object? v) => _enum(UserType.values, v, (e) => e.value);

class PagedResult<T> {
  const PagedResult(this.items, this.page, this.totalCount, this.hasMore);
  final List<T> items;
  final int page;
  final int totalCount;
  final bool hasMore;

  factory PagedResult.fromJson(Json j, T Function(Json) map) => PagedResult(
    (j['items'] as List).cast<Json>().map(map).toList(),
    j['page'] as int,
    j['totalCount'] as int,
    j['hasMore'] as bool? ?? false,
  );
}

class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.userType,
    required this.isProfileComplete,
    required this.verificationStatus,
    this.rejectionReason,
  });
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final UserType userType;
  final bool isProfileComplete;

  /// not_submitted · pending · verified · rejected
  final String verificationStatus;

  /// Admin's reason when [verificationStatus] is `rejected`.
  final String? rejectionReason;

  factory Account.fromJson(Json j) => Account(
    id: j['id'] as String,
    fullName: j['fullName'] as String? ?? '',
    phoneNumber: j['phoneNumber'] as String? ?? '',
    email: j['email'] as String?,
    userType: toUserType(j['userType']),
    isProfileComplete: j['isProfileComplete'] as bool? ?? false,
    verificationStatus: j['verificationStatus'] as String? ?? 'verified',
    rejectionReason: j['rejectionReason'] as String?,
  );
}

class OtpSent {
  const OtpSent(this.phone, this.resendAfterSeconds, this.devCode);
  final String phone;
  final int resendAfterSeconds;

  /// Development only — the API returns the code so you can test without SMS.
  final String? devCode;
}

StoreCategory storeCategoryFromJson(Json j) =>
    StoreCategory(id: j['id'] as String, nameAr: j['nameAr'] as String, image: j['imageUrl'] as String? ?? '');

Store storeFromJson(Json j) => Store(
  id: j['id'] as String,
  nameAr: j['nameAr'] as String,
  categoryId: j['categoryId'] as String? ?? '',
  categoryName: j['categoryName'] as String?,
  logo: j['logoUrl'] as String? ?? '',
  cover: j['coverImageUrl'] as String? ?? '',
  descriptionAr: j['descriptionAr'] as String?,
  rating: _d(j['rating']),
  isVerified: j['isVerified'] as bool? ?? false,
  activeCampaigns: j['activeCampaigns'] as int? ?? 0,
  productsCount: j['productsCount'] as int? ?? 0,
  participants: j['participants'] as int? ?? 0,
);

Product productSummaryFromJson(Json j) => Product(
  id: j['id'] as String,
  storeId: j['storeId'] as String,
  categoryId: j['categoryId'] as String? ?? '',
  nameAr: j['nameAr'] as String,
  price: _d(j['price']),
  stockQuantity: j['stockQuantity'] as int? ?? 0,
  images: [if (j['mainImageUrl'] != null) j['mainImageUrl'] as String],
  activeCampaignId: j['activeCampaignId'] as String?,
);

/// Campaign summary carries a light product (name + main image); price = original price.
Campaign campaignFromJson(Json j, {String? descriptionAr, String? productDescription, List<String>? images}) => Campaign(
  id: j['id'] as String,
  storeId: j['storeId'] as String,
  storeName: j['storeName'] as String?,
  product: Product(
    id: j['productId'] as String,
    storeId: j['storeId'] as String,
    categoryId: '',
    nameAr: j['productName'] as String,
    price: _d(j['originalPrice']),
    images: images ?? [if (j['imageUrl'] != null) j['imageUrl'] as String],
    descriptionAr: productDescription,
  ),
  titleAr: j['titleAr'] as String,
  descriptionAr: descriptionAr,
  originalPrice: _d(j['originalPrice']),
  campaignPrice: _d(j['campaignPrice']),
  targetQuantity: j['targetQuantity'] as int,
  currentQuantity: j['currentQuantity'] as int,
  participantsCount: j['participantsCount'] as int? ?? 0,
  maxPerCustomer: j['maxQuantityPerCustomer'] as int?,
  startDate: _date(j['startDate']),
  endDate: _date(j['endDate']),
  status: toCampaignStatus(j['status']),
);

class CampaignDetail {
  const CampaignDetail(this.campaign, this.store);
  final Campaign campaign;
  final Store store;

  factory CampaignDetail.fromJson(Json j) => CampaignDetail(
    campaignFromJson(
      j['campaign'] as Json,
      descriptionAr: j['descriptionAr'] as String?,
      productDescription: j['productDescriptionAr'] as String?,
      images: (j['images'] as List?)?.cast<String>(),
    ),
    storeFromJson(j['store'] as Json),
  );
}

class ProductDetail {
  const ProductDetail(this.product, this.activeCampaign);
  final Product product;
  final Campaign? activeCampaign;

  factory ProductDetail.fromJson(Json j) => ProductDetail(
    Product(
      id: j['id'] as String,
      storeId: j['storeId'] as String,
      storeName: j['storeName'] as String?,
      categoryId: j['categoryId'] as String,
      categoryName: j['categoryName'] as String?,
      nameAr: j['nameAr'] as String,
      descriptionAr: j['descriptionAr'] as String?,
      price: _d(j['price']),
      stockQuantity: j['stockQuantity'] as int? ?? 0,
      images: (j['images'] as List).cast<String>(),
    ),
    j['activeCampaign'] == null ? null : campaignFromJson(j['activeCampaign'] as Json),
  );
}

class ProductCategoryNode {
  const ProductCategoryNode(this.id, this.nameAr, this.children);
  final String id;
  final String nameAr;
  final List<ProductCategoryNode> children;

  factory ProductCategoryNode.fromJson(Json j) => ProductCategoryNode(
    j['id'] as String,
    j['nameAr'] as String,
    (j['children'] as List? ?? []).cast<Json>().map(ProductCategoryNode.fromJson).toList(),
  );
}

/// Home slide from the admin dashboard. [linkType]: none · campaign · product · store · storeCategory.
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.buttonLabel,
    required this.linkType,
    this.linkId,
  });
  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final String linkType;
  final String? linkId;

  factory HomeBanner.fromJson(Json j) => HomeBanner(
    id: j['id'] as String,
    imageUrl: j['imageUrl'] as String,
    title: j['titleAr'] as String?,
    subtitle: j['subtitleAr'] as String?,
    buttonLabel: j['buttonLabelAr'] as String?,
    linkType: j['linkType'] as String? ?? 'none',
    linkId: j['linkId'] as String?,
  );
}

/// Public app settings (support contacts are configured on the server per environment).
class AppConfig {
  const AppConfig({
    this.supportPhone,
    this.supportWhatsApp,
    this.supportEmail,
    required this.platformFeePercent,
    required this.deliveryFee,
  });
  final String? supportPhone;
  final String? supportWhatsApp;
  final String? supportEmail;
  final double platformFeePercent;
  final double deliveryFee;

  bool get hasSupportContact => supportPhone != null || supportWhatsApp != null || supportEmail != null;

  factory AppConfig.fromJson(Json j) {
    final s = (j['support'] as Json?) ?? const {};
    return AppConfig(
      supportPhone: s['phone'] as String?,
      supportWhatsApp: s['whatsApp'] as String?,
      supportEmail: s['email'] as String?,
      platformFeePercent: _d(j['platformFeePercent']),
      deliveryFee: _d(j['deliveryFee']),
    );
  }
}

class HomeData {
  const HomeData({
    this.banners = const [],
    required this.categories,
    required this.endingSoon,
    required this.almostComplete,
    required this.featuredStores,
    required this.latest,
  });
  final List<HomeBanner> banners;
  final List<StoreCategory> categories;
  final List<Campaign> endingSoon;
  final List<Campaign> almostComplete;
  final List<Store> featuredStores;
  final List<Campaign> latest;

  factory HomeData.fromJson(Json j) {
    List<Campaign> c(String k) => (j[k] as List).cast<Json>().map(campaignFromJson).toList();
    return HomeData(
      banners: ((j['banners'] as List?) ?? const []).cast<Json>().map(HomeBanner.fromJson).toList(),
      categories: (j['categories'] as List).cast<Json>().map(storeCategoryFromJson).toList(),
      endingSoon: c('endingSoon'),
      almostComplete: c('almostComplete'),
      featuredStores: (j['featuredStores'] as List).cast<Json>().map(storeFromJson).toList(),
      latest: c('latest'),
    );
  }
}

class SearchData {
  const SearchData(this.campaigns, this.products, this.stores);
  final List<Campaign> campaigns;
  final List<Product> products;
  final List<Store> stores;

  bool get isEmpty => campaigns.isEmpty && products.isEmpty && stores.isEmpty;

  factory SearchData.fromJson(Json j) => SearchData(
    (j['campaigns'] as List).cast<Json>().map(campaignFromJson).toList(),
    (j['products'] as List).cast<Json>().map(productSummaryFromJson).toList(),
    (j['stores'] as List).cast<Json>().map(storeFromJson).toList(),
  );
}

Region regionFromJson(Json j) => Region(
  id: j['id'] as String,
  nameAr: j['nameAr'] as String,
  cities:
      (j['cities'] as List)
          .cast<Json>()
          .map(
            (c) => City(
              id: c['id'] as String,
              nameAr: c['nameAr'] as String,
              districts:
                  (c['districts'] as List).cast<Json>().map((d) => District(id: d['id'] as String, nameAr: d['nameAr'] as String)).toList(),
            ),
          )
          .toList(),
);

Address addressFromJson(Json j) => Address(
  id: j['id'] as String,
  regionId: j['regionId'] as String?,
  cityId: j['cityId'] as String?,
  districtId: j['districtId'] as String?,
  addressName: j['addressName'] as String,
  regionName: j['regionName'] as String,
  cityName: j['cityName'] as String,
  districtName: j['districtName'] as String,
  phoneNumber: _localPhone(j['phoneNumber'] as String),
  details: j['addressDetails'] as String?,
  isDefault: j['isDefault'] as bool? ?? false,
);

/// +966551234567 → 0551234567 (how Saudi numbers are shown in the app).
String _localPhone(String e164) => e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;

// ---------------- cart ----------------

class CartLine {
  const CartLine({
    required this.id,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.campaignId,
    this.campaignTitle,
    this.campaignCurrent,
    this.campaignTarget,
    this.maxPerCustomer,
    required this.quantity,
    required this.unitPrice,
    this.originalPrice,
    required this.lineTotal,
    this.issue,
  });
  final String id;
  final String productId;
  final String productName;
  final String? imageUrl;
  final String? campaignId;
  final String? campaignTitle;
  final int? campaignCurrent;
  final int? campaignTarget;
  final int? maxPerCustomer;
  final int quantity;
  final double unitPrice;
  final double? originalPrice;
  final double lineTotal;

  /// campaign_ended · unavailable · price_changed
  final String? issue;

  bool get isCampaign => campaignId != null;

  factory CartLine.fromJson(Json j) => CartLine(
    id: j['id'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    imageUrl: j['imageUrl'] as String?,
    campaignId: j['campaignId'] as String?,
    campaignTitle: j['campaignTitle'] as String?,
    campaignCurrent: j['campaignCurrentQuantity'] as int?,
    campaignTarget: j['campaignTargetQuantity'] as int?,
    maxPerCustomer: j['maxQuantityPerCustomer'] as int?,
    quantity: j['quantity'] as int,
    unitPrice: _d(j['unitPrice']),
    originalPrice: j['originalPrice'] == null ? null : _d(j['originalPrice']),
    lineTotal: _d(j['lineTotal']),
    issue: j['issue'] as String?,
  );
}

class CartStoreGroup {
  const CartStoreGroup(this.storeId, this.storeName, this.storeLogo, this.lines, this.subtotal);
  final String storeId;
  final String storeName;
  final String? storeLogo;
  final List<CartLine> lines;
  final double subtotal;

  factory CartStoreGroup.fromJson(Json j) => CartStoreGroup(
    j['storeId'] as String,
    j['storeName'] as String,
    j['storeLogoUrl'] as String?,
    (j['items'] as List).cast<Json>().map(CartLine.fromJson).toList(),
    _d(j['subtotal']),
  );
}

class CartView {
  const CartView(this.stores, this.itemsCount, this.total, this.savings);
  final List<CartStoreGroup> stores;
  final int itemsCount;
  final double total;
  final double savings;

  static const empty = CartView([], 0, 0, 0);
  bool get isEmpty => stores.isEmpty;
  Iterable<CartLine> get lines => stores.expand((s) => s.lines);

  factory CartView.fromJson(Json j) => CartView(
    (j['stores'] as List).cast<Json>().map(CartStoreGroup.fromJson).toList(),
    j['itemsCount'] as int,
    _d(j['total']),
    _d(j['savings']),
  );
}

class CheckoutLineResult {
  const CheckoutLineResult(this.success, this.orderId, this.orderNumber, this.amount, this.campaignCompleted, this.code, this.message);
  final bool success;
  final String? orderId;
  final String? orderNumber;
  final double amount;
  final bool campaignCompleted;
  final String? code;
  final String? message;
}

class CheckoutOutcome {
  const CheckoutOutcome(this.lines, this.totalCharged, this.succeeded, this.failed);
  final List<CheckoutLineResult> lines;
  final double totalCharged;
  final int succeeded;
  final int failed;

  factory CheckoutOutcome.fromJson(Json j) => CheckoutOutcome(
    (j['items'] as List)
        .cast<Json>()
        .map(
          (i) => CheckoutLineResult(
            i['success'] as bool,
            i['orderId'] as String?,
            i['orderNumber'] as String?,
            _d(i['amount']),
            i['campaignCompleted'] as bool? ?? false,
            i['code'] as String?,
            i['message'] as String?,
          ),
        )
        .toList(),
    _d(j['totalCharged']),
    j['succeededCount'] as int,
    j['failedCount'] as int,
  );
}

// ---------------- orders ----------------

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.createdAt,
    required this.quantity,
    required this.totalAmount,
    required this.campaignId,
    required this.campaignTitle,
    required this.campaignStatus,
    required this.campaignCurrent,
    required this.campaignTarget,
    required this.campaignEndDate,
    required this.productName,
    this.imageUrl,
    required this.storeName,
  });
  final String id;
  final String number;
  final CampaignOrderStatus status;
  final DateTime createdAt;
  final int quantity;
  final double totalAmount;
  final String campaignId;
  final String campaignTitle;
  final CampaignStatus campaignStatus;
  final int campaignCurrent;
  final int campaignTarget;
  final DateTime campaignEndDate;
  final String productName;
  final String? imageUrl;
  final String storeName;

  int get remaining => (campaignTarget - campaignCurrent).clamp(0, campaignTarget);

  factory OrderSummary.fromJson(Json j) => OrderSummary(
    id: j['id'] as String,
    number: j['number'] as String,
    status: toOrderStatus(j['status']),
    createdAt: _date(j['createdAt']),
    quantity: j['quantity'] as int,
    totalAmount: _d(j['totalAmount']),
    campaignId: j['campaignId'] as String,
    campaignTitle: j['campaignTitle'] as String,
    campaignStatus: toCampaignStatus(j['campaignStatus']),
    campaignCurrent: j['campaignCurrentQuantity'] as int,
    campaignTarget: j['campaignTargetQuantity'] as int,
    campaignEndDate: _date(j['campaignEndDate']),
    productName: j['productName'] as String,
    imageUrl: j['imageUrl'] as String?,
    storeName: j['storeName'] as String,
  );
}

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.unitPrice,
    required this.originalPrice,
    required this.addressName,
    required this.addressSummary,
    required this.addressPhone,
    this.paymentMethod,
    this.paymentStatus,
    this.paidAt,
    this.refundedAt,
    this.deliveryStatus,
    this.driverName,
    this.driverPhone,
    this.deliveryCode,
    this.confirmedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.canCancel,
  });
  final OrderSummary order;
  final double unitPrice;
  final double originalPrice;
  final String addressName;
  final String addressSummary;
  final String addressPhone;
  final String? paymentMethod;
  final PaymentStatus? paymentStatus;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final DeliveryStatus? deliveryStatus;
  final String? driverName;
  final String? driverPhone;
  final String? deliveryCode;
  final DateTime? confirmedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool canCancel;

  double get savings => (originalPrice - unitPrice) * order.quantity;

  factory OrderDetail.fromJson(Json j) {
    final payment = j['payment'] as Json?;
    final delivery = j['delivery'] as Json?;
    return OrderDetail(
      order: OrderSummary.fromJson(j['order'] as Json),
      unitPrice: _d(j['unitPrice']),
      originalPrice: _d(j['originalPrice']),
      addressName: j['addressName'] as String,
      addressSummary: j['addressSummary'] as String,
      addressPhone: _localPhone(j['addressPhone'] as String),
      paymentMethod: payment?['method'] as String?,
      paymentStatus: payment == null ? null : toPaymentStatus(payment['status']),
      paidAt: _dateOrNull(payment?['paidAt']),
      refundedAt: _dateOrNull(payment?['refundedAt']),
      deliveryStatus: delivery == null ? null : toDeliveryStatus(delivery['status']),
      driverName: delivery?['driverName'] as String?,
      driverPhone: delivery?['driverPhone'] as String?,
      deliveryCode: delivery?['deliveryCode'] as String?,
      confirmedAt: _dateOrNull(j['confirmedAt']),
      deliveredAt: _dateOrNull(j['deliveredAt']),
      cancelledAt: _dateOrNull(j['cancelledAt']),
      cancellationReason: j['cancellationReason'] as String?,
      canCancel: j['canCancel'] as bool? ?? false,
    );
  }
}

AppNotification notificationFromJson(Json j) => AppNotification(
  title: j['title'] as String,
  body: j['body'] as String,
  time: _date(j['createdAt']),
  isRead: j['isRead'] as bool? ?? false,
);
