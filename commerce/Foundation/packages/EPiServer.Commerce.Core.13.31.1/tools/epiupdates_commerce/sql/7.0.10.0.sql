--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 10    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- creating stored procedure ecf_CatalogContentTypeGetUsage
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogContentTypeGetUsage]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogContentTypeGetUsage]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogContentTypeGetUsage]
	@MetaClassName nvarchar(256),
	@OnlyPublished	BIT = 0
AS
BEGIN
	IF (@MetaClassName = 'CatalogContent')
	BEGIN
		SELECT c.Name, c.CatalogId ObjectId, 2 ObjectTypeId, l.LanguageCode LanguageName FROM Catalog c
		INNER JOIN CatalogLanguage l ON l.CatalogId = c.CatalogId
		WHERE @OnlyPublished = 0 OR c.IsActive = 1
	END
	ELSE 
	BEGIN
		DECLARE @MetaClassTemp TABLE (MetaClassId INT)
		INSERT INTO @MetaClassTemp 
		SELECT MetaClassId FROM MetaClass
		WHERE Name = @MetaClassName
			
		SELECT n.Name, CatalogNodeId ObjectId, 1 ObjectTypeId, l.LanguageCode LanguageName FROM CatalogNode n
		INNER JOIN CatalogLanguage l ON l.CatalogId = n.CatalogId
		INNER JOIN @MetaClassTemp  mc ON n.MetaClassId = mc.MetaClassId
		LEFT JOIN CatalogContentProperty p ON p.ObjectId = n.CatalogNodeId AND p.ObjectTypeId = 1
		WHERE @OnlyPublished = 0 OR (n.IsActive = 1  AND (p.Boolean = 1 OR p.Boolean is null)) AND p.MetaFieldName = 'Epi_IsPublished'
		UNION ALL
		SELECT e.Name, CatalogEntryId ObjectId, 0 ObjectTypeId, l.LanguageCode LanguageName FROM CatalogEntry e
		INNER JOIN CatalogLanguage l ON l.CatalogId = e.CatalogId
		INNER JOIN @MetaClassTemp  mc ON e.MetaClassId = mc.MetaClassId
		LEFT JOIN CatalogContentProperty p ON p.ObjectId = e.CatalogEntryId AND p.ObjectTypeId = 0
		WHERE @OnlyPublished = 0 OR (e.IsActive = 1  AND (p.Boolean = 1 OR p.Boolean is null)) AND p.MetaFieldName = 'Epi_IsPublished'
	END
END
GO
-- end creating stored procedure ecf_CatalogContentTypeGetUsage

-- creating stored procedure ecf_CatalogContentTypeIsUsed
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogContentTypeIsUsed]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogContentTypeIsUsed]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogContentTypeIsUsed]
	@MetaClassName nvarchar(256)
AS
BEGIN
	DECLARE @CatalogUsed INT, @NodeUsed INT, @EntryUsed INT

	IF (@MetaClassName = 'CatalogContent')
	BEGIN
		SELECT @CatalogUsed = COUNT(*) FROM Catalog c 
		RETURN @CatalogUsed
	END
	ELSE 
	BEGIN
		DECLARE @MetaClassTemp TABLE (MetaClassId INT)
		INSERT INTO @MetaClassTemp 
		SELECT MetaClassId FROM MetaClass
		WHERE Name = @MetaClassName
			
		SELECT @NodeUsed = COUNT(*) FROM CatalogNode n
		INNER JOIN @MetaClassTemp  mc ON n.MetaClassId = mc.MetaClassId
				
		SELECT @EntryUsed = COUNT(*) FROM CatalogEntry e
		INNER JOIN @MetaClassTemp  mc ON e.MetaClassId = mc.MetaClassId
		
		RETURN @NodeUsed + @EntryUsed
	END
END
GO
-- end creating stored procedure ecf_CatalogContentTypeIsUsed

-- creating stored procedure ecf_PropertyDefinitionGetUsage
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_PropertyDefinitionGetUsage]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_PropertyDefinitionGetUsage]
GO

CREATE PROCEDURE [dbo].[ecf_PropertyDefinitionGetUsage]
	@PropertyName nvarchar(256),
	@OnlyNoneMasterLanguage	BIT = 0,
	@OnlyPublished	BIT = 0
