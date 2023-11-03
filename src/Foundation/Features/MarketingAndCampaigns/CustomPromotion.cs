namespace Foundation.Features.MarketingAndCampaigns;

[ContentType(GUID = "76EBFEFF-2CFB-42F2-B4A3-EA5EA5A41515")]
public class CustomPromotion : EntryPromotion
{
    [PromotionRegion(PromotionRegionName.Condition)]
    public virtual CustomPromotionBlock Conditions { get; set; }

    [PromotionRegion(PromotionRegionName.Reward)]
    public virtual int Percentage { get; set; }
}