using System.Globalization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Miga.Domain.Common;

namespace Miga.Infrastructure.Files;

/// <summary>Stores uploaded images and returns their public URL path. Swap for S3 / Azure Blob in production.</summary>
public interface IFileStorage
{
    Task<string> SaveImageAsync(IFormFile file, string folder, CancellationToken ct);
}

public class LocalFileStorage(IWebHostEnvironment env) : IFileStorage
{
    public const long MaxBytes = 5 * 1024 * 1024;

    private static readonly Dictionary<string, byte[][]> Signatures = new()
    {
        [".jpg"] = [[0xFF, 0xD8, 0xFF]],
        [".jpeg"] = [[0xFF, 0xD8, 0xFF]],
        [".png"] = [[0x89, 0x50, 0x4E, 0x47]],
        [".webp"] = [[0x52, 0x49, 0x46, 0x46]],
    };

    public async Task<string> SaveImageAsync(IFormFile file, string folder, CancellationToken ct)
    {
        if (file.Length == 0) throw AppException.BadRequest("empty_file", "الملف فارغ");
        if (file.Length > MaxBytes) throw AppException.BadRequest("file_too_large", "حجم الصورة يجب ألا يتجاوز 5 ميجابايت");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!Signatures.TryGetValue(ext, out var magic)) throw AppException.BadRequest("unsupported_file", "الصيغ المسموحة: JPG أو PNG أو WEBP");

        // Check the real content, not just the extension.
        var header = new byte[4];
        await using (var peek = file.OpenReadStream())
        {
            _ = await peek.ReadAsync(header, ct);
        }
        if (!magic.Any(m => header.AsSpan(0, m.Length).SequenceEqual(m))) throw AppException.BadRequest("unsupported_file", "الملف ليس صورة صالحة");

        // Folder comes from code (an allow-list), never from the client.
        var relative = Path.Combine("uploads", folder, DateTime.UtcNow.ToString("yyyy-MM", CultureInfo.InvariantCulture));
        var root = env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot");
        var dir = Path.Combine(root, relative);
        Directory.CreateDirectory(dir);

        var name = $"{Guid.NewGuid():N}{ext}";
        await using (var target = File.Create(Path.Combine(dir, name)))
        {
            await file.CopyToAsync(target, ct);
        }
        return "/" + Path.Combine(relative, name).Replace('\\', '/');
    }
}
