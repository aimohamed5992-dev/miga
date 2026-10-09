// Lightweight UI models mirroring Miga.Domain entities.
// Image fields hold asset file names (see MigaImages) until the API serves URLs.

import '../enums/enums.dart';

class Region {
  const Region({required this.id, required this.nameAr, required this.cities});
  final String id;
  final String nameAr;
  final List<City> cities;
}

class City {
  const City({required this.id, required this.nameAr, required this.districts});
  final String id;
  final String nameAr;
  final List<District> districts;
}

class District {
  const District({required this.id, required this.nameAr});
  final String id;
  final String nameAr;
}

class Address {
  const Address({
    this.regionId,
    this.cityId,
    this.districtId,
    required this.id,
    required this.addressName,
    required this.regionName,
    required this.cityName,
    required this.districtName,
    required this.phoneNumber,
    this.details,
    this.isDefault = false,
  });
  final String id;
  final String? regionId;
  final String? cityId;
  final String? districtId;
  final String addressName;
  final String regionName;
  final String cityName;
  final String districtName;
  final String phoneNumber;
  final String? details;
  final bool isDefault;

  String get summary => '$districtName، $cityName، $regionName';
}

class StoreCategory {
  const StoreCategory({required this.id, required this.nameAr, required this.image});
  final String id;
  final String nameAr;
  final String image;
}

class Store {
  const Store({
    required this.id,
    required this.nameAr,
    required this.categoryId,
    required this.logo,
    required this.cover,
    this.descriptionAr,
    this.rating = 4.8,
    this.isVerified = true,
    this.status = StoreStatus.active,
    this.categoryName,
    this.activeCampaigns = 0,
    this.productsCount = 0,
    this.participants = 0,
    this.cityId,
    this.pickupAddress,
  });
  final String id;
  final String nameAr;
  final String categoryId;

  /// City the store ships from — drivers are matched to its orders by this city.
  final String? cityId;

  /// Where drivers collect orders (merchant's warehouse).
  final String? pickupAddress;
  final String? categoryName;
  final int activeCampaigns;
  final int productsCount;
  final int participants;
  final String logo;
  final String cover;
  final String? descriptionAr;
  final double rating;
  final bool isVerified;
  final StoreStatus status;
}

class ProductCategory {
  const ProductCategory({required this.id, required this.storeId, required this.nameAr, this.parentId});
  final String id;
  final String storeId;
  final String nameAr;
  final String? parentId;
}

class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.nameAr,
    required this.price,
    required this.images,
    this.descriptionAr,
    this.stockQuantity = 0,
    this.isActive = true,
    this.categoryName,
    this.storeName,
    this.activeCampaignId,
    this.inActiveCampaign = false,
  });
  final bool inActiveCampaign;
  final String id;
  final String storeId;
  final String categoryId;
  final String? categoryName;
  final String? storeName;
  final String? activeCampaignId;
  final String nameAr;
  final double price;
  final List<String> images;
  final String? descriptionAr;
  final int stockQuantity;
  final bool isActive;

  String get mainImage => images.isEmpty ? '' : images.first;
}

class Campaign {
  const Campaign({
    required this.id,
    required this.storeId,
    required this.product,
    required this.titleAr,
    required this.originalPrice,
    required this.campaignPrice,
    required this.targetQuantity,
    required this.currentQuantity,
    required this.startDate,
    required this.endDate,
    this.descriptionAr,
    this.maxPerCustomer,
    this.participantsCount = 0,
    this.status = CampaignStatus.active,
    this.storeName,
  });
  final String id;
  final String storeId;
  final String? storeName;
  final Product product;
  final String titleAr;
  final String? descriptionAr;
  final double originalPrice;
  final double campaignPrice;
  final int targetQuantity;
  final int currentQuantity;
  final int? maxPerCustomer;
  final int participantsCount;
  final DateTime startDate;
  final DateTime endDate;
  final CampaignStatus status;

  double get progress => targetQuantity == 0 ? 0 : (currentQuantity / targetQuantity).clamp(0, 1);
  int get remainingQuantity => (targetQuantity - currentQuantity).clamp(0, targetQuantity);
  int get discountPercent => originalPrice == 0 ? 0 : (((originalPrice - campaignPrice) / originalPrice) * 100).round();
  double get savingPerUnit => originalPrice - campaignPrice;
  Duration get timeLeft => endDate.difference(DateTime.now());
}

class CartItem {
  const CartItem({required this.id, required this.product, required this.quantity, required this.unitPrice, this.campaign});
  final String id;
  final Product product;
  final Campaign? campaign;
  final int quantity;
  final double unitPrice;

  double get total => unitPrice * quantity;
  OrderType get type => campaign == null ? OrderType.product : OrderType.campaign;
}

class CampaignOrder {
  const CampaignOrder({
    required this.id,
    required this.number,
    required this.campaign,
    required this.customerName,
    required this.address,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
  });
  final String id;
  final String number;
  final Campaign campaign;
  final String customerName;
  final Address address;
  final int quantity;
  final double unitPrice;
  final CampaignOrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;

  double get totalAmount => unitPrice * quantity;
}

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.number,
    required this.campaign,
    required this.totalQuantity,
    required this.customersCount,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String number;
  final Campaign campaign;
  final int totalQuantity;
  final int customersCount;
  final MerchantOrderStatus status;
  final DateTime createdAt;

  double get totalAmount => totalQuantity * campaign.campaignPrice;
}

class Delivery {
  const Delivery({
    required this.id,
    required this.number,
    required this.order,
    required this.storeName,
    required this.storeAddress,
    required this.status,
    required this.fee,
    required this.distanceKm,
  });
  final String id;
  final String number;
  final CampaignOrder order;
  final String storeName;
  final String storeAddress;
  final DeliveryStatus status;
  final double fee;
  final double distanceKm;
}

class AppNotification {
  const AppNotification({required this.title, required this.body, required this.time, this.isRead = false});
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
}
