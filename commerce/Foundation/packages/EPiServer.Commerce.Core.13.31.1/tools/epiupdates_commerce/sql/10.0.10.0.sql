--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 10    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[ecf_CatalogEntry_Delete]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntry_Delete]
    @CatalogEntries dbo.udttEntityList READONLY
AS
BEGIN
	DELETE CE
	FROM dbo.CatalogEntry CE
	INNER JOIN @CatalogEntries Ids
	ON CE.CatalogEntryId = Ids.EntityId

	DELETE CE
	FROM dbo.CatalogItemAsset CE
	INNER JOIN @CatalogEntries Ids
	ON CE.CatalogEntryId = Ids.EntityId

	DELETE CE
	FROM dbo.CatalogItemSeo CE
	INNER JOIN @CatalogEntries Ids
	ON CE.CatalogEntryId = Ids.EntityId
END
GO
PRINT N'Creating [dbo].[ecf_CatalogEntryAssocations_Delete]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryAssocations_Delete]
    @CatalogEntries dbo.udttEntityList readonly
AS
BEGIN
	DELETE CEA FROM [CatalogEntryAssociation] CEA
	INNER JOIN [CatalogAssociation] CA ON CEA.CatalogAssociationId = CA.CatalogAssociationId
	INNER JOIN @CatalogEntries CE ON CA.CatalogEntryId = CE.EntityId

	DELETE CA FROM [CatalogAssociation] CA
	INNER JOIN @CatalogEntries CE ON CA.CatalogEntryId = CE.EntityId
END
GO
PRINT N'Creating [dbo].[ecf_NodeEntryRelations_Delete]...';


GO
CREATE PROCEDURE [dbo].[ecf_NodeEntryRelations_Delete]
    @CatalogEntries dbo.udttEntityList readonly,
    @CatalogNodes dbo.udttEntityList readonly
AS
BEGIN
	DELETE CER
	FROM CatalogEntryRelation CER 
	INNER JOIN @CatalogEntries CE ON CE.EntityId = CER.ParentEntryId

	DELETE CER
	FROM CatalogEntryRelation CER 
	INNER JOIN @CatalogEntries CE ON CE.EntityId = CER.ChildEntryId

	DELETE NER
	FROM NodeEntryRelation NER
	INNER JOIN @CatalogEntries CE ON CE.EntityId = NER.CatalogEntryId

	DELETE NER
	FROM NodeEntryRelation NER
	INNER JOIN @CatalogNodes CN on CN.EntityId = NER.CatalogNodeId
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 10, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
