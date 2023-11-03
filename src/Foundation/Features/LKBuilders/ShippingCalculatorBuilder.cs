using EPiServer.Commerce.Order.Calculator;
using Mediachase.Commerce.Orders;
using Mediachase.Commerce.Orders.Dto;

namespace Foundation.Features.LKBuilders;

public interface IShippingCalculatorBuilder
{
    Money GetDiscountedShippingAmount(IShipment shipment, IMarket market, Currency currency);
    Money GetSalesTax(IShipment shipment, IMarket market, Currency currency);
    Money GetShippingCost(IShipment shipment, IMarket market, Currency currency);
    Money GetShippingItemsTotal(IShipment shipment, Currency currency);
    Money GetShippingReturnItemsTotal(IShipment shipment, Currency currency);
    Money GetShippingTax(IShipment shipment, IMarket market, Currency currency);
    ShippingTotals GetShippingTotals(IShipment shipment, IMarket market, Currency currency);
}

public class ShippingCalculatorBuilder : DefaultShippingCalculator, IShippingCalculatorBuilder
{
    protected readonly IShippingCalculator ShippingCalculator = ServiceLocator.Current.GetInstance<IShippingCalculator>();

    public ShippingCalculatorBuilder(
        ILineItemCalculator lineItemCalculator,
        IReturnLineItemCalculator returnLineItemCalculator,
        ITaxCalculator taxCalculator,
        IEnumerable<IShippingPlugin> shippingPlugins,
        IEnumerable<IShippingGateway> shippingGateways)
      : base(lineItemCalculator, returnLineItemCalculator, taxCalculator, shippingPlugins, shippingGateways)
    { }

    protected override ShippingMethodDto GetShippingMethods()
    {
        return new ShippingMethodDto();
    }
    protected override Money CalculateShippingCost(IShipment shipment, IMarket market, Currency currency)
    {
        return new Money(0m, currency);
    }
    protected override bool CanBeConverted(Money moneyFrom, Currency currencyTo)
    {
        return true;
    }
    protected override Money CalculateShippingItemsTotal(IShipment shipment, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateShippingReturnItemsTotal(IShipment shipment, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateShippingTax(IShipment shipment, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }
    protected override Money CalculateReturnShippingTax(IShipment shipment, IMarket market, Currency currency)
    {
        return new Money(0, currency);
    }

    protected override void ValidateShippingCostForShipment(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Shipping cost must be greater than 0");
        }
    }
    protected override void ValidateShippingItemTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Shipping item total must be greater than 0");
        }
    }
    protected override void ValidateShippingTax(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Shipping tax must be greater than 0");
        }
    }
    protected override void ValidateSalesTax(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Sales tax must be greater than 0");
        }
    }

    public virtual Money GetDiscountedShippingAmount(IShipment shipment, IMarket market, Currency currency)
    {
        return ShippingCalculator.GetDiscountedShippingAmount(shipment, market, currency);
    }

    public virtual Money GetSalesTax(IShipment shipment, IMarket market, Currency currency)
    {
        return ShippingCalculator.GetSalesTax(shipment, market, currency);
    }

    public virtual Money GetShippingCost(IShipment shipment, IMarket market, Currency currency)
    {
        return ShippingCalculator.GetShippingCost(shipment, market, currency);
    }

    public virtual Money GetShippingItemsTotal(IShipment shipment, Currency currency)
    {
        return ShippingCalculator.GetShippingItemsTotal(shipment, currency);
    }

    public virtual Money GetShippingReturnItemsTotal(IShipment shipment, Currency currency)
    {
        return ShippingCalculator.GetShippingReturnItemsTotal(shipment, currency);
    }

    public virtual Money GetShippingTax(IShipment shipment, IMarket market, Currency currency)
    {
        return ShippingCalculator.GetShippingTax(shipment, market, currency);
    }

    public virtual ShippingTotals GetShippingTotals(IShipment shipment, IMarket market, Currency currency)
    {
        return ShippingCalculator.GetShippingTotals(shipment, market, currency);
    }
}