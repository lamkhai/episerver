using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

// Research: Get the entries of a bundle

public interface IBundleService
{
    IEnumerable<BundleEntry> ListBundleEntries(ContentReference referenceToBundle); // Retrieve entries from a bundle
}

public class BundleService : IBundleService
{
    public IEnumerable<BundleEntry> ListBundleEntries(ContentReference referenceToBundle)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();

        // Relations to bundle entries are of type BundleEntry
        var bundleEntries = relationRepository.GetChildren<BundleEntry>(referenceToBundle);
        return bundleEntries;
    }
}