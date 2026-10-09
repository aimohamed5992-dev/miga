// Mirrors Miga.Domain enums in the .NET backend (same numeric values).

enum UserType {
  customer(1, 'عميل'),
  merchant(2, 'تاجر'),
  driver(3, 'مندوب'),
  admin(4, 'مدير');

  const UserType(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum StoreStatus {
  active(1, 'نشط'),
  inactive(2, 'غير نشط'),
  suspended(3, 'موقوف');

  const StoreStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum CampaignStatus {
  draft(1, 'مسودة'),
  active(2, 'نشطة'),
  completed(3, 'مكتملة'),
  failed(4, 'لم تكتمل'),
  cancelled(5, 'ملغاة'),
  processing(6, 'قيد التجهيز'),
  closed(7, 'مغلقة');

  const CampaignStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum CampaignOrderStatus {
  pending(1, 'بانتظار الدفع'),
  paid(2, 'مدفوع'),
  confirmed(3, 'مؤكد'),
  preparing(4, 'قيد التجهيز'),
  readyForDelivery(5, 'جاهز للتوصيل'),
  outForDelivery(6, 'في الطريق'),
  delivered(7, 'تم التسليم'),
  cancelled(8, 'ملغي'),
  refunded(9, 'مسترد');

  const CampaignOrderStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum PaymentStatus {
  pending(1, 'معلق'),
  paid(2, 'مدفوع'),
  failed(3, 'فشل'),
  cancelled(4, 'ملغي'),
  refunded(5, 'مسترد'),
  partiallyRefunded(6, 'مسترد جزئيًا');

  const PaymentStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum MerchantOrderStatus {
  pending(1, 'جديد'),
  sentToMerchant(2, 'أُرسل للتاجر'),
  confirmed(3, 'مؤكد'),
  preparing(4, 'قيد التجهيز'),
  ready(5, 'جاهز للاستلام'),
  completed(6, 'مكتمل'),
  cancelled(7, 'ملغي');

  const MerchantOrderStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum DeliveryStatus {
  pending(1, 'بانتظار مندوب'),
  assigned(2, 'تم الإسناد'),
  driverAccepted(3, 'قبلها المندوب'),
  pickedUp(4, 'تم الاستلام'),
  outForDelivery(5, 'في الطريق'),
  delivered(6, 'تم التسليم'),
  failed(7, 'فشل التوصيل'),
  cancelled(8, 'ملغي');

  const DeliveryStatus(this.value, this.labelAr);
  final int value;
  final String labelAr;
}

enum OrderType {
  product(1, 'منتج'),
  campaign(2, 'حملة');

  const OrderType(this.value, this.labelAr);
  final int value;
  final String labelAr;
}
