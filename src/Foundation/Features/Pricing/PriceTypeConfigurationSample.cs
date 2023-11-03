using Mediachase.BusinessFoundation.Data.Meta.Management;
using Mediachase.BusinessFoundation.Data;

namespace Foundation.Features.Pricing;

public class PriceTypeConfigurationSample
{
    #region GetPriceTypeFromEnumAndConfiguration
    public IDictionary<CustomerPricing.PriceType, PriceTypeDefinition> GetAllPriceTypeDefinitions()
    {
        // Get all price types - included predefined and price types from configuration file.
        var priceTypeDefinitions = PriceTypeConfiguration.Instance.PriceTypeDefinitions;
        return priceTypeDefinitions;
    }
    #endregion

    private void AddVIPCustomerPriceGroup()
    {
        var metaFieldType = DataContext.Current.MetaModel.RegisteredTypes["ContactGroup"];
        var metaEnumItems = MetaEnum.GetItems(metaFieldType);
        var hasVIPGroup = metaEnumItems.Any(item => string.Equals(item.Name, "VIP", StringComparison.InvariantCultureIgnoreCase));
        if (!hasVIPGroup)
        {
            var lastIndex = metaEnumItems.Count();
            MetaEnum.AddItem(metaFieldType, "VIP", ++lastIndex);
        }
    }
}