using EPiServer.Web;
using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Pages;

[ContentType(
        DisplayName = "ImagePage",
        GUID = "61f028c8-be3d-4942-b58c-65ea8b28e7b6",
        Description = "Description for this image page type")]
public class ImagePage : PageData
{
    [CultureSpecific]
    [Display(
      Name = "Page image",
      Description = "Link to image that will be displayed on the page.",
      GroupName = SystemTabNames.Content,
      Order = 1)]
    [UIHint(UIHint.Image)]
    public virtual ContentReference Image { get; set; }

    public virtual string BlobPathToReadWrite { get; set; }
}