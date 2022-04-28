--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 0, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_Inventory_DeleteInventory]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_DeleteInventory]
    @partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
	if (not exists (select 1 from @partialKeys k where WarehouseCode is not null))
	begin
	    delete mi
		from [dbo].[InventoryService] mi
		INNER JOIN @partialKeys k
		ON mi.CatalogEntryCode = k.CatalogEntryCode
	end
	else 
	begin
	    delete mi
	    from [dbo].[InventoryService] mi
	    where exists (
	        select 1 
	        from @partialKeys keys 
	        where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
	          and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
	end
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_DeleteInventoryByKeys]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_DeleteInventoryByKeys]
    @inventoryKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    delete mi
    from [dbo].[InventoryService] mi
    INNER JOIN @inventoryKeys k
    ON mi.CatalogEntryCode = k.CatalogEntryCode
    AND mi.WarehouseCode = k.WarehouseCode
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 0, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
