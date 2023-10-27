namespace Foundation.Features.LKBuilders;

public interface IOrderGroupFactoryBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    IOrderForm CreateOrderForm(TOrderGroup orderGroup, OrderFormModel model);
    void WorkWithShipment(TOrderGroup orderGroup);
}

public class OrderGroupFactoryBuilder<TOrderGroup> : IOrderGroupFactoryBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IOrderGroupFactory OrderGroupFactory = ServiceLocator.Current.GetInstance<IOrderGroupFactory>();

    public virtual IOrderForm CreateOrderForm(TOrderGroup orderGroup, OrderFormModel model)
    {
        var orderForm = OrderGroupFactory.CreateOrderForm(orderGroup);
        orderGroup.Forms.Add(orderForm);

        if (model != null)
        {
            if (!string.IsNullOrEmpty(model.Name))
            {
                orderForm.Name = model.Name;
            }
        }

        return orderForm;
    }

    public virtual void WorkWithShipment(TOrderGroup orderGroup)
    {
        //Create and add shipment to first form
        var shipment = OrderGroupFactory.CreateShipment(orderGroup);

        //Pass in OrderGroupFactory for unit testing as a from will be created if there is none o
        orderGroup.AddShipment(shipment, OrderGroupFactory);

        //Set address after adding to collection because of limitation in implementation
        shipment.ShippingAddress = OrderGroupFactory.CreateOrderAddress(orderGroup);

        //Create and add shipment to second form (b2b)
        var secondForm = orderGroup.Forms.Last();
        orderGroup.AddShipment(secondForm, shipment);

        //Remove shipment from first form
        orderGroup.GetFirstForm().Shipments.Remove(shipment);

        //Remove shipment from second form (b2b)
        orderGroup.Forms.Last().Shipments.Remove(shipment);
    }
}

public class OrderFormModel
{
    public string Name { get; set; }
}