using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Controllers;

[TemplateDescriptor(Inherited = true)]
public class DefaultPageController : PageController<SitePageData>
{
    public ViewResult Index(SitePageData currentPage)
    {
        return View($"~/Views/{currentPage.GetOriginalType().Name}/Index.cshtml", currentPage);
    }
}