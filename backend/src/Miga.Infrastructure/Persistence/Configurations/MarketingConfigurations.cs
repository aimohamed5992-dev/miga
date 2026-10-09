using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Miga.Domain.Entities;

namespace Miga.Infrastructure.Persistence.Configurations;

public class BannerConfiguration : IEntityTypeConfiguration<Banner>
{
    public void Configure(EntityTypeBuilder<Banner> b)
    {
        b.Property(x => x.ImageUrl).HasMaxLength(500).IsRequired();
        b.Property(x => x.TitleAr).HasMaxLength(120);
        b.Property(x => x.SubtitleAr).HasMaxLength(200);
        b.Property(x => x.ButtonLabelAr).HasMaxLength(40);
        b.HasIndex(x => new { x.IsActive, x.SortOrder });
    }
}

public class FavoriteCampaignConfiguration : IEntityTypeConfiguration<FavoriteCampaign>
{
    public void Configure(EntityTypeBuilder<FavoriteCampaign> b)
    {
        b.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.Campaign).WithMany().HasForeignKey(x => x.CampaignId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.UserId, x.CampaignId }).IsUnique();
    }
}
