using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IBundleService
{
    void AddBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation);
    IEnumerable<BundleEntry> GetBundleByEntry(ContentReference entry);
    IEnumerable<ContentReference> GetParentBundles(EntryContentBase entryContent);
    IEnumerable<BundleEntry> ListBundleEntries(ContentReference referenceToBundle); // Retrieve entries from a bundle
}

public class BundleService : IBundleService
{
    public void AddBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        var newBundleEntry = new BundleEntry
        {
            GroupName = "GroupX",
            Quantity = 1.0m,
            SortOrder = 100,
            Parent = referenceToBundle,
            Child = referenceToProductOrVariation
        };

        relationRepository.UpdateRelation(newBundleEntry);
    }

    public IEnumerable<BundleEntry> GetBundleByEntry(ContentReference entry)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations between bundle and bundle entry is BundleEntry
        var bundleRelations = relationRepository.GetParents<BundleEntry>(entry);

        return bundleRelations;
    }

    public IEnumerable<ContentReference> GetParentBundles(EntryContentBase entryContent)
    {
        var bundleLinks = entryContent.GetParentBundles();
        return bundleLinks;
    }

    public IEnumerable<BundleEntry> ListBundleEntries(ContentReference referenceToBundle)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations to bundle entries are of type BundleEntry
        var bundleEntries = relationRepository.GetChildren<BundleEntry>(referenceToBundle);
        return bundleEntries;
    }
}