namespace Foundation.Features.MarketingAndCampaigns;

[ContentType(GUID = "530a7f07-8d12-4625-bda3-8e135a10b74d")]
[AvailableContentTypes(Include = new[] { typeof(PromotionData) })]
public class SeasonalCampaign : SalesCampaign, IRoutable
{
    [Display(Order = 12, GroupName = SystemTabNames.PageHeader, Prompt = "Hero Image")]
    public virtual ContentReference HeroImage { get; set; }

    [Display(Order = 13, GroupName = SystemTabNames.PageHeader, Prompt = "Banner Image")]
    public virtual ContentReference BannerImage { get; set; }

    public virtual string RouteSegment { get; set; }
}