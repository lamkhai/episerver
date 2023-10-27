using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    void AddNoteToOrderGroup(TOrderGroup orderGroup, OrderNoteModel model);
    TOrderGroup Create(string name);
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
    protected readonly IOrderRepository OrderRepository = ServiceLocator.Current.GetInstance<IOrderRepository>();

    protected readonly Guid ContactId = PrincipalInfo.CurrentPrincipal.GetContactId();

    private readonly IOrderGroupFactoryBuilder<TOrderGroup> _orderGroupFactoryBuilder;

    public OrderBuilder(IOrderGroupFactoryBuilder<TOrderGroup> orderGroupFactoryBuilder)
    {
        _orderGroupFactoryBuilder = orderGroupFactoryBuilder;
    }

    public virtual void AddNoteToOrderGroup(TOrderGroup orderGroup, OrderNoteModel model)
    {
        var note = _orderGroupFactoryBuilder.CreateOrderNote(orderGroup, model);

        orderGroup.Notes.Add(note);

        OrderRepository.Save(orderGroup);
    }

    public virtual TOrderGroup Create(string name)
    {
        return OrderRepository.Create<TOrderGroup>(ContactId, name);
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