AS
BEGIN
	DECLARE @MetaClassTemp TABLE (MetaClassId INT)    
	INSERT INTO @MetaClassTemp
	SELECT DISTINCT r.MetaClassId 
	FROM MetaField mf 
			INNER JOIN MetaClassMetaFieldRelation r ON mf.MetaFieldId = r.MetaFieldId
			WHERE mf.Name = @PropertyName

	DECLARE @Languages TABLE (CatalogId INT, LanguageName NVARCHAR(100))
	INSERT INTO @Languages
	SELECT c.CatalogId, l.LanguageCode LanguageName FROM Catalog c
				INNER JOIN CatalogLanguage l ON c.CatalogId = l.CatalogId
				WHERE (@OnlyNoneMasterLanguage = 0 OR l.LanguageCode <> c.DefaultLanguage)

	IF (@OnlyPublished = 0)
		BEGIN	
			SELECT n.Name, CatalogNodeId ObjectId, 1 ObjectTypeId, l.LanguageName FROM CatalogNode n
			INNER JOIN @Languages l ON n.CatalogId = l.CatalogId
			INNER JOIN @MetaClassTemp mc ON n.MetaClassId = mc.MetaClassId
			UNION ALL
			SELECT e.Name, CatalogEntryId ObjectId, 0 ObjectTypeId, l.LanguageName FROM CatalogEntry e
			INNER JOIN @Languages l ON e.CatalogId = l.CatalogId
			INNER JOIN @MetaClassTemp mc ON e.MetaClassId = mc.MetaClassId
		END
	ELSE
		BEGIN
			SELECT n.Name, CatalogNodeId ObjectId, 1 ObjectTypeId, l.LanguageName FROM CatalogNode n
			INNER JOIN @Languages l ON n.CatalogId = l.CatalogId
			INNER JOIN @MetaClassTemp mc ON n.MetaClassId = mc.MetaClassId
			LEFT JOIN CatalogContentProperty p ON n.CatalogNodeId = p.ObjectId AND p.ObjectTypeId = 1 
			WHERE (n.IsActive = 1  AND ((p.Boolean = 1 AND p.MetaFieldName = 'Epi_IsPublished') OR (p.MetaFieldName is null AND p.Boolean is null))) 
			UNION ALL
			SELECT e.Name, CatalogEntryId ObjectId, 0 ObjectTypeId, l.LanguageName FROM CatalogEntry e
			INNER JOIN @Languages l ON e.CatalogId = l.CatalogId
			INNER JOIN @MetaClassTemp mc ON e.MetaClassId = mc.MetaClassId
			LEFT JOIN CatalogContentProperty p ON e.CatalogEntryId = p.ObjectId AND p.ObjectTypeId = 1
			WHERE (e.IsActive = 1  AND ((p.Boolean = 1 AND p.MetaFieldName = 'Epi_IsPublished') OR (p.MetaFieldName is null AND p.Boolean is null))) 
		END
END
GO
-- end creating stored procedure ecf_PropertyDefinitionGetUsage


-- creating stored procedure ecf_PropertyDefinitionIsUsed
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_PropertyDefinitionIsUsed]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_PropertyDefinitionIsUsed]
GO
CREATE PROCEDURE [dbo].[ecf_PropertyDefinitionIsUsed]
	@PropertyName nvarchar(256)
AS
BEGIN
	DECLARE @MetaClassTemp TABLE (MetaClassId INT)    
	INSERT INTO @MetaClassTemp
	SELECT DISTINCT r.MetaClassId 
	FROM MetaField mf 
			INNER JOIN MetaClassMetaFieldRelation r ON mf.MetaFieldId = r.MetaFieldId
			WHERE mf.Name = @PropertyName

	DECLARE @NodeUsed INT, @EntryUsed INT
	
	SELECT @NodeUsed = COUNT(*) FROM CatalogNode n INNER JOIN @MetaClassTemp mc ON n.MetaClassId = mc.MetaClassId	
	SELECT @EntryUsed = COUNT(*) FROM CatalogEntry e INNER JOIN @MetaClassTemp mc ON e.MetaClassId = mc.MetaClassId

	RETURN @NodeUsed + @EntryUsed
END
GO
-- end creating stored procedure ecf_PropertyDefinitionIsUsed
 
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 10, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
