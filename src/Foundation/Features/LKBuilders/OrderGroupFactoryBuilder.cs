using EPiServer.Core.Internal;
using EPiServer.Security;
using Mediachase.Commerce.Orders;

namespace Foundation.Features.LKBuilders;

public interface IOrderGroupFactoryBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    IOrderForm CreateOrderForm(TOrderGroup orderGroup, OrderFormModel model);
    IOrderNote CreateOrderNote(TOrderGroup orderGroup, OrderNoteModel model);

    void WorkWithAddresses(TOrderGroup orderGroup, AddressModel model);
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

    public virtual IOrderNote CreateOrderNote(TOrderGroup orderGroup, OrderNoteModel model)
    {
        var note = OrderGroupFactory.CreateOrderNote(orderGroup);

        if (model != null)
        {
            note.CustomerId = model.CustomerId;
            note.Type = model.Type.ToString();
            note.Title = model.Title;
            note.Detail = model.Detail;
            note.Created = DateTime.UtcNow;
        }

        return note;
    }

    public virtual void WorkWithAddresses(TOrderGroup orderGroup, AddressModel model)
    {
        var address = OrderGroupFactory.CreateOrderAddress(orderGroup);

        //Use Id to reuse
        address.Id = model?.Id;
        orderGroup.GetFirstForm().Payments.First().BillingAddress = address;

        //Since there is already an address with model?.Id it will use that address instead of creating another one on the order.
        var reuseOtherAddress = OrderGroupFactory.CreateOrderAddress(orderGroup);
        reuseOtherAddress.Id = model?.Id;
        orderGroup.GetFirstShipment().ShippingAddress = reuseOtherAddress;

        //Region Name and Region Code should be used when dealing with states
        address.RegionName = model?.RegionName;
        address.RegionCode = model?.RegionCode;
        address.CountryCode = model?.CountryCode;
        address.CountryName = model?.CountryName;
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

public class AddressModel
{
    public string Id { get; set; }
    public string RegionName { get; set; }
    public string RegionCode { get; set; }
    public string CountryCode { get; set; }
    public string CountryName { get; set; }
}

public class LineItemModel
{
    public string Code { get; set; }
    public string DisplayName { get; set; }
    public decimal Quantity { get; set; }
}

public class OrderFormModel
{
    public string Name { get; set; }
}

public class OrderNoteModel
{
    public Guid CustomerId { get; set; }
    public OrderNoteTypes Type { get; set; }
    public string Title { get; set; }
    public string Detail { get; set; }
}