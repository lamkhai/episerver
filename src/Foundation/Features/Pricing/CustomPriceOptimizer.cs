namespace Foundation.Features.Pricing;

public class CustomPriceOptimizer : IPriceOptimizer
{
    public IEnumerable<IOptimizedPriceValue> OptimizePrices(IEnumerable<IPriceValue> prices)
    {
        return prices.GroupBy(p => new { p.CatalogKey, p.MinQuantity, p.MarketId, p.ValidFrom, p.CustomerPricing, p.UnitPrice.Currency })
          .Select(g => g.OrderByDescending(c => c.UnitPrice.Amount).First()).Select(p => new OptimizedPriceValue(p, null));
    }
}