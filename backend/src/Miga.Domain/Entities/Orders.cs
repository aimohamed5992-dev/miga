namespace Miga.Domain.Entities;

/// <summary>Customer cart: one cart, split by store at checkout. Items can be regular products or campaign participations.</summary>
public class Cart : Entity
{
    public Guid CustomerId { get; set; }
    public CustomerProfile Customer { get; set; } = null!;

    public bool IsActive { get; set; } = true;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<CartItem> Items { get; set; } = new List<CartItem>();
}

public class CartItem : Entity
{
    public Guid CartId { get; set; }
    public Cart Cart { get; set; } = null!;

    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;

    /// <summary>Null for a regular product; set when the item joins a campaign.</summary>
    public Guid? CampaignId { get; set; }
    public Campaign? Campaign { get; set; }

    public int Quantity { get; set; }

    /// <summary>Price at the moment of adding to the cart.</summary>
    public decimal UnitPrice { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>One customer's participation in one campaign (individual order, address and payment).</summary>
public class CampaignOrder : Entity
{
    /// <summary>Human-readable number, e.g. MG-10482.</summary>
    public string Number { get; set; } = string.Empty;

    public Guid CampaignId { get; set; }
    public Campaign Campaign { get; set; } = null!;

    public Guid CustomerId { get; set; }
    public ApplicationUser Customer { get; set; } = null!;

    public Guid DeliveryAddressId { get; set; }
    public Address DeliveryAddress { get; set; } = null!;

    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalAmount { get; set; }

    public CampaignOrderStatus Status { get; set; } = CampaignOrderStatus.Pending;
    public DateTime? ConfirmedAt { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public DateTime? CancelledAt { get; set; }
    public string? CancellationReason { get; set; }

    public Payment? Payment { get; set; }
    public Delivery? Delivery { get; set; }
}

public class Payment : Entity
{
    public Guid CampaignOrderId { get; set; }
    public CampaignOrder CampaignOrder { get; set; } = null!;

    public decimal Amount { get; set; }

    /// <summary>mada / applepay / card / stcpay.</summary>
    public string? PaymentMethod { get; set; }
    public string? TransactionId { get; set; }
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
    public DateTime? PaidAt { get; set; }
    public DateTime? RefundedAt { get; set; }
    public string? FailureReason { get; set; }
}

/// <summary>
/// Aggregated order the merchant receives when a campaign completes
/// (e.g. 100 pieces = sum of all CampaignOrders). Split into Deliveries per customer.
/// </summary>
public class MerchantOrder : Entity
{
    /// <summary>e.g. MO-2201.</summary>
    public string Number { get; set; } = string.Empty;

    public Guid CampaignId { get; set; }
    public Campaign Campaign { get; set; } = null!;

    public Guid StoreId { get; set; }
    public Store Store { get; set; } = null!;

    public int TotalQuantity { get; set; }
    public int CustomersCount { get; set; }
    public decimal TotalAmount { get; set; }

    /// <summary>MIGA commission deducted from TotalAmount.</summary>
    public decimal PlatformFee { get; set; }

    /// <summary>Code drivers show at the warehouse.</summary>
    public string PickupCode { get; set; } = string.Empty;

    public MerchantOrderStatus Status { get; set; } = MerchantOrderStatus.Pending;
    public DateTime? ConfirmedAt { get; set; }
    public DateTime? ReadyAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public ICollection<Delivery> Deliveries { get; set; } = new List<Delivery>();
}

/// <summary>Delivery of one CampaignOrder from the merchant's store to the customer.</summary>
public class Delivery : Entity
{
    /// <summary>e.g. DL-7300.</summary>
    public string Number { get; set; } = string.Empty;

    public Guid CampaignOrderId { get; set; }
    public CampaignOrder CampaignOrder { get; set; } = null!;

    public Guid MerchantOrderId { get; set; }
    public MerchantOrder MerchantOrder { get; set; } = null!;

    public Guid? DriverUserId { get; set; }
    public ApplicationUser? DriverUser { get; set; }

    public Guid DeliveryAddressId { get; set; }
    public Address DeliveryAddress { get; set; } = null!;

    public DeliveryStatus Status { get; set; } = DeliveryStatus.Pending;

    public decimal Fee { get; set; }
    public decimal? DistanceKm { get; set; }

    /// <summary>Code the customer gives the driver to confirm hand-over.</summary>
    public string DeliveryCode { get; set; } = string.Empty;

    public DateTime? AssignedAt { get; set; }
    public DateTime? AcceptedAt { get; set; }
    public DateTime? PickedUpAt { get; set; }
    public DateTime? OutForDeliveryAt { get; set; }
    public DateTime? DeliveredAt { get; set; }

    public string? DeliveryNotes { get; set; }
    public string? FailureReason { get; set; }
    public string? ProofImageUrl { get; set; }
}
