namespace Foundation.Features.LKBuilders;

public interface ICartBuilder : IOrderBuilder<ICart>
{
}

public class CartBuilder : OrderBuilder<ICart>, ICartBuilder
{
}