--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 5, @patch int = 0  
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

-- create udttCatalogItemSeo type
IF NOT EXISTS (SELECT * FROM sys.types WHERE name = N'udttCatalogItemSeo' AND is_table_type = 1)
	CREATE TYPE [dbo].[udttCatalogItemSeo] AS TABLE(
		[LanguageCode] [nvarchar](50) NOT NULL,
		[CatalogNodeId] [int] NULL,
		[CatalogEntryId] [int] NULL,
		[Uri] [nvarchar](255) NOT NULL,
		[ApplicationId] [uniqueidentifier] NOT NULL,
		[UriSegment] [nvarchar](255) NULL
	);
GO
-- end of create udttCatalogItemSeo type

-- create stored procedure ecf_CatalogEntryItemSeo_ValidateUri, which validate, and generate SEO Uri database
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUri]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[ApplicationId], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.ApplicationId = c.ApplicationId
		AND t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogNodeId > 0 OR t.CatalogEntryId <> c.CatalogEntryId
END
GO
-- end of create stored procedure ecf_CatalogEntryItemSeo_ValidateUri

-- create stored procedure ecf_CatalogEntryItemSeo_ValidateUriSegment, which validate, and generate SEO UriSegment database
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]
GO
 
CREATE PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri Segment and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], t.[ApplicationId], '' AS [UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.ApplicationId = c.ApplicationId
		AND t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.CatalogEntryId <> c.CatalogEntryId -- check against entry only
		AND t.UriSegment = c.UriSegment COLLATE DATABASE_DEFAULT
END
GO
-- end of create stored procedure ecf_CatalogEntryItemSeo_ValidateUriSegment

-- create stored procedure ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment, which validates, and generates SEO database
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]
GO
CREATE PROCEDURE [dbo].ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and Uri Segment, then return invalid record
	DECLARE @ValidSeoUri dbo.udttCatalogItemSeo
	DECLARE @ValidUriSegment dbo.udttCatalogItemSeo
	
	INSERT INTO @ValidSeoUri ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [ApplicationId], [UriSegment] ) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUri] @CatalogItemSeo		
	
	INSERT INTO @ValidUriSegment ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [ApplicationId], [UriSegment] ) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUriSegment] @CatalogItemSeo

	MERGE @ValidSeoUri as U
	USING @ValidUriSegment as S
	ON 
		U.ApplicationId = S.ApplicationId AND 
		U.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT AND 
		U.CatalogEntryId = S.CatalogEntryId
	WHEN MATCHED -- update the UriSegment for existing row in #ValidSeoUri
		THEN UPDATE SET U.UriSegment = S.UriSegment
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in #ValidSeoUri table (source table)
		THEN INSERT VALUES(S.LanguageCode, S.CatalogNodeId, S.CatalogEntryId, S.Uri, S.ApplicationId, S.UriSegment)
	;

	SELECT * FROM @ValidSeoUri
END
GO
-- end of create stored procedure ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment

-- create fn_UriSegmentExistsOnSiblingNodeOrEntry function
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fn_UriSegmentExistsOnSiblingNodeOrEntry' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
GO
CREATE FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
(
    @entityId int,
    @type bit, -- 0 = Node, 1 = Entry
    @UriSegment nvarchar(255),
    @ApplicationId uniqueidentifier,
    @LanguageCode nvarchar(50)
)
RETURNS bit
AS
BEGIN
    DECLARE @RetVal bit
    DECLARE @Count int
    DECLARE @parentId int
    
    -- get the parentId, based on entityId and the entity type
    IF @type = 0 
        SET @parentId = (SELECT ParentNodeId FROM CatalogNode WHERE CatalogNodeId = @entityId)
    ELSE
        SET @parentId = (SELECT CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId)

    SET @RetVal = 0

    -- check if the UriSegment exists on sibling node
    SET @Count = (
                    SELECT COUNT(S.CatalogNodeId)
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId AND N.ApplicationId = S.ApplicationId 
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE S.ApplicationId = @ApplicationId 
                        AND LanguageCode = LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1
                )
                
    IF @Count = 0 -- check against sibling entry if only UriSegment does not exist on sibling node
    BEGIN
        -- check if the UriSegment exists on sibling entry
        SET @Count = (
                        SELECT COUNT(S.CatalogEntryId)
                        FROM CatalogItemSeo S WITH (NOLOCK)
                        INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId AND N.ApplicationId = S.ApplicationId 
                        LEFT JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
                        WHERE 
                            S.ApplicationId = @ApplicationId 
                            AND S.LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                            AND S.CatalogEntryId <> @entityId 
                            AND R.CatalogNodeId = @parentId  
                            AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                            AND N.IsActive = 1
                    )
    END

    IF @Count <> 0
    BEGIN
        SET @RetVal = 1
    END

    RETURN @RetVal;
END
GO
-- end of create fn_UriSegmentExistsOnSiblingNodeOrEntry function

-- create stored procedure ecf_CatalogNodeItemSeo_ValidateUri, which validates, and generates SEO database
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUri]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[ApplicationId], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.ApplicationId = c.ApplicationId
		AND t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogEntryId > 0 OR t.CatalogNodeId <> c.CatalogNodeId
END
GO
-- end of create stored procedure ecf_CatalogNodeItemSeo_ValidateUri

-- create stored procedure ecf_CatalogNodeItemSeo_ValidateUriSegment, which validates, and generates SEO database
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri segment and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], t.[ApplicationId], '' AS [UriSegment] 
	FROM @CatalogItemSeo t
	WHERE (t.CatalogNodeId > 0 AND dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogNodeId, 0, t.UriSegment, t.ApplicationId, t.LanguageCode) = 1)
			OR
			(t.CatalogEntryId > 0 AND dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogEntryId, 1, t.UriSegment, t.ApplicationId, t.LanguageCode) = 1)
END
GO
-- end of create stored procedure ecf_CatalogNodeItemSeo_ValidateUriSegment

-- create stored procedure ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment, which validates, and generates SEO database
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and Uri Segment, then return invalid record
	DECLARE @ValidSeoUri dbo.udttCatalogItemSeo
	DECLARE @ValidUriSegment dbo.udttCatalogItemSeo
	
	INSERT INTO @ValidSeoUri ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [ApplicationId], [UriSegment] ) 
		EXEC [ecf_CatalogNodeItemSeo_ValidateUri] @CatalogItemSeo		
	
	INSERT INTO @ValidUriSegment ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [ApplicationId], [UriSegment] ) 
		EXEC [ecf_CatalogNodeItemSeo_ValidateUriSegment] @CatalogItemSeo

	MERGE @ValidSeoUri as U
	USING @ValidUriSegment as S
	ON 
		U.ApplicationId = S.ApplicationId AND 
		U.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT AND 
		U.CatalogNodeId = S.CatalogNodeId
	WHEN MATCHED -- update the UriSegment for existing row in #ValidSeoUri
		THEN UPDATE SET U.UriSegment = S.UriSegment
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in #ValidSeoUri table (source table)
		THEN INSERT VALUES(S.LanguageCode, S.CatalogNodeId, S.CatalogEntryId, S.Uri, S.ApplicationId, S.UriSegment)
	;

	SELECT * FROM @ValidSeoUri
END
GO
-- end of create stored procedure ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 5, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
