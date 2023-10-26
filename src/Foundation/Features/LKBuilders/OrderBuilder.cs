using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    TOrderGroup Create(string name);
    IOrderForm CreateOrderForm(TOrderGroup orderGroup, string name);
    void Delete(OrderReference orderLink);
    TOrderGroup Load(int orderGroupId);
    TOrderGroup Load(OrderReference orderReference);
    IEnumerable<TOrderGroup> LoadAllForContactId(string name);
    OrderReference Save(TOrderGroup order);
    OrderReference SaveAsPaymentPlan(TOrderGroup order);
    OrderReference SaveAsPurchaseOrder(TOrderGroup order);
}

public class OrderBuilder<TOrderGroup> : IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IOrderGroupFactory OrderGroupFactory = ServiceLocator.Current.GetInstance<IOrderGroupFactory>();
    protected readonly IOrderRepository OrderRepository = ServiceLocator.Current.GetInstance<IOrderRepository>();

    protected readonly Guid ContactId = PrincipalInfo.CurrentPrincipal.GetContactId();

    public virtual TOrderGroup Create(string name)
    {
        return OrderRepository.Create<TOrderGroup>(ContactId, name);
    }

    public virtual IOrderForm CreateOrderForm(TOrderGroup orderGroup, string name)
    {
        var orderForm = OrderGroupFactory.CreateOrderForm(orderGroup);
        orderGroup.Forms.Add(orderForm);
        orderForm.Name = name;
        return orderForm;
    }

    public virtual void Delete(OrderReference orderLink)
    {
        OrderRepository.Delete(orderLink);
    }

    public virtual TOrderGroup Load(int orderGroupId)
    {
        return OrderRepository.Load<TOrderGroup>(orderGroupId);
    }

    public virtual TOrderGroup Load(OrderReference orderReference)
    {
        return OrderRepository.Load(orderReference) as TOrderGroup;
    }

    public virtual IEnumerable<TOrderGroup> LoadAllForContactId(string name)
    {
        return OrderRepository.Load<TOrderGroup>(ContactId, name);
    }

    public virtual OrderReference Save(TOrderGroup order)
    {
        return OrderRepository.Save(order);
    }

    public virtual OrderReference SaveAsPaymentPlan(TOrderGroup order)
    {
        return OrderRepository.SaveAsPaymentPlan(order);
    }

    public virtual OrderReference SaveAsPurchaseOrder(TOrderGroup order)
    {
        return OrderRepository.SaveAsPurchaseOrder(order);
    }
}