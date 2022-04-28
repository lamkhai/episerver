--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_Inventory_AdjustInventory]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_AdjustInventory]
    @changes [dbo].[udttInventory] READONLY
AS
BEGIN
    if exists (
        select 1 from @changes src 
        where not exists (select 1 from [dbo].[InventoryService] dst where dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]))
    begin
        raiserror('unmatched key found in update set', 16, 1)
    end
    else
    begin
        update dst
        set      
            [PurchaseAvailableQuantity] = dst.[PurchaseAvailableQuantity] + src.[PurchaseAvailableQuantity],
            [PreorderAvailableQuantity] = dst.[PreorderAvailableQuantity] + src.[PreorderAvailableQuantity],
            [BackorderAvailableQuantity] = dst.[BackorderAvailableQuantity] + src.[BackorderAvailableQuantity],
            [PurchaseRequestedQuantity] = dst.[PurchaseRequestedQuantity] + src.[PurchaseRequestedQuantity],
            [PreorderRequestedQuantity] = dst.[PreorderRequestedQuantity] + src.[PreorderRequestedQuantity],
            [BackorderRequestedQuantity] = dst.[BackorderRequestedQuantity] + src.[BackorderRequestedQuantity]
        from [dbo].[InventoryService] dst
        join (
            select 
                [CatalogEntryCode], [WarehouseCode],
                SUM([PurchaseAvailableQuantity]) as [PurchaseAvailableQuantity],
                SUM([PreorderAvailableQuantity]) as [PreorderAvailableQuantity],
                SUM([BackorderAvailableQuantity]) as [BackorderAvailableQuantity],
                SUM([PurchaseRequestedQuantity]) as [PurchaseRequestedQuantity],
                SUM([PreorderRequestedQuantity]) as [PreorderRequestedQuantity],
                SUM([BackorderRequestedQuantity]) as [BackorderRequestedQuantity]
            from @changes
            group by [CatalogEntryCode], [WarehouseCode]) src 
          on dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]

        select
        mi.[CatalogEntryCode], 
        mi.[WarehouseCode], 
        mi.[IsTracked], 
        mi.[PurchaseAvailableQuantity], 
        mi.[PreorderAvailableQuantity], 
        mi.[BackorderAvailableQuantity], 
        mi.[PurchaseRequestedQuantity], 
        mi.[PreorderRequestedQuantity], 
        mi.[BackorderRequestedQuantity], 
        mi.[PurchaseAvailableUtc],
        mi.[PreorderAvailableUtc],
        mi.[BackorderAvailableUtc],
        mi.[AdditionalQuantity],
        mi.[ReorderMinQuantity]
        from [dbo].[InventoryService] mi
        inner join @changes c on
             mi.[CatalogEntryCode] = c.[CatalogEntryCode]
              and mi.[WarehouseCode] = c.[WarehouseCode]
        order by [CatalogEntryCode], [WarehouseCode]
    end
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
