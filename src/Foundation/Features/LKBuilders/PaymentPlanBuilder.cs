namespace Foundation.Features.LKBuilders;

public interface IPaymentPlanBuilder : IOrderBuilder<IPaymentPlan>
{
}

public class PaymentPlanBuilder : OrderBuilder<IPaymentPlan>, IPaymentPlanBuilder
{
    public PaymentPlanBuilder(IOrderGroupFactoryBuilder<IPaymentPlan> orderGroupFactoryBuilder) : base(orderGroupFactoryBuilder)
    {
    }
}