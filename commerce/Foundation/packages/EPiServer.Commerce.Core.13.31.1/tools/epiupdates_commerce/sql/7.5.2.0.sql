--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

CREATE TYPE [dbo].[udttInventoryCode] AS TABLE
(
    [ApplicationId] UNIQUEIDENTIFIER NOT NULL, 
    [Code] NVARCHAR(100) NOT NULL, 
    PRIMARY KEY CLUSTERED
	(
		[ApplicationId] ASC,
		[Code] ASC
	)
)
GO

ALTER PROCEDURE [dbo].[ecf_Inventory_QueryInventory]
    @entryKeys [dbo].[udttInventoryCode] READONLY,
	@warehouseKeys [dbo].[udttInventoryCode] READONLY,
	@partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    select
        [ApplicationId], 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @entryKeys keys1 
        where mi.[ApplicationId] = keys1.[ApplicationId]
          and mi.[CatalogEntryCode] = keys1.[Code])
    union
	select
        [ApplicationId], 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @warehouseKeys keys2 
        where mi.[ApplicationId] = keys2.[ApplicationId]
          and mi.[WarehouseCode] = keys2.[Code])
    union
	select
        [ApplicationId], 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @partialKeys keys3 
        where mi.[ApplicationId] = keys3.[ApplicationId]
          and mi.[CatalogEntryCode] = keys3.[CatalogEntryCode]
          and mi.[WarehouseCode] = keys3.[WarehouseCode])
    order by [ApplicationId], [CatalogEntryCode], [WarehouseCode]


END
GO 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
