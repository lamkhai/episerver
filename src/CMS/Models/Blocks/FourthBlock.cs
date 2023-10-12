using EPiServer.Framework.DataAnnotations;
using EPiServer.Web.Mvc;
using Microsoft.AspNetCore.Mvc;

namespace CMS.Models.Blocks;

[ContentType(DisplayName = "FourthBlock", GUID = "5ed39f97-0978-451d-9785-0c8fff767c87")]
public class FourthBlock : BlockData
{
}

[TemplateDescriptor]
public partial class FourthBlockTemplate : BlockComponent<FourthBlock>
{
    protected override IViewComponentResult InvokeComponent(FourthBlock currentContent) => throw new NotImplementedException();
}

[TemplateDescriptor(Tags = new string[] { "Mobile" })]
public partial class FourthBlockMobileTemplate : BlockComponent<FourthBlock>
{
    protected override IViewComponentResult InvokeComponent(FourthBlock currentContent) => throw new NotImplementedException();
}