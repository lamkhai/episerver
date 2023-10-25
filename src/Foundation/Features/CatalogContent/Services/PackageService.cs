using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IPackageService
{
    void AddPackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation);
    IEnumerable<PackageEntry> GetPackageByEntry(ContentReference entry);
    IEnumerable<ContentReference> GetParentPackages(EntryContentBase entryContent);
    IEnumerable<PackageEntry> ListPackageEntries(ContentReference referenceToPackage); // Retrieve entries from a package
}

public class PackageService : IPackageService
{
    public void AddPackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        var newPackageEntry = new PackageEntry
        {
            GroupName = "GroupX",
            Quantity = 1.0m,
            SortOrder = 100,
            Parent = referenceToPackage,
            Child = referenceToPackageOrVariation
        };

        relationRepository.UpdateRelation(newPackageEntry);
    }

    public IEnumerable<PackageEntry> GetPackageByEntry(ContentReference entry)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations between package and package entry is PackageEntry
        var packageRelations = relationRepository.GetParents<PackageEntry>(entry);

        return packageRelations;
    }

    public IEnumerable<ContentReference> GetParentPackages(EntryContentBase entryContent)
    {
        var packageLinks = entryContent.GetParentPackages();
        return packageLinks;
    }

    public IEnumerable<PackageEntry> ListPackageEntries(ContentReference referenceToPackage)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations to package entries are of type PackageEntry
        var packageEntries = relationRepository.GetChildren<PackageEntry>(referenceToPackage);
        return packageEntries;
    }
}