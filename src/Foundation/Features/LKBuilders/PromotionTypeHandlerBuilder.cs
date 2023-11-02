using EPiServer.Commerce.Marketing.Promotions;

namespace Foundation.Features.LKBuilders;

public interface IPromotionTypeHandlerBuilder
{
    void DisableBuiltinPromotions();
    void DisableBuyQuantityGetFreeItems();
    void EnableBuyQuantityGetFreeItems();
}

public class PromotionTypeHandlerBuilder : IPromotionTypeHandlerBuilder
{
    protected readonly PromotionTypeHandler PromotionTypeHandler = ServiceLocator.Current.GetInstance<PromotionTypeHandler>();

    public virtual void DisableBuiltinPromotions()
    {
        PromotionTypeHandler.DisableBuiltinPromotions();

    }

    public virtual void DisableBuyQuantityGetFreeItems()
    {
        PromotionTypeHandler.DisablePromotions(new[] { typeof(BuyQuantityGetFreeItems) });
    }

    public virtual void EnableBuyQuantityGetFreeItems()
    {
        PromotionTypeHandler.EnablePromotions(new[] { typeof(BuyQuantityGetFreeItems) });
    }
}