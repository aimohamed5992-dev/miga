using Miga.Domain;
using Miga.Domain.Entities;
using Miga.Infrastructure.Persistence;

namespace Miga.Infrastructure.Notifications;

/// <summary>
/// Queues in-app notifications on the current DbContext (saved with the caller's transaction, so a
/// notification never exists for a change that rolled back). Push (FCM) delivery is added later.
/// </summary>
public class Notifier(MigaDbContext db)
{
    public void Notify(Guid userId, NotificationType type, string title, string body, Guid? referenceId = null) =>
        db.Notifications.Add(new Notification { UserId = userId, Type = type, Title = title, Body = body, ReferenceId = referenceId });
}
