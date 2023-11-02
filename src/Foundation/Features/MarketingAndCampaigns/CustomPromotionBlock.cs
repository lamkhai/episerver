namespace Foundation.Features.MarketingAndCampaigns;

[ContentType(GUID = "15B7BEA8-967A-4C5C-87F3-7346E71CBCC9")]
public class CustomPromotionBlock : BlockData
{
    public virtual int RequiredQuantity { get; set; }
    public virtual IList<ContentReference> Targets { get; set; }
}