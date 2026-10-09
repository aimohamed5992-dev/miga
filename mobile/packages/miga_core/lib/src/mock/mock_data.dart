// Sample data for the design gallery (DesignGalleryPage) and model tests. The apps read everything from the API.

import '../enums/enums.dart';
import '../models/models.dart';

class MockData {
  MockData._();

  static final DateTime _now = DateTime.now();

  // ---------------- Locations: Region → City → District ----------------
  static const regions = <Region>[
    Region(
      id: 'r1',
      nameAr: 'منطقة الرياض',
      cities: [
        City(
          id: 'c1',
          nameAr: 'الرياض',
          districts: [
            District(id: 'd1', nameAr: 'النرجس'),
            District(id: 'd2', nameAr: 'الياسمين'),
            District(id: 'd3', nameAr: 'الملقا'),
            District(id: 'd4', nameAr: 'العليا'),
            District(id: 'd5', nameAr: 'حطين'),
          ],
        ),
        City(id: 'c2', nameAr: 'الخرج', districts: [District(id: 'd6', nameAr: 'الخالدية'), District(id: 'd7', nameAr: 'السلام')]),
      ],
    ),
    Region(
      id: 'r2',
      nameAr: 'منطقة مكة المكرمة',
      cities: [
        City(
          id: 'c3',
          nameAr: 'جدة',
          districts: [District(id: 'd8', nameAr: 'الروضة'), District(id: 'd9', nameAr: 'الشاطئ'), District(id: 'd10', nameAr: 'السلامة')],
        ),
        City(id: 'c4', nameAr: 'مكة المكرمة', districts: [District(id: 'd11', nameAr: 'العزيزية'), District(id: 'd12', nameAr: 'الشوقية')]),
      ],
    ),
    Region(
      id: 'r3',
      nameAr: 'المنطقة الشرقية',
      cities: [
        City(
          id: 'c5',
          nameAr: 'الدمام',
          districts: [District(id: 'd13', nameAr: 'الفيصلية'), District(id: 'd14', nameAr: 'الشاطئ الغربي')],
        ),
        City(id: 'c6', nameAr: 'الخبر', districts: [District(id: 'd15', nameAr: 'العقربية'), District(id: 'd16', nameAr: 'الثقبة')]),
      ],
    ),
  ];

  static const addresses = <Address>[
    Address(
      id: 'a1',
      addressName: 'المنزل',
      regionName: 'منطقة الرياض',
      cityName: 'الرياض',
      districtName: 'النرجس',
      phoneNumber: '0551234567',
      details: 'شارع الأمير سعود، فيلا 12',
      isDefault: true,
    ),
    Address(
      id: 'a2',
      addressName: 'العمل',
      regionName: 'منطقة الرياض',
      cityName: 'الرياض',
      districtName: 'العليا',
      phoneNumber: '0559876543',
      details: 'برج المملكة، الدور 20',
    ),
  ];

  // ---------------- Store categories ----------------
  static const storeCategories = <StoreCategory>[
    StoreCategory(id: 'sc1', nameAr: 'إلكترونيات', image: 'cat_electronics.png'),
    StoreCategory(id: 'sc2', nameAr: 'بقالة', image: 'cat_grocery.png'),
    StoreCategory(id: 'sc3', nameAr: 'أزياء', image: 'cat_fashion.png'),
    StoreCategory(id: 'sc4', nameAr: 'عناية وجمال', image: 'cat_beauty.png'),
    StoreCategory(id: 'sc5', nameAr: 'مطاعم', image: 'cat_restaurants.png'),
    StoreCategory(id: 'sc6', nameAr: 'المنزل', image: 'cat_home.png'),
  ];

