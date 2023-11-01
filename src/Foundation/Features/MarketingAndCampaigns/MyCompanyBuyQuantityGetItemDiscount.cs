using EPiServer.Commerce.Marketing.Promotions;

namespace Foundation.Features.MarketingAndCampaigns;

[ContentType(GUID = "be97060d-622c-4811-94fa-d3c1c5f18eb8")]
[AvailableContentTypes(Include = new[] { typeof(PromotionData) })]
public class MyCompanyBuyQuantityGetItemDiscount : BuyQuantityGetItemDiscount
{
    [Display(Order = 13, GroupName = SystemTabNames.PageHeader, Prompt = "Other Info")]
    public virtual string OtherInfo { get; set; }
}