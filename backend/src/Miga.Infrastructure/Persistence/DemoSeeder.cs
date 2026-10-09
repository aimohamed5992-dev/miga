using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Miga.Domain;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence;

/// <summary>
/// Development-only demo catalog mirroring the Flutter sample data (miga_core/mock_data.dart, used by the design gallery):
/// one verified merchant, 4 stores, product categories, 12 products and 8 campaigns, plus one verified driver in Riyadh,
/// and a Jeddah test trio (merchant + driver + customer in the same city) for end-to-end runs.
/// Image URLs are the asset file names the apps already bundle.
/// </summary>
public static class DemoSeeder
{
    public const string MerchantPhone = "+966511111111";
    public const string DriverPhone = "+966522222222";
    public const string JeddahMerchantPhone = "+966531111111";
    public const string JeddahDriverPhone = "+966532222222";
    public const string JeddahCustomerPhone = "+966533333333";

    public static async Task SeedAsync(IServiceProvider services, CancellationToken ct = default)
    {
        var db = services.GetRequiredService<MigaDbContext>();
        await SeedDriverAsync(services, db, ct);
        await SeedJeddahTrioAsync(services, db, ct);
        await SeedCatalogAsync(services, db, ct);
        // After the catalog so the starter slides can link to its campaign, category and store.
        await SeedBannersAsync(db, ct);
    }

    private static async Task SeedCatalogAsync(IServiceProvider services, MigaDbContext db, CancellationToken ct)
    {
        if (await db.Stores.AnyAsync(s => s.Merchant.User.PhoneNumber == MerchantPhone, ct)) return;

        var users = services.GetRequiredService<UserManager<ApplicationUser>>();
        var log = services.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(DemoSeeder));
        var now = DateTime.UtcNow;

        var merchantUser = await users.Users.FirstOrDefaultAsync(u => u.PhoneNumber == MerchantPhone, ct);
        if (merchantUser == null)
        {
            merchantUser = new ApplicationUser { UserName = MerchantPhone, PhoneNumber = MerchantPhone, PhoneNumberConfirmed = true, FullName = "سعود الحربي", UserType = UserType.Merchant };
            await users.CreateAsync(merchantUser);
            await users.AddToRoleAsync(merchantUser, nameof(UserType.Merchant));
        }
        var merchant = new MerchantProfile
        {
            UserId = merchantUser.Id, BusinessNameAr = "مؤسسة الخير للتجارة", BusinessNameEn = "Al Khair Trading",
            CommercialRegistrationNumber = "1010456789", IsVerified = true,
        };
        db.MerchantProfiles.Add(merchant);

        var categories = await db.StoreCategories.ToDictionaryAsync(c => c.NameEn, ct);
        var riyadh = await db.Cities.FirstAsync(c => c.NameEn == "Riyadh", ct);

        Store NewStore(string ar, string en, string category, string logo, string cover, string desc, decimal rating) => new()
        {
            MerchantId = merchant.Id, NameAr = ar, NameEn = en, StoreCategoryId = categories[category].Id, LogoUrl = logo, CoverImageUrl = cover,
            DescriptionAr = desc, Rating = rating, IsVerified = true, Status = StoreStatus.Active, CityId = riyadh.Id, PickupAddress = "الرياض، حي السلي، مستودع 4",
        };
        var tech = NewStore("تقنية الجملة", "Tech Wholesale", "Electronics", "store_logo_1.png", "store_cover_electronics.jpg", "أجهزة ذكية وإكسسوارات بأسعار الجملة", 4.9m);
        var grocery = NewStore("أسواق الخير", "Al Khair Markets", "Grocery", "store_logo_2.png", "store_cover_grocery.jpg", "مواد غذائية ومنتجات منزلية بالجملة", 4.7m);
        var fashion = NewStore("دار الأناقة", "Elegance House", "Fashion", "store_logo_3.png", "store_cover_fashion.jpg", "أزياء وأحذية بأسعار مخفضة", 4.6m);
        var beauty = NewStore("عطور الشرق", "Orient Perfumes", "Beauty", "store_logo_4.png", "store_cover_beauty.jpg", "عطور ومستحضرات تجميل أصلية", 4.8m);
        db.Stores.AddRange(tech, grocery, fashion, beauty);