  // ---------------- Stores ----------------
  static const stores = <Store>[
    Store(
      id: 's1',
      nameAr: 'تقنية الجملة',
      categoryId: 'sc1',
      logo: 'store_logo_1.png',
      cover: 'store_cover_electronics.jpg',
      descriptionAr: 'أجهزة ذكية وإكسسوارات بأسعار الجملة',
      rating: 4.9,
    ),
    Store(
      id: 's2',
      nameAr: 'أسواق الخير',
      categoryId: 'sc2',
      logo: 'store_logo_2.png',
      cover: 'store_cover_grocery.jpg',
      descriptionAr: 'مواد غذائية ومنتجات منزلية بالجملة',
      rating: 4.7,
    ),
    Store(
      id: 's3',
      nameAr: 'دار الأناقة',
      categoryId: 'sc3',
      logo: 'store_logo_3.png',
      cover: 'store_cover_fashion.jpg',
      descriptionAr: 'أزياء وأحذية بأسعار مخفضة',
      rating: 4.6,
    ),
    Store(
      id: 's4',
      nameAr: 'عطور الشرق',
      categoryId: 'sc4',
      logo: 'store_logo_4.png',
      cover: 'store_cover_beauty.jpg',
      descriptionAr: 'عطور ومستحضرات تجميل أصلية',
      rating: 4.8,
    ),
  ];

  static Store storeById(String id) => stores.firstWhere((s) => s.id == id);

  // ---------------- Product categories (per store) ----------------
  static const productCategories = <ProductCategory>[
    ProductCategory(id: 'pc1', storeId: 's1', nameAr: 'جوالات'),
    ProductCategory(id: 'pc2', storeId: 's1', nameAr: 'إكسسوارات'),
    ProductCategory(id: 'pc3', storeId: 's1', nameAr: 'لابتوبات'),
    ProductCategory(id: 'pc4', storeId: 's4', nameAr: 'عطور'),
    ProductCategory(id: 'pc5', storeId: 's3', nameAr: 'أحذية'),
    ProductCategory(id: 'pc6', storeId: 's2', nameAr: 'أرز وحبوب'),
    ProductCategory(id: 'pc7', storeId: 's2', nameAr: 'قهوة وزيوت'),
    ProductCategory(id: 'pc8', storeId: 's4', nameAr: 'عناية بالبشرة'),
    ProductCategory(id: 'pc9', storeId: 's2', nameAr: 'أدوات مطبخ'),
  ];

  static String productCategoryName(String id) => productCategories.firstWhere((c) => c.id == id).nameAr;

