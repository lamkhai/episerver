--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 9    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogNodeIdByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogNodeIdByCode] 
GO

CREATE PROCEDURE [dbo].[ecf_GetCatalogNodeIdByCode]
	@ApplicationId uniqueidentifier,
	@CatalogNodeCode nvarchar(100)
AS
BEGIN
	SELECT TOP 1 CatalogNodeId from [CatalogNode]
	WHERE ApplicationId = @ApplicationId AND
		  Code = @CatalogNodeCode
END

GO

-- create CatalogEntry_Delete trigger
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogEntry_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogEntry_Delete]
GO

CREATE TRIGGER [dbo].[CatalogEntry_Delete] ON CatalogEntry FOR DELETE
AS
	--Delete all draft of deleted entry
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogEntryId AND d.ObjectTypeId = 0

	--Delete all extra info of this entry
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogEntryId AND c.ObjectTypeId = 0

	--Delete all properties of deleted entries
	DELETE p FROM CatalogContentProperty p
	INNER JOIN deleted ON p.ObjectId = deleted.CatalogEntryId AND p.ObjectTypeId = 0

	DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT)
	INSERT INTO @AffectedMetaKeys
	SELECT MK.MetaClassId, MK.MetaObjectId
	FROM MetaKey MK
		INNER JOIN deleted D
		ON MK.MetaObjectId = D.CatalogEntryId AND MK.MetaClassId = D.MetaClassId
	
	-- Delete data for all reference type meta fields (dictionaries etc)
	DECLARE @ClassId INT
	DECLARE @ObjectId INT
	DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId FROM @AffectedMetaKeys

	OPEN cur
	FETCH NEXT FROM cur INTO @ClassId, @ObjectId

	WHILE @@FETCH_STATUS = 0 BEGIN
		EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId
		FETCH NEXT FROM cur INTO @ClassId, @ObjectId
	END

	CLOSE cur
	DEALLOCATE cur
GO
-- end of creating CatalogEntry_Delete trigger

-- create CatalogNode_Delete trigger
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogNode_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogNode_Delete]
GO

CREATE TRIGGER [dbo].[CatalogNode_Delete] ON CatalogNode FOR DELETE
AS
	--Delete all draft of deleted nodes
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogNodeId AND d.ObjectTypeId = 1

	--Delete all extra info of deleted nodes
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogNodeId AND c.ObjectTypeId = 1

	--Delete all properties of deleted nodes
	DELETE p FROM CatalogContentProperty p
	INNER JOIN deleted ON p.ObjectId = deleted.CatalogNodeId AND p.ObjectTypeId = 1

	DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT)
	INSERT INTO @AffectedMetaKeys
	SELECT MK.MetaClassId, MK.MetaObjectId
	FROM MetaKey MK
		INNER JOIN deleted D
		ON MK.MetaObjectId = D.CatalogNodeId AND MK.MetaClassId = D.MetaClassId
	
	-- Delete data for all reference type meta fields (dictionaries etc)
	DECLARE @ClassId INT
	DECLARE @ObjectId INT
	DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId FROM @AffectedMetaKeys

	OPEN cur
	FETCH NEXT FROM cur INTO @ClassId, @ObjectId

	WHILE @@FETCH_STATUS = 0 BEGIN
		EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId
		FETCH NEXT FROM cur INTO @ClassId, @ObjectId
	END

	CLOSE cur
	DEALLOCATE cur
GO
--end of creating CatalogNode_Delete trigger

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttMetaStringDictionaryValues')
DROP TYPE [dbo].[udttMetaStringDictionaryValues]
GO

CREATE TYPE [dbo].[udttMetaStringDictionaryValues] AS TABLE (
    [Key]     NVARCHAR (100) NOT NULL,
    [Value]   NTEXT          NOT NULL);
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_SaveMultiValueDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_SaveMultiValueDictionary] 
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_SaveMultiValueDictionary]
	@MetaKey INT,
	@DictionaryValues dbo.[udttIdTable] READONLY
AS
	SET NOCOUNT ON

	MERGE INTO MetaMultiValueDictionary AS TARGET
	USING (SELECT @MetaKey AS MetaKey, V.ID AS MetaDictionaryId FROM @DictionaryValues V) AS SOURCE
	ON (TARGET.MetaKey = SOURCE.MetaKey AND TARGET.MetaDictionaryId = SOURCE.MetaDictionaryId)
	WHEN NOT MATCHED THEN
		INSERT (MetaKey, MetaDictionaryId) VALUES (SOURCE.MetaKey, SOURCE.MetaDictionaryId);

	DELETE TARGET
	FROM MetaMultiValueDictionary TARGET
	WHERE TARGET.MetaKey = @MetaKey AND NOT EXISTS (SELECT 1 FROM @DictionaryValues WHERE ID = TARGET.MetaDictionaryId)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_SaveMetaStringDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_SaveMetaStringDictionary] 
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_SaveMetaStringDictionary]
	@MetaKey INT,
	@DictionaryValues dbo.[udttMetaStringDictionaryValues] READONLY
AS
	SET NOCOUNT ON
	
	MERGE INTO MetaStringDictionaryValue AS TARGET
	USING (SELECT @MetaKey as MetaKey, V.[Key], V.Value FROM @DictionaryValues V) AS SOURCE
	ON (TARGET.MetaKey = SOURCE.MetaKey AND TARGET.[Key] = SOURCE.[Key])
	WHEN MATCHED
		THEN UPDATE SET TARGET.Value = SOURCE.Value
	WHEN NOT MATCHED THEN
		INSERT (MetaKey, [Key], Value) VALUES (SOURCE.MetaKey, SOURCE.[Key], SOURCE.Value);

	DELETE TARGET
	FROM MetaStringDictionaryValue TARGET
	WHERE TARGET.MetaKey = @MetaKey AND NOT EXISTS (SELECT 1 FROM @DictionaryValues WHERE [Key] = TARGET.[Key])
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_AddMetaStringDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_AddMetaStringDictionary] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_AddMultiValueDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_AddMultiValueDictionary] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_ClearStringDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_ClearStringDictionary] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_ClearMultiValueDictionary]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[mdpsp_sys_ClearMultiValueDictionary] 
GO

--beginUpdatingDatabaseVersion 

INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 9, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
