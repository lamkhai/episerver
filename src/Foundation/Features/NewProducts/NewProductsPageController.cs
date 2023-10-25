using Foundation.Features.Search;
using Foundation.Infrastructure.Cms.Settings;

namespace Foundation.Features.NewProducts
{
    public class NewProductsPageController : PageController<NewProductsPage>
    {
        private readonly ISearchService _searchService;
        private readonly ISettingsService _settingsService;

        public NewProductsPageController(
            ISearchService searchService,
            ISettingsService settingsService)
        {
            _searchService = searchService;
            _settingsService = settingsService;
        }

        public ActionResult Index(NewProductsPage currentPage, int page = 1)
        {
            var searchsettings = _settingsService.GetSiteSettings<SearchSettings>();
            var model = new NewProductsPageViewModel(currentPage)
            {
                ProductViewModels = _searchService.SearchNewProducts(currentPage, out var pages, searchsettings?.SearchCatalog ?? 0, page),
                PageNumber = page,
                Pages = pages
            };

            return View(model);
        }

        [HttpGet("LoadAProduct"), AllowAnonymous] // https://localhost:44397/en/new-arrivals/LoadAProduct?productId=
        public IActionResult LoadAProduct(int productId)
        {
            //Get the currently configured content loader and reference converter from the service locator
            var contentLoader = ServiceLocator.Current.GetInstance<IContentLoader>();
            var referenceConverter = ServiceLocator.Current.GetInstance<ReferenceConverter>();

            //We use the content link builder to get the contentlink to our product
            var productLink = referenceConverter.GetContentLink(productId, CatalogContentType.CatalogEntry, 0);

            //Get the product using CMS API
            var productContent = contentLoader.Get<CatalogContentBase>(productLink);

            //The commerce content name represents the name of the product
            //var productName = productContent.Name;

            return Ok(new
            {
                productContent.ContentGuid,
                productContent.CatalogId,
                productContent.ContentType,
                productContent.ContentTypeID,
                productContent.Name,
                productContent.RouteSegment,
                productContent.Status,
                productContent.StartPublish,
                productContent.StopPublish,
            });
        }
    }
}