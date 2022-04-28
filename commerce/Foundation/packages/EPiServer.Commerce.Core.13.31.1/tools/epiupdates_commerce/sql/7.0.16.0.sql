--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 16    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- begin of modifying ecfVersion_ListByWorkIds SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.CatalogId, e.ApplicationId, e.contentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId
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
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId
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
-- end of modifying ecfVersion_ListByWorkIds SP

-- begin of creating ecfVersionVariation_ListByWorkIds SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionVariation_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds]
GO
CREATE PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	-- master language version should load variation info directly from ecfVersionVariation table
	SELECT
		va.WorkId,
		va.TaxCategoryId,
		va.TrackInventory,
		va.[Weight],
		va.MinQuantity,
		va.MaxQuantity,
		va.[Length],
		va.Height,
		va.Width,
		va.PackageId 
	FROM ecfVersionVariation va
	INNER JOIN @ContentLinks links ON va.WorkId = links.WorkId
	INNER JOIN ecfVersion ve ON ve.WorkId = links.WorkId
	WHERE ve.LanguageName = ve.MasterLanguageName COLLATE DATABASE_DEFAULT

	UNION ALL

	-- non-master language version should fall-back to published-master content
	SELECT 
		v.WorkId,
		va.TaxCategoryId,
		va.TrackInventory,
		va.[Weight],
		va.MinQuantity,
		va.MaxQuantity,
		va.[Length],
		va.Height,
		va.Width,
		va.PackageId  
	FROM Variation AS va
	INNER JOIN @ContentLinks links ON va.CatalogEntryId = links.ObjectId AND links.ObjectTypeId = 0
	INNER JOIN ecfVersion v ON v.WorkId = links.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId
	
END
GO
-- end of creating ecfVersionVariation_ListByWorkIds SP

-- creating stored procedure ecfVersion_UpdateVersionsCurrentLanguageRemoved
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateVersionsCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_UpdateVersionsCurrentLanguageRemoved]
GO
CREATE PROCEDURE [dbo].[ecfVersion_UpdateVersionsCurrentLanguageRemoved]
	@Objects dbo.udttObjectWorkId readonly
AS
BEGIN
	DECLARE @temp TABLE(CatalogId int, ObjectId int, ObjectTypeId int)

	INSERT INTO @temp (CatalogId, ObjectId, ObjectTypeId)
	SELECT e.CatalogId, e.CatalogEntryId ObjectId, o.ObjectTypeId FROM CatalogEntry e
	INNER JOIN @Objects o ON e.CatalogEntryId = o.ObjectId and o.ObjectTypeId = 0
	UNION ALL
	SELECT n.CatalogId, n.CatalogNodeId ObjectId, o.ObjectTypeId FROM CatalogNode n
	INNER JOIN @Objects o ON n.CatalogNodeId = o.ObjectId and o.ObjectTypeId = 1
	
	UPDATE v
	SET
		CurrentLanguageRemoved = CASE WHEN cl.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT THEN 0 ELSE 1 END,
		MasterLanguageName = c.DefaultLanguage
	FROM	ecfVersion v
	INNER JOIN @Objects o ON v.ObjectId = o.ObjectId and v.ObjectTypeId = o.ObjectTypeId
	INNER JOIN @temp t ON t.ObjectId = o.ObjectId and t.ObjectTypeId = o.ObjectTypeId		
	INNER JOIN Catalog c ON c.CatalogId = t.CatalogId
	LEFT JOIN CatalogLanguage cl ON v.LanguageName = cl.LanguageCode AND cl.CatalogId = t.CatalogId
END
GO
-- end creating stored procedure ecfVersion_UpdateVersionsCurrentLanguageRemoved

-- begin of modifying ecfVersionCatalog_ListByWorkIds SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
GO
CREATE PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	-- master language version should load catalog info directly from ecfVersionCatalog table
	SELECT 
		c.WorkId,
		c.DefaultCurrency,
		c.WeightBase,
		c.LengthBase,
		c.DefaultLanguage,
		c.Languages,
		c.IsPrimary,
		c.UriSegment,
		c.[Owner]		 
	FROM ecfVersionCatalog c
	INNER JOIN @ContentLinks l 	ON l.WorkId = c.WorkId
	INNER JOIN ecfVersion v ON v.WorkId = l.WorkId
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT

	UNION ALL

	-- non-master language version should fall-back to published-master content
	SELECT 
		v.WorkId,
		c.DefaultCurrency,
		c.WeightBase,
		c.LengthBase,
		c.DefaultLanguage,
		[dbo].fn_JoinCatalogLanguages(c.CatalogId) AS Languages,
		c.IsPrimary,
		cl.UriSegment,
		c.[Owner]		 
	FROM [Catalog] c
	INNER JOIN @ContentLinks l ON c.CatalogId = l.ObjectId AND l.ObjectTypeId = 2
	INNER JOIN ecfVersion v ON v.WorkId = l.WorkId
	INNER JOIN CatalogLanguage cl ON cl.CatalogId = c.CatalogId AND cl.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId
END
GO
-- end of modifying ecfVersionCatalog_ListByWorkIds SP
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 16, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
