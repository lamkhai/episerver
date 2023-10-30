namespace Foundation.Features.LKBuilders;

public interface ICartBuilder<TCart> : IOrderBuilder<TCart>
    where TCart : class, ICart
{
    void AddLineItem(TCart cart, LineItemModel model);
    TCart LoadCart(string orderTypeName);
    TCart LoadOrCreateCart(string orderTypeName);
}

public class CartBuilder<TCart> : OrderBuilder<TCart>, ICartBuilder<TCart>
    where TCart : class, ICart
{
    protected readonly IOrderGroupCalculator OrderGroupCalculator = ServiceLocator.Current.GetInstance<IOrderGroupCalculator>();
    protected readonly IOrderGroupFactory OrderGroupFactory = ServiceLocator.Current.GetInstance<IOrderGroupFactory>();
    protected readonly IPaymentProcessor PaymentProcessor = ServiceLocator.Current.GetInstance<IPaymentProcessor>();

    public CartBuilder(IOrderGroupFactoryBuilder<TCart> orderGroupFactoryBuilder) : base(orderGroupFactoryBuilder)
    {
    }

    public virtual void AddLineItem(TCart cart, LineItemModel model)
    {
        var lineItem = cart.GetAllLineItems().FirstOrDefault(x => x.Code == model.Code && !x.IsGift);
        if (lineItem == null)
        {
            lineItem = cart.CreateLineItem(model.Code, OrderGroupFactory);
            lineItem.DisplayName = model.DisplayName;
            lineItem.Quantity = model.Quantity;
            cart.AddLineItem(lineItem, OrderGroupFactory);
        }
        else
        {
            var shipment = cart.GetFirstShipment();
            cart.UpdateLineItemQuantity(shipment, lineItem, lineItem.Quantity + model.Quantity);
        }
    }

    public virtual TCart LoadCart(string orderTypeName)
    {
        return OrderRepository.LoadCart<TCart>(ContactId, orderTypeName);
    }

    public virtual TCart LoadOrCreateCart(string orderTypeName)
    {
        return OrderRepository.LoadOrCreateCart<TCart>(ContactId, orderTypeName);
    }
}