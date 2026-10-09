using System.Text.RegularExpressions;

namespace Miga.Domain.Common;

/// <summary>Saudi mobile numbers, normalized to +9665XXXXXXXX (accepts 05…, 5…, 9665…, +9665…, 009665…).</summary>
public static partial class PhoneNumber
{
    [GeneratedRegex(@"^5\d{8}$")]
    private static partial Regex LocalPart();

    public static bool TryNormalize(string? input, out string normalized)
    {
        normalized = string.Empty;
        if (string.IsNullOrWhiteSpace(input)) return false;

        // Keep digits only (also converts Arabic-Indic digits ٠-٩ typed on Arabic keyboards).
        var digits = new string(input.Select(ToAsciiDigit).Where(char.IsAsciiDigit).ToArray());
        if (digits.StartsWith("00966")) digits = digits[5..];
        else if (digits.StartsWith("966")) digits = digits[3..];
        else if (digits.StartsWith('0')) digits = digits[1..];

        if (!LocalPart().IsMatch(digits)) return false;
        normalized = "+966" + digits;
        return true;
    }

    public static string Normalize(string? input) =>
        TryNormalize(input, out var n) ? n : throw AppException.BadRequest("invalid_phone", "رقم الجوال غير صحيح، يجب أن يبدأ بـ 5 ويتكون من 9 أرقام");

    private static char ToAsciiDigit(char c) => c is >= '٠' and <= '٩' ? (char)('0' + (c - '٠')) : c;
}