        ProductCategory Cat(Store s, string ar, string en, int order) { var c = new ProductCategory { StoreId = s.Id, NameAr = ar, NameEn = en, SortOrder = order }; db.ProductCategories.Add(c); return c; }
        var phones = Cat(tech, "جوالات", "Phones", 0);
        var accessories = Cat(tech, "إكسسوارات", "Accessories", 1);
        var laptops = Cat(tech, "لابتوبات", "Laptops", 2);
        var rice = Cat(grocery, "أرز وحبوب", "Rice & Grains", 0);
        var coffee = Cat(grocery, "قهوة وزيوت", "Coffee & Oils", 1);
        var kitchen = Cat(grocery, "أدوات مطبخ", "Kitchenware", 2);
        var shoes = Cat(fashion, "أحذية", "Shoes", 0);
        var perfumes = Cat(beauty, "عطور", "Perfumes", 0);
        var skincare = Cat(beauty, "عناية بالبشرة", "Skincare", 1);

        Product P(Store s, ProductCategory c, string ar, string en, decimal price, int stock, string image, string? desc = null)
        {
            var p = new Product { StoreId = s.Id, ProductCategoryId = c.Id, NameAr = ar, NameEn = en, Price = price, StockQuantity = stock, DescriptionAr = desc };
            p.Images.Add(new ProductImage { ImageUrl = image, IsMain = true });
            db.Products.Add(p);
            return p;
        }
        var phone = P(tech, phones, "هاتف ذكي برو 256 جيجا", "Smartphone Pro 256GB", 3899, 300, "p_phone.jpg", "شاشة 6.7 بوصة، كاميرا ثلاثية 48 ميجابكسل، بطارية تدوم طوال اليوم، ضمان سنتين من الوكيل.");
        var headphones = P(tech, accessories, "سماعات لاسلكية بعزل الضوضاء", "Noise-cancelling Headphones", 899, 500, "p_headphones.jpg", "عزل ضوضاء نشط، تشغيل حتى 30 ساعة، شحن سريع.");
        P(tech, accessories, "ساعة ذكية رياضية", "Sport Smartwatch", 749, 400, "p_watch.jpg");
        P(tech, laptops, "لابتوب نحيف 14 بوصة", "Slim Laptop 14\"", 4299, 120, "p_laptop.jpg");
        var perfume = P(beauty, perfumes, "عطر عود ملكي 100 مل", "Royal Oud 100ml", 450, 800, "p_perfume.jpg", "عود فاخر بمزيج شرقي يدوم طويلاً.");
        var sneakers = P(fashion, shoes, "حذاء رياضي للجري", "Running Sneakers", 399, 600, "p_sneakers.jpg");
        var basmati = P(grocery, rice, "أرز بسمتي 10 كجم", "Basmati Rice 10kg", 89, 2000, "p_rice.jpg", "أرز بسمتي هندي فاخر حبة طويلة.");
        var dates = P(grocery, rice, "تمر سكري فاخر 3 كجم", "Sukkari Dates 3kg", 120, 1500, "p_dates.jpg");
        var arabicCoffee = P(grocery, coffee, "قهوة عربية مختصة 1 كجم", "Specialty Arabic Coffee 1kg", 95, 1000, "p_coffee.jpg");
        P(grocery, coffee, "زيت زيتون بكر ممتاز 2 لتر", "Extra Virgin Olive Oil 2L", 75, 900, "p_oil.jpg");
        var skincareSet = P(beauty, skincare, "مجموعة العناية بالبشرة", "Skincare Set", 280, 350, "p_skincare.jpg");
        P(grocery, kitchen, "طقم أواني طبخ 10 قطع", "Cookware Set 10pc", 650, 200, "p_cookware.jpg");

