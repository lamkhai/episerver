using EPiServer.Commerce.Order.Calculator;

namespace Foundation.Features.LKBuilders;

public interface IOrderFormCalculatorBuilder
{
    Money GetDiscountTotal(IOrderForm orderForm, Currency currency);
    Money GetHandlingTotal(IOrderForm orderForm, Currency currency);
    OrderFormTotals GetOrderFormTotals(IOrderForm orderForm, IMarket market, Currency currency);
    Money GetShippingSubTotal(IOrderForm orderForm, IMarket market, Currency currency);
    Money GetSubTotal(IOrderForm orderForm, Currency currency);
    Money GetTaxTotal(IOrderForm orderForm, IMarket market, Currency currency);
    Money GetTotal(IOrderForm orderForm, IMarket market, Currency currency);
}

public class OrderFormCalculatorBuilder : DefaultOrderFormCalculator, IOrderFormCalculatorBuilder
{
    protected readonly IOrderFormCalculator OrderFormCalculator = ServiceLocator.Current.GetInstance<IOrderFormCalculator>();

    public OrderFormCalculatorBuilder(IShippingCalculator shippingCalculator) : base(shippingCalculator) { }

    protected override Money CalculateTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateSubtotal(IOrderForm orderForm, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateHandlingTotal(IOrderForm orderForm, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateShippingSubTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateTaxTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }

    protected override void ValidateTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Order total must be greater than 0");
        }
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
    protected override void ValidateShippingSubTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Shipping subtotal must be greater than 0");
        }
    }
    protected override void ValidateTaxTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Tax total must be greater than 0");
        }
    }

    public virtual Money GetDiscountTotal(IOrderForm orderForm, Currency currency)
    {
        return OrderFormCalculator.GetDiscountTotal(orderForm, currency);
    }

    public virtual Money GetHandlingTotal(IOrderForm orderForm, Currency currency)
    {
        return OrderFormCalculator.GetHandlingTotal(orderForm, currency);
    }

    public virtual OrderFormTotals GetOrderFormTotals(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return OrderFormCalculator.GetOrderFormTotals(orderForm, market, currency);
    }

    public virtual Money GetShippingSubTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return OrderFormCalculator.GetShippingSubTotal(orderForm, market, currency);
    }

    public virtual Money GetSubTotal(IOrderForm orderForm, Currency currency)
    {
        return OrderFormCalculator.GetSubTotal(orderForm, currency);
    }

    public virtual Money GetTaxTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return OrderFormCalculator.GetTaxTotal(orderForm, market, currency);
    }

    public virtual Money GetTotal(IOrderForm orderForm, IMarket market, Currency currency)
    {
        return OrderFormCalculator.GetTotal(orderForm, market, currency);
    }
}