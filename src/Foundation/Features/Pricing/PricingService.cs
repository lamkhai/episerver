using EPiServer.ServiceApi.Commerce.Models.Catalog;

namespace Foundation.Features.Pricing;

public interface IPricingService
{
    void DeletePriceDetailValue(ContentReference catalogContentReference);
    IList<IPriceDetailValue> ListAllPriceDetailValue(ContentReference catalogContentReference);
    IList<IPriceDetailValue> ListPriceDetailValueWithPaging(ContentReference catalogContentReference, int offset, int numberOfItems, out int totalCount);
    IList<IPriceDetailValue> ListPriceDetailWithPriceFilter(ContentReference catalogContentReference, int offset, int numberOfItems, out int totalCount);
    IPriceDetailValue SavePriceDetailValue(Entry catalogEntry);
}

public class PricingService : IPricingService
{
    public void DeletePriceDetailValue(ContentReference catalogContentReference)
    {
        var priceDetailService = ServiceLocator.Current.GetInstance<IPriceDetailService>();

        var priceList = priceDetailService.List(catalogContentReference);
        IEnumerable<long> priceValueIds = priceList.Select(p => p.PriceValueId).ToList(); // List price value Id

        priceDetailService.Delete(priceValueIds);
    }

    public IList<IPriceDetailValue> ListAllPriceDetailValue(ContentReference catalogContentReference)
    {
        var priceDetailService = ServiceLocator.Current.GetInstance<IPriceDetailService>();

        // Gets the price details of a CatalogEntry
        return priceDetailService.List(catalogContentReference);
    }

    public IList<IPriceDetailValue> ListPriceDetailValueWithPaging(ContentReference catalogContentReference, int offset, int numberOfItems, out int totalCount)
    {
        var priceDetailService = ServiceLocator.Current.GetInstance<IPriceDetailService>();

        // Gets price details for the CatalogEntry with paging
        return priceDetailService.List(catalogContentReference, offset, numberOfItems, out totalCount);
    }

    public IList<IPriceDetailValue> ListPriceDetailWithPriceFilter(ContentReference catalogContentReference, int offset, int numberOfItems, out int totalCount)
    {
        var priceDetailService = ServiceLocator.Current.GetInstance<IPriceDetailService>();

        // Gets price details for the CatalogEntry with paging support and filter for market, currencies and customer pricings.
        MarketId marketId = new MarketId("ER");
        PriceFilter filter = new PriceFilter();
        filter.Currencies = new List<Currency> { Currency.EUR, Currency.GBP };
        return priceDetailService.List(catalogContentReference, marketId, filter, offset, numberOfItems, out totalCount);
    }

    public IPriceDetailValue SavePriceDetailValue(Entry catalogEntry)
    {
        var priceDetailService = ServiceLocator.Current.GetInstance<IPriceDetailService>();

        // Set Price Detail value for Catalog Entry.
        var priceDetailValue = new PriceDetailValue
        {
            CatalogKey = new CatalogKey(catalogEntry.Code),
            MarketId = new MarketId("US"),
            CustomerPricing = CustomerPricing.AllCustomers,
            ValidFrom = DateTime.UtcNow.AddDays(-7),
            ValidUntil = DateTime.UtcNow.AddDays(7),
            MinQuantity = 0m,
            UnitPrice = new Money(100m, Currency.USD)
        };

        return priceDetailService.Save(priceDetailValue);
    }
}