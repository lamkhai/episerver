using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Components;

[TemplateDescriptor(Inherited = true)]
public class PagePartialComponent : PartialContentComponent<SitePageData>
{
    protected override IViewComponentResult InvokeComponent(SitePageData currentContent)
    {
        return View("/Views/Shared/Components/PagePartial/Default.cshtml", currentContent);
    }
}