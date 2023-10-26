namespace Foundation.Features.LKBuilders;

public interface IOrderGroupFactoryBuilder
{
    IOrderForm CreateOrderForm<TOrderGroup>(TOrderGroup orderGroup, OrderFormModel model) where TOrderGroup : class, IOrderGroup;
}

public class OrderGroupFactoryBuilder : IOrderGroupFactoryBuilder
{
    protected readonly IOrderGroupFactory OrderGroupFactory = ServiceLocator.Current.GetInstance<IOrderGroupFactory>();

    public virtual IOrderForm CreateOrderForm<TOrderGroup>(TOrderGroup orderGroup, OrderFormModel model) where TOrderGroup : class, IOrderGroup
    {
        var orderForm = OrderGroupFactory.CreateOrderForm(orderGroup);
        orderGroup.Forms.Add(orderForm);

        if (model != null)
        {
            if (!string.IsNullOrEmpty(model.Name))
            {
                orderForm.Name = model.Name;
            }
        }

        return orderForm;
    }
}

public class OrderFormModel
{
    public string Name { get; set; }
}