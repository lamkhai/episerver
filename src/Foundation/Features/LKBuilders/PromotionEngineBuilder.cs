namespace Foundation.Features.LKBuilders;

public interface IPromotionEngineBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    IEnumerable<RewardDescription> Update(TOrderGroup orderGroup);
}

public class PromotionEngineBuilder<TOrderGroup> : IPromotionEngineBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IPromotionEngine PromotionEngine = ServiceLocator.Current.GetInstance<IPromotionEngine>();

    public virtual IEnumerable<RewardDescription> Update(TOrderGroup orderGroup)
    {
        //run apply discounts on the cart
        var rewardDescriptions = orderGroup.ApplyDiscounts(PromotionEngine, new PromotionEngineSettings());
        //  rewardDescriptions = PromotionEngine.Run(orderGroup, new PromotionEngineSettings());

        return rewardDescriptions;
    }
}