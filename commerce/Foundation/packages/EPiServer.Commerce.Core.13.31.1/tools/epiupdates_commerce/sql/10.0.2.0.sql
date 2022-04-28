--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 2    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecf_SerializableCart_SaveBatch]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_SaveBatch] 
	@CartData [dbo].[udttSerializableCart] READONLY
AS
BEGIN
  UPDATE SerializableCart
  SET 			
		[CustomerId] = t2.CustomerId,
		[Name] = t2.Name,
		[MarketId] = t2.MarketId,
		[Created] = t2.Created,
		[Modified] = t2.Modified,
		[Data] = t2.Data
 FROM SerializableCart t1
 INNER JOIN @CartData t2 ON t1.CartId = t2.CartId
END
GO
PRINT N'Creating [dbo].[ecf_NodeEntryRelation_GetMaxSortOrder]...';


GO
CREATE PROCEDURE [dbo].[ecf_NodeEntryRelation_GetMaxSortOrder]
	@CatalogNodeId INT
AS
BEGIN
	SELECT Max(SortOrder) FROM NodeEntryRelation WHERE CatalogNodeId = @CatalogNodeId
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_InsertBatch]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_InsertBatch] 
	@CartData [dbo].[udttSerializableCart] READONLY
AS
BEGIN
	INSERT INTO SerializableCart(
		[CustomerId],
		[Name],
		[MarketId],
		[Created],
		[Modified],
		[Data]
	)
	SELECT 
		t1.[CustomerId],
		t1.[Name],
		t1.[MarketId],
		t1.[Created],
		t1.[Modified],
		t1.[Data]
	FROM @CartData t1
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 2, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
