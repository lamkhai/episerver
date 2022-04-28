--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 26    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Updating table [dbo].[MetaDataType]...';
GO
UPDATE MetaDataType
SET [Length] = -1,
	[SqlName] = N'nvarchar',
	[Variable] = 1
WHERE [Name] = N'NText'

UPDATE MetaDataType
SET [Length] = 4000
WHERE [Name] = N'ShortString'

UPDATE MetaDataType
SET [Length] = -1,
	[SqlName] = N'nvarchar',
	[Variable] = 1
WHERE [Name] = N'LongString'

UPDATE MetaDataType
SET [Length] = -1,
	[SqlName] = N'nvarchar',
	[Variable] = 1
WHERE [Name] = N'LongHtmlString'
GO


PRINT N'Altering [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
ALTER FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
(
    @entityId int,
    @type bit, -- 0 = Node, 1 = Entry
    @UriSegment nvarchar(255),
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @parentId int
	DECLARE @CatalogId int
    
    -- get the parentId and CatalogId, based on entityId and the entity type
    IF @type = 0
	BEGIN
		SELECT @parentId = ParentNodeId, @CatalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @entityId
		--no validation should be done until parent id is properly set
		IF(@parentId < 0)
			RETURN 0;
	END
    ELSE
	BEGIN
        SET @parentId = (SELECT TOP 1 CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId ORDER BY IsPrimary DESC)
		SET @CatalogId = (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @entityId)
	END

    SET @RetVal = 0

               
    IF NOT EXISTS( SELECT S.CatalogNodeId
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND ((@parentId = 0 AND N.CatalogId = @CatalogId AND N.ParentNodeId = 0) OR (@parentId <> 0 AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)))
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1) 
    BEGIN
    	-- check against sibling entry if only UriSegment does not exist on sibling node	
		IF EXISTS(
					SELECT S.CatalogEntryId
					FROM CatalogItemSeo S WITH (NOLOCK)
					INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId
					LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
					WHERE 
						S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
						AND S.CatalogEntryId <> @entityId 
						AND R.CatalogNodeId = @parentId
						AND R.CatalogId = @CatalogId
						AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
						AND N.IsActive = 1
						)
		BEGIN
			SET @RetVal = 1
		END
	END
	ELSE
	BEGIN
		SET @RetVal = 1
	END

    RETURN @RetVal;
END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_LoadBatch]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_LoadBatch]
	@PropertyReferences [udttCatalogContentPropertyReference] READONLY
