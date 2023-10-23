using EPiServer.Framework.DataAnnotations;
using EPiServer.Framework.Web.Mvc;
using EPiServer.Framework.Web;
using EPiServer.Web.Mvc;
using EPiServer.Web;
using Microsoft.AspNetCore.Mvc;
using CMS.Models.ViewModels;
using CMS.Models.Pages;

namespace CMS.Controllers;

[TemplateDescriptor(
      Inherited = true,
      TemplateTypeCategory = TemplateTypeCategories.MvcController, //Required as controllers for blocks are registered as MvcPartialController by default
      Tags = new[] { RenderingTags.Preview, RenderingTags.Edit },
      AvailableWithoutTag = false)]
[VisitorGroupImpersonation]
[RequireClientResources]
public class PreviewController : ActionControllerBase, IRenderTemplate<BlockData>//, IModifyLayout
{
    private readonly IContentLoader _contentLoader;

    public PreviewController(IContentLoader contentLoader)
    {
        _contentLoader = contentLoader;
    }

    public IActionResult Index(IContent currentContent)
    {
        //As the layout requires a page for title etc we "borrow" the start page
        var startPage = _contentLoader.Get<FirstPage>(SiteDefinition.Current.StartPage);
        var model = new PreviewModel(startPage, currentContent);

        return View(model);
    }

    public void ModifyLayout(LayoutModel layoutModel)
    {
        layoutModel.HideHeader = true;
        layoutModel.HideFooter = true;
    }
}