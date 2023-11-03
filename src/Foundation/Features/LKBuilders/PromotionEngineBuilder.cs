using Mediachase.Commerce.Orders;

namespace Foundation.Features.LKBuilders;

public interface IPromotionEngineBuilder
{
    IEnumerable<RewardDescription> Calculate();
    IEnumerable<RewardDescription> Evaluate(ContentReference entryLink);
    IEnumerable<RewardDescription> Evaluate(IEnumerable<ContentReference> entryLinks);
    PromotionFilterContext Filter(PromotionFilterContext filterContext, IEnumerable<string> couponCodes);
    IEnumerable<DiscountedEntry> GetPrices(ContentReference entryLink);
    IEnumerable<PromotionItems> GetPromotionItemsForCampaign(ContentReference campaign);
    void Report(IEnumerable<PromotionInformation> appliedPromotions);
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
        // cart.ApplyDiscounts(PromotionEngine, new PromotionEngineSettings() { ExclusionLevel = ExclusionLevel.Unit });
        return PromotionEngine.Run(cart, new PromotionEngineSettings() { ExclusionLevel = ExclusionLevel.Unit });
    }

    public virtual IEnumerable<RewardDescription> Evaluate(ContentReference entryLink)
    {
        return PromotionEngine.Evaluate(entryLink);
    }

    public virtual IEnumerable<RewardDescription> Evaluate(IEnumerable<ContentReference> entryLinks)
    {
        return PromotionEngine.Evaluate(entryLinks);
    }

    public virtual PromotionFilterContext Filter(PromotionFilterContext filterContext, IEnumerable<string> couponCodes)
    {
        foreach (var promotion in filterContext.IncludedPromotions)
        {
            var couponCode = promotion.Coupon.Code;
            if (String.IsNullOrEmpty(couponCode))
            {
                continue;
            }

            if (couponCodes.Contains(couponCode, StringComparer.OrdinalIgnoreCase))
            {
                filterContext.AddCouponCode(promotion.ContentGuid, couponCode);
            }
            else
            {
                filterContext.ExcludePromotion(
                  promotion,
                  FulfillmentStatus.CouponCodeRequired,
                  filterContext.RequestedStatuses.HasFlag(RequestFulfillmentStatus.NotFulfilled));
            }
        }
        return filterContext;
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

    public void Report(IEnumerable<PromotionInformation> appliedPromotions)
    {
        // Store any information needed about the coupon codes that were used.
    }
}