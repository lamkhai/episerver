using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface ICategorizationService
{
    void AddCategory(ContentReference referenceToEntryOrCategory, ContentReference referenceToCategory);
    IEnumerable<NodeRelation> ListCategories(ContentReference referenceToEntryOrCategory);
    void RemoveCategory(ContentReference referenceToEntryOrCategory, ContentReference referenceToCategory);
}

public class CategorizationService : ICategorizationService
{
    public void AddCategory(ContentReference referenceToEntryOrCategory, ContentReference referenceToCategory)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        var newCategory = new NodeRelation
        {
            SortOrder = 100,
            Child = referenceToEntryOrCategory,
            Parent = referenceToCategory
        };
        relationRepository.UpdateRelation(newCategory);
    }

    public IEnumerable<NodeRelation> ListCategories(ContentReference referenceToEntryOrCategory)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        var categories = relationRepository.GetChildren<NodeRelation>(referenceToEntryOrCategory);
        return categories;
    }

    public void RemoveCategory(ContentReference referenceToEntryOrCategory, ContentReference referenceToCategory)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        // Define a relation matching the one to remove, or use
        // GetRelations to find the one you want to remove and pass that to
        // RemoveRelation
        var relationToRemove = new NodeRelation
        {
            Child = referenceToEntryOrCategory,
            Parent = referenceToCategory
        };
        // Removes matching NodeRelation, or no action if no match exists
        relationRepository.RemoveRelation(relationToRemove);
    }
}