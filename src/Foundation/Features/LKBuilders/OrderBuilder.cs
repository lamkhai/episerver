using EPiServer.Security;
using Mediachase.Commerce.Security;

namespace Foundation.Features.LKBuilders;

public interface IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    TOrderGroup Create(string name);
}

public class OrderBuilder<TOrderGroup> : IOrderBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly IOrderRepository OrderRepository = ServiceLocator.Current.GetInstance<IOrderRepository>();

    public virtual TOrderGroup Create(string name)
    {
        var contactId = PrincipalInfo.CurrentPrincipal.GetContactId();
        return OrderRepository.Create<TOrderGroup>(contactId, name);
    }
}