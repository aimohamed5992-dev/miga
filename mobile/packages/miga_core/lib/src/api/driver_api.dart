// Driver side of the API: registration, availability, delivery requests, the delivery flow and earnings.

import '../enums/enums.dart';
import 'api_client.dart';
import 'api_models.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();
DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// A ready delivery in the driver's city that nobody has claimed yet.
class DeliveryRequest {
  const DeliveryRequest({
    required this.id,
    required this.number,
    required this.fee,
    this.distanceKm,
    required this.storeName,
    this.pickupAddress,
    required this.district,
    required this.city,
    required this.productName,
    this.imageUrl,
    required this.quantity,
    required this.readySince,
  });
  final String id;
  final String number;
  final double fee;
  final double? distanceKm;
  final String storeName;
  final String? pickupAddress;
  final String district;
  final String city;
  final String productName;
  final String? imageUrl;
  final int quantity;
  final DateTime readySince;

  factory DeliveryRequest.fromJson(Json j) => DeliveryRequest(
    id: j['id'] as String,
    number: j['number'] as String,
    fee: _d(j['fee']),
    distanceKm: _dn(j['distanceKm']),
    storeName: j['storeName'] as String,
    pickupAddress: j['pickupAddress'] as String?,
    district: j['district'] as String,
    city: j['city'] as String,
    productName: j['productName'] as String,
    imageUrl: j['imageUrl'] as String?,
    quantity: j['quantity'] as int,
    readySince: _dateOrNull(j['readySince'])!,
  );
}

/// One customer delivery claimed by this driver. Accepted → PickedUp (merchant's code) → OutForDelivery
/// → Delivered (customer's code) or Failed.
class DriverDelivery {
  const DriverDelivery({
    required this.id,
    required this.number,
    required this.status,
    required this.fee,
    this.distanceKm,
    required this.storeName,
    this.pickupAddress,
    this.storePhone,
    required this.customerName,
    required this.customerPhone,
    required this.addressName,
    required this.district,
    required this.city,
    required this.region,
    this.addressDetails,
    this.latitude,
    this.longitude,
    required this.productName,
    this.imageUrl,
    required this.quantity,
    this.acceptedAt,
    this.pickedUpAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.failureReason,
  });
  final String id;
  final String number;
  final DeliveryStatus status;
  final double fee;
  final double? distanceKm;
  final String storeName;
  final String? pickupAddress;
  final String? storePhone;
  final String customerName;
  final String customerPhone;
  final String addressName;
  final String district;
  final String city;
  final String region;
  final String? addressDetails;
  final double? latitude;
  final double? longitude;
  final String productName;
  final String? imageUrl;
  final int quantity;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final String? failureReason;

  bool get isActive => const [DeliveryStatus.driverAccepted, DeliveryStatus.pickedUp, DeliveryStatus.outForDelivery].contains(status);
  String get fullAddress => [district, city, if (addressDetails?.isNotEmpty ?? false) addressDetails].join('، ');

  factory DriverDelivery.fromJson(Json j) => DriverDelivery(
    id: j['id'] as String,
    number: j['number'] as String,
    status: toDeliveryStatus(j['status']),
    fee: _d(j['fee']),
    distanceKm: _dn(j['distanceKm']),
    storeName: j['storeName'] as String,
    pickupAddress: j['pickupAddress'] as String?,
    storePhone: j['storePhone'] as String?,
    customerName: j['customerName'] as String? ?? '',
    customerPhone: j['customerPhone'] as String? ?? '',
    addressName: j['addressName'] as String? ?? '',
    district: j['district'] as String? ?? '',
    city: j['city'] as String? ?? '',
    region: j['region'] as String? ?? '',
    addressDetails: j['addressDetails'] as String?,
    latitude: _dn(j['latitude']),
    longitude: _dn(j['longitude']),
    productName: j['productName'] as String,
    imageUrl: j['imageUrl'] as String?,
    quantity: j['quantity'] as int,
    acceptedAt: _dateOrNull(j['acceptedAt']),
    pickedUpAt: _dateOrNull(j['pickedUpAt']),
    outForDeliveryAt: _dateOrNull(j['outForDeliveryAt']),
    deliveredAt: _dateOrNull(j['deliveredAt']),
    failureReason: j['failureReason'] as String?,
  );
}

class DriverHome {
  const DriverHome({
    required this.isVerified,
    required this.isAvailable,
    required this.todayEarnings,
    required this.todayDeliveries,
    required this.todayDistanceKm,
    required this.requestsCount,
    this.activeDelivery,
    required this.rating,
    this.cityName,
    this.vehicleType,
    this.vehicleModel,
    this.plateNumber,
  });
  final bool isVerified;
  final bool isAvailable;
  final double todayEarnings;
  final int todayDeliveries;
  final double todayDistanceKm;
  final int requestsCount;
  final DriverDelivery? activeDelivery;
  final double rating;
  final String? cityName;

  /// car · van · truck · bike
  final String? vehicleType;
  final String? vehicleModel;
  final String? plateNumber;