AS
BEGIN
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0  --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, CTE1.LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			INNER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)
		-- Select CatalogContentProperty data
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
								THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
								ELSE P.LongString END 
							AS LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, CTE1.LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			INNER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)	
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], P.LongString LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_Save]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_Save]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ObjectId int,
	@ObjectTypeId int,
	@LanguageName NVARCHAR(50),
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	DECLARE @catalogId INT
	SET @catalogId =
		CASE
			WHEN @ObjectTypeId = 0 THEN
				(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
			WHEN @ObjectTypeId = 1 THEN
				(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
		END
	IF @LanguageName NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
	BEGIN
		SET @LanguageName = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @catalogId)
	END

	--delete properties where is null in input table
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND 
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1
	
	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
			LongString,
			[Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString, 
			[Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

	END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND 
			A.ObjectTypeId = I.ObjectTypeId AND 
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED 
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
			A.CultureSpecific = I.CultureSpecific,
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogNodeId > 0 OR t.CatalogEntryId <> c.CatalogEntryId
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly,
	@UseLessStrictUriSegmentValidation bit
AS
BEGIN
	DECLARE @query nvarchar(4000);

	-- validate Entry Uri Segment and return invalid record
	SET @query =
	'SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], NULL AS [UriSegment]
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.CatalogEntryId <> c.CatalogEntryId -- check against entry only
		AND t.UriSegment = c.UriSegment COLLATE DATABASE_DEFAULT'

	IF (@UseLessStrictUriSegmentValidation = 1)
	BEGIN
		SET @query = @query + '
		WHERE dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogEntryId, 1, t.UriSegment, t.LanguageCode) = 1

		UNION 

		SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], NULL AS [UriSegment]
		FROM @CatalogItemSeo t
		INNER JOIN @CatalogItemSeo s ON 
			t.LanguageCode = s.LanguageCode COLLATE DATABASE_DEFAULT
			AND t.CatalogEntryId <> s.CatalogEntryId -- check against entry only
			AND t.UriSegment = s.UriSegment COLLATE DATABASE_DEFAULT
			AND dbo.fn_AreSiblings(t.CatalogEntryId, s.CatalogEntryId) =  1'
	END

	exec sp_executesql @query, N'@CatalogItemSeo dbo.udttCatalogItemSeo readonly', @CatalogItemSeo = @CatalogItemSeo
END
GO
PRINT N'Altering [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]
AS
	;WITH
	GlobalDuplicates AS(
		SELECT S.*
		FROM
		CatalogItemSeo S
		INNER JOIN
			(SELECT UriSegment, LanguageCode
			FROM CatalogItemSeo
			GROUP BY UriSegment, LanguageCode COLLATE DATABASE_DEFAULT 
			HAVING COUNT(*) > 1) D
		ON D.UriSegment = S.UriSegment and D.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT),
	GlobalDuplicatesWithParents AS(
			SELECT
				G.*,
				COALESCE(NR.ParentNodeId, N.ParentNodeId) AS ParentNodeId,
				COALESCE(NR.CatalogId, N.CatalogId) AS CatalogId
			FROM GlobalDuplicates G
			INNER JOIN
			CatalogNode N
			ON G.CatalogNodeId = N.CatalogNodeId
			LEFT OUTER JOIN CatalogNodeRelation NR
			ON NR.ChildNodeId = N.CatalogNodeId
		UNION ALL
			SELECT
				G.*,
				NER.CatalogNodeId AS ParentNodeId,
				NER.CatalogId as CatalogId
			FROM GlobalDuplicates G
			INNER JOIN CatalogEntry E
			ON G.CatalogEntryId = E.CatalogEntryId
			LEFT OUTER JOIN NodeEntryRelation NER
			ON NER.CatalogEntryId = E.CatalogEntryId)

	SELECT GP.UriSegment, GP.LanguageCode, GP.CatalogEntryId, GP.CatalogNodeId, GP.ParentNodeId, GP.CatalogId
	FROM GlobalDuplicatesWithParents GP
	INNER JOIN
		(SELECT ParentNodeId, CatalogId, UriSegment, LanguageCode
		FROM GlobalDuplicatesWithParents
		GROUP BY ParentNodeId, CatalogId, UriSegment, LanguageCode COLLATE DATABASE_DEFAULT 
		HAVING COUNT(*) > 1) C
		ON
			GP.ParentNodeId = C.ParentNodeId AND GP.CatalogId = C.CatalogId AND
			GP.UriSegment = C.UriSegment AND GP.LanguageCode = C.LanguageCode COLLATE DATABASE_DEFAULT
GO
PRINT N'Altering [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogEntryId > 0 OR t.CatalogNodeId <> c.CatalogNodeId
END
GO
PRINT N'Altering [dbo].[ecf_CheckExistEntryNodeByCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CheckExistEntryNodeByCode]
	@EntryNodeCode nvarchar(100)
AS
BEGIN
	DECLARE @exist BIT
	SET @exist = 0
	IF EXISTS (SELECT * FROM [CatalogEntry] WHERE Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END
	
	IF @exist = 0 AND EXISTS (SELECT * FROM [CatalogNode] WHERE Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END

	SELECT @exist
END
GO
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
	INNER JOIN @ObjectIds i ON vn.ObjectId = i.ContentId AND vn.ObjectTypeId = @ObjectTypeId
	INNER JOIN CatalogLanguage cl ON vn.CatalogId = cl.CatalogId AND vn.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
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
PRINT N'Altering [dbo].[ecfVersion_ListByEntryWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByEntryWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.ContentGuid, e.ClassTypeId, e.MetaClassId, e.IsPublished AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND links.ObjectTypeId = 0
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	
	
	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN @ContentLinks links ON links.ObjectId = r.CatalogEntryId AND links.ObjectTypeId = 0
	WHERE r.IsPrimary = 1 
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListByNodeWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByNodeWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	SELECT draft.*, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND links.ObjectTypeId = 1
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode
	LEFT JOIN ecfVersionProperty p ON  p.WorkId = draft.WorkId
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

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
PRINT N'Altering [dbo].[ecfVersion_PublishContentVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_PublishContentVersion]
	@WorkId			INT,
	@ObjectId		INT,
	@ObjectTypeId	INT,
	@LanguageName	NVARCHAR(50),
	@MaxVersions	INT,
	@ResetCommonDraft BIT = 1
AS
BEGIN
	-- Update old published version status to previously published
	UPDATE	ecfVersion
	SET		[Status] = 5, -- previously published = 5
	        IsCommonDraft = 0		
	WHERE	[Status] = 4 -- published = 4
			AND ObjectId = @ObjectId
			AND ObjectTypeId = @ObjectTypeId
			AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
			AND WorkId != @WorkId

	-- Update is common draft
	IF @ResetCommonDraft = 1
		EXEC ecfVersion_SetCommonDraft @WorkId = @WorkId, @Force = 1

	-- Delete previously published version. The number of previous published version must be <= maxVersions.
	-- This only take effect by language
	CREATE TABLE #WorkIds(Id INT IDENTITY(1,1) NOT NULL, WorkId INT NOT NULL)
	INSERT INTO #WorkIds(WorkId)
	SELECT WorkId
	FROM ecfVersion
	WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND [Status] = 5 AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId DESC
	
	-- Delete all previously published version that older than @MaxVersions of this content
	DELETE FROM ecfVersion
	WHERE WorkId IN (SELECT WorkId 
					 FROM  #WorkIds 
					 WHERE Id > @MaxVersions - 1)
	
	DROP TABLE #WorkIds
END
GO
PRINT N'Altering [dbo].[ecfVersion_SyncCatalogData]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, '', d.CreatedBy, d.Created, d.ModifiedBy, d.Modified,
				  c.EndDate, d.SeoUriSegment
			FROM @ContentDraft d
			INNER JOIN dbo.Catalog c on d.ObjectId = c.CatalogId)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, [MasterLanguageName], IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET 
			target.CatalogId = SOURCE.CatalogId,
			target.MasterLanguageName = SOURCE.MasterLanguageName, 
			target.IsCommonDraft = SOURCE.IsCommonDraft,
			target.StartPublish = SOURCE.StartPublish, 
			target.Name = SOURCE.Name, 
			target.Code = SOURCE.Code,
			target.Modified = SOURCE.Modified, 
			target.ModifiedBy = SOURCE.ModifiedBy,
			target.StopPublish = SOURCE.StopPublish,
			target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, StopPublish, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified, SOURCE.StopPublish, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;

	-- Adjust any previous and already existing versions and making sure they are not flagged as common draft.
	-- For any updated rows having status Published (4) existing rows with the same status will be changed to
	-- Previously Published (5).
	UPDATE existing	SET 
		   existing.IsCommonDraft = 0,	
	       existing.Status = CASE WHEN updated.Status = 4 AND existing.Status = 4 THEN 5 ELSE existing.Status END
	FROM ecfVersion AS existing INNER JOIN @ContentDraft AS updated ON 
		existing.ObjectId = updated.ObjectId 
		AND existing.ObjectTypeId = updated.ObjectTypeId 
		AND existing.LanguageName = updated.LanguageName COLLATE DATABASE_DEFAULT
	WHERE existing.WorkId NOT IN (SELECT WorkId FROM @WorkIds);

	-- Insert/Update Catalog draft table
	DECLARE @catalogs AS dbo.[udttVersionCatalog]
	INSERT INTO @catalogs
		SELECT w.WorkId, c.DefaultCurrency, c.WeightBase, c.LengthBase, c.DefaultLanguage, [dbo].[fn_JoinCatalogLanguages](c.CatalogId) as Languages, c.IsPrimary, c.[Owner]
		FROM @WorkIds w
		INNER JOIN dbo.Catalog c ON w.ObjectId = c.CatalogId AND w.MasterLanguageName = c.DefaultLanguage COLLATE DATABASE_DEFAULT

	EXEC [ecfVersionCatalog_Save] @VersionCatalogs = @catalogs, @PublishAction = 1

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO
PRINT N'Altering [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
	@ObjectIds udttObjectWorkId readonly
AS
BEGIN
	DECLARE @WorkIds TABLE (WorkId INT)
	INSERT INTO @WorkIds (WorkId)
		SELECT ver.WorkId
		FROM ecfVersion ver
		INNER JOIN @ObjectIds c ON ver.ObjectId = c.ObjectId AND ver.ObjectTypeId = c.ObjectTypeId
		WHERE (ver.Status = 4)
	UNION
		SELECT ver.WorkId
		FROM ecfVersion ver
		INNER JOIN @ObjectIds c ON ver.ObjectId = c.ObjectId AND ver.ObjectTypeId = c.ObjectTypeId
		WHERE (ver.IsCommonDraft = 1 AND 
		NOT EXISTS(SELECT 1 FROM ecfVersion ev WHERE ev.ObjectId = c.ObjectId AND ev.ObjectTypeId = c.ObjectTypeId AND ev.Status = 4 ))
	
	--update entry versions
	UPDATE ver 
	SET ver.SeoUri = s.Uri,
	    ver.SeoUriSegment = s.UriSegment
	FROM ecfVersion ver
	INNER JOIN @WorkIds ids ON ver.WorkId = ids.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogEntryId = ver.ObjectId AND ver.ObjectTypeId = 0)
	WHERE s.LanguageCode = ver.LanguageName COLLATE DATABASE_DEFAULT
	
	--update node versions
	UPDATE ver 
	SET ver.SeoUri = s.Uri,
	    ver.SeoUriSegment = s.UriSegment
	FROM ecfVersion ver
	INNER JOIN @WorkIds ids on ver.WorkId = ids.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogNodeId = ver.ObjectId AND ver.ObjectTypeId = 1)
	WHERE s.LanguageCode = ver.LanguageName COLLATE DATABASE_DEFAULT
