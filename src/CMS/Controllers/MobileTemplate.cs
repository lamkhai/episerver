using CMS.Models.Pages;
using EPiServer.Framework;
using EPiServer.Framework.DataAnnotations;
using EPiServer.Framework.Initialization;
using EPiServer.Web;
using EPiServer.Web.Mvc;

namespace CMS.Controllers;

[TemplateDescriptor(Name = "MobileTemplate")]
public partial class MobileTemplate : PageController<PageData>
{
}

[InitializableModule]
public class MobileRedirectSample : IInitializableModule
{
    private IHttpContextAccessor _httpContextAccessor;
    public void Initialize(InitializationEngine context)
    {
        _httpContextAccessor = context.Locate.Advanced.GetRequiredService<IHttpContextAccessor>();
        context.Locate.Advanced.GetRequiredService<ITemplateResolverEvents>().TemplateResolved
          += new EventHandler<TemplateResolverEventArgs>(MobileRedirectSample_TemplateResolved);
    }

    public void Uninitialize(InitializationEngine context)
    {
        //context.Locate.Advanced.GetRequiredService<ITemplateResolverEvents>().TemplateResolved
        //  -= new EventHandler<TemplateResolverEventArgs>MobileRedirectSample_TemplateResolved);
    }

    void MobileRedirectSample_TemplateResolved(object sender, TemplateResolverEventArgs eventArgs)
    {
        if (eventArgs.ItemToRender != null && eventArgs.ItemToRender is FirstPage)
        {
            //The sample code uses package 'Wangkanai.Detection' for device detection
            //var detection = _httpContextAccessor.HttpContext.RequestServices.GetRequiredService<IDetection>();
            //if (detection.Device.Type == DeviceType.Mobile)
            //{
            //    var mobileRender = eventArgs.SupportedTemplates
            //      .SingleOrDefault(r => r.Name.Contains("Mobile") &&
            //        r.TemplateTypeCategory == eventArgs.SelectedTemplate.TemplateTypeCategory);

            //    if (mobileRender != null)
            //    {
            //        eventArgs.SelectedTemplate = mobileRender;
            //    }
            //}
        }
    }

    public void Preload(string[] parameters)
    {
    }
}