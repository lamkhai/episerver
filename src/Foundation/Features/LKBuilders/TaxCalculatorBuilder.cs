using EPiServer.Commerce.Order.Calculator;
using Mediachase.Commerce.Orders;

namespace Foundation.Features.LKBuilders;

public interface ITaxCalculatorBuilder
{
    Money CalculateSalesTax(ILineItem lineItem, IMarket market, IOrderAddress shippingAddress, Money basePrice);
    Money CalculateSalesTax(IEnumerable<ILineItem> lineItems, IMarket market, IOrderAddress shippingAddress, Currency currency);
}

public class TaxCalculatorBuilder : DefaultTaxCalculator, ITaxCalculatorBuilder
{
    protected readonly ITaxCalculator TaxCalculator = ServiceLocator.Current.GetInstance<ITaxCalculator>();

    public TaxCalculatorBuilder(IContentRepository contentRepository, ReferenceConverter referenceConverter) : base(contentRepository, referenceConverter) { }

    protected override IEnumerable<ITaxValue> GetTaxValues(string taxCategory, string languageCode, IOrderAddress orderAddress)
    {
        return new List<ITaxValue>() { new TaxValue(10, "SalesTax", "clothing", TaxType.SalesTax) };
    }

    public virtual Money CalculateSalesTax(ILineItem lineItem, IMarket market, IOrderAddress shippingAddress, Money basePrice)
    {
        return TaxCalculator.GetSalesTax(lineItem, market, shippingAddress, basePrice);
    }

    public virtual Money CalculateSalesTax(IEnumerable<ILineItem> lineItems, IMarket market, IOrderAddress shippingAddress, Currency currency)
    {
        return TaxCalculator.GetSalesTax(lineItems, market, shippingAddress, currency);
    }
}