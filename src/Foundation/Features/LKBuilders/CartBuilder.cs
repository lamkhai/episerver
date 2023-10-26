namespace Foundation.Features.LKBuilders;

public interface ICartBuilder<TCart> : IOrderBuilder<TCart>
    where TCart : class, ICart
{
    TCart LoadCart(string orderTypeName);
    TCart LoadOrCreateCart(string orderTypeName);
}

public class CartBuilder<TCart> : OrderBuilder<TCart>, ICartBuilder<TCart>
    where TCart : class, ICart
{
    public virtual TCart LoadCart(string orderTypeName)
    {
        return OrderRepository.LoadCart<TCart>(ContactId, orderTypeName);
    }

    public virtual TCart LoadOrCreateCart(string orderTypeName)
    {
        return OrderRepository.LoadOrCreateCart<TCart>(ContactId, orderTypeName);
    }
}