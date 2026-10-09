namespace Miga.Domain.Entities;

// Merchant → Stores → (StoreCategory, ProductCategories → Products, Campaigns)

/// <summary>Store sections shown to customers: Electronics, Grocery, Fashion, Beauty, Restaurants…</summary>
public class StoreCategory : Entity
{
    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public string? DescriptionAr { get; set; }
    public string? DescriptionEn { get; set; }
    public string? IconUrl { get; set; }
    public string? ImageUrl { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<Store> Stores { get; set; } = new List<Store>();
}

public class Store : Entity
{
    public Guid MerchantId { get; set; }
    public MerchantProfile Merchant { get; set; } = null!;

    public Guid StoreCategoryId { get; set; }
    public StoreCategory StoreCategory { get; set; } = null!;

    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public string? DescriptionAr { get; set; }
    public string? DescriptionEn { get; set; }
    public string? LogoUrl { get; set; }
    public string? CoverImageUrl { get; set; }

    /// <summary>Pickup address for drivers.</summary>
    public string? PickupAddress { get; set; }
    public Guid? CityId { get; set; }
    public City? City { get; set; }

    public StoreStatus Status { get; set; } = StoreStatus.Active;
    public bool IsVerified { get; set; }
    public decimal Rating { get; set; }

    public ICollection<ProductCategory> ProductCategories { get; set; } = new List<ProductCategory>();
    public ICollection<Product> Products { get; set; } = new List<Product>();
    public ICollection<Campaign> Campaigns { get; set; } = new List<Campaign>();
}

/// <summary>Product categories inside a store, with optional parent for sub-categories.</summary>
public class ProductCategory : Entity
{
    public Guid StoreId { get; set; }
    public Store Store { get; set; } = null!;

    public Guid? ParentCategoryId { get; set; }
    public ProductCategory? ParentCategory { get; set; }

    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public string? DescriptionAr { get; set; }
    public string? DescriptionEn { get; set; }
    public string? ImageUrl { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<ProductCategory> Children { get; set; } = new List<ProductCategory>();
    public ICollection<Product> Products { get; set; } = new List<Product>();
}

public class Product : Entity
{
    public Guid StoreId { get; set; }
    public Store Store { get; set; } = null!;

    public Guid ProductCategoryId { get; set; }
    public ProductCategory ProductCategory { get; set; } = null!;

    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public string? DescriptionAr { get; set; }
    public string? DescriptionEn { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsDeleted { get; set; }

    public ICollection<ProductImage> Images { get; set; } = new List<ProductImage>();
    public ICollection<Campaign> Campaigns { get; set; } = new List<Campaign>();
    public ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
}

public class ProductImage : Entity
{
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;

    public string ImageUrl { get; set; } = string.Empty;
    public int SortOrder { get; set; }
    public bool IsMain { get; set; }
}
