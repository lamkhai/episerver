using EPiServer.Commerce.Order.Calculator;
using Mediachase.Commerce.Markets;

namespace Foundation.Features.LKBuilders;

public interface IOrderGroupCalculatorBuilder
{
    Money GetOrderDiscountTotal(IOrderGroup orderGroup);
    Money GetHandlingTotal(IOrderGroup orderGroup);
    OrderGroupTotals GetOrderGroupTotals(IOrderGroup orderGroup);
    Money GetShippingSubTotal(IOrderGroup orderGroup);
    Money GetSubTotal(IOrderGroup orderGroup);
    Money GetTaxTotal(IOrderGroup orderGroup);
    Money GetTotal(IOrderGroup orderGroup);
}

public class OrderGroupCalculatorBuilder : DefaultOrderGroupCalculator, IOrderGroupCalculatorBuilder
{
    protected readonly IOrderGroupCalculator OrderGroupCalculator = ServiceLocator.Current.GetInstance<IOrderGroupCalculator>();

    public OrderGroupCalculatorBuilder(IOrderFormCalculator orderFormCalculator, IReturnOrderFormCalculator returnOrderFormCalculator, IMarketService marketService) : base(orderFormCalculator, returnOrderFormCalculator, marketService) { }

    protected override Money CalculateTotal(IOrderGroup orderGroup)
    {
        return new Money(0, orderGroup.Currency);
    }
    protected override Money CalculateSubTotal(IOrderGroup orderGroup)
    {
        return new Money(0, orderGroup.Currency);
    }
    protected override Money CalculateHandlingTotal(IOrderGroup orderGroup)
    {
        return new Money(0, orderGroup.Currency);
    }
    protected override Money CalculateShippingSubTotal(IOrderGroup orderGroup)
    {
        return new Money(0, orderGroup.Currency);
    }
    protected override Money CalculateTaxTotal(IOrderGroup orderGroup)
    {
        return new Money(0, orderGroup.Currency);
    }

    protected override void ValidateTotal(Money money)
    {
        if (money.Amount <= 0)
        {
            throw new ValidationException("Total must be greater than 0");
        }
    }
    protected override void ValidateSubTotal(Money money)
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

    public virtual Money GetOrderDiscountTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetOrderDiscountTotal(orderGroup);
    }

    public virtual Money GetHandlingTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetHandlingTotal(orderGroup);
    }

    public virtual OrderGroupTotals GetOrderGroupTotals(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetOrderGroupTotals(orderGroup);
    }

    public virtual Money GetShippingSubTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetShippingSubTotal(orderGroup);
    }

    public virtual Money GetSubTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetSubTotal(orderGroup);
    }

    public virtual Money GetTaxTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetTaxTotal(orderGroup);
    }

    public virtual Money GetTotal(IOrderGroup orderGroup)
    {
        return OrderGroupCalculator.GetTotal(orderGroup);
    }
}