using CMS.Models.Blocks;
using EPiServer.Framework.Web;
using EPiServer.Web.Mvc;

namespace CMS.Business;

public class ViewTemplateModelRegistrator : IViewTemplateModelRegistrator
{
    public void Register(TemplateModelCollection viewTemplateModelRegistrator)
    {
        viewTemplateModelRegistrator.Add(typeof(ThirdBlock),
          new TemplateModel()
          {
              Name = "SidebarTeaserRight",
              Description = "Displays a teaser for a page.",
              Path = "~/Views/Shared/SidebarThirdBlockRight.cshtml",
              AvailableWithoutTag = true
          },
          new TemplateModel()
          {
              Name = "SidebarTeaserLeft",
              Description = "Displays a teaser for a page.",
              Path = "~/Views/Shared/SidebarThirdBlockLeft.cshtml",
              Tags = new string[] { RenderingTags.Sidebar }
          });

        viewTemplateModelRegistrator.Add(typeof(FourthBlock),
          new TemplateModel()
          {
              Name = "SidebarTeaser",
              Description = "Displays a teaser of a page.",
              Path = "~/Views/Shared/FourthBlock.cshtml",
              Tags = new string[] { RenderingTags.Sidebar }
          });
    }
}