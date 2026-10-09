using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence.Configurations;

public class CartConfiguration : IEntityTypeConfiguration<Cart>
{
    public void Configure(EntityTypeBuilder<Cart> b)
    {
        b.HasOne(x => x.Customer).WithMany(c => c.Carts).HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.CustomerId, x.IsActive });
    }
}

public class CartItemConfiguration : IEntityTypeConfiguration<CartItem>
{
    public void Configure(EntityTypeBuilder<CartItem> b)
    {
        b.HasOne(x => x.Cart).WithMany(c => c.Items).HasForeignKey(x => x.CartId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.Product).WithMany(p => p.CartItems).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.Campaign).WithMany().HasForeignKey(x => x.CampaignId).OnDelete(DeleteBehavior.Cascade);

        // Same product can appear once as a regular item and once per campaign.
        b.HasIndex(x => new { x.CartId, x.ProductId, x.CampaignId }).IsUnique();
        b.ToTable(t => t.HasCheckConstraint("CK_CartItem_Quantity", "`Quantity` > 0"));
    }
}

public class CampaignOrderConfiguration : IEntityTypeConfiguration<CampaignOrder>
{
    public void Configure(EntityTypeBuilder<CampaignOrder> b)
    {
        b.HasOne(x => x.Campaign).WithMany(c => c.Orders).HasForeignKey(x => x.CampaignId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.Customer).WithMany(u => u.CampaignOrders).HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.DeliveryAddress).WithMany().HasForeignKey(x => x.DeliveryAddressId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.Number).HasMaxLength(20).IsRequired();
        b.Property(x => x.CancellationReason).HasMaxLength(300);

        b.HasIndex(x => x.Number).IsUnique();
        b.HasIndex(x => new { x.CustomerId, x.CampaignId });
        b.HasIndex(x => new { x.CampaignId, x.Status });
        b.ToTable(t => t.HasCheckConstraint("CK_CampaignOrder_Quantity", "`Quantity` > 0"));
    }
}

public class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> b)
    {
        b.HasOne(x => x.CampaignOrder).WithOne(o => o.Payment).HasForeignKey<Payment>(x => x.CampaignOrderId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.PaymentMethod).HasMaxLength(30);
        b.Property(x => x.TransactionId).HasMaxLength(200);
        b.Property(x => x.FailureReason).HasMaxLength(300);
        b.HasIndex(x => x.CampaignOrderId).IsUnique();
        b.HasIndex(x => x.TransactionId);
    }
}

public class MerchantOrderConfiguration : IEntityTypeConfiguration<MerchantOrder>
{
    public void Configure(EntityTypeBuilder<MerchantOrder> b)
    {
        b.HasOne(x => x.Campaign).WithOne(c => c.MerchantOrder).HasForeignKey<MerchantOrder>(x => x.CampaignId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.Store).WithMany().HasForeignKey(x => x.StoreId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.Number).HasMaxLength(20).IsRequired();
        b.Property(x => x.PickupCode).HasMaxLength(10);

        b.HasIndex(x => x.Number).IsUnique();
        b.HasIndex(x => x.CampaignId).IsUnique();
        b.HasIndex(x => new { x.StoreId, x.Status });
    }
}

public class DeliveryConfiguration : IEntityTypeConfiguration<Delivery>
{
    public void Configure(EntityTypeBuilder<Delivery> b)
    {
        b.HasOne(x => x.CampaignOrder).WithOne(o => o.Delivery).HasForeignKey<Delivery>(x => x.CampaignOrderId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.MerchantOrder).WithMany(m => m.Deliveries).HasForeignKey(x => x.MerchantOrderId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.DriverUser).WithMany(u => u.Deliveries).HasForeignKey(x => x.DriverUserId).OnDelete(DeleteBehavior.Restrict);
        b.HasOne(x => x.DeliveryAddress).WithMany().HasForeignKey(x => x.DeliveryAddressId).OnDelete(DeleteBehavior.Restrict);

        b.Property(x => x.Number).HasMaxLength(20).IsRequired();
        b.Property(x => x.DeliveryCode).HasMaxLength(10);
        b.Property(x => x.DeliveryNotes).HasMaxLength(1000);
        b.Property(x => x.FailureReason).HasMaxLength(300);
        b.Property(x => x.ProofImageUrl).HasMaxLength(500);

        b.HasIndex(x => x.Number).IsUnique();
        b.HasIndex(x => x.CampaignOrderId).IsUnique();
        b.HasIndex(x => new { x.DriverUserId, x.Status });
        b.HasIndex(x => new { x.Status, x.MerchantOrderId });
    }
}
