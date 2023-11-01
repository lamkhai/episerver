using EPiServer.Framework.DataAnnotations;

namespace Foundation.Features.MarketingAndCampaigns;

[TemplateDescriptor(Default = true)]
public class MyCompanyBuyQuantityGetItemDiscountPartialController : PartialContentController<MyCompanyBuyQuantityGetItemDiscount>
{
    public ActionResult Index(MyCompanyBuyQuantityGetItemDiscount currentDiscount)
    {
        // Implementation of action view the page. 
        return View(currentDiscount);
    }
}