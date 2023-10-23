using CMS.Models.Pages;
using EPiServer.Framework.DataAnnotations;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using static CMS.Globals;

namespace CMS.Controllers;

[TemplateDescriptor(Default = true)]
public class SecondPageController : PageControllerBase<SecondPage>
{
    //[Authorize(AuthenticationSchemes = Schemes.Oidc)]
    public ActionResult Index(SecondPage currentPage)
    {
        // Implementation of action view the page. 

        return View(currentPage);
    }

    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(Schemes.Another);
        return View();
    }
}