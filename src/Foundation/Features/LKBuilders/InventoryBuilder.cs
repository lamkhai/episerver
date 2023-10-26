using Mediachase.Commerce.InventoryService;

namespace Foundation.Features.LKBuilders;

public interface IInventoryBuilder
{
    void AdjustInventory(IEnumerable<InventoryChange> changes);
    void DeleteInventories(IEnumerable<InventoryKey> inventoryKeys);
    void DeleteInventoriesByEntry(IEnumerable<string> catalogEntryCodes);
    void DeleteInventoriesByWarehouse(IEnumerable<string> warehouseCode);
    void InsertInventories(IEnumerable<InventoryRecord> records);
    IEnumerable<InventoryRecord> ListAllInventories();
    IEnumerable<InventoryRecord> QueryInventoriesByEntry(IEnumerable<string> catalogEntryCodes);
    IEnumerable<InventoryRecord> QueryInventoriesByPartialKey(IEnumerable<InventoryKey> partialKeys);
    IEnumerable<InventoryRecord> QueryInventoriesByWarehouse(IEnumerable<string> warehouseCodes);
    IEnumerable<InventoryRecord> QueryInventoriesInRangeByEntry(IEnumerable<string> catalogEntryCodes, int offset, int count, out int totalCount);
    IEnumerable<InventoryRecord> QueryInventoriesInRangeByPartialKey(IEnumerable<InventoryKey> partialKeys, int offset, int count, out int totalCount);
    IEnumerable<InventoryRecord> QueryInventoriesInRangeByWarehouse(IEnumerable<string> warehouseCodes, int offset, int count, out int totalCount);
    InventoryResponse RequestInventory(InventoryRequest request);
    void SaveInventories(IEnumerable<InventoryRecord> records);
    void UpdateInventories(IEnumerable<InventoryRecord> records);
}

public class InventoryBuilder : IInventoryBuilder
{
    // Incerements or decrements matching values in the inventory provider.
    public void AdjustInventory(IEnumerable<InventoryChange> changes)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.Adjust(changes);
    }

    // Deletes all specified inventory data.
    public void DeleteInventories(IEnumerable<InventoryKey> inventoryKeys)
    {
        if (inventoryKeys == null || inventoryKeys.Contains(null))
        {
            throw new ArgumentNullException(nameof(inventoryKeys));
        }
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.Delete(inventoryKeys);
    }

    // Deletes all inventory data for the specified catalog entries.
    public void DeleteInventoriesByEntry(IEnumerable<string> catalogEntryCodes)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.DeleteByEntry(catalogEntryCodes);
    }

    // Deletes all inventory data for the specified warehouses.
    public void DeleteInventoriesByWarehouse(IEnumerable<string> warehouseCode)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.DeleteByWarehouse(warehouseCode);
    }​

    // Inserts the specified inventory records.
    public void InsertInventories(IEnumerable<InventoryRecord> records)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.Insert(records);
    }

    // List all inventory records. 
    public IEnumerable<InventoryRecord> ListAllInventories()
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.List();
    }

    // List all inventory records by entry code.
    public IEnumerable<InventoryRecord> QueryInventoriesByEntry(IEnumerable<string> catalogEntryCodes)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByEntry(catalogEntryCodes);
    }

    // List all inventory records matching an item in inventory key.
    public IEnumerable<InventoryRecord> QueryInventoriesByPartialKey(IEnumerable<InventoryKey> partialKeys)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByPartialKey(partialKeys);
    }

    // List all inventory records by warehouse codes.
    public IEnumerable<InventoryRecord> QueryInventoriesByWarehouse(IEnumerable<string> warehouseCodes)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByWarehouse(warehouseCodes);
    }

    // List all inventory records by entry code in a specified range.
    public IEnumerable<InventoryRecord> QueryInventoriesInRangeByEntry(IEnumerable<string> catalogEntryCodes, int offset, int count, out int totalCount)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByEntry(catalogEntryCodes, offset, count, out totalCount);
    }

    // List all inventory records matching an item in inventory key in specified range.
    public IEnumerable<InventoryRecord> QueryInventoriesInRangeByPartialKey(IEnumerable<InventoryKey> partialKeys, int offset, int count, out int totalCount)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByPartialKey(partialKeys, offset, count, out totalCount);
    }

    // List all inventory records by warehouse code in specified range.
    public IEnumerable<InventoryRecord> QueryInventoriesInRangeByWarehouse(IEnumerable<string> warehouseCodes, int offset, int count, out int totalCount)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.QueryByWarehouse(warehouseCodes, offset, count, out totalCount);
    }

    // Requests a transactional inventory operation.
    public InventoryResponse RequestInventory(InventoryRequest request)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        return inventoryService.Request(request);
    }

    // Saves the specified inventory records.
    public void SaveInventories(IEnumerable<InventoryRecord> records)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.Save(records);
    }

    // Updates the specified inventory records.
    public void UpdateInventories(IEnumerable<InventoryRecord> records)
    {
        var inventoryService = ServiceLocator.Current.GetInstance<IInventoryService>();
        inventoryService.Update(records);
    }
}