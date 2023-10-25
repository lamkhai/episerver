using EPiServer.Commerce.Catalog.Linking;

namespace Foundation.Features.CatalogContent.Services;

public interface ICategorizationService
{
    IEnumerable<NodeRelation> ListCategories(ContentReference referenceToEntryOrCategory);
}

public class CategorizationService : ICategorizationService
{
    public IEnumerable<NodeRelation> ListCategories(ContentReference referenceToEntryOrCategory)
    {
        var relationRepository = ServiceLocator.Current.GetInstance<IRelationRepository>();
        var categories = relationRepository.GetChildren<NodeRelation>(referenceToEntryOrCategory);
        return categories;
    }
}