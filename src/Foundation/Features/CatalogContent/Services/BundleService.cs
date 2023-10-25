using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IBundleService
{
    void AddBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation);
    IEnumerable<BundleEntry> GetBundleByEntry(ContentReference entry);
    IEnumerable<ContentReference> GetParentBundles(EntryContentBase entryContent);
    IEnumerable<BundleEntry> ListBundleEntries(ContentReference referenceToBundle); // Retrieve entries from a bundle
    void RemoveBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation);
    void UpdateBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation, decimal newQuantity);
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

    public void RemoveBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Define a relation matching the one to remove, or use
        // GetRelations to find the one you want to remove and pass that to
        // RemoveRelation
        var relationToRemove = new BundleEntry
        {
            Parent = referenceToBundle,
            Child = referenceToProductOrVariation
        };

        // Removes matching BundleEntry, or no action if no match exists
        relationRepository.RemoveRelation(relationToRemove);
    }

    public void UpdateBundleEntry(ContentReference referenceToBundle, ContentReference referenceToProductOrVariation, decimal newQuantity)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        var bundleEntries = relationRepository.GetChildren<BundleEntry>(referenceToBundle);

        // Find the matching BundleEntry by comparing the child, ignoring versions since relations are not version specific
        var matchingEntry = bundleEntries.FirstOrDefault(r => r.Child.CompareToIgnoreWorkID(referenceToProductOrVariation));

        // Update if there was a matching entry
        if (matchingEntry != null)
        {
            // Set new data
            matchingEntry.Quantity = newQuantity;

            relationRepository.UpdateRelation(matchingEntry);
        }
    }
}