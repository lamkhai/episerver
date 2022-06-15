using EPiServer.Core;

namespace Alloy.MVC.Find.Models.Pages
{
    public interface IHasRelatedContent
    {
        ContentArea RelatedContentArea { get; }
    }
}
