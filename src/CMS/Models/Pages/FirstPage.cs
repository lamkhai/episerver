using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Pages;

[ContentType(DisplayName = "FirstPage", GUID = "5448b99f-4e2b-4b8b-ae8c-63a3e94b09ec", Description = "First page type for creating pages.")]
public class FirstPage : SitePageData
{
    public virtual string Heading { get; set; }

    public virtual string MainIntro { get; set; }

    [CultureSpecific]
    [Display(
        Name = "Main body",
        Description = "The main body editor area lets you insert text and images into a page.",
        GroupName = SystemTabNames.Content,
        Order = 10)]
    public virtual XhtmlString MainBody { get; set; }
}