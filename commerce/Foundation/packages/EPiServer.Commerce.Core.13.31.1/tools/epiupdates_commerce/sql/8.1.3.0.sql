--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 1, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
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
		WHERE dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogEntryId, 1, t.UriSegment, t.LanguageCode) = 1'
	END

	exec sp_executesql @query, N'@CatalogItemSeo dbo.udttCatalogItemSeo readonly', @CatalogItemSeo = @CatalogItemSeo
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
	-- validate Uri segment and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], NULL AS [UriSegment] 
	FROM @CatalogItemSeo t
	WHERE
		t.CatalogNodeId > 0 AND dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogNodeId, 0, t.UriSegment, t.LanguageCode) = 1
GO
PRINT N'Creating [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogItemSeo_FindUriSegmentConflicts]
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
PRINT N'Refreshing [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 1, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
