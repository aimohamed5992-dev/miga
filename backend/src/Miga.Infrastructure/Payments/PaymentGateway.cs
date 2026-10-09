namespace Miga.Infrastructure.Payments;

public record PaymentResult(bool Success, string? TransactionId, string? FailureReason);

/// <summary>
/// Card / mada / Apple Pay / STC Pay charges. Replace <see cref="MockPaymentGateway"/> with a real
/// provider (Moyasar, HyperPay, Tap…). A real gateway is asynchronous (3-D Secure redirect + webhook):
/// the order would then stay Pending with a short reservation until the webhook confirms it.
/// </summary>
public interface IPaymentGateway
{
    Task<PaymentResult> ChargeAsync(decimal amount, string method, string reference, CancellationToken ct);
    Task<PaymentResult> RefundAsync(string transactionId, decimal amount, CancellationToken ct);
}

public class MockPaymentGateway : IPaymentGateway
{
    public static readonly string[] Methods = ["mada", "applepay", "card", "stcpay"];

    /// <summary>Method that always fails — lets the apps and tests exercise the payment-failed path.</summary>
    public const string FailingTestMethod = "test_fail";

    public Task<PaymentResult> ChargeAsync(decimal amount, string method, string reference, CancellationToken ct) =>
        Task.FromResult(method == FailingTestMethod
            ? new PaymentResult(false, null, "تم رفض العملية من البنك")
            : new PaymentResult(true, $"MOCK-{Guid.NewGuid():N}", null));

    public Task<PaymentResult> RefundAsync(string transactionId, decimal amount, CancellationToken ct) =>
        Task.FromResult(new PaymentResult(true, transactionId, null));
}
