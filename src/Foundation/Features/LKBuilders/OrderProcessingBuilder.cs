using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IOrderProcessingBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    IEnumerable<RewardDescription> ApplyDiscounts(TOrderGroup orderGroup);
    IEnumerable<PaymentProcessingResult> ProcessPayments(TOrderGroup orderGroup);
    void UpdateInventoryOrRemoveLineItems(TOrderGroup orderGroup);
    bool UpdatePlacedPrice(TOrderGroup orderGroup);
    void Validate(TOrderGroup orderGroup);
}

public class OrderProcessingBuilder<TOrderGroup> : IOrderProcessingBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IInventoryProcessor InventoryProcessor = ServiceLocator.Current.GetInstance<IInventoryProcessor>();
    protected readonly ILineItemValidator LineItemValidator = ServiceLocator.Current.GetInstance<ILineItemValidator>();
    protected readonly IOrderGroupCalculator OrderGroupCalculator = ServiceLocator.Current.GetInstance<IOrderGroupCalculator>();
    protected readonly IPaymentProcessor PaymentProcessor = ServiceLocator.Current.GetInstance<IPaymentProcessor>();
    protected readonly IPlacedPriceProcessor PlacedPriceProcessor = ServiceLocator.Current.GetInstance<IPlacedPriceProcessor>();
    protected readonly IPromotionEngine PromotionEngine = ServiceLocator.Current.GetInstance<IPromotionEngine>();
    
    public virtual IEnumerable<RewardDescription> ApplyDiscounts(TOrderGroup orderGroup)
    {
        //run apply discounts on the cart
        var rewardDescriptions = orderGroup.ApplyDiscounts(PromotionEngine, new PromotionEngineSettings());
        //  rewardDescriptions = PromotionEngine.Run(orderGroup, new PromotionEngineSettings());

        return rewardDescriptions;
    }

    public virtual IEnumerable<PaymentProcessingResult> ProcessPayments(TOrderGroup orderGroup)
    {
        //Process payments for the cart
        return orderGroup.ProcessPayments(PaymentProcessor, OrderGroupCalculator);
    }

    public virtual void UpdateInventoryOrRemoveLineItems(TOrderGroup orderGroup)
    {
        var validationIssues = new Dictionary<ILineItem, ValidationIssue>();

        //Update Inventory on cart
        orderGroup.UpdateInventoryOrRemoveLineItems((item, issue) => validationIssues.Add(item, issue), InventoryProcessor);

        //Update inventory on shipment line items
        var shipment = orderGroup.GetFirstShipment();
        InventoryProcessor.UpdateInventoryOrRemoveLineItem(shipment, (item, issue) => validationIssues.Add(item, issue));
    }

    public virtual bool UpdatePlacedPrice(TOrderGroup orderGroup)
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
        return PlacedPriceProcessor.UpdatePlacedPrice(lineItem, PrincipalInfo.CurrentPrincipal.GetCustomerContact(),
            orderGroup.MarketId, orderGroup.Currency, (item, issue) => validationIssues.Add(item, issue));
    }

    public virtual void Validate(TOrderGroup orderGroup)
    {
        var validationIssues = new Dictionary<ILineItem, ValidationIssue>();

        //Check all line items on cart
        orderGroup.ValidateOrRemoveLineItems((item, issue) => validationIssues.Add(item, issue), LineItemValidator);

        //Check one lineitem
        var lineItem = orderGroup.GetAllLineItems().First();
        if (!LineItemValidator.Validate(lineItem, orderGroup.MarketId, (item, issue) => validationIssues.Add(item, issue)))
        {
            //Check validationIssues for problems
        }
    }
}