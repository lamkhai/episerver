namespace Foundation.Features.LKBuilders;

public interface IPurchaseOrderBuilder : IOrderBuilder<IPurchaseOrder>
{
    OrderProcessingResult CancelOrder(IPurchaseOrder purchaseOrder);
    OrderProcessingResult HoldOrder(IPurchaseOrder purchaseOrder);
    OrderProcessingResult ProcessOrder(IPurchaseOrder purchaseOrder);
    OrderProcessingResult ReleaseOrder(IPurchaseOrder purchaseOrder);
}

public class PurchaseOrderBuilder : OrderBuilder<IPurchaseOrder>, IPurchaseOrderBuilder
{
    protected readonly IPurchaseOrderProcessor PurchaseOrderProcessor = ServiceLocator.Current.GetInstance<IPurchaseOrderProcessor>();

    public PurchaseOrderBuilder(IOrderGroupFactoryBuilder<IPurchaseOrder> orderGroupFactoryBuilder) : base(orderGroupFactoryBuilder)
    {
    }

    public virtual OrderProcessingResult CancelOrder(IPurchaseOrder purchaseOrder)
    {
        return PurchaseOrderProcessor.CancelOrder(purchaseOrder);
    }

    public virtual OrderProcessingResult HoldOrder(IPurchaseOrder purchaseOrder)
    {
        return PurchaseOrderProcessor.HoldOrder(purchaseOrder);
    }

    public virtual OrderProcessingResult ProcessOrder(IPurchaseOrder purchaseOrder)
    {
        return PurchaseOrderProcessor.ProcessOrder(purchaseOrder);
    }

    public virtual OrderProcessingResult ReleaseOrder(IPurchaseOrder purchaseOrder)
    {
        return PurchaseOrderProcessor.ReleaseOrder(purchaseOrder);
    }
}