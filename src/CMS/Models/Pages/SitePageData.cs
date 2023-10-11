using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Pages;

public abstract class SitePageData : PageData
{
    [Display(GroupName = "SEO", Order = 200, Name = "Search keywords")]
    public virtual string MetaKeywords { get; set; }
}