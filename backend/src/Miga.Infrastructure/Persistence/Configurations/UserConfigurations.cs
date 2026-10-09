using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence.Configurations;

public class CustomerProfileConfiguration : IEntityTypeConfiguration<CustomerProfile>
{
    public void Configure(EntityTypeBuilder<CustomerProfile> b)
    {
        b.HasOne(x => x.User).WithOne(u => u.CustomerProfile).HasForeignKey<CustomerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.UserId).IsUnique();
    }
}

public class MerchantProfileConfiguration : IEntityTypeConfiguration<MerchantProfile>
{
    public void Configure(EntityTypeBuilder<MerchantProfile> b)
    {
        b.HasOne(x => x.User).WithOne(u => u.MerchantProfile).HasForeignKey<MerchantProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.UserId).IsUnique();
        b.Property(x => x.BusinessNameAr).HasMaxLength(200);
        b.Property(x => x.BusinessNameEn).HasMaxLength(200);
        b.Property(x => x.CommercialRegistrationNumber).HasMaxLength(20);
        b.Property(x => x.TaxNumber).HasMaxLength(20);
        b.Property(x => x.CommercialRegistrationDocUrl).HasMaxLength(500);
        b.Property(x => x.BankName).HasMaxLength(100);
        b.Property(x => x.Iban).HasMaxLength(34);
        b.Property(x => x.RejectionReason).HasMaxLength(500);
    }
}

public class DriverProfileConfiguration : IEntityTypeConfiguration<DriverProfile>
{
    public void Configure(EntityTypeBuilder<DriverProfile> b)
    {
        b.HasOne(x => x.User).WithOne(u => u.DriverProfile).HasForeignKey<DriverProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.City).WithMany().HasForeignKey(x => x.CityId).OnDelete(DeleteBehavior.SetNull);
        b.HasIndex(x => x.UserId).IsUnique();
        b.HasIndex(x => new { x.CityId, x.IsAvailable });
        b.Property(x => x.NationalId).HasMaxLength(20);
        b.Property(x => x.DrivingLicenseNumber).HasMaxLength(30);
        b.Property(x => x.VehicleType).HasMaxLength(50);
        b.Property(x => x.VehicleModel).HasMaxLength(100);
        b.Property(x => x.VehiclePlateNumber).HasMaxLength(20);
        b.Property(x => x.Rating).HasPrecision(3, 2);
        b.Property(x => x.RejectionReason).HasMaxLength(500);
    }
}

public class OtpCodeConfiguration : IEntityTypeConfiguration<OtpCode>
{
    public void Configure(EntityTypeBuilder<OtpCode> b)
    {
        b.Property(x => x.PhoneNumber).HasMaxLength(20);
        b.Property(x => x.CodeHash).HasMaxLength(100);
        b.HasIndex(x => new { x.PhoneNumber, x.CreatedAt });
    }
}

public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> b)
    {
        b.HasOne(x => x.User).WithMany(u => u.Notifications).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.Title).HasMaxLength(150);
        b.Property(x => x.Body).HasMaxLength(1000);
        b.HasIndex(x => new { x.UserId, x.IsRead, x.CreatedAt });
    }
}

public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> b)
    {
        b.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.Property(x => x.TokenHash).HasMaxLength(100).IsRequired();
        b.HasIndex(x => x.TokenHash).IsUnique();
        b.Ignore(x => x.IsActive);
    }
}

public class MerchantPayoutConfiguration : IEntityTypeConfiguration<MerchantPayout>
{
    public void Configure(EntityTypeBuilder<MerchantPayout> b)
    {
        b.HasOne(x => x.Merchant).WithMany(m => m.Payouts).HasForeignKey(x => x.MerchantId).OnDelete(DeleteBehavior.Restrict);
        b.Property(x => x.Iban).HasMaxLength(34).IsRequired();
        b.Property(x => x.TransferReference).HasMaxLength(100);
        b.Property(x => x.RejectionReason).HasMaxLength(500);
        b.HasIndex(x => new { x.MerchantId, x.Status });
        b.ToTable(t => t.HasCheckConstraint("CK_MerchantPayout_Amount", "`Amount` > 0"));
    }
}