END
GO
PRINT N'Altering [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
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
		c.[Owner]		 
	FROM [Catalog] c
	INNER JOIN @ContentLinks l ON c.CatalogId = l.ObjectId AND l.ObjectTypeId = 2
	INNER JOIN ecfVersion v ON v.WorkId = l.WorkId
	INNER JOIN CatalogLanguage cl ON cl.CatalogId = c.CatalogId AND cl.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId
END
GO
PRINT N'Altering [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	
	DECLARE @propertyData udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid], [IsNull])
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync
	END

	-- delete rows where values have been nulled out
	DELETE A 
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @propertyData T
	ON	A.WorkId = T.WorkId AND 
		A.MetaFieldId = T.MetaFieldId AND
		T.[IsNull] = 1

	-- now null rows are handled, so remove them to not insert empty rows
	DELETE FROM @propertyData
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
	ON		A.WorkId = I.WorkId AND
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 		
			A.LanguageName = I.LanguageName,	
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Sync version properties with version
	UPDATE [dbo].[ecfVersion]
     SET [StartPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E 
		ON E.[WorkId] = I.[WorkId] 
	WHERE I.[MetaFieldName] = 'Epi_StartPublish'
	 
	  
	UPDATE [dbo].[ecfVersion]
     SET [StopPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_StopPublish'

	UPDATE [dbo].[ecfVersion]
     SET [Status] = CASE when I.[Boolean] = 0 THEN 2
					ELSE 4 END
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfVersion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_IsPublished'

END
GO
PRINT N'Altering [dbo].[mdpsp_sys_CreateMetaClassProcedure]...';


GO
ALTER procedure [dbo].[mdpsp_sys_CreateMetaClassProcedure]
    @MetaClassId int
as
begin
    set nocount on
    begin try
        declare @CRLF nchar(1) = CHAR(10)
        declare @MetaClassName nvarchar(256)
        declare @TableName sysname
        declare @IsEntryMetaClass bit = 0
        declare @IsNodeMetaClass bit = 0

        select @MetaClassName = Name, @TableName = TableName from MetaClass where MetaClassId = @MetaClassId
        SET @IsEntryMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogEntry'))
        SET @IsNodeMetaClass = (SELECT [dbo].[mdpfn_sys_IsInheritedFromMetaClass](@MetaClassId, 'CatalogNode'))

        if @MetaClassName is null raiserror('Metaclass not found.',16,1)

        declare @azureCompatible bit
        SET @azureCompatible = (SELECT TOP 1 AzureCompatible FROM dbo.AzureCompatible)
        
        -- get required info for each field
        declare @ParameterIndex int
        declare @ColumnName sysname
        declare @FieldIsMultilanguage bit
        declare @FieldIsEncrypted bit
        declare @FieldIsNullable bit
        declare @ColumnDataType sysname
        declare fields cursor local for
            select
                mfindex.ParameterIndex,
                mf.Name as ColumnName,
                mf.MultiLanguageValue as FieldIsMultilanguage,
                mf.IsEncrypted as FieldIsEncrypted,
                mf.AllowNulls,
                mdt.SqlName + case
                        when mdt.Variable = 1 then 
							case when (mf.Length = -1) then '(max)'
							else '(' + CAST(mf.Length as nvarchar) + ')'
							end
                        when mf.DataTypeId in (5,24) and mfprecis.Value is not null and mfscale.Value is not null then '(' + cast(mfprecis.Value as nvarchar) + ',' + cast(mfscale.Value as nvarchar) + ')'
                        else '' end as ColumnDataType
            from (
                select ROW_NUMBER() over (order by innermf.Name) as ParameterIndex, innermf.MetaFieldId
                from MetaField innermf
                where innermf.SystemMetaClassId = 0
                  and exists (select 1 from MetaClassMetaFieldRelation cfr where cfr.MetaClassId = @MetaClassId and cfr.MetaFieldId = innermf.MetaFieldId)) mfindex
            join MetaField mf on mfindex.MetaFieldId = mf.MetaFieldId
            join MetaDataType mdt on mf.DataTypeId = mdt.DataTypeId
            left outer join MetaAttribute mfprecis on mf.MetaFieldId = mfprecis.AttrOwnerId and mfprecis.AttrOwnerType = 2 and mfprecis.[Key] = 'MdpPrecision'
            left outer join MetaAttribute mfscale on mf.MetaFieldId = mfscale.AttrOwnerId and mfscale.AttrOwnerType = 2 and mfscale.[Key] = 'MdpScale'

        -- aggregate field parts into lists for stored procedures
        declare @ParameterName nvarchar(max)
        declare @ColumnReadBase nvarchar(max)
        declare @ColumnReadLocal nvarchar(max)
        declare @WriteValue nvarchar(max)
        declare @ParameterDefinitions nvarchar(max) = ''
        declare @UnlocalizedSelectValues nvarchar(max) = ''
        declare @LocalizedSelectValues nvarchar(max) = ''
        declare @AllInsertColumns nvarchar(max) = ''
        declare @AllInsertValues nvarchar(max) = ''
        declare @BaseInsertColumns nvarchar(max) = ''
        declare @BaseInsertValues nvarchar(max) = ''
        declare @LocalInsertColumns nvarchar(max) = ''
        declare @LocalInsertValues nvarchar(max) = ''
        declare @AllUpdateActions nvarchar(max) = ''
        declare @BaseUpdateActions nvarchar(max) = ''
        declare @LocalUpdateActions nvarchar(max) = ''
        open fields
        while 1=1
        begin
            fetch next from fields into @ParameterIndex, @ColumnName, @FieldIsMultilanguage, @FieldIsEncrypted, @FieldIsNullable, @ColumnDataType
            if @@FETCH_STATUS != 0 break

            set @ParameterName = '@f' + cast(@ParameterIndex as nvarchar(10))
            set @ColumnReadBase = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(T.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'T.[' + @ColumnName + ']' end
            set @ColumnReadLocal = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(L.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'L.[' + @ColumnName + ']' end
            set @WriteValue = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(' + @ParameterName + ',1)' else @ParameterName end

            set @ParameterDefinitions = @ParameterDefinitions + ',' + @ParameterName + ' ' + @ColumnDataType
            set @UnlocalizedSelectValues = @UnlocalizedSelectValues + ',' + @ColumnReadBase
            set @LocalizedSelectValues = @LocalizedSelectValues + ',' + case when @FieldIsMultilanguage = 1 then @ColumnReadLocal else @ColumnReadBase end
            set @AllInsertColumns = @AllInsertColumns + ',[' + @ColumnName + ']'
            set @AllInsertValues = @AllInsertValues + ',' + @WriteValue
            set @BaseInsertColumns = @BaseInsertColumns + case when @FieldIsMultilanguage = 0 then ',[' + @ColumnName + ']' else '' end
            set @BaseInsertValues = @BaseInsertValues + case when @FieldIsMultilanguage = 0 then ',' + @WriteValue else '' end
            set @LocalInsertColumns = @LocalInsertColumns + case when @FieldIsMultilanguage = 1 then ',[' + @ColumnName + ']' else '' end
            set @LocalInsertValues = @LocalInsertValues + case when @FieldIsMultilanguage = 1 then ',' + @WriteValue else '' end
            set @AllUpdateActions = @AllUpdateActions + ',[' + @ColumnName + ']=' + @WriteValue
            set @BaseUpdateActions = @BaseUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 0 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
            set @LocalUpdateActions = @LocalUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 1 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
        end
        close fields

        declare @OpenEncryptionKey nvarchar(max)
        declare @CloseEncryptionKey nvarchar(max)
        if exists(  select 1
                    from MetaField mf
                    join MetaClassMetaFieldRelation cfr on mf.MetaFieldId = cfr.MetaFieldId
                    where cfr.MetaClassId = @MetaClassId and mf.SystemMetaClassId = 0 and mf.IsEncrypted = 1) and @azureCompatible <> 1
        begin
            set @OpenEncryptionKey = 'exec mdpsp_sys_OpenSymmetricKey' + @CRLF
            set @CloseEncryptionKey = 'exec mdpsp_sys_CloseSymmetricKey' + @CRLF
        end
        else
        begin
            set @OpenEncryptionKey = ''
            set @CloseEncryptionKey = ''
        end

        -- create stored procedures
        declare @procedures table (name sysname, defn nvarchar(max), verb nvarchar(max))
        IF @IsEntryMetaClass = 1 OR @IsNodeMetaClass = 1
        BEGIN
            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_ListSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_ListSpecificRecord] @Language nvarchar(20),@Count int as' + @CRLF +
                'begin' + @CRLF +
                    'if exists (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N''' + @TableName + ''') ' + @CRLF +
                    'begin' + @CRLF +
                        @OpenEncryptionKey +
                        'select TOP(@Count) T.ObjectId,C.IsActive,C.StartDate StartPublish,C.EndDate StopPublish,C.CatalogId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                        'from [' + @TableName + '] T' + @CRLF +
                        'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ' + @CRLF +
                        'inner join Catalog' + CASE WHEN @IsEntryMetaClass = 1 THEN 'Entry' ELSE 'Node' END + ' C on T.ObjectId = C.Catalog' + CASE WHEN @IsEntryMetaClass = 1 THEN 'Entry' ELSE 'Node' END + 'Id' + @CRLF +
						'inner join Catalog cat on cat.CatalogId = C.CatalogId ' + @CRLF +
						'inner join CatalogLanguage cl on cl.CatalogId = cat.CatalogId and cl.LanguageCode = @Language ' + @CRLF +
						'where C.MetaClassId = ' + CAST(@MetaClassId AS VARCHAR(16)) + @CRLF +
                        'order by T.ObjectId ASC ' + @CRLF +
                        @CloseEncryptionKey +
                    'end' + @CRLF +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_DeleteSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_DeleteSpecificRecord] @IdsToDelete dbo.udttIdTable readonly as' + @CRLF +
                'begin' + @CRLF +
                'DELETE M FROM [' + @TableName + '] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
                'DELETE M FROM [' + @TableName + '_Localization] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
                'end' + @CRLF)
        END
        ELSE
        BEGIN
            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Get',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Get] @ObjectId int,@Language nvarchar(20)=null as ' + @CRLF +
                'begin' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T where ObjectId=@ObjectId' + @CRLF +
                'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T' + @CRLF +
                'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
                'where T.ObjectId= @ObjectId' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Update',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Update]' + @CRLF +
                '@ObjectId int,@Language nvarchar(20)=null,@CreatorId nvarchar(100),@Created datetime,@ModifierId nvarchar(100),@Modified datetime,@Retval int out' + @ParameterDefinitions + ' as' + @CRLF +
                'begin' + @CRLF +
                'set nocount on' + @CRLF +
                'declare @ins bit' + @CRLF +
                'begin try' + @CRLF +
                'begin transaction' + @CRLF +
                @OpenEncryptionKey +
                'if @ObjectId=-1 select @ObjectId=isnull(MAX(ObjectId),0)+1, @Retval=@ObjectId, @ins=0 from [' + @TableName + ']' + @CRLF +
                'else set @ins=case when exists(select 1 from [' + @TableName + '] where ObjectId=@ObjectId) then 0 else 1 end' + @CRLF +
                'if @Language is null' + @CRLF +
                'begin' + @CRLF +
                '  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @AllInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @AllInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @AllUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId' + @CRLF +
                'end' + @CRLF +
                'else' + @CRLF +
                'begin' + @CRLF +
                '  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @BaseInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @BaseInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @BaseUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId' + @CRLF +
                '  if not exists (select 1 from [' + @TableName + '_Localization] where ObjectId=@ObjectId and Language=@Language)' + @CRLF +
                '  insert [' + @TableName + '_Localization] (ObjectId,Language,ModifierId,Modified' + @LocalInsertColumns + ')' + @CRLF +
                '  values (@ObjectId,@Language,@ModifierId,@Modified' + @LocalInsertValues + ')' + @CRLF +
                '  else update [' + @TableName + '_Localization] set ModifierId=@ModifierId,Modified=@Modified' + @LocalUpdateActions + @CRLF +
                '  where ObjectId=@ObjectId and Language=@language' + @CRLF +
                'end' + @CRLF +
                @CloseEncryptionKey +
                'commit transaction' + @CRLF +
                'end try' + @CRLF +
                'begin catch' + @CRLF +
                '  declare @m nvarchar(4000),@v int,@t int' + @CRLF +
                '  select @m=ERROR_MESSAGE(),@v=ERROR_SEVERITY(),@t=ERROR_STATE()' + @CRLF +
                '  rollback transaction' + @CRLF +
                '  raiserror(@m, @v, @t)' + @CRLF +
                'end catch' + @CRLF +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Delete',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Delete] @ObjectId int as' + @CRLF +
                'begin' + @CRLF +
                'delete [' + @TableName + '] where ObjectId=@ObjectId' + @CRLF +
                'delete [' + @TableName + '_Localization] where ObjectId=@ObjectId' + @CRLF +
				'DECLARE @AffectedMetaKeys udttIdTable ' + @CRLF +
					'INSERT INTO @AffectedMetaKeys ' + @CRLF +
				'SELECT MK.MetaKey ' + @CRLF +
					'FROM MetaKey MK ' + @CRLF +
				'WHERE MK.MetaObjectId = @ObjectId '  + @CRLF +
				'AND MK.MetaClassId = '+ CAST(@MetaClassId as nvarchar(10))  + @CRLF +
                'exec mdpsp_sys_DeleteMetaKeyObjects @AffectedMetaKeys ' + @CRLF +
				'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_List',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_List] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
                'begin' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + ' from [' + @TableName + '] T' + @CRLF +
                'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
                'from [' + @TableName + '] T' + @CRLF +
                'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)

            insert into @procedures (name, defn)
            values ('mdpsp_avto_' + @TableName + '_Search',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_Search] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
                'begin' + @CRLF +
                'if len(@select_list)>0 set @select_list='',''+@select_list' + @CRLF +
                @OpenEncryptionKey +
                'if @Language is null exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T ''+@search_condition)' + @CRLF +
                'else exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ''+@search_condition)' + @CRLF +
                @CloseEncryptionKey +
                'end' + @CRLF)
        END

        update tgt
        set verb = case when r.ROUTINE_NAME is null then 'create ' else 'alter ' end
        from @procedures tgt
        left outer join INFORMATION_SCHEMA.ROUTINES r on r.ROUTINE_SCHEMA COLLATE DATABASE_DEFAULT = 'dbo' and r.ROUTINE_NAME COLLATE DATABASE_DEFAULT = tgt.name COLLATE DATABASE_DEFAULT

        -- install procedures
        declare @sqlstatement nvarchar(max)
        declare procedure_cursor cursor local for select verb + defn from @procedures
        open procedure_cursor
        while 1=1
        begin
            fetch next from procedure_cursor into @sqlstatement
            if @@FETCH_STATUS != 0 break
            exec(@sqlstatement)
        end
        close procedure_cursor
    end try
    begin catch
        declare @m nvarchar(4000), @v int, @t int
        select @m = ERROR_MESSAGE(), @v = ERROR_SEVERITY(), @t = ERROR_STATE()
        raiserror(@m,@v,@t)
    end catch
end
GO
PRINT N'Altering [dbo].[CatalogContentProperty_SaveBatch]...';


GO

ALTER PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@Data dbo.[udttCatalogContentEx] readonly,
	@SyncVersion bit = 1
AS
BEGIN
	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString,
				[Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0
		END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND
			A.ObjectTypeId = I.ObjectTypeId AND
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
			A.Boolean = I.Boolean,
			A.Number = I.Number,
			A.FloatNumber = I.FloatNumber,
			A.[Money] = I.[Money],
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date],
			A.[Binary] = I.[Binary],
			A.[String] = I.[String],
			A.LongString = I.LongString,
			A.[Guid] = I.[Guid]

	WHEN NOT MATCHED BY TARGET
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number,
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	-- Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC ecfVersionProperty_SyncBatchPublishedVersion @ContentProperty
	END

	-- Update CatalogContentEx
	EXEC CatalogContentEx_Save @Data
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly,
	@UseLessStrictUriSegmentValidation bit
AS
BEGIN
	-- validate Entry Uri and Uri Segment, then return invalid record
	DECLARE @InvalidSeoUri dbo.udttCatalogItemSeo
	DECLARE @InvalidUriSegment dbo.udttCatalogItemSeo
	
	INSERT INTO @InvalidSeoUri ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment]) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUri] @CatalogItemSeo

	INSERT INTO @InvalidUriSegment ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment]) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUriSegment] @CatalogItemSeo, @UseLessStrictUriSegmentValidation

	MERGE @InvalidSeoUri as U
	USING @InvalidUriSegment as S
	ON 
		U.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT AND 
		U.CatalogEntryId = S.CatalogEntryId
	WHEN MATCHED -- update the UriSegment for existing row in #ValidSeoUri
		THEN UPDATE SET U.UriSegment = S.UriSegment
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in #ValidSeoUri table (source table)
		THEN INSERT VALUES(S.LanguageCode, S.CatalogNodeId, S.CatalogEntryId, S.Uri, S.UriSegment)
	;

	SELECT * FROM @InvalidSeoUri
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and Uri Segment, then return invalid record
	DECLARE @ValidSeoUri dbo.udttCatalogItemSeo
	DECLARE @ValidUriSegment dbo.udttCatalogItemSeo
	
	INSERT INTO @ValidSeoUri ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment] ) 
		EXEC [ecf_CatalogNodeItemSeo_ValidateUri] @CatalogItemSeo		
	
	INSERT INTO @ValidUriSegment ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment] ) 
		EXEC [ecf_CatalogNodeItemSeo_ValidateUriSegment] @CatalogItemSeo

	MERGE @ValidSeoUri as U
	USING @ValidUriSegment as S
	ON 
		U.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT AND 
		U.CatalogNodeId = S.CatalogNodeId
	WHEN MATCHED -- update the UriSegment for existing row in #ValidSeoUri
		THEN UPDATE SET U.UriSegment = S.UriSegment
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in #ValidSeoUri table (source table)
		THEN INSERT VALUES(S.LanguageCode, S.CatalogNodeId, S.CatalogEntryId, S.Uri, S.UriSegment)
	;

	SELECT * FROM @ValidSeoUri
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListByCatalogWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByCatalogWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	SELECT draft.*, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId AND links.ObjectTypeId = 2
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

END
GO
PRINT N'Altering [dbo].[ecfVersion_SyncEntryData]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SyncEntryData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))
	
	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, c.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, c.Code, d.CreatedBy, d.Created, d.ModifiedBy, d.Modified, 
				  c.EndDate, s.Uri, s.Title, s.[Description], s.Keywords, s.UriSegment
			FROM @ContentDraft d
			INNER JOIN dbo.CatalogEntry c on d.ObjectId = c.CatalogEntryId
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogEntryId AND d.LanguageName = s.LanguageCode COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET 
			target.CatalogId = SOURCE.CatalogId,
			target.IsCommonDraft = SOURCE.IsCommonDraft, 
			target.[Status] = SOURCE.[Status],
			target.StartPublish = SOURCE.StartPublish, 
			target.Name = SOURCE.Name, 
			target.Code = SOURCE.Code, 
			target.Modified = SOURCE.Modified, 
			target.ModifiedBy = SOURCE.ModifiedBy, 
			target.StopPublish = SOURCE.StopPublish,
			target.SeoUri = SOURCE.SeoUri, 
			target.SeoTitle = SOURCE.SeoTitle, 
			target.SeoDescription = SOURCE.SeoDescription, 
			target.SeoKeywords = SOURCE.SeoKeywords, 
			target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
				StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish, SOURCE.SeoUri, SOURCE.SeoTitle, SOURCE.SeoDescription, SOURCE.SeoKeywords, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;
	
	-- Adjust any previous and already existing versions and making sure they are not flagged as common draft.
	-- For any updated rows having status Published (4) existing rows with the same status will be changed to
	-- Previously Published (5).
	UPDATE existing	SET 
		   existing.IsCommonDraft = 0,	
	       existing.Status = CASE WHEN updated.Status = 4 AND existing.Status = 4 THEN 5 ELSE existing.Status END
	FROM ecfVersion AS existing INNER JOIN @ContentDraft AS updated ON 
		existing.ObjectId = updated.ObjectId 
		AND existing.ObjectTypeId = updated.ObjectTypeId 
		AND existing.LanguageName = updated.LanguageName COLLATE DATABASE_DEFAULT
	WHERE existing.WorkId NOT IN (SELECT WorkId FROM @WorkIds);

	-- Insert/Update Draft Asset
	DECLARE @draftAsset AS dbo.[udttCatalogContentAsset]
	INSERT INTO @draftAsset 
		SELECT w.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder 
		FROM @WorkIds w
		INNER JOIN CatalogItemAsset a ON w.ObjectId = a.CatalogEntryId
	
	DECLARE @workIdList dbo.[udttObjectWorkId]
	INSERT INTO @workIdList 
		SELECT NULL, NULL, w.WorkId, NULL 
		FROM @WorkIds w
	
	EXEC [ecfVersionAsset_Save] @workIdList, @draftAsset

	-- Insert/Update Draft Variation
	DECLARE @draftVariant dbo.[udttVariantDraft]
	INSERT INTO @draftVariant
		SELECT ids.WorkId, v.TaxCategoryId, v.TrackInventory, v.[Weight], v.MinQuantity, v.MaxQuantity, v.[Length], v.Height, v.Width, v.PackageId
		FROM @WorkIds ids
		INNER JOIN Variation v on ids.ObjectId = v.CatalogEntryId
		
	EXEC [ecfVersionVariation_Save] @draftVariant

	DECLARE @versionProperties dbo.udttCatalogContentProperty
	INSERT INTO @versionProperties (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid])
		SELECT
			w.WorkId, c.ObjectId, c.ObjectTypeId, c.MetaFieldId, c.MetaClassId, c.MetaFieldName, c.LanguageName, c.Boolean, c.Number,
			c.FloatNumber, c.[Money], c.[Decimal], c.[Date], c.[Binary], c.String, c.LongString, c.[Guid]
		FROM @workIds w
		INNER JOIN CatalogContentProperty c
		ON
			w.ObjectId = c.ObjectId AND
			w.LanguageName = c.LanguageName
		WHERE
			c.ObjectTypeId = 0

	EXEC [ecfVersionProperty_SyncBatchPublishedVersion] @versionProperties

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO
PRINT N'Altering [dbo].[ecfVersion_SyncNodeData]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SyncNodeData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, c.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status], 
				  c.StartDate, c.Name, c.Code, d.CreatedBy, d.Created, d.ModifiedBy, d.Modified,
				  c.EndDate, s.Uri, s.Title, s.[Description], s.Keywords, s.UriSegment
			FROM @ContentDraft d
			INNER JOIN dbo.CatalogNode c on d.ObjectId = c.CatalogNodeId
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogNodeId AND d.LanguageName = s.LanguageCode COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET 
			target.CatalogId = SOURCE.CatalogId,
			target.IsCommonDraft = SOURCE.IsCommonDraft, 
			target.[Status] = SOURCE.[Status], 
			target.StartPublish = SOURCE.StartPublish, 
			target.Name = SOURCE.Name, 
			target.Code = SOURCE.Code, 
			target.Modified = SOURCE.Modified, 
			target.ModifiedBy = SOURCE.ModifiedBy,
			target.StopPublish = SOURCE.StopPublish,
			target.SeoUri = SOURCE.SeoUri, 
			target.SeoTitle = SOURCE.SeoTitle, 
			target.SeoDescription = SOURCE.SeoDescription, 
			target.SeoKeywords = SOURCE.SeoKeywords, 
			target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			    StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
				StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish, SOURCE.SeoUri, SOURCE.SeoTitle, SOURCE.SeoDescription, SOURCE.SeoKeywords, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;
	
	-- Adjust any previous and already existing versions and making sure they are not flagged as common draft.
	-- For any updated rows having status Published (4) existing rows with the same status will be changed to
	-- Previously Published (5).
	UPDATE existing	SET 
		   existing.IsCommonDraft = 0,	
	       existing.Status = CASE WHEN updated.Status = 4 AND existing.Status = 4 THEN 5 ELSE existing.Status END
	FROM ecfVersion AS existing INNER JOIN @ContentDraft AS updated ON 
		existing.ObjectId = updated.ObjectId 
		AND existing.ObjectTypeId = updated.ObjectTypeId 
		AND existing.LanguageName = updated.LanguageName COLLATE DATABASE_DEFAULT
	WHERE existing.WorkId NOT IN (SELECT WorkId FROM @WorkIds);

	-- Insert/Update Draft Asset
	DECLARE @draftAsset AS dbo.[udttCatalogContentAsset]
	INSERT INTO @draftAsset 
		SELECT w.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder 
		FROM @WorkIds w
		INNER JOIN dbo.CatalogItemAsset a ON w.ObjectId = a.CatalogNodeId WHERE a.CatalogNodeId > 0

	DECLARE @workIdList dbo.[udttObjectWorkId]
	INSERT INTO @workIdList 
		SELECT NULL, NULL, w.WorkId, NULL 
		FROM @WorkIds w
	
	EXEC [ecfVersionAsset_Save] @workIdList, @draftAsset

	DECLARE @versionProperties dbo.udttCatalogContentProperty
	INSERT INTO @versionProperties (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid])
		SELECT
			w.WorkId, c.ObjectId, c.ObjectTypeId, c.MetaFieldId, c.MetaClassId, c.MetaFieldName, c.LanguageName, c.Boolean, c.Number,
			c.FloatNumber, c.[Money], c.[Decimal], c.[Date], c.[Binary], c.String, c.LongString, c.[Guid]
		FROM @workIds w
		INNER JOIN CatalogContentProperty c
		ON
			w.ObjectId = c.ObjectId AND
			w.LanguageName = c.LanguageName
		WHERE 
			c.ObjectTypeId = 1

	EXEC [ecfVersionProperty_SyncBatchPublishedVersion] @versionProperties

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO
PRINT N'Altering [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]
	@MetaClassId	INT,
	@MetaFieldId	INT,
	@Weight	INT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON

	DECLARE @IsAbstractClass	BIT
	SELECT @IsAbstractClass = IsAbstract FROM MetaClass WHERE MetaClassId = @MetaClassId

    BEGIN TRAN
	IF NOT EXISTS( SELECT * FROM MetaClass WHERE MetaClassId = @MetaClassId AND IsSystem = 0)
	BEGIN
		RAISERROR ('Wrong @MetaClassId. The class is system or not exists.', 16,1)
		GOTO ERR
	END

	IF NOT EXISTS( SELECT * FROM MetaField WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0)
	BEGIN
		RAISERROR ('Wrong @MetaFieldId. The field is system or not exists.', 16,1)
		GOTO ERR
	END

	DECLARE @IsCatalogMetaClass BIT
	SET @IsCatalogMetaClass = 0

	IF @IsAbstractClass = 0
	BEGIN
		-- Step 1. Insert a new column.
		DECLARE @Name		NVARCHAR(256)
		DECLARE @DataTypeId	INT
		DECLARE @Length		INT
		DECLARE @AllowNulls		BIT
		DECLARE @MultiLanguageValue BIT
		DECLARE @AllowSearch	BIT
		DECLARE @IsEncrypted	BIT

		SELECT @Name = [Name], @DataTypeId = DataTypeId,  @Length = [Length], @AllowNulls = AllowNulls, @MultiLanguageValue = MultiLanguageValue, @AllowSearch = AllowSearch, @IsEncrypted = IsEncrypted
		FROM [MetaField]
        WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0

		-- Step 1-1. Create a new column query.

		DECLARE @MetaClassTableName NVARCHAR(256)
		DECLARE @SqlDataTypeName NVARCHAR(256)
		DECLARE @IsVariableDataType BIT
		DECLARE @DefaultValue	NVARCHAR(50)

		SELECT @MetaClassTableName = TableName FROM MetaClass WHERE MetaClassId = @MetaClassId

		IF @@ERROR<> 0 GOTO ERR

		SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaClassTableName)

		IF @IsCatalogMetaClass = 0
		BEGIN
			SELECT @SqlDataTypeName = SqlName,  @IsVariableDataType = Variable, @DefaultValue = DefaultValue FROM MetaDataType WHERE DataTypeId= @DataTypeId

			IF @@ERROR<> 0 GOTO ERR

			DECLARE @ExecLine 			NVARCHAR(1024)
			DECLARE @ExecLineLocalization 	NVARCHAR(1024)

			SET @ExecLine = 'ALTER TABLE [dbo].['+@MetaClassTableName+'] ADD ['+@Name+'] ' + @SqlDataTypeName
			SET @ExecLineLocalization = 'ALTER TABLE [dbo].['+@MetaClassTableName+'_Localization] ADD ['+@Name+'] ' + @SqlDataTypeName

			IF @IsVariableDataType = 1
			BEGIN
				IF(@Length = -1)
				BEGIN
					SET @ExecLine = @ExecLine + '(max)'
					SET @ExecLineLocalization = @ExecLineLocalization + '(max)'
				END
				ELSE
				BEGIN
					SET @ExecLine = @ExecLine + ' (' + STR(@Length) + ')'
					SET @ExecLineLocalization = @ExecLineLocalization + ' (' + STR(@Length) + ')'
				END
			END
			ELSE
			BEGIN
				IF @DataTypeId = 5 OR @DataTypeId = 24
				BEGIN
					DECLARE @MdpPrecision NVARCHAR(10)
					DECLARE @MdpScale NVARCHAR(10)

					SET @MdpPrecision = NULL
					SET @MdpScale = NULL

					SELECT @MdpPrecision = [Value] FROM MetaAttribute
					WHERE
						AttrOwnerId = @MetaFieldId AND
						AttrOwnerType = 2 AND
						[Key] = 'MdpPrecision'

					SELECT @MdpScale = [Value] FROM MetaAttribute
					WHERE
						AttrOwnerId = @MetaFieldId AND
						AttrOwnerType = 2 AND
						[Key] = 'MdpScale'

					IF @MdpPrecision IS NOT NULL AND @MdpScale IS NOT NULL
					BEGIN
						SET @ExecLine = @ExecLine + ' (' + @MdpPrecision + ',' + @MdpScale + ')'
						SET @ExecLineLocalization = @ExecLineLocalization + ' (' + @MdpPrecision + ',' + @MdpScale + ')'
					END
				END
			END

			SET @ExecLineLocalization = @ExecLineLocalization + ' NULL'

			IF @AllowNulls = 1
			BEGIN
				SET @ExecLine = @ExecLine + ' NULL'
			END
			ELSE
				BEGIN
					SET @ExecLine = @ExecLine + ' NOT NULL DEFAULT ' + @DefaultValue

					--IF @IsVariableDataType = 1
					--BEGIN
						--SET @ExecLine = @ExecLine + ' (' + STR(@Length) + ')'
					--END

					SET @ExecLine = @ExecLine  +'  WITH VALUES'
				END

			--PRINT (@ExecLine)

			-- Step 1-2. Create a new column.
			EXEC (@ExecLine)

			IF @@ERROR<> 0 GOTO ERR

			-- Step 1-3. Create a new localization column.
			EXEC (@ExecLineLocalization)

			IF @@ERROR <> 0 GOTO ERR
		END
	END

	-- Step 2. Insert a record in to MetaClassMetaFieldRelation table.
	INSERT INTO [MetaClassMetaFieldRelation] (MetaClassId, MetaFieldId, Weight) VALUES(@MetaClassId, @MetaFieldId, @Weight)

	IF @@ERROR <> 0 GOTO ERR

	IF @IsAbstractClass = 0 AND @IsCatalogMetaClass = 0
	BEGIN
		EXEC mdpsp_sys_CreateMetaClassProcedure @MetaClassId

		IF @@ERROR <> 0 GOTO ERR
	END

	--IF @@ERROR <> 0 GOTO ERR

	COMMIT TRAN

    RETURN

ERR:
	ROLLBACK TRAN
    RETURN
END
GO
PRINT N'Refreshing [dbo].[ecfVersion_Insert]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_Insert]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_Save]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_CreateMetaClassProcedureAll]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_CreateMetaClassProcedureAll]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldAllowMultiLanguage]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_MetaFieldIsEncrypted]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_MetaFieldIsEncrypted]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 26, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
