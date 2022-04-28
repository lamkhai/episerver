--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 1, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[ecfVersion_IsNonPublishedContent]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_IsNonPublishedContent]
(
	@WorkId INT,
    @ObjectId INT,
	@ObjectTypeId INT,
	@LanguageName NVARCHAR(50) = NULL,
	@Result BIT OUTPUT
)
AS
BEGIN	
	SET NOCOUNT ON

	DECLARE @TempResult TABLE(WorkId INT, [Status] INT, IsCommonDraft BIT)
	INSERT INTO @TempResult (WorkId, [Status], IsCommonDraft)
	SELECT WorkId, [Status], IsCommonDraft 
	FROM dbo.ecfVersion vn
	INNER JOIN CatalogLanguage cl ON vn.CatalogId = cl.CatalogId AND vn.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE ObjectId = @ObjectId
	  AND ObjectTypeId = @ObjectTypeId
	  AND (@LanguageName IS NULL OR (LanguageName = @LanguageName COLLATE DATABASE_DEFAULT))

	IF NOT EXISTS (SELECT 1 FROM @TempResult WHERE [Status] = 4)
	   AND EXISTS (SELECT 1 FROM @TempResult WHERE IsCommonDraft = 1 AND WorkId = @WorkId)
	BEGIN
		SET @Result = 1
	END
	ELSE
	BEGIN
		SET @Result = 0
	END
END
GO
PRINT N'Altering [dbo].[ecfVersion_List]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_List]
	@ObjectIds [dbo].[udttContentList] READONLY,
	@ObjectTypeId int
AS
BEGIN
	SELECT vn.*
	FROM dbo.ecfVersion vn
	INNER JOIN @ObjectIds i ON vn.ObjectId = i.ContentId
	INNER JOIN CatalogLanguage cl ON vn.CatalogId = cl.CatalogId AND vn.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE vn.ObjectTypeId = @ObjectTypeId
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListByContentId]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByContentId]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN
	SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status]
	FROM dbo.ecfVersion v
	INNER JOIN CatalogLanguage cl ON v.CatalogId = cl.CatalogId AND v.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE v.ObjectId = @ObjectId 
	AND v.ObjectTypeId = @ObjectTypeId 
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.ContentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId 
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND draft.ObjectId = e.CatalogEntryId
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND draft.ObjectId = n.CatalogNodeId
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = n.MetaClassId
											AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
											AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE links.ObjectTypeId = 1 -- node

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN CatalogNode n ON r.CatalogNodeId = n.CatalogNodeId
	INNER JOIN dbo.ecfVersion v ON v.ObjectTypeId = 0 AND v.ObjectId = r.CatalogEntryId AND r.CatalogId = n.CatalogId
	INNER JOIN @ContentLinks l ON l.WorkId = v.WorkId
	INNER JOIN CatalogLanguage cl ON v.CatalogId = cl.CatalogId AND v.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE r.IsPrimary = 1
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListFiltered]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListFiltered]
(
    @ObjectId INT = NULL,
    @ObjectTypeId INT = NULL,
    @ModifiedBy NVARCHAR(255) = NULL,
    @Languages [udttLanguageCode] READONLY,
    @Statuses [udttIdTable] READONLY,
    @StartIndex INT,
    @MaxRows INT
)
AS

BEGIN    
    SET NOCOUNT ON

    DECLARE @StatusCount INT
    SELECT @StatusCount = COUNT(*) FROM @Statuses

    DECLARE @LanguageCount INT
    SELECT @LanguageCount = COUNT(*) FROM @Languages

    DECLARE @query NVARCHAR(2000)

    SET @query = ''
 
    -- Build WHERE clause, only add the condition if specified
    DECLARE @Where NVARCHAR(1000) = ' FROM ecfVersion vn INNER JOIN CatalogLanguage cl ON vn.CatalogId = cl.CatalogId AND vn.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT WHERE 1 = 1 '
    IF @ObjectId IS NOT NULL
    SET @Where = @Where + ' AND ObjectId  = @ObjectId '
    IF @ObjectTypeId IS NOT NULL
    SET @Where = @Where + ' AND ObjectTypeId = @ObjectTypeId '
    IF @ModifiedBy IS NOT NULL
    SET @Where = @Where + ' AND ModifiedBy = @ModifiedBy '

    -- Optimized for case where only one Status or LanguageName is specified
    -- Otherwise SQL Server will use join even if we are querying for only one Status or Language (most common cases), which is ineffecient
    IF @StatusCount > 1
    BEGIN
    SET @Where = @Where + ' AND [Status] IN (SELECT ID FROM @Statuses) '
    END
    ELSE IF @StatusCount = 1
    BEGIN
    SET @Where = @Where + ' AND [Status] = (SELECT TOP (1) ID FROM @Statuses) '
    END
    IF @LanguageCount > 1
    BEGIN
    SET @Where = @Where + ' AND [LanguageName] IN (SELECT LanguageCode FROM @Languages) '
    END
    ELSE IF @LanguageCount = 1
    BEGIN
    SET @Where = @Where + ' AND [LanguageName] IN (SELECT TOP (1) LanguageCode FROM @Languages) '
    END

    SET @query = @Where

    DECLARE @filter NVARCHAR(2000)

    SET @filter = 'SELECT COUNT(WorkId) AS TotalRows ' + @query

    IF (@MaxRows > 0)
    BEGIN
        SET @filter = @filter + 
        ';SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status] '
        + @query +
        ' ORDER BY  Modified DESC
        OFFSET '  + CAST(@StartIndex AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@MaxRows AS NVARCHAR(50)) + ' ROWS ONLY';
    END

    EXEC sp_executesql @filter,
    N'@ObjectId int, @ObjectTypeId int, @ModifiedBy nvarchar(255), @Statuses [udttIdTable] READONLY, @Languages [udttLanguageCode] READONLY',
    @ObjectId = @ObjectId, @ObjectTypeId = @ObjectTypeId, @ModifiedBy = @ModifiedBy, @Statuses = @Statuses, @Languages = @Languages
     
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListMatchingSegments]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListMatchingSegments]
	@ParentId INT,
	@CatalogId INT,
	@SeoUriSegment NVARCHAR(255)
AS
BEGIN
	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName, v.CatalogId
	FROM ecfVersion v
		INNER JOIN CatalogEntry e on e.CatalogEntryId = v.ObjectId
		LEFT OUTER JOIN NodeEntryRelation r ON v.ObjectId = r.CatalogEntryId
		INNER JOIN CatalogLanguage cl ON v.CatalogId = cl.CatalogId AND v.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 0 
		AND
			((r.CatalogNodeId = @ParentId AND (r.CatalogId = @CatalogId OR @CatalogId = 0))
			OR
			(@ParentId = 0 AND r.CatalogNodeId IS NULL AND (e.CatalogId = @CatalogId OR @CatalogId = 0)))

	UNION ALL

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName, v.CatalogId
	FROM ecfVersion v
		INNER JOIN CatalogNode n ON v.ObjectId = n.CatalogNodeId
		INNER JOIN CatalogLanguage cl ON v.CatalogId = cl.CatalogId AND v.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
		LEFT OUTER JOIN CatalogNodeRelation nr on v.ObjectId = nr.ChildNodeId
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 1
		AND
			((n.ParentNodeId = @ParentId AND (n.CatalogId = @CatalogId OR @CatalogId = 0))
			OR
			(nr.ParentNodeId = @ParentId AND (nr.CatalogId = @CatalogId OR @CatalogId = 0)))
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 1, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
