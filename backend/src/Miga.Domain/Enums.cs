namespace Miga.Domain;

// Numeric values are shared with the Flutter apps (miga_core/enums.dart) — never renumber.

public enum UserType
{
    Customer = 1,
    Merchant = 2,
    Driver = 3,
    Admin = 4
}

public enum StoreStatus
{
    Active = 1,
    Inactive = 2,
    Suspended = 3
}

public enum CampaignStatus
{
    Draft = 1,
    Active = 2,
    Completed = 3,
    Failed = 4,
    Cancelled = 5,
    Processing = 6,
    Closed = 7
}

public enum CampaignOrderStatus
{
    Pending = 1,
    Paid = 2,
    Confirmed = 3,
    Preparing = 4,
    ReadyForDelivery = 5,
    OutForDelivery = 6,
    Delivered = 7,
    Cancelled = 8,
    Refunded = 9
}

public enum PaymentStatus
{
    Pending = 1,
    Paid = 2,
    Failed = 3,
    Cancelled = 4,
    Refunded = 5,
    PartiallyRefunded = 6
}

public enum MerchantOrderStatus
{
    Pending = 1,
    SentToMerchant = 2,
    Confirmed = 3,
    Preparing = 4,
    Ready = 5,
    Completed = 6,
    Cancelled = 7
}

public enum DeliveryStatus
{
    Pending = 1,
    Assigned = 2,
    DriverAccepted = 3,
    PickedUp = 4,
    OutForDelivery = 5,
    Delivered = 6,
    Failed = 7,
    Cancelled = 8
}

public enum OrderType
{
    Product = 1,
    Campaign = 2
}

public enum NotificationType
{
    General = 1,
    CampaignCompleted = 2,
    CampaignFailed = 3,
    OrderStatus = 4,
    DeliveryRequest = 5,
    Payment = 6
}
