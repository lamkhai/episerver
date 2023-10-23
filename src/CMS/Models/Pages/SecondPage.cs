using EPiServer.SpecializedProperties;
using EPiServer.Web;
using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Pages;

[ContentType(DisplayName = "SecondPage", GUID = "d2398c66-3f86-405a-bc24-8a47daa6cc1d", Description = "Second page type for creating pages.")]
public class SecondPage : SitePageData
{
    [CultureSpecific]
    [Display(
        Name = "Main body",
        Description = "The main body editor area lets you insert text and images into a page.",
        GroupName = SystemTabNames.Content,
        Order = 10)]
    public virtual XhtmlString MainBody { get; set; }

    public virtual string Heading { get; set; }

    public virtual CategoryList CategoryList { get; set; }
    public virtual ContentArea ContentArea { get; set; }
    public virtual IList<ContentReference> ContentReferenceList { get; set; }
    public virtual ContentReference ContentReference { get; set; }
    public virtual ContentReference TargetPage { get; set; }

    [UIHint(UIHint.Image)]
    public virtual ContentReference Image { get; set; }
    public virtual PageReference PageReference { get; set; }
    public virtual LinkItem LinkItem { get; set; }
    public virtual LinkItemCollection LinkItemCollection { get; set; }
    public virtual Url Url { get; set; }
    public virtual XhtmlString XhtmlString { get; set; }
    // other properties
}