using Mediachase.Commerce.Inventory;

namespace Foundation.Features.LKBuilders;

public interface IWarehouseBuilder
{
    void CreateNewWarehouse();
    void DeleteWarehouse(int warehouseId);
    IWarehouse GetWarehouse(int warehouseId);
    IWarehouse GetWarehouse(string warehouseCode);
    IEnumerable<IWarehouse> ListAllWarehouses();
    void UpdateWarehouse(string warehouseCode);
}

public class WarehouseBuilder : IWarehouseBuilder
{
    public void CreateNewWarehouse()
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        var warehouse = new Warehouse
        {
            Code = "NY",
            Name = "New York store",
            IsActive = true,
            IsPrimary = false,
            IsFulfillmentCenter = false,
            IsPickupLocation = true,
            IsDeliveryLocation = true,
            ContactInformation = new WarehouseContactInformation
            {
                FirstName = "First Name",
                LastName = "Last Name",
                Line1 = "Address Line 1",
                Line2 = "Address Line 2",
                City = "City",
                State = "State",
                CountryCode = "Country Code",
                PostalCode = "Postal Code",
                RegionCode = "Region Code",
                DaytimePhoneNumber = "Daytime Phone Number",
                EveningPhoneNumber = "Evening Phone Number",
                FaxNumber = "Fax Number",
                Email = "Email"
            }
        };
        warehouseRepository.Save(warehouse);
    }

    public void DeleteWarehouse(int warehouseId)
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        warehouseRepository.Delete(warehouseId);
    }

    // Get a specific Warehouse by ID
    public IWarehouse GetWarehouse(int warehouseId)
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        return warehouseRepository.Get(warehouseId);
    }

    // Get a specific Warehouse by Code
    public IWarehouse GetWarehouse(string warehouseCode)
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        return warehouseRepository.Get(warehouseCode);
    }

    // Get list Warehouse
    public IEnumerable<IWarehouse> ListAllWarehouses()
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        return warehouseRepository.List();
    }

    public void UpdateWarehouse(string warehouseCode)
    {
        var warehouseRepository = ServiceLocator.Current.GetInstance<IWarehouseRepository>();
        var warehouse = warehouseRepository.Get(warehouseCode); // It's a read-only object
        var writableCloneWarehouse = new Warehouse(warehouse); // create writable clone before updating
        writableCloneWarehouse.IsPickupLocation = true;
        warehouseRepository.Save(writableCloneWarehouse);
    }
}