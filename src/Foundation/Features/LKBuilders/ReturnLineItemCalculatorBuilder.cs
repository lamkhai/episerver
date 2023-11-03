using EPiServer.Commerce.Order.Calculator;

namespace Foundation.Features.LKBuilders;

public interface IReturnLineItemCalculatorBuilder
{
    Money GetDiscountedPrice(IReturnLineItem returnLineItem, Currency currency);
    Money GetExtendedPrice(IReturnLineItem returnLineItem, Currency currency);
    Money GetSalesTax(IReturnLineItem returnLineItem, IMarket market, Currency currency, IOrderAddress shippingAddress);
}

public class ReturnLineItemCalculatorBuilder : DefaultReturnLineItemCalculator, IReturnLineItemCalculatorBuilder
{
    protected readonly IReturnLineItemCalculator ReturnLineItemCalculator = ServiceLocator.Current.GetInstance<IReturnLineItemCalculator>();

    public ReturnLineItemCalculatorBuilder(ITaxCalculator taxCalculator) : base(taxCalculator) { }

    protected override Money CalculateExtendedPrice(IReturnLineItem lineItem, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateDiscountedPrice(IReturnLineItem returnLineItem, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateSalesTax(IReturnLineItem returnLineItem, IMarket market, Currency currency, IOrderAddress shippingAddress)
    {
        return new Money(0, currency);
    }

    protected override void ValidateExtendedPrice(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Extended price must be greater than 0");
        }
    }
    protected override void ValidateDiscountedPrice(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Discounted price must be greater than 0");
        }
    }
    protected override void ValidateSalesTax(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Sales tax must be greater than 0");
        }
    }

    public virtual Money GetDiscountedPrice(IReturnLineItem returnLineItem, Currency currency)
    {
        return ReturnLineItemCalculator.GetDiscountedPrice(returnLineItem, currency);
    }

    public virtual Money GetExtendedPrice(IReturnLineItem returnLineItem, Currency currency)
    {
        return ReturnLineItemCalculator.GetExtendedPrice(returnLineItem, currency);
    }

    public virtual Money GetSalesTax(IReturnLineItem returnLineItem, IMarket market, Currency currency, IOrderAddress shippingAddress)
    {
        return ReturnLineItemCalculator.GetSalesTax(returnLineItem, market, currency, shippingAddress);
    }
}