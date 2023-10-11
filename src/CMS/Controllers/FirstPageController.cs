using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using Microsoft.AspNetCore.Mvc;

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