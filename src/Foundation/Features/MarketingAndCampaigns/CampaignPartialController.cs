using EPiServer.Framework.DataAnnotations;

namespace Foundation.Features.MarketingAndCampaigns;

[TemplateDescriptor(Default = true)]
public class CampaignPartialController : PartialContentComponent<SalesCampaign>
{
    protected override IViewComponentResult InvokeComponent(SalesCampaign currentCampaign)
    {
        // Implementation of action view the page
        return View(currentCampaign);
    }
}