        void C(Store s, Product p, string title, decimal price, int target, int current, int? maxPer, TimeSpan started, TimeSpan endsIn, CampaignStatus status = CampaignStatus.Active, string? desc = null) =>
            db.Campaigns.Add(new Campaign
            {
                StoreId = s.Id, ProductId = p.Id, MerchantUserId = merchantUser.Id, TitleAr = title, TitleEn = p.NameEn, DescriptionAr = desc,
                OriginalPrice = p.Price, CampaignPrice = price, TargetQuantity = target, CurrentQuantity = current, MaxQuantityPerCustomer = maxPer,
                StartDate = now - started, EndDate = now + endsIn, Status = status,
                CompletedAt = status == CampaignStatus.Completed ? now - TimeSpan.FromDays(1) : null,
            });
        C(tech, phone, "حملة الهاتف الذكي برو", 2999, 100, 73, 3, TimeSpan.FromDays(3), new TimeSpan(2, 5, 0, 0), desc: "انضم الآن واحصل على الهاتف بسعر الجملة. عند اكتمال 100 قطعة يتم شحن الطلب للجميع.");
        C(grocery, basmati, "أرز بسمتي بسعر الجملة", 55, 500, 462, 10, TimeSpan.FromDays(5), TimeSpan.FromHours(9));
        C(beauty, perfume, "عطر عود ملكي", 199, 200, 64, 2, TimeSpan.FromDays(1), TimeSpan.FromDays(6));
        C(tech, headphones, "سماعات بعزل الضوضاء", 549, 150, 121, null, TimeSpan.FromDays(4), new TimeSpan(1, 3, 0, 0));
        C(grocery, dates, "تمر سكري فاخر", 70, 300, 300, null, TimeSpan.FromDays(7), -TimeSpan.FromDays(1), CampaignStatus.Completed);
        C(fashion, sneakers, "حذاء الجري الرياضي", 219, 120, 35, null, TimeSpan.FromDays(2), TimeSpan.FromDays(9));
        C(grocery, arabicCoffee, "قهوة عربية مختصة", 59, 250, 198, null, TimeSpan.FromDays(2), TimeSpan.FromDays(3));
        C(beauty, skincareSet, "مجموعة العناية بالبشرة", 149, 150, 12, null, TimeSpan.FromDays(12), -TimeSpan.FromHours(4), CampaignStatus.Failed);

