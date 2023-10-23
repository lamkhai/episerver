using CMS.Models.Pages;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Controllers;

public abstract class PageControllerBase<T> : PageController<T> where T : SitePageData
{
    // Providing a logout action for the page.
    public ActionResult Logout()
    {
        // LKTODO: FormsAuthentication.SignOut();
        return RedirectToAction("Index");
    }
}