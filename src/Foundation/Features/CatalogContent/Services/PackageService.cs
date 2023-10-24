using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

// Research: Get the entries of a package

public interface IPackageService
{
    IEnumerable<PackageEntry> ListPackageEntries(ContentReference referenceToPackage); // Retrieve entries from a package
}

public class PackageService : IPackageService
{
    public IEnumerable<PackageEntry> ListPackageEntries(ContentReference referenceToPackage)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations to package entries are of type PackageEntry
        var packageEntries = relationRepository.GetChildren<PackageEntry>(referenceToPackage);
        return packageEntries;
    }
}