namespace Foundation.Features.LKBuilders;

public interface ILineItemValidatorBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    void Validate(TOrderGroup orderGroup);
}

public class LineItemValidatorBuilder<TOrderGroup> : ILineItemValidatorBuilder<TOrderGroup>
    where TOrderGroup : class, IOrderGroup
{
    protected readonly ILineItemValidator LineItemValidator = ServiceLocator.Current.GetInstance<ILineItemValidator>();

    public virtual void Validate(TOrderGroup orderGroup)
    {
        var validationIssues = new Dictionary<ILineItem, ValidationIssue>();

        //Check all line items on cart
        orderGroup.ValidateOrRemoveLineItems((item, issue) => validationIssues.Add(item, issue), LineItemValidator);

        //Check one lineitem
        var lineItem = orderGroup.GetAllLineItems().First();
        if (!LineItemValidator.Validate(lineItem, orderGroup.MarketId, (item, issue) => validationIssues.Add(item, issue)))
        {
            //Check validationIssues for problems
        }
    }
}