namespace Miga.Domain.Common;

/// <summary>
/// Expected business error. The API turns it into a ProblemDetails response with
/// the HTTP status, a stable machine code (for the apps) and an Arabic message (for users).
/// </summary>
public class AppException(int statusCode, string code, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
    public string Code { get; } = code;

    public static AppException BadRequest(string code, string message) => new(400, code, message);
    public static AppException Unauthorized(string code, string message) => new(401, code, message);
    public static AppException Forbidden(string code, string message) => new(403, code, message);
    public static AppException NotFound(string code, string message) => new(404, code, message);
    public static AppException Conflict(string code, string message) => new(409, code, message);
    public static AppException TooManyRequests(string code, string message) => new(429, code, message);
}
