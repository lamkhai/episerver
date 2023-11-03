using EPiServer.Commerce.Catalog.DataAnnotations;
using EPiServer.DataAccess;
using EPiServer.Security;
using EPiServer.SpecializedProperties;

namespace Foundation.Features.CatalogContent.Variation;

[CatalogContentType(
    GUID = "838cb97a-31a4-48f4-bf12-0bf27e147200",
    MetaClassName = "LKCatalogContentTypeSample",
    DisplayName = "LK: Content Type Sample",
    Description = "LK: A customize for variation content"
)]
public class LKCatalogContentTypeSample : VariationContent
{
    [CultureSpecific]
    [Tokenize]
    [Encrypted]
    [UseInComparison]
    [IncludeValuesInSearchResults]
    [IncludeInDefaultSearch]
    [SortableInSearchResults]
    public virtual string LKDescription { get; set; }

    public virtual int LKSize { get; set; }

    [DecimalSettings(18, 0)]
    public virtual decimal Discount { get; set; }

    [BackingType(typeof(PropertyIntegerList))]
    [Display(Name = "List of int", Order = 5)]
    public virtual IList<int> IntList { get; set; }

    [BackingType(typeof(PropertyDateList))]
    [Display(Name = "List of date", Order = 8)]
    public virtual IList<DateTime> DateTimeList { get; set; }

    [BackingType(typeof(PropertyStringList))]
    [Display(Name = "List of string", Order = 6)]
    public virtual IList<string> StringList { get; set; }

    [BackingType(typeof(PropertyDoubleList))]
    [Display(Name = "List of double", Order = 7)]
    public virtual IList<double> DoubleList { get; set; }
}

//public ContentReference CreateNewSku(ContentReference linkToParentNode)
//{
//    var contentRepository = ServiceLocator.Current.GetInstance<IContentRepository>();
//    //Create a new instance of CatalogContentTypeSample that will be a child to the specified parentNode.
//    var newSku = contentRepository.GetDefault<LKCatalogContentTypeSample>(linkToParentNode);
//    //Set some required properties.
//    newSku.Code = "MyNewCode";
//    newSku.SeoUri = "NewSku.aspx";
//    //Set the description
//    newSku.Description = "This new SKU is great";
//    //Publish the new content and return its ContentReference.
//    return contentRepository.Save(newSku, SaveAction.Publish, AccessLevel.NoAccess);
//}