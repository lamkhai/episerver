using CMS.Models.Pages;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Controllers;

public class ImagePageController : PageController<ImagePage>
{
    public ActionResult Index(ImagePage currentPage)
    {
        /* Implementation of action. 
         * You can create your own view model class that you pass to the view
         * or you can pass the page type for simpler templates */

        return View(currentPage);
    }
}