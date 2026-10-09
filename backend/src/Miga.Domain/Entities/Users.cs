using Microsoft.AspNetCore.Identity;

namespace Miga.Domain.Entities;

/// <summary>ASP.NET Core Identity user (Guid keys). Login is by phone number + OTP.</summary>
public class ApplicationUser : IdentityUser<Guid>
{
    public string FullName { get; set; } = string.Empty;
    public UserType UserType { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Why an admin suspended the account (shown to admins; cleared on reactivation).</summary>
    public string? SuspensionReason { get; set; }
    public DateTime? SuspendedAt { get; set; }

    public CustomerProfile? CustomerProfile { get; set; }
    public MerchantProfile? MerchantProfile { get; set; }
    public DriverProfile? DriverProfile { get; set; }

    public ICollection<Address> Addresses { get; set; } = new List<Address>();
    public ICollection<CampaignOrder> CampaignOrders { get; set; } = new List<CampaignOrder>();
    public ICollection<Delivery> Deliveries { get; set; } = new List<Delivery>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
}

public class CustomerProfile : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public ICollection<Cart> Carts { get; set; } = new List<Cart>();
}

public class MerchantProfile : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string? BusinessNameAr { get; set; }
    public string? BusinessNameEn { get; set; }
    public string? CommercialRegistrationNumber { get; set; }
    public string? TaxNumber { get; set; }
    public string? CommercialRegistrationDocUrl { get; set; }
    public bool IsVerified { get; set; }

    /// <summary>Set when an admin rejects the registration; the merchant can fix the data and resubmit.</summary>
    public string? RejectionReason { get; set; }
    public DateTime? ReviewedAt { get; set; }

    /// <summary>Payout destination (Saudi IBAN: SA + 22 digits).</summary>
    public string? BankName { get; set; }
    public string? Iban { get; set; }

    public ICollection<Store> Stores { get; set; } = new List<Store>();
    public ICollection<MerchantPayout> Payouts { get; set; } = new List<MerchantPayout>();
}

public enum PayoutStatus
{
    Requested = 1,
    Paid = 2,
    Rejected = 3
}

/// <summary>Withdrawal of settled earnings to the merchant's bank account.</summary>
public class MerchantPayout : Entity
{
    public Guid MerchantId { get; set; }
    public MerchantProfile Merchant { get; set; } = null!;

    public decimal Amount { get; set; }
    public string Iban { get; set; } = string.Empty;
    public PayoutStatus Status { get; set; } = PayoutStatus.Requested;
    public DateTime? PaidAt { get; set; }

    /// <summary>Bank transfer reference entered by finance when marking it paid.</summary>
    public string? TransferReference { get; set; }

    /// <summary>Why finance rejected it (the amount returns to the available balance).</summary>
    public string? RejectionReason { get; set; }
}

public class DriverProfile : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string? NationalId { get; set; }
    public string? DrivingLicenseNumber { get; set; }
    public string? VehicleType { get; set; }
    public string? VehicleModel { get; set; }
    public string? VehiclePlateNumber { get; set; }

    /// <summary>City the driver works in (requests are matched by city).</summary>
    public Guid? CityId { get; set; }
    public City? City { get; set; }

    public bool IsAvailable { get; set; }

    /// <summary>Last position reported by the driver app while online (admin live map).</summary>
    public decimal? LastLatitude { get; set; }
    public decimal? LastLongitude { get; set; }
    public DateTime? LastLocationAt { get; set; }

    public bool IsVerified { get; set; }
    public decimal Rating { get; set; } = 5;

    /// <summary>Set when an admin rejects the registration; the driver can fix the data and resubmit.</summary>
    public string? RejectionReason { get; set; }
    public DateTime? ReviewedAt { get; set; }
}

/// <summary>One-time login code. Only a hash of the code is stored.</summary>
public class OtpCode : Entity
{
    public string PhoneNumber { get; set; } = string.Empty;
    public string CodeHash { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public bool IsUsed { get; set; }
}

public class Notification : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public NotificationType Type { get; set; } = NotificationType.General;
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;

    /// <summary>Optional id of the related campaign / order / delivery for deep links.</summary>
    public Guid? ReferenceId { get; set; }
    public bool IsRead { get; set; }
}

/// <summary>Long-lived token to renew the short JWT. Stored hashed; rotated on every use.</summary>
public class RefreshToken : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string TokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }

    public bool IsActive => RevokedAt == null && ExpiresAt > DateTime.UtcNow;
}