  factory DriverHome.fromJson(Json j) => DriverHome(
    isVerified: j['isVerified'] as bool,
    isAvailable: j['isAvailable'] as bool,
    todayEarnings: _d(j['todayEarnings']),
    todayDeliveries: j['todayDeliveries'] as int,
    todayDistanceKm: _d(j['todayDistanceKm']),
    requestsCount: j['requestsCount'] as int,
    activeDelivery: j['activeDelivery'] == null ? null : DriverDelivery.fromJson(j['activeDelivery'] as Json),
    rating: _d(j['rating']),
    cityName: j['cityName'] as String?,
    vehicleType: (j['vehicle'] as Json?)?['type'] as String?,
    vehicleModel: (j['vehicle'] as Json?)?['model'] as String?,
    plateNumber: (j['vehicle'] as Json?)?['plateNumber'] as String?,
  );
}

class DriverEarnings {
  const DriverEarnings({
    required this.total,
    required this.deliveries,
    required this.distanceKm,
    required this.rating,
    required this.lifetimeEarnings,
    required this.buckets,
    required this.recent,
  });
  final double total;
  final int deliveries;
  final double distanceKm;
  final double rating;
  final double lifetimeEarnings;
  final List<(String label, double amount)> buckets;
  final List<DriverDelivery> recent;

  factory DriverEarnings.fromJson(Json j) => DriverEarnings(
    total: _d(j['total']),
    deliveries: j['deliveries'] as int,
    distanceKm: _d(j['distanceKm']),
    rating: _d(j['rating']),
    lifetimeEarnings: _d(j['lifetimeEarnings']),
    buckets: (j['buckets'] as List).cast<Json>().map((b) => (b['label'] as String, _d(b['amount']))).toList(),
    recent: (j['recent'] as List).cast<Json>().map(DriverDelivery.fromJson).toList(),
  );
}

class DriverApi {
  DriverApi(this._c);
  final ApiClient _c;

  Future<Account> register({
    required String fullName,
    required String nationalId,
    required String cityId,
    required String vehicleType,
    required String vehiclePlateNumber,
    String? vehicleModel,
    String? drivingLicenseNumber,
  }) async => Account.fromJson(
    await _c.post('/api/driver/register', {
          'fullName': fullName,
          'nationalId': nationalId,
          'cityId': cityId,
          'vehicleType': vehicleType,
          'vehiclePlateNumber': vehiclePlateNumber,
          'vehicleModel': (vehicleModel?.isEmpty ?? true) ? null : vehicleModel,
          'drivingLicenseNumber': (drivingLicenseNumber?.isEmpty ?? true) ? null : drivingLicenseNumber,
        })
        as Json,
  );

  Future<DriverHome> home() async => DriverHome.fromJson(await _c.get('/api/driver/home') as Json);

  /// Work city (refused while deliveries are in progress) and vehicle details; returns the refreshed home.
  Future<DriverHome> updateProfile({String? cityId, String? vehicleType, String? vehicleModel, String? plateNumber}) async =>
      DriverHome.fromJson(
        await _c.patch('/api/driver/profile', {
              'cityId': cityId,
              'vehicleType': vehicleType,
              'vehicleModel': vehicleModel,
              'plateNumber': plateNumber,
            })
            as Json,
      );

  Future<void> setAvailability(bool available) => _c.patch('/api/driver/availability', {'available': available});

  /// Current position while online — shown to MIGA operations on the admin live map.
  Future<void> reportLocation(double latitude, double longitude) =>
      _c.post('/api/driver/location', {'latitude': latitude, 'longitude': longitude});

  Future<List<DeliveryRequest>> requests() async =>
      ((await _c.get('/api/driver/requests')) as List).cast<Json>().map(DeliveryRequest.fromJson).toList();

  /// [history] = delivered / failed; otherwise the driver's in-progress deliveries.
  Future<List<DriverDelivery>> deliveries({bool history = false}) async =>
      ((await _c.get('/api/driver/deliveries', query: {'scope': history ? 'history' : 'active'})) as List)
          .cast<Json>()
          .map(DriverDelivery.fromJson)
          .toList();

  Future<DriverDelivery> delivery(String id) async => DriverDelivery.fromJson(await _c.get('/api/driver/deliveries/$id') as Json);

  Future<DriverDelivery> accept(String id) async => DriverDelivery.fromJson(await _c.post('/api/driver/deliveries/$id/accept') as Json);

  Future<void> release(String id) => _c.post('/api/driver/deliveries/$id/release');

  /// [code] is the merchant's pickup code, shown on the merchant's order screen.
  Future<DriverDelivery> pickUp(String id, String code) async =>
      DriverDelivery.fromJson(await _c.post('/api/driver/deliveries/$id/pickup', {'pickupCode': code}) as Json);

  Future<DriverDelivery> start(String id) async => DriverDelivery.fromJson(await _c.post('/api/driver/deliveries/$id/start') as Json);

  /// [code] is the customer's delivery code from their order screen.
  Future<DriverDelivery> deliver(String id, String code, {String? proofImageUrl}) async => DriverDelivery.fromJson(
    await _c.post('/api/driver/deliveries/$id/deliver', {'deliveryCode': code, 'proofImageUrl': proofImageUrl}) as Json,
  );

  Future<DriverDelivery> fail(String id, String reason) async =>
      DriverDelivery.fromJson(await _c.post('/api/driver/deliveries/$id/fail', {'reason': reason}) as Json);

  /// [month] = this month by week; otherwise the last 7 days.
  Future<DriverEarnings> earnings({bool month = false}) async =>
      DriverEarnings.fromJson(await _c.get('/api/driver/earnings', query: {'period': month ? 'month' : 'week'}) as Json);
}
