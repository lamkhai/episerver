using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IRelatedEntryService
{
    void AddAssociation(ContentReference referenceToEntry, ContentReference referenceToRelatedEntry);
    IEnumerable<Association> ListAssociations(ContentReference referenceToEntry);
}

public class RelatedEntryService : IRelatedEntryService
{
    public void AddAssociation(ContentReference referenceToEntry, ContentReference referenceToRelatedEntry)
    {
        var associationRepository = ServiceLocator.Current.GetInstance<IAssociationRepository>();
        var newAssociation = new Association
        {
            Group = new AssociationGroup
            {
                Name = "CrossSell",
                Description = "",
                SortOrder = 100
            },
            SortOrder = 100,
            Source = referenceToEntry,
            Target = referenceToRelatedEntry,
            Type = new AssociationType
            {
                Id = AssociationType.DefaultTypeId,
                Description = ""
            }
        };
        associationRepository.UpdateAssociation(newAssociation);
    }

    public IEnumerable<Association> ListAssociations(ContentReference referenceToEntry)
    {
        var associationRepository = ServiceLocator.Current.GetInstance<IAssociationRepository>();
        var associations = associationRepository.GetAssociations(referenceToEntry);
        return associations;
    }
}