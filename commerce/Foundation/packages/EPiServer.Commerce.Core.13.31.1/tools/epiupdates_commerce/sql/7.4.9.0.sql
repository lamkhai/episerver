--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 9    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER TRIGGER [dbo].[CatalogEntry_Delete] ON [dbo].[CatalogEntry] FOR DELETE
AS
	--Delete all draft of deleted entries
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogEntryId AND d.ObjectTypeId = 0

	--Delete all extra info of deleted entries
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogEntryId AND c.ObjectTypeId = 0

	--Delete all properties of deleted entries
	DELETE p FROM CatalogContentProperty p
	INNER JOIN deleted ON p.ObjectId = deleted.CatalogEntryId AND p.ObjectTypeId = 0

	--Only need to delete metakey objects if they exist
	DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT)
	INSERT INTO @AffectedMetaKeys
	SELECT DISTINCT MK.MetaClassId, MK.MetaObjectId
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


--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 9, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
