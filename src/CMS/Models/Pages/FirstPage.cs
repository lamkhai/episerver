using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Pages;

[ContentType(DisplayName = "FirstPage", GUID = "5448b99f-4e2b-4b8b-ae8c-63a3e94b09ec", Description = "First page type for creating pages.")]
public class FirstPage : SitePageData
{
    [CultureSpecific]
    [Display(
        Name = "Main body",
        Description = "The main body editor area lets you insert text and images into a page.",
        GroupName = SystemTabNames.Content,
        Order = 10)]
    public virtual XhtmlString MainBody { get; set; }
}