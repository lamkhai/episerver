using EPiServer.Core;
using EPiServer.DataAbstraction;
using EPiServer.DataAnnotations;
using Alloy.MVC.Find.Models;
using Alloy.MVC.Find.Models.Pages;
using System.ComponentModel.DataAnnotations;

namespace Alloy.MVC.Find
{
    [SiteContentType(GUID = "0877D78B-8673-4CF9-9F78-3E50C30C4479",
        GroupName = Alloy.MVC.Find.Global.GroupNames.Specialized,
        DisplayName = "Find GDPR API Demo Page")]
    public class GDPRApiDemoPage : SitePageData, ISearchPage
    {
    }
}
