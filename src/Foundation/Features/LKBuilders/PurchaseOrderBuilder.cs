namespace Foundation.Features.LKBuilders;

public interface IPurchaseOrderBuilder : IOrderBuilder<IPurchaseOrder>
{
}

public class PurchaseOrderBuilder : OrderBuilder<IPurchaseOrder>, IPurchaseOrderBuilder
{
    public PurchaseOrderBuilder(IOrderGroupFactoryBuilder<IPurchaseOrder> orderGroupFactoryBuilder) : base(orderGroupFactoryBuilder)
    {
    }
}