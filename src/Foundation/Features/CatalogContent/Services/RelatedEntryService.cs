using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface IRelatedEntryService
{
    void AddAssociation(ContentReference referenceToEntry, ContentReference referenceToRelatedEntry);
    IEnumerable<Association> ListAssociations(ContentReference referenceToEntry);
    void RemoveAssociation(ContentReference referenceToEntry, ContentReference referenceToRelatedEntry);
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

    public void RemoveAssociation(ContentReference referenceToEntry, ContentReference referenceToRelatedEntry)
    {
        var associationRepository = ServiceLocator.Current.GetInstance<IAssociationRepository>();
        // Define an association matching the one to remove, or use
        // GetAssociations to find the one you want to remove and pass that to
        // RemoveAssociation
        var relationToRemove = new Association
        {
            // Group with name is required to match the correct association
            Group = new AssociationGroup
            {
                Name = "CrossSell"
            },
            // Source is required here to match the correct association
            Source = referenceToEntry,
            Target = referenceToRelatedEntry,
            // Type with id is required to match the correct association
            Type = new AssociationType
            {
                Id = AssociationType.DefaultTypeId
            }
        };
        // Removes matching Association, or no action if no match exists
        associationRepository.RemoveAssociation(relationToRemove);
    }
}