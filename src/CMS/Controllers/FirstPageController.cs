using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using EPiServer.Framework.Localization;
using EPiServer.Framework.Web;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;
using System.Text;

namespace CMS.Controllers;

[TemplateDescriptor(
    Inherited = false,
    Description = "Default template to be used by first pages")]
public class FirstPageController : PageControllerBase<FirstPage>
{
    public ActionResult Index(FirstPage currentPage)
    {
        // Implementation of action view the page.

        return View(currentPage);
    }
}

[TemplateDescriptor(Tags = new string[] { RenderingTags.Mobile })]
public class FirstPageMobileController : PageController<FirstPage>
{
    public ActionResult Index(FirstPage currentPage)
    {
        // Implementation of action view the page. 
        StringBuilder builder = new();
        builder.Append(LocalizationService.Current.GetString("/mystring"));
        builder.Append(LocalizationService.Current.GetString("/subnode/myotherstring"));

        return View(currentPage);
    }
}