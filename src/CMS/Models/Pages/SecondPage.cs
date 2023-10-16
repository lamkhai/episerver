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
}