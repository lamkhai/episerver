using CMS.Models.Pages;

namespace CMS.Models.ViewModels;

public interface IPageViewModel<out T> where T : SitePageData
{
    T CurrentPage { get; }

    LayoutModel Layout { get; set; }

    IContent Section { get; set; }
}