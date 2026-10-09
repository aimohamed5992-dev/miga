using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Miga.Domain.Common;

namespace Miga.Api.Infrastructure;

/// <summary>
/// Every error leaves the API as ProblemDetails: { status, title (Arabic message), code }.
/// The apps show `title` and branch on `code`.
/// </summary>
public class ApiExceptionHandler(IProblemDetailsService problems, ILogger<ApiExceptionHandler> log, IHostEnvironment env) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception ex, CancellationToken ct)
    {
        var (status, code, message) = ex switch
        {
            AppException app => (app.StatusCode, app.Code, app.Message),
            DbUpdateConcurrencyException => (409, "concurrency_conflict", "تم تعديل البيانات من مكان آخر، حدّث الصفحة وحاول مرة أخرى"),
            _ => (500, "server_error", "حدث خطأ غير متوقع، حاول لاحقًا"),
        };

        if (status >= 500) log.LogError(ex, "Unhandled error on {Path}", http.Request.Path);

        http.Response.StatusCode = status;
        return await problems.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = http,
            Exception = ex,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Title = message,
                // Full exception only outside production, to speed up debugging.
                Detail = status >= 500 && !env.IsProduction() ? ex.ToString() : null,
                Extensions = { ["code"] = code },
            },
        });
    }
}
