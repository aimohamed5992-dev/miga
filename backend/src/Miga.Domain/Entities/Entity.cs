namespace Miga.Domain.Entities;

/// <summary>Base for every non-Identity entity: Guid key + creation time (UTC).</summary>
public abstract class Entity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
