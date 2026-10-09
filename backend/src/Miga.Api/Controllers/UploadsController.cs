using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Contracts;
using Miga.Domain.Common;
using Miga.Infrastructure.Files;

namespace Miga.Api.Controllers;

/// <summary>Image uploads (product photos, store logo/cover, documents, delivery proof). Returns the URL to save on the entity.</summary>
[ApiController]
[Route("api/uploads")]
[Authorize]
public class UploadsController(IFileStorage storage) : ControllerBase
{
    private static readonly HashSet<string> Folders = ["products", "stores", "documents", "deliveries", "avatars", "banners"];

    /// <param name="folder">products · stores · documents · deliveries · avatars · banners (admins only)</param>
    [HttpPost("{folder}")]
    [RequestSizeLimit(LocalFileStorage.MaxBytes + 64 * 1024)]
    public async Task<UploadResponse> Upload(string folder, IFormFile file, CancellationToken ct)
    {
        if (!Folders.Contains(folder)) throw AppException.BadRequest("invalid_folder", "نوع الملف غير مدعوم");
        if (folder == "banners" && !User.IsInRole("Admin")) throw AppException.Forbidden("forbidden", "غير مصرح لك برفع صور البانرات");
        return new UploadResponse(await storage.SaveImageAsync(file, folder, ct));
    }
}
