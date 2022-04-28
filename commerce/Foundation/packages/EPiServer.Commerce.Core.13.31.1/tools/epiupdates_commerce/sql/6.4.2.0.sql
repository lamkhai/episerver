--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 4, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_reporting_LowStock]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_reporting_LowStock] 

GO 

CREATE PROCEDURE [dbo].[ecf_reporting_LowStock] 
	@ApplicationID uniqueidentifier
As

BEGIN

    SELECT E.[Name], E.Code as SkuId, I.BackorderAvailableUtc as [BackorderAvailabilityDate],
    I.PreorderAvailableUtc as [PreorderAvailabilityDate],
    I.IsTracked as [InventoryStatus],
    [AllowBackorder] = 
        CASE 
            WHEN I.BackorderAvailableQuantity > 0 THEN 1
            ELSE 0
        END,
    [AllowPreOrder] = 
        CASE 
            WHEN I.PreorderAvailableUtc > convert(datetime,0x0000000000000000) THEN 1
            ELSE 0
        END,
    I.BackorderAvailableQuantity as [BackorderQuantity],
    I.PreorderAvailableQuantity as [PreorderQuantity],
    I.ReorderMinQuantity,
    I.WarehouseCode,
    I.AdditionalQuantity as [ReservedQuantity],
    I.PurchaseAvailableQuantity + I.AdditionalQuantity as [InstockQuantity],
    W.Name as WarehouseName from [InventoryService] I
    INNER JOIN [CatalogEntry] E ON E.Code = I.CatalogEntryCode 
    INNER JOIN Catalog C ON C.CatalogId = E.CatalogId
    INNER JOIN [Warehouse] W ON I.WarehouseCode = W.Code
    WHERE I.PurchaseAvailableQuantity <= I.ReorderMinQuantity AND I.IsTracked <> 0 
    AND C.ApplicationId = @ApplicationID

END

GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 4, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
