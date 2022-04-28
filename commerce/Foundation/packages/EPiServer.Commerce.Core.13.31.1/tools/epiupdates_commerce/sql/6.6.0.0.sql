--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 6, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_ListSimple]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_ListSimple] 

GO

CREATE PROCEDURE dbo.ecf_CatalogEntry_ListSimple
    @CatalogEntries dbo.udttEntityList readonly
AS
BEGIN
    SELECT n.*
	FROM CatalogEntry n
	JOIN @CatalogEntries r ON n.CatalogEntryId = r.EntityId
	ORDER BY r.SortOrder
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_Full]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_Full] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_Full]
    @CatalogEntryId int,
    @ReturnInactive bit = 0
AS
BEGIN
    SELECT v.*
    FROM Variation v
    WHERE v.CatalogEntryId = @CatalogEntryId

    SELECT m.*
    FROM Merchant m
    JOIN Variation v ON m.MerchantId = v.MerchantId
    WHERE v.CatalogEntryId = @CatalogEntryId

    SELECT CA.* from [CatalogAssociation] CA
    WHERE
        CA.CatalogEntryId = @CatalogEntryId
    ORDER BY CA.SORTORDER

    SELECT A.* from [CatalogItemAsset] A
    WHERE
        A.CatalogEntryId = @CatalogEntryId
END

GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 6, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
