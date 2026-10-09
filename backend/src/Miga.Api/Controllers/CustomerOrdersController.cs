using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Common;
using Miga.Infrastructure.Features.Cart;
using Miga.Infrastructure.Features.Orders;

namespace Miga.Api.Controllers;

[ApiController]
[Route("api/customer")]
[Authorize(Roles = "Customer")]
public class CustomerOrdersController(CartService cart, CheckoutService checkout, CustomerOrderQueries orders, CampaignLifecycleService lifecycle) : ControllerBase
{
    // ---- cart ----

    [HttpGet("cart")]
    public Task<CartDto> Cart(CancellationToken ct) => cart.GetAsync(User.UserId(), ct);

    [HttpPost("cart/items")]
    public Task<CartDto> AddItem(AddCartItemRequest req, CancellationToken ct) => cart.AddAsync(User.UserId(), req.ProductId, req.CampaignId, req.Quantity, ct);

    [HttpPatch("cart/items/{itemId:guid}")]
    public Task<CartDto> SetQuantity(Guid itemId, CartQuantityRequest req, CancellationToken ct) => cart.SetQuantityAsync(User.UserId(), itemId, req.Quantity, ct);

    [HttpDelete("cart/items/{itemId:guid}")]
    public Task<CartDto> RemoveItem(Guid itemId, CancellationToken ct) => cart.RemoveAsync(User.UserId(), itemId, ct);

    [HttpDelete("cart")]
    public async Task<IActionResult> Clear(CancellationToken ct)
    {
        await cart.ClearAsync(User.UserId(), ct);
        return NoContent();
    }

    // ---- checkout ----

    /// <summary>Pays for the cart's campaign lines. Each line succeeds or fails independently (see `items`).</summary>
    [HttpPost("checkout")]
    public Task<CheckoutResult> Checkout(CheckoutRequest req, CancellationToken ct) =>
        checkout.CheckoutAsync(User.UserId(), req.AddressId, req.PaymentMethod, req.CartItemIds, ct);

    // ---- orders ----

    /// <param name="scope">current · past</param>
    [HttpGet("orders")]
    public Task<PagedResult<OrderSummaryDto>> Orders([FromQuery] OrderScope scope = OrderScope.Current, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        orders.ListAsync(User.UserId(), scope, page, pageSize, ct);

    [HttpGet("orders/{id:guid}")]
    public Task<OrderDetailDto> Order(Guid id, CancellationToken ct) => orders.GetAsync(User.UserId(), id, ct);

    [HttpPost("orders/{id:guid}/cancel")]
    public async Task<OrderDetailDto> Cancel(Guid id, CancelOrderRequest req, CancellationToken ct)
    {
        await lifecycle.CancelByCustomerAsync(User.UserId(), id, req.Reason, ct);
        return await orders.GetAsync(User.UserId(), id, ct);
    }
}

/// <summary>In-app notifications for any signed-in user (customer, merchant, driver).</summary>
[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController(CustomerOrderQueries queries) : ControllerBase
{
    [HttpGet]
    public Task<List<NotificationDto>> List(CancellationToken ct) => queries.NotificationsAsync(User.UserId(), ct);

    [HttpPost("read-all")]
    public async Task<IActionResult> ReadAll(CancellationToken ct)
    {
        await queries.MarkAllReadAsync(User.UserId(), ct);
        return NoContent();
    }
}
