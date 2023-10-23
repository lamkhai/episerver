using System.ComponentModel.DataAnnotations;

namespace CMS.Models.Blocks;

[ContentType(DisplayName = "ThirdBlock", GUID = "38d57768-e09e-4da9-90df-54c73c61b270", Description = "Heading and image.")]
public class ThirdBlock : BlockData
{
    [CultureSpecific]
    [Display(
        Name = "Heading",
        Description = "Add a heading.",
        GroupName = SystemTabNames.Content,
        Order = 1)]
    public virtual string Heading { get; set; }

    [Display(
        Name = "Image", Description = "Add an image (optional)",
        GroupName = SystemTabNames.Content,
        Order = 2)]
    public virtual ContentReference Image { get; set; }
}