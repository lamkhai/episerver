using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    TOrderGroup Create(string name);
    TOrderGroup Load(int orderGroupId);
    TOrderGroup Load(OrderReference orderReference);
    IEnumerable<TOrderGroup> LoadAllForContactId(string name);
}

public class OrderBuilder<TOrderGroup> : IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IOrderRepository OrderRepository = ServiceLocator.Current.GetInstance<IOrderRepository>();
    protected readonly Guid ContactId = PrincipalInfo.CurrentPrincipal.GetContactId();

    public virtual TOrderGroup Create(string name)
    {
        return OrderRepository.Create<TOrderGroup>(ContactId, name);
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
}