  // ---------------- Products ----------------
  static const products = <Product>[
    Product(
      id: 'p1',
      storeId: 's1',
      categoryId: 'pc1',
      nameAr: 'هاتف ذكي برو 256 جيجا',
      price: 3899,
      images: ['p_phone.jpg'],
      stockQuantity: 300,
      descriptionAr: 'شاشة 6.7 بوصة، كاميرا ثلاثية 48 ميجابكسل، بطارية تدوم طوال اليوم، ضمان سنتين من الوكيل.',
    ),
    Product(
      id: 'p2',
      storeId: 's1',
      categoryId: 'pc2',
      nameAr: 'سماعات لاسلكية بعزل الضوضاء',
      price: 899,
      images: ['p_headphones.jpg'],
      stockQuantity: 500,
      descriptionAr: 'عزل ضوضاء نشط، تشغيل حتى 30 ساعة، شحن سريع.',
    ),
    Product(
      id: 'p3',
      storeId: 's1',
      categoryId: 'pc2',
      nameAr: 'ساعة ذكية رياضية',
      price: 749,
      images: ['p_watch.jpg'],
      stockQuantity: 400,
    ),
    Product(
      id: 'p4',
      storeId: 's1',
      categoryId: 'pc3',
      nameAr: 'لابتوب نحيف 14 بوصة',
      price: 4299,
      images: ['p_laptop.jpg'],
      stockQuantity: 120,
    ),
    Product(
      id: 'p5',
      storeId: 's4',
      categoryId: 'pc4',
      nameAr: 'عطر عود ملكي 100 مل',
      price: 450,
      images: ['p_perfume.jpg'],
      stockQuantity: 800,
      descriptionAr: 'عود فاخر بمزيج شرقي يدوم طويلاً.',
    ),
    Product(
      id: 'p6',
      storeId: 's3',
      categoryId: 'pc5',
      nameAr: 'حذاء رياضي للجري',
      price: 399,
      images: ['p_sneakers.jpg'],
      stockQuantity: 600,
    ),
    Product(
      id: 'p7',
      storeId: 's2',
      categoryId: 'pc6',
      nameAr: 'أرز بسمتي 10 كجم',
      price: 89,
      images: ['p_rice.jpg'],
      stockQuantity: 2000,
      descriptionAr: 'أرز بسمتي هندي فاخر حبة طويلة.',
    ),
    Product(
      id: 'p8',
      storeId: 's2',
      categoryId: 'pc6',
      nameAr: 'تمر سكري فاخر 3 كجم',
      price: 120,
      images: ['p_dates.jpg'],
      stockQuantity: 1500,
    ),
    Product(
      id: 'p9',
      storeId: 's2',
      categoryId: 'pc7',
      nameAr: 'قهوة عربية مختصة 1 كجم',
      price: 95,
      images: ['p_coffee.jpg'],
      stockQuantity: 1000,
    ),
    Product(
      id: 'p10',
      storeId: 's2',
      categoryId: 'pc7',
      nameAr: 'زيت زيتون بكر ممتاز 2 لتر',
      price: 75,
      images: ['p_oil.jpg'],
      stockQuantity: 900,
    ),
    Product(
      id: 'p11',
      storeId: 's4',
      categoryId: 'pc8',
      nameAr: 'مجموعة العناية بالبشرة',
      price: 280,
      images: ['p_skincare.jpg'],
      stockQuantity: 350,
    ),
    Product(
      id: 'p12',
      storeId: 's2',
      categoryId: 'pc9',
      nameAr: 'طقم أواني طبخ 10 قطع',
      price: 650,
      images: ['p_cookware.jpg'],
      stockQuantity: 200,
    ),
  ];

  static Product productById(String id) => products.firstWhere((p) => p.id == id);