        await db.SaveChangesAsync(ct);
        log.LogInformation("Seeded demo catalog (merchant {Phone})", MerchantPhone);
    }

    /// <summary>Verified, online driver in Riyadh (separate so it also lands in databases seeded before drivers existed).</summary>
    private static async Task SeedDriverAsync(IServiceProvider services, MigaDbContext db, CancellationToken ct)
    {
        var users = services.GetRequiredService<UserManager<ApplicationUser>>();
        if (await users.Users.AnyAsync(u => u.PhoneNumber == DriverPhone, ct)) return;
        var user = new ApplicationUser { UserName = DriverPhone, PhoneNumber = DriverPhone, PhoneNumberConfirmed = true, FullName = "فهد الشمري", UserType = UserType.Driver };
        await users.CreateAsync(user);
        await users.AddToRoleAsync(user, nameof(UserType.Driver));
        var riyadh = await db.Cities.FirstAsync(c => c.NameEn == "Riyadh", ct);
        db.DriverProfiles.Add(new DriverProfile
        {
            UserId = user.Id, NationalId = "1098765432", CityId = riyadh.Id, VehicleType = "van", VehicleModel = "هيونداي H1 2023",
            VehiclePlateNumber = "أ ب ج 1234", DrivingLicenseNumber = "1098765432", IsVerified = true, IsAvailable = true, Rating = 4.9m,
        });
        await db.SaveChangesAsync(ct);
    }

    /// <summary>
    /// Merchant, driver and customer in Jeddah, ready for a full cycle: verified store with a pickup address,
    /// 4 products and 2 live campaigns; a verified online driver; a customer with a default address.
    /// Each account is skipped if its number already exists.
    /// </summary>
    private static async Task SeedJeddahTrioAsync(IServiceProvider services, MigaDbContext db, CancellationToken ct)
    {
        var users = services.GetRequiredService<UserManager<ApplicationUser>>();
        var jeddah = await db.Cities.Include(c => c.Districts).FirstAsync(c => c.NameEn == "Jeddah", ct);
        var now = DateTime.UtcNow;

        async Task<ApplicationUser?> NewUser(string phone, string name, UserType type)
        {
            if (await users.Users.AnyAsync(u => u.PhoneNumber == phone, ct)) return null;
            var u = new ApplicationUser { UserName = phone, PhoneNumber = phone, PhoneNumberConfirmed = true, FullName = name, UserType = type };
            await users.CreateAsync(u);
            await users.AddToRoleAsync(u, type.ToString());
            return u;
        }

        if (await NewUser(JeddahMerchantPhone, "خالد الزهراني", UserType.Merchant) is { } merchantUser)
        {
            var merchant = new MerchantProfile
            {
                UserId = merchantUser.Id, BusinessNameAr = "مؤسسة جدة للتجارة", CommercialRegistrationNumber = "4030555555", IsVerified = true, ReviewedAt = now,
            };
            db.MerchantProfiles.Add(merchant);
            var grocery = await db.StoreCategories.FirstAsync(c => c.NameEn == "Grocery", ct);
            var store = new Store
            {
                MerchantId = merchant.Id, NameAr = "سوق جدة للجملة", NameEn = "Jeddah Wholesale Market", StoreCategoryId = grocery.Id,
                DescriptionAr = "مواد غذائية وقهوة وتمور بأسعار الجملة", LogoUrl = "store_logo_2.png", CoverImageUrl = "store_cover_grocery.jpg",
                IsVerified = true, Status = StoreStatus.Active, CityId = jeddah.Id, PickupAddress = "جدة، حي السلامة، شارع صاري، مستودع 12", Rating = 5,
            };
            db.Stores.Add(store);
            var coffeeDates = new ProductCategory { StoreId = store.Id, NameAr = "قهوة وتمور", NameEn = "Coffee & Dates", SortOrder = 0 };
            var oilRice = new ProductCategory { StoreId = store.Id, NameAr = "زيوت وأرز", NameEn = "Oil & Rice", SortOrder = 1 };
            db.ProductCategories.AddRange(coffeeDates, oilRice);
            Product P(ProductCategory c, string ar, string en, decimal price, int stock, string image)
            {
                var p = new Product { StoreId = store.Id, ProductCategoryId = c.Id, NameAr = ar, NameEn = en, Price = price, StockQuantity = stock };
                p.Images.Add(new ProductImage { ImageUrl = image, IsMain = true });
                db.Products.Add(p);
                return p;
            }
            var coffee = P(coffeeDates, "قهوة عربية شقراء 1 كجم", "Light Arabic Coffee 1kg", 120, 300, "p_coffee.jpg");
            var dates = P(coffeeDates, "تمر سكري فاخر 3 كجم", "Sukkari Dates 3kg", 95, 400, "p_dates.jpg");
            P(oilRice, "زيت زيتون بكر 1 لتر", "Olive Oil 1L", 65, 250, "p_oil.jpg");
            P(oilRice, "أرز بسمتي 5 كجم", "Basmati Rice 5kg", 45, 600, "p_rice.jpg");
            db.Campaigns.AddRange(
                new Campaign
                {
                    StoreId = store.Id, ProductId = coffee.Id, MerchantUserId = merchantUser.Id, TitleAr = "قهوة جدة بسعر الجملة", TitleEn = coffee.NameEn,
                    DescriptionAr = "كلما زاد المشتركون وصلنا للسعر", OriginalPrice = 120, CampaignPrice = 89, TargetQuantity = 6, MaxQuantityPerCustomer = 3,
                    StartDate = now, EndDate = now.AddDays(7), Status = CampaignStatus.Active,
                },
                new Campaign
                {
                    StoreId = store.Id, ProductId = dates.Id, MerchantUserId = merchantUser.Id, TitleAr = "تمر سكري للعائلة", TitleEn = dates.NameEn,
                    OriginalPrice = 95, CampaignPrice = 69, TargetQuantity = 20, MaxQuantityPerCustomer = 5,
                    StartDate = now, EndDate = now.AddDays(10), Status = CampaignStatus.Active,
                });
        }

        if (await NewUser(JeddahDriverPhone, "ماجد الحربي", UserType.Driver) is { } driverUser)
            db.DriverProfiles.Add(new DriverProfile
            {
                UserId = driverUser.Id, NationalId = "1076543210", CityId = jeddah.Id, VehicleType = "van", VehicleModel = "تويوتا هايس 2023",
                VehiclePlateNumber = "ج د ة 2468", DrivingLicenseNumber = "1076543210", IsVerified = true, IsAvailable = true, ReviewedAt = now,
            });

        if (await NewUser(JeddahCustomerPhone, "نواف العمري", UserType.Customer) is { } customer)
        {
            customer.Email = "nawaf.test@miga.sa";
            customer.NormalizedEmail = customer.Email.ToUpperInvariant();
            db.CustomerProfiles.Add(new CustomerProfile { UserId = customer.Id });
            var district = jeddah.Districts.First(d => d.NameAr == "أبحر الشمالية");
            db.Addresses.Add(new Address
            {
                UserId = customer.Id, RegionId = jeddah.RegionId, CityId = jeddah.Id, DistrictId = district.Id, AddressName = "المنزل",
                PhoneNumber = "0533333333", AddressDetails = "شارع التحلية، عمارة 9، شقة 4", IsDefault = true,
            });
        }
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Starter home slides (the bundled banner images), each opening a real target. Admins edit them from the dashboard.</summary>
    private static async Task SeedBannersAsync(MigaDbContext db, CancellationToken ct)
    {
        if (await db.Banners.AnyAsync(ct)) return;
        var phoneCampaign = await db.Campaigns.Where(c => c.TitleAr == "حملة الهاتف الذكي برو").Select(c => (Guid?)c.Id).FirstOrDefaultAsync(ct);
        var electronics = await db.StoreCategories.Where(c => c.NameEn == "Electronics").Select(c => (Guid?)c.Id).FirstOrDefaultAsync(ct);
        var grocery = await db.Stores.Where(s => s.NameAr == "أسواق الخير").Select(s => (Guid?)s.Id).FirstOrDefaultAsync(ct);
        Banner B(int order, string image, string title, string subtitle, BannerLinkType type, Guid? link) => new()
        {
            SortOrder = order, ImageUrl = image, TitleAr = title, SubtitleAr = subtitle, ButtonLabelAr = "تسوّق الآن",
            LinkType = link == null ? BannerLinkType.None : type, LinkId = link,
        };
        db.Banners.AddRange(
            B(0, "banner_1.jpg", "اشترِ مع الجماعة", "ووفّر حتى 60% على منتجات الجملة", BannerLinkType.Campaign, phoneCampaign),
            B(1, "banner_2.jpg", "أحدث الأجهزة الذكية", "بأسعار الجملة لفترة محدودة", BannerLinkType.StoreCategory, electronics),
            B(2, "banner_3.jpg", "مقاضي البيت بالجملة", "أرز، تمور، قهوة وزيت زيتون", BannerLinkType.Store, grocery));
        await db.SaveChangesAsync(ct);
    }
}
