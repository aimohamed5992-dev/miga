using System.ComponentModel.DataAnnotations;

namespace Miga.Api.Contracts;

public record AddCartItemRequest([Required] Guid ProductId, Guid? CampaignId, [Range(1, 1000)] int Quantity = 1);

public record CartQuantityRequest([Range(0, 1000)] int Quantity);

/// <param name="PaymentMethod">mada · applepay · card · stcpay (test_fail simulates a declined payment).</param>
/// <param name="CartItemIds">Optional subset of cart lines; all lines when omitted.</param>
public record CheckoutRequest([Required] Guid AddressId, [Required] string PaymentMethod, List<Guid>? CartItemIds);

public record CancelOrderRequest([Required, StringLength(300, MinimumLength = 2)] string Reason);