  // ---------------- Campaigns ----------------
  static final campaigns = <Campaign>[
    Campaign(
      id: 'cm1',
      storeId: 's1',
      product: productById('p1'),
      titleAr: 'حملة الهاتف الذكي برو',
      originalPrice: 3899,
      campaignPrice: 2999,
      targetQuantity: 100,
      currentQuantity: 73,
      participantsCount: 61,
      maxPerCustomer: 3,
      startDate: _now.subtract(const Duration(days: 3)),
      endDate: _now.add(const Duration(days: 2, hours: 5)),
      descriptionAr: 'انضم الآن واحصل على الهاتف بسعر الجملة. عند اكتمال 100 قطعة يتم شحن الطلب للجميع.',
    ),
    Campaign(
      id: 'cm2',
      storeId: 's2',
      product: productById('p7'),
      titleAr: 'أرز بسمتي بسعر الجملة',
      originalPrice: 89,
      campaignPrice: 55,
      targetQuantity: 500,
      currentQuantity: 462,
      participantsCount: 188,
      maxPerCustomer: 10,
      startDate: _now.subtract(const Duration(days: 5)),
      endDate: _now.add(const Duration(hours: 9)),
    ),
    Campaign(
      id: 'cm3',
      storeId: 's4',
      product: productById('p5'),
      titleAr: 'عطر عود ملكي',
      originalPrice: 450,
      campaignPrice: 199,
      targetQuantity: 200,
      currentQuantity: 64,
      participantsCount: 52,
      maxPerCustomer: 2,
      startDate: _now.subtract(const Duration(days: 1)),
      endDate: _now.add(const Duration(days: 6)),
    ),
    Campaign(
      id: 'cm4',
      storeId: 's1',
      product: productById('p2'),
      titleAr: 'سماعات بعزل الضوضاء',
      originalPrice: 899,
      campaignPrice: 549,
      targetQuantity: 150,
      currentQuantity: 121,
      participantsCount: 97,
      startDate: _now.subtract(const Duration(days: 4)),
      endDate: _now.add(const Duration(days: 1, hours: 3)),
    ),
    Campaign(
      id: 'cm5',
      storeId: 's2',
      product: productById('p8'),
      titleAr: 'تمر سكري فاخر',
      originalPrice: 120,
      campaignPrice: 70,
      targetQuantity: 300,
      currentQuantity: 300,
      participantsCount: 140,
      startDate: _now.subtract(const Duration(days: 7)),
      endDate: _now.subtract(const Duration(days: 1)),
      status: CampaignStatus.completed,
    ),
    Campaign(
      id: 'cm6',
      storeId: 's3',
      product: productById('p6'),
      titleAr: 'حذاء الجري الرياضي',
      originalPrice: 399,
      campaignPrice: 219,
      targetQuantity: 120,
      currentQuantity: 35,
      participantsCount: 30,
      startDate: _now.subtract(const Duration(days: 2)),
      endDate: _now.add(const Duration(days: 9)),
    ),
    Campaign(
      id: 'cm7',
      storeId: 's2',
      product: productById('p9'),
      titleAr: 'قهوة عربية مختصة',
      originalPrice: 95,
      campaignPrice: 59,
      targetQuantity: 250,
      currentQuantity: 198,
      participantsCount: 120,
      startDate: _now.subtract(const Duration(days: 2)),
      endDate: _now.add(const Duration(days: 3)),
    ),
    Campaign(
      id: 'cm8',
      storeId: 's4',
      product: productById('p11'),
      titleAr: 'مجموعة العناية بالبشرة',
      originalPrice: 280,
      campaignPrice: 149,
      targetQuantity: 150,
      currentQuantity: 12,
      participantsCount: 10,
      startDate: _now.subtract(const Duration(days: 12)),
      endDate: _now.subtract(const Duration(hours: 4)),
      status: CampaignStatus.failed,
    ),
  ];

  static Campaign campaignById(String id) => campaigns.firstWhere((c) => c.id == id);
  static List<Campaign> get activeCampaigns => campaigns.where((c) => c.status == CampaignStatus.active).toList();
  static List<Campaign> get endingSoon => activeCampaigns.where((c) => c.timeLeft.inHours < 30).toList();
  static List<Campaign> get almostComplete => activeCampaigns.where((c) => c.progress >= .75).toList();

  static const banners = ['banner_1.jpg', 'banner_2.jpg', 'banner_3.jpg'];

