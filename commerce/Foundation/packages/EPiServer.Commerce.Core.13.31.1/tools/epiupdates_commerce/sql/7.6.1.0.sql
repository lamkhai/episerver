--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 6, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.CatalogId, e.ApplicationId, e.contentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId 
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND draft.ObjectId = e.CatalogEntryId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.CatalogId, c.ApplicationId, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.CatalogId, n.ApplicationId, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND draft.ObjectId = n.CatalogNodeId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = n.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 1 -- node
	
	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN CatalogNode n ON r.CatalogNodeId = n.CatalogNodeId
	INNER JOIN dbo.ecfVersion v ON v.ObjectTypeId = 0 AND v.CurrentLanguageRemoved = 0 AND v.ObjectId = r.CatalogEntryId AND r.CatalogId = n.CatalogId
	INNER JOIN @ContentLinks l ON l.WorkId = v.WorkId
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 6, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
