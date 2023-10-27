namespace Foundation.Features.LKBuilders;

public interface IOrderGroupFactoryBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    IOrderForm CreateOrderForm(TOrderGroup orderGroup, OrderFormModel model);

    void WorkWithLineItems(TOrderGroup orderGroup, LineItemModel model);
    void WorkWithPayments(TOrderGroup orderGroup);
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

    public virtual void WorkWithLineItems(TOrderGroup orderGroup, LineItemModel model)
    {
        //add line item to first shipment on first form
        var lineItem = OrderGroupFactory.CreateLineItem(model?.Code, orderGroup);

        //use orderFactory for unit testing
        orderGroup.AddLineItem(lineItem, OrderGroupFactory);

        //add line item to second shipment on first form
        var shipment = orderGroup.GetFirstForm().Shipments.Last();
        orderGroup.AddLineItem(shipment, lineItem);

        //add line item to second form first shipment
        var orderForm = orderGroup.Forms.Last();

        //add orderFactory for unit testing 
        orderGroup.AddLineItem(orderForm, lineItem, OrderGroupFactory);

        //remove line item from first form first shipment 
        orderGroup.GetFirstShipment().LineItems.Remove(lineItem);

        //remove line item from first form second shipment
        orderGroup.GetFirstForm().Shipments.Last().LineItems.Remove(lineItem);

        //remove line item from second form first shipment (b2b)
        orderGroup.Forms.Last().Shipments.First().LineItems.Remove(lineItem);
    }

    public virtual void WorkWithPayments(TOrderGroup orderGroup)
    {
        //Create and add payment to first form
        var creditCard = OrderGroupFactory.CreateCardPayment(orderGroup);
        var invoice = OrderGroupFactory.CreatePayment(orderGroup);

        //Pass in OrderGroupFactory for unit testing as a from will be created if there is none on the cart.
        orderGroup.AddPayment(creditCard, OrderGroupFactory);
        orderGroup.AddPayment(invoice, OrderGroupFactory);

        //Set address after adding to collection becasue of limitation in implementation
        creditCard.BillingAddress = OrderGroupFactory.CreateOrderAddress(orderGroup);

        //Create and add payment to second form (b2b)
        var secondForm = orderGroup.Forms.Last();
        orderGroup.AddPayment(secondForm, creditCard);
        orderGroup.AddPayment(secondForm, invoice);

        //Set address after adding to collection becasue of limitation in implementation
        creditCard.BillingAddress = OrderGroupFactory.CreateOrderAddress(orderGroup);

        //Remove payment from first form
        orderGroup.GetFirstForm().Payments.Remove(invoice);

        //Remove payment from second form (b2b)
        orderGroup.Forms.Last().Payments.Remove(invoice);
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

public class LineItemModel
{
    public string Code { get; set; }
}

public class OrderFormModel
{
    public string Name { get; set; }
}