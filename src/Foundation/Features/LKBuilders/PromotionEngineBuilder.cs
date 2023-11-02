using Mediachase.Commerce.Orders;

namespace Foundation.Features.LKBuilders;

public interface IPromotionEngineBuilder
{
    IEnumerable<RewardDescription> Calculate();
    IEnumerable<RewardDescription> Evaluate(ContentReference entryLink);
    IEnumerable<RewardDescription> Evaluate(IEnumerable<ContentReference> entryLinks);
    IEnumerable<DiscountedEntry> GetPrices(ContentReference entryLink);
    IEnumerable<PromotionItems> GetPromotionItemsForCampaign(ContentReference campaign);
}

public class PromotionEngineBuilder : IPromotionEngineBuilder
{
    private readonly ICartBuilder<ICart> _cartBuilder;

    protected readonly IMarket Market = ServiceLocator.Current.GetInstance<IMarket>();
    protected readonly IPromotionEngine PromotionEngine = ServiceLocator.Current.GetInstance<IPromotionEngine>();

    public PromotionEngineBuilder(ICartBuilder<ICart> cartBuilder)
    {
        _cartBuilder = cartBuilder;
    }

    public virtual IEnumerable<RewardDescription> Calculate()
    {
        var cart = _cartBuilder.LoadOrCreateCart(Cart.DefaultName);
        return PromotionEngine.Run(cart);
    }

    public virtual IEnumerable<RewardDescription> Evaluate(ContentReference entryLink)
    {
        return PromotionEngine.Evaluate(entryLink);
    }

    public virtual IEnumerable<RewardDescription> Evaluate(IEnumerable<ContentReference> entryLinks)
    {
        return PromotionEngine.Evaluate(entryLinks);
    }

    public virtual IEnumerable<DiscountedEntry> GetPrices(ContentReference entryLink)
    {
        // var market = currentMarket.GetCurrentMarket();
        // PromotionEngine.GetDiscountPrices(entryLink, market, market.DefaultCurrency);
        return PromotionEngine.GetDiscountPrices(entryLink, Market);
    }

    public virtual IEnumerable<PromotionItems> GetPromotionItemsForCampaign(ContentReference campaign)
    {
        return PromotionEngine.GetPromotionItemsForCampaign(campaign);
    }
}