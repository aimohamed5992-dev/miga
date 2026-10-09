using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Miga.Api.Contracts;
using Miga.Api.Infrastructure;
using Miga.Infrastructure.Features.Addresses;

namespace Miga.Api.Controllers;

[ApiController]
[Route("api/customer/addresses")]
[Authorize(Roles = "Customer")]
public class AddressesController(AddressService addresses) : ControllerBase
{
    [HttpGet]
    public Task<List<AddressDto>> List(CancellationToken ct) => addresses.ListAsync(User.UserId(), ct);

    [HttpGet("{id:guid}")]
    public Task<AddressDto> Get(Guid id, CancellationToken ct) => addresses.GetAsync(User.UserId(), id, ct);

    [HttpPost]
    public async Task<ActionResult<AddressDto>> Create(AddressRequest req, CancellationToken ct)
    {
        var created = await addresses.CreateAsync(User.UserId(), req.ToInput(), ct);
        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    public Task<AddressDto> Update(Guid id, AddressRequest req, CancellationToken ct) => addresses.UpdateAsync(User.UserId(), id, req.ToInput(), ct);

    [HttpPost("{id:guid}/default")]
    public async Task<IActionResult> MakeDefault(Guid id, CancellationToken ct)
    {
        await addresses.SetDefaultAsync(User.UserId(), id, ct);
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await addresses.DeleteAsync(User.UserId(), id, ct);
        return NoContent();
    }
}
