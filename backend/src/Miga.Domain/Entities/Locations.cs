namespace Miga.Domain.Entities;

// Addresses are built from Region → City → District + address name + phone (per the spec).

public class Region : Entity
{
    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public int SortOrder { get; set; }

    public ICollection<City> Cities { get; set; } = new List<City>();
}

public class City : Entity
{
    public Guid RegionId { get; set; }
    public Region Region { get; set; } = null!;

    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;

    /// <summary>City centre (reference data; used to place approximate points on the admin map).</summary>
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    public ICollection<District> Districts { get; set; } = new List<District>();
}

public class District : Entity
{
    public Guid CityId { get; set; }
    public City City { get; set; } = null!;

    public string NameAr { get; set; } = string.Empty;
    public string NameEn { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;

    /// <summary>Approximate district centre, when known.</summary>
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
}

public class Address : Entity
{
    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public Guid RegionId { get; set; }
    public Region Region { get; set; } = null!;

    public Guid CityId { get; set; }
    public City City { get; set; } = null!;

    public Guid DistrictId { get; set; }
    public District District { get; set; } = null!;

    /// <summary>e.g. "المنزل", "العمل".</summary>
    public string AddressName { get; set; } = string.Empty;

    /// <summary>Contact number for this address (can differ from the account phone).</summary>
    public string PhoneNumber { get; set; } = string.Empty;

    public string? AddressDetails { get; set; }
    public string? BuildingNumber { get; set; }
    public string? StreetName { get; set; }
    public string? PostalCode { get; set; }

    // Optional — the address is defined by Region/City/District; coordinates improve routing.
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    public bool IsDefault { get; set; }
    public bool IsDeleted { get; set; }
}
