using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence.Configurations;

public class StoreCategoryConfiguration : IEntityTypeConfiguration<StoreCategory>
{
    public void Configure(EntityTypeBuilder<StoreCategory> b)
    {
        b.Property(x => x.NameAr).HasMaxLength(100).IsRequired();
        b.Property(x => x.NameEn).HasMaxLength(100);
        b.Property(x => x.DescriptionAr).HasMaxLength(500);
        b.Property(x => x.DescriptionEn).HasMaxLength(500);
        b.Property(x => x.IconUrl).HasMaxLength(500);
        b.Property(x => x.ImageUrl).HasMaxLength(500);
    }
}

public class StoreConfiguration : IEntityTypeConfiguration<Store>
{
    public void Configure(EntityTypeBuilder<Store> b)
    {
        b.HasOne(x => x.Merchant).WithMany(m => m.Stores).HasForeignKey(x => x.MerchantId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.StoreCategory).WithMany(c => c.Stores).HasForeignKey(x => x.StoreCategoryId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.City).WithMany().HasForeignKey(x => x.CityId).OnDelete(DeleteBehavior.SetNull);

        b.Property(x => x.NameAr).HasMaxLength(200).IsRequired();
        b.Property(x => x.NameEn).HasMaxLength(200);
        b.Property(x => x.DescriptionAr).HasMaxLength(1000);
        b.Property(x => x.DescriptionEn).HasMaxLength(1000);
        b.Property(x => x.LogoUrl).HasMaxLength(500);
        b.Property(x => x.CoverImageUrl).HasMaxLength(500);
        b.Property(x => x.PickupAddress).HasMaxLength(500);
        b.Property(x => x.Rating).HasPrecision(3, 2);

        b.HasIndex(x => new { x.StoreCategoryId, x.Status });
        b.HasIndex(x => x.MerchantId);
    }
}

public class ProductCategoryConfiguration : IEntityTypeConfiguration<ProductCategory>
{
    public void Configure(EntityTypeBuilder<ProductCategory> b)
    {
        b.HasOne(x => x.Store).WithMany(s => s.ProductCategories).HasForeignKey(x => x.StoreId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.ParentCategory).WithMany(p => p.Children).HasForeignKey(x => x.ParentCategoryId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.NameAr).HasMaxLength(100).IsRequired();
        b.Property(x => x.NameEn).HasMaxLength(100);
        b.Property(x => x.DescriptionAr).HasMaxLength(500);
        b.Property(x => x.DescriptionEn).HasMaxLength(500);
        b.Property(x => x.ImageUrl).HasMaxLength(500);

        b.HasIndex(x => new { x.StoreId, x.ParentCategoryId, x.SortOrder });
    }
}

public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> b)
    {
        b.HasOne(x => x.Store).WithMany(s => s.Products).HasForeignKey(x => x.StoreId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.ProductCategory).WithMany(c => c.Products).HasForeignKey(x => x.ProductCategoryId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.NameAr).HasMaxLength(200).IsRequired();
        b.Property(x => x.NameEn).HasMaxLength(200);
        b.Property(x => x.DescriptionAr).HasMaxLength(2000);
        b.Property(x => x.DescriptionEn).HasMaxLength(2000);

        b.HasIndex(x => new { x.StoreId, x.IsActive });
        b.HasIndex(x => x.ProductCategoryId);
        // Soft delete without a global filter so past campaigns/orders keep resolving their product.
    }
}

public class ProductImageConfiguration : IEntityTypeConfiguration<ProductImage>
{
    public void Configure(EntityTypeBuilder<ProductImage> b)
    {
        b.HasOne(x => x.Product).WithMany(p => p.Images).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.ImageUrl).HasMaxLength(500).IsRequired();
        b.HasIndex(x => new { x.ProductId, x.SortOrder });
    }
}

public class CampaignConfiguration : IEntityTypeConfiguration<Campaign>
{
    public void Configure(EntityTypeBuilder<Campaign> b)
    {
        b.HasOne(x => x.Store).WithMany(s => s.Campaigns).HasForeignKey(x => x.StoreId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.Product).WithMany(p => p.Campaigns).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.MerchantUser).WithMany().HasForeignKey(x => x.MerchantUserId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.TitleAr).HasMaxLength(200).IsRequired();
        b.Property(x => x.TitleEn).HasMaxLength(200);
        b.Property(x => x.DescriptionAr).HasMaxLength(2000);
        b.Property(x => x.DescriptionEn).HasMaxLength(2000);
        b.Property(x => x.ConcurrencyStamp).IsConcurrencyToken();
        b.Ignore(x => x.RemainingQuantity);

        // Browse active campaigns, and find expired ones for the background job.
        b.HasIndex(x => new { x.Status, x.StartDate, x.EndDate });
        b.HasIndex(x => new { x.StoreId, x.Status });

        b.ToTable(t =>
        {
            t.HasCheckConstraint("CK_Campaign_Prices", "`CampaignPrice` > 0 AND `CampaignPrice` < `OriginalPrice`");
            t.HasCheckConstraint("CK_Campaign_Quantities", "`TargetQuantity` > 0 AND `CurrentQuantity` >= 0");
        });
    }
}
