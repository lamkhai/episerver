using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IPackageService
{
    void AddPackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation);
    IEnumerable<PackageEntry> GetPackageByEntry(ContentReference entry);
    IEnumerable<ContentReference> GetParentPackages(EntryContentBase entryContent);
    IEnumerable<PackageEntry> ListPackageEntries(ContentReference referenceToPackage); // Retrieve entries from a package
    void RemovePackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation);
    void UpdatePackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation, decimal newQuantity);
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

    public void RemovePackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Define a relation matching the one to remove, or use
        // GetRelations to find the one you want to remove and pass that to
        // RemoveRelation
        var relationToRemove = new PackageEntry
        {
            Parent = referenceToPackage,
            Child = referenceToPackageOrVariation
        };

        // Removes matching PackageEntry, or no action if no match exists
        relationRepository.RemoveRelation(relationToRemove);
    }

    public void UpdatePackageEntry(ContentReference referenceToPackage, ContentReference referenceToPackageOrVariation, decimal newQuantity)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        var packageEntries = relationRepository.GetChildren<PackageEntry>(referenceToPackage);

        // Find the matching PackageEntry by comparing the child, ignoring versions since relations are not version specific
        var matchingEntry = packageEntries.FirstOrDefault(r => r.Child.CompareToIgnoreWorkID(referenceToPackageOrVariation));

        // Update if there was a matching entry
        if (matchingEntry != null)
        {
            // Set new data
            matchingEntry.Quantity = newQuantity;

            relationRepository.UpdateRelation(matchingEntry);
        }
    }
}