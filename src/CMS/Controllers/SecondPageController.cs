using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Controllers;

[TemplateDescriptor(Default = true)]
public class SecondPageController : PageControllerBase<SecondPage>
{
    public ActionResult Index(SecondPage currentPage)
    {
        // Implementation of action view the page. 

        return View(currentPage);
    }
}