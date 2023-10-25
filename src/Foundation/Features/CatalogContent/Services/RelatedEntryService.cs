using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IRelatedEntryService
{
    IEnumerable<Association> ListAssociations(ContentReference referenceToEntry);
}

public class RelatedEntryService : IRelatedEntryService
{
    public IEnumerable<Association> ListAssociations(ContentReference referenceToEntry)
    {
        var associationRepository = ServiceLocator.Current.GetInstance<IAssociationRepository>();
        var associations = associationRepository.GetAssociations(referenceToEntry);
        return associations;
    }
}