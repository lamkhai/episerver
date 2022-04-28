--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
	BEGIN 
	declare @major int = 7, @minor int = 0, @patch int = 0
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
		select 0,'Already correct database version' 
	ELSE 
		select 1, 'Upgrading database' 
	END 
ELSE 
	select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- Adding column ContentGuid
IF NOT EXISTS(SELECT * FROM sys.columns 
            WHERE Name = N'ContentGuid' AND Object_ID = Object_ID(N'Catalog'))
BEGIN
	ALTER TABLE [dbo].[Catalog]
	ADD ContentGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
END
GO

IF NOT EXISTS(SELECT * FROM sys.columns 
            WHERE Name = N'ContentGuid' AND Object_ID = Object_ID(N'CatalogEntry'))
	
	
BEGIN
	ALTER TABLE [dbo].[CatalogEntry]
	ADD ContentGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
	
	
END
GO

IF NOT EXISTS(SELECT * FROM sys.columns 
            WHERE Name = N'ContentGuid' AND Object_ID = Object_ID(N'CatalogNode'))
BEGIN
	ALTER TABLE [dbo].[CatalogNode]
	ADD ContentGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
END
GO

-- Drop ecf_EncodeGuid function
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'ecf_EncodeGuid' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[ecf_EncodeGuid]
GO

-- Drop GuidMapping trigger 
IF EXISTS (SELECT * FROM sys.objects WHERE [type] = 'TR' AND [name] = 'GuidMapping_CatalogInsert')
    DROP TRIGGER GuidMapping_CatalogInsert;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE [type] = 'TR' AND [name] = 'GuidMapping_EntryInsert')
    DROP TRIGGER GuidMapping_EntryInsert;
GO

IF EXISTS (SELECT * FROM sys.objects WHERE [type] = 'TR' AND [name] = 'GuidMapping_NodeInsert')
    DROP TRIGGER GuidMapping_NodeInsert;
GO

-- drop SP ecf_GuidMapping_FindEntity
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMapping_FindEntity]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMapping_FindEntity] 
GO

-- begin create SP ecf_Guid_FindEntity
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Guid_FindEntity]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Guid_FindEntity] 
GO
CREATE PROCEDURE [dbo].[ecf_Guid_FindEntity]
    @ContentGuid uniqueidentifier
AS
BEGIN
	DECLARE @Id INT

	SET @Id = (SELECT CatalogEntryId FROM [CatalogEntry] WHERE ContentGuid = @ContentGuid)
	IF @Id != 0
	BEGIN
		SELECT @Id, 0
		RETURN;
	END

	SET @Id = (SELECT CatalogNodeId FROM [CatalogNode] WHERE ContentGuid = @ContentGuid)
	IF @Id != 0
	BEGIN
		SELECT @Id, 1
		RETURN;
	END

	SET @Id = (SELECT CatalogId FROM [Catalog] WHERE ContentGuid = @ContentGuid)
	IF @Id != 0
	BEGIN
		SELECT @Id, 2
		RETURN;
	END

END
GO
-- end of creating ecf_Guid_FindEntity

-- drop sp ecf_GuidMappingCatalog_FindGuid
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingCatalog_FindGuid]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingCatalog_FindGuid] 
GO

-- begin create SP ecf_GuidCatalog_Get
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidCatalog_Get]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidCatalog_Get] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidCatalog_Get]
   @CatalogEntityId int
AS
BEGIN
	SELECT ContentGuid
		FROM [Catalog] c
	WHERE c.CatalogId = @CatalogEntityId
	
END
GO
-- end of creating ecf_GuidCatalog_Get

-- drop sp ecf_GuidMappingCatalog_FindGuids
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingCatalog_FindGuids]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingCatalog_FindGuids] 
GO

-- begin create SP ecf_GuidCatalog_Find
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidCatalog_Find]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidCatalog_Find] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidCatalog_Find]
	@ContentList udttCatalogList readonly
AS

BEGIN
	SELECT c.CatalogId as Id, ContentGuid
	FROM [Catalog] c
	INNER JOIN @ContentList as idTable on idTable.CatalogId = c.CatalogId
END
GO
-- end of creating ecf_GuidCatalog_Find

-- drop sp ecf_GuidMappingEntry_FindGuid
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingEntry_FindGuid]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingEntry_FindGuid] 
GO

-- begin create SP ecf_GuidEntry_Get
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidEntry_Get]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidEntry_Get] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidEntry_Get]
    @CatalogEntityId int
AS
BEGIN
	SELECT ContentGuid
		FROM [CatalogEntry]
	WHERE CatalogEntryId = @CatalogEntityId
END
GO
-- end of creating ecf_GuidEntry_Get

-- drop sp ecf_GuidMappingEntry_FindGuids
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingEntry_FindGuids]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingEntry_FindGuids] 
GO

-- begin create SP ecf_GuidEntry_Find
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidEntry_Find]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidEntry_Find] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidEntry_Find]
	@ContentList udttContentList readonly
AS
BEGIN
	SELECT c.CatalogEntryId AS Id, ContentGuid
	FROM [CatalogEntry] c
	INNER JOIN @ContentList AS idTable ON idTable.ContentId = c.CatalogEntryId	
END
GO
-- end of creating ecf_GuidEntry_Find

-- drop sp ecf_GuidMappingNode_FindGuid
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingNode_FindGuid]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingNode_FindGuid] 
GO

-- begin create SP ecf_GuidNode_Get
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidNode_Get]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidNode_Get] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidNode_Get]
    @CatalogEntityId int
AS
BEGIN
	SELECT ContentGuid
		FROM CatalogNode
	WHERE CatalogNodeId = @CatalogEntityId
	
END
GO
-- end of creating ecf_GuidNode_Get

-- drop sp ecf_GuidMappingNode_FindGuids
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingNode_FindGuids]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingNode_FindGuids] 
GO

-- begin create SP ecf_GuidNode_Find
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidNode_Find]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidNode_Find] 
GO
CREATE PROCEDURE [dbo].[ecf_GuidNode_Find]
	@ContentList udttContentList readonly
AS
BEGIN
	SELECT n.CatalogNodeId AS Id, ContentGuid
	FROM CatalogNode n
	INNER JOIN @ContentList AS idTable ON idTable.ContentId = n.CatalogNodeId
END
GO
-- end of creating ecf_GuidNode_Find

-- drop sp ecf_GuidMappingCatalog_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingCatalog_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingCatalog_Insert] 
GO



-- drop sp ecf_GuidMappingNode_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingNode_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingNode_Insert] 
GO


-- drop sp ecf_GuidMappingEntry_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GuidMappingEntry_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GuidMappingEntry_Insert] 
GO


--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
