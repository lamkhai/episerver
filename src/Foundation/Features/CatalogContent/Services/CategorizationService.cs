using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface ICategorizationService
{
    void AddCategory(ContentReference referenceToEntryOrCategory, ContentReference referenceToCategory);
    IEnumerable<NodeRelation> ListCategories(ContentReference referenceToEntryOrCategory);
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
}