using EPiServer.Commerce.Order.Calculator;

namespace Foundation.Features.LKBuilders;

public interface IReturnOrderFormCalculatorBuilder
{
    Money GetDiscountTotal(IReturnOrderForm returnOrderForm, Currency currency);
    Money GetHandlingTotal(IReturnOrderForm returnOrderForm, Currency currency);
    Money GetOrderDiscountTotal(IReturnOrderForm returnOrderForm, Currency currency);
    Money GetSubTotal(IReturnOrderForm returnOrderForm, Currency currency);
    Money GetReturnTaxTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency);
    Money GetTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency);
}

public class ReturnOrderFormCalculatorBuilder : DefaultReturnOrderFormCalculator, IReturnOrderFormCalculatorBuilder
{
    protected readonly IReturnOrderFormCalculator ReturnOrderFormCalculator = ServiceLocator.Current.GetInstance<IReturnOrderFormCalculator>();

    public ReturnOrderFormCalculatorBuilder(IShippingCalculator shippingCalculator) : base(shippingCalculator) { }

    protected override Money CalculateTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateSubtotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateHandlingTotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateReturnTaxTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }

    protected override void ValidateSubtotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Subtotal must be greater than 0");
        }
    }
    protected override void ValidateHandlingTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Handling total must be greater than 0");
        }
    }
    protected override void ValidateReturnTaxTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Return tax total must be greater than 0");
        }
    }

    public virtual Money GetDiscountTotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return ReturnOrderFormCalculator.GetDiscountTotal(returnOrderForm, currency);
    }

    public virtual Money GetHandlingTotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return ReturnOrderFormCalculator.GetHandlingTotal(returnOrderForm, currency);
    }

    public virtual Money GetOrderDiscountTotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return ReturnOrderFormCalculator.GetOrderDiscountTotal(returnOrderForm, currency);
    }

    public virtual Money GetSubTotal(IReturnOrderForm returnOrderForm, Currency currency)
    {
        return ReturnOrderFormCalculator.GetSubTotal(returnOrderForm, currency);
    }

    public virtual Money GetReturnTaxTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency)
    {
        return ReturnOrderFormCalculator.GetReturnTaxTotal(returnOrderForm, market, currency);
    }

    public virtual Money GetTotal(IReturnOrderForm returnOrderForm, IMarket market, Currency currency)
    {
        return ReturnOrderFormCalculator.GetTotal(returnOrderForm, market, currency);
    }
}