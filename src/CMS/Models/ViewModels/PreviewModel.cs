using CMS.Models.Pages;

namespace CMS.Models.ViewModels;

public class PreviewModel : PageViewModel<SitePageData>
{
    public PreviewModel(SitePageData currentPage, IContent previewContent) : base(currentPage)
    {
        PreviewContentArea = new ContentArea();
        PreviewContentArea.Items.Add(new ContentAreaItem
        {
            ContentLink = previewContent.ContentLink
        });
    }

    public ContentArea PreviewContentArea { get; set; }
}