  // ---------------- Orders ----------------
  static final customerOrders = <CampaignOrder>[
    CampaignOrder(
      id: 'o1',
      number: 'MG-10482',
      campaign: campaigns[0],
      customerName: 'محمد العتيبي',
      address: addresses[0],
      quantity: 1,
      unitPrice: 2999,
      status: CampaignOrderStatus.paid,
      paymentStatus: PaymentStatus.paid,
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
    CampaignOrder(
      id: 'o2',
      number: 'MG-10411',
      campaign: campaigns[4],
      customerName: 'محمد العتيبي',
      address: addresses[0],
      quantity: 2,
      unitPrice: 70,
      status: CampaignOrderStatus.outForDelivery,
      paymentStatus: PaymentStatus.paid,
      createdAt: _now.subtract(const Duration(days: 6)),
    ),
    CampaignOrder(
      id: 'o3',
      number: 'MG-10398',
      campaign: campaigns[1],
      customerName: 'محمد العتيبي',
      address: addresses[1],
      quantity: 4,
      unitPrice: 55,
      status: CampaignOrderStatus.delivered,
      paymentStatus: PaymentStatus.paid,
      createdAt: _now.subtract(const Duration(days: 12)),
    ),
    CampaignOrder(
      id: 'o4',
      number: 'MG-10350',
      campaign: campaigns[7],
      customerName: 'محمد العتيبي',
      address: addresses[0],
      quantity: 1,
      unitPrice: 149,
      status: CampaignOrderStatus.refunded,
      paymentStatus: PaymentStatus.refunded,
      createdAt: _now.subtract(const Duration(days: 13)),
    ),
  ];

  static final merchantOrders = <MerchantOrder>[
    MerchantOrder(
      id: 'mo1',
      number: 'MO-2201',
      campaign: campaigns[4],
      totalQuantity: 300,
      customersCount: 140,
      status: MerchantOrderStatus.preparing,
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
    MerchantOrder(
      id: 'mo2',
      number: 'MO-2188',
      campaign: campaigns[1],
      totalQuantity: 500,
      customersCount: 188,
      status: MerchantOrderStatus.ready,
      createdAt: _now.subtract(const Duration(days: 3)),
    ),
    MerchantOrder(
      id: 'mo3',
      number: 'MO-2150',
      campaign: campaigns[6],
      totalQuantity: 250,
      customersCount: 120,
      status: MerchantOrderStatus.completed,
      createdAt: _now.subtract(const Duration(days: 9)),
    ),
  ];

  static const _customerNames = ['سارة القحطاني', 'عبدالله الشهري', 'نورة الدوسري', 'فهد المطيري', 'ريم الغامدي', 'خالد الزهراني'];

  static final deliveries = List<Delivery>.generate(6, (i) {
    final order = CampaignOrder(
      id: 'do$i',
      number: 'MG-${10500 + i}',
      campaign: campaigns[i % 2 == 0 ? 4 : 1],
      customerName: _customerNames[i],
      address: Address(
        id: 'da$i',
        addressName: 'المنزل',
        regionName: 'منطقة الرياض',
        cityName: 'الرياض',
        districtName: regions[0].cities[0].districts[i % 5].nameAr,
        phoneNumber: '05500000${10 + i}',
        details: 'شارع ${i + 5}، مبنى ${i + 12}',
      ),
      quantity: i + 1,
      unitPrice: i % 2 == 0 ? 70 : 55,
      status: CampaignOrderStatus.readyForDelivery,
      paymentStatus: PaymentStatus.paid,
      createdAt: _now.subtract(Duration(hours: i * 3)),
    );
    return Delivery(
      id: 'dl$i',
      number: 'DL-${7300 + i}',
      order: order,
      storeName: i % 2 == 0 ? 'أسواق الخير' : 'أسواق الخير - فرع العليا',
      storeAddress: 'الرياض، حي السلي، مستودع 4',
      status:
          const [
            DeliveryStatus.assigned,
            DeliveryStatus.assigned,
            DeliveryStatus.pickedUp,
            DeliveryStatus.outForDelivery,
            DeliveryStatus.delivered,
            DeliveryStatus.delivered,
          ][i],
      fee: 15 + i * 2.5,
      distanceKm: 3.2 + i * 1.7,
    );
  });

  static final notifications = <AppNotification>[
    AppNotification(
      title: 'اكتملت الحملة 🎉',
      body: 'حملة "تمر سكري فاخر" اكتملت وجاري تجهيز طلبك.',
      time: _now.subtract(const Duration(minutes: 20)),
    ),
    AppNotification(title: 'طلبك في الطريق', body: 'المندوب في طريقه إليك، الطلب MG-10411.', time: _now.subtract(const Duration(hours: 2))),
    AppNotification(
      title: 'باقي 27 قطعة فقط!',
      body: 'حملة الهاتف الذكي برو قاربت على الاكتمال، شارك أصدقاءك.',
      time: _now.subtract(const Duration(hours: 6)),
      isRead: true,
    ),
    AppNotification(
      title: 'تم استرداد المبلغ',
      body: 'لم تكتمل حملة العناية بالبشرة وتم استرداد 149 ر.س.',
      time: _now.subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];
}
