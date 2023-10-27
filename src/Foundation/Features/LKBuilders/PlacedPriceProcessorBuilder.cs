using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IPlacedPriceProcessorBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
}

public class PlacedPriceProcessorBuilder<TOrderGroup> : IPlacedPriceProcessorBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IPlacedPriceProcessor PlacedPriceProcessor = ServiceLocator.Current.GetInstance<IPlacedPriceProcessor>();

    public virtual void Update(TOrderGroup orderGroup)
    {
        var validationIssues = new Dictionary<ILineItem, ValidationIssue>();

        //Update all placed prices on the cart
        orderGroup.UpdatePlacedPriceOrRemoveLineItems(PrincipalInfo.CurrentPrincipal.GetCustomerContact(),
          (item, issue) => validationIssues.Add(item, issue), PlacedPriceProcessor);

        //Update line item placed price
        var lineItem = orderGroup.GetAllLineItems().First();
        //lineItem.UpdatePlacedPrice(PrincipalInfo.CurrentPrincipal.GetCustomerContact(), orderGroup.Market,
        //  orderGroup.Currency, (item, issue) => validationIssues.Add(item, issue), PlacedPriceProcessor);

        //Update line item placed price
        PlacedPriceProcessor.UpdatePlacedPrice(lineItem, PrincipalInfo.CurrentPrincipal.GetCustomerContact(),
          orderGroup.MarketId, orderGroup.Currency, (item, issue) => validationIssues.Add(item, issue));
    }
}