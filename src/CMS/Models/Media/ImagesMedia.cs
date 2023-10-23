using EPiServer.Framework.DataAnnotations;

namespace CMS.Models.Media;

[ContentType(DisplayName = "ImagesMedia", GUID = "a4afb648-f7c0-4207-8ac0-f0c532de99ca",
             Description = "Used for generic image types")]
[MediaDescriptor(ExtensionString = "jpg,jpeg,jpe,ico,gif,bmp,png")]
public class ImagesMedia : ImageData
{
}