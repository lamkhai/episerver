using EPiServer.Commerce.Order.Calculator;

namespace Foundation.Features.LKBuilders;

public interface ILineItemCalculatorBuilder
{
    Money GetDiscountedPrice(ILineItem lineItem, Currency currency);
    Money GetExtendedPrice(ILineItem lineItem, Currency currency);
    LineItemPrices GetLineItemPrices(ILineItem lineItem, Currency currency);
    Money GetSalesTax(ILineItem lineItem, IMarket market, Currency currency, IOrderAddress shippingAddress);
    Money GetSalesTax(IEnumerable<ILineItem> lineitems, IMarket market, Currency currency, IOrderAddress shippingAddress);
}

public class LineItemCalculatorBuilder : ILineItemCalculatorBuilder
{
    protected readonly ILineItemCalculator LineItemCalculator = ServiceLocator.Current.GetInstance<ILineItemCalculator>();

    public virtual Money GetDiscountedPrice(ILineItem lineItem, Currency currency)
    {
        return LineItemCalculator.GetDiscountedPrice(lineItem, currency);
    }

    public virtual Money GetExtendedPrice(ILineItem lineItem, Currency currency)
    {
        return LineItemCalculator.GetExtendedPrice(lineItem, currency);
    }

    public virtual LineItemPrices GetLineItemPrices(ILineItem lineItem, Currency currency)
    {
        return LineItemCalculator.GetLineItemPrices(lineItem, currency);
    }

    public virtual Money GetSalesTax(ILineItem lineItem, IMarket market, Currency currency, IOrderAddress shippingAddress)
    {
        return LineItemCalculator.GetSalesTax(lineItem, market, currency, shippingAddress);
    }

    public virtual Money GetSalesTax(IEnumerable<ILineItem> lineitems, IMarket market, Currency currency, IOrderAddress shippingAddress)
    {
        return LineItemCalculator.GetSalesTax(lineitems, market, currency, shippingAddress);
    }
}

public class LineItemCalculatorSample : DefaultLineItemCalculator
{
    public LineItemCalculatorSample(ITaxCalculator taxCalculator) : base(taxCalculator)
    {
    }

    protected override Money CalculateExtendedPrice(ILineItem lineItem, Currency currency)
    {
        return new Money(0, currency);
    }

    protected override Money CalculateSalesTax(ILineItem lineItem, IMarket market, Currency currency, IOrderAddress shippingAddress)
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

    protected override void ValidateSalesTax(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Sales tax must be greater than 0");
        }
    }
}