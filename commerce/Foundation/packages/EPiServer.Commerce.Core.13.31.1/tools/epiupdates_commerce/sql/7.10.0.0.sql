--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 10, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Altering table [dbo].ecfVersion: dropping default contraints on CurrentLanguageRemoved column...';
GO

DECLARE @Command  NVARCHAR(1000)
SELECT @Command = 'ALTER TABLE [dbo].ecfVersion drop constraint ' + d.name
FROM sys.tables t
JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id
WHERE t.name = N'ecfVersion' AND c.name = N'CurrentLanguageRemoved'

EXECUTE (@Command)
GO

PRINT N'Altering table [dbo].ecfVersion: dropping CurrentLanguageRemoved column...';
GO

ALTER TABLE [dbo].ecfVersion
DROP COLUMN CurrentLanguageRemoved
GO

PRINT N'Deleting orphan rows in table [dbo].ecfVersion';
GO

DELETE FROM ecfVersion WHERE ObjectTypeId = 0 AND ObjectId NOT IN (SELECT CatalogEntryId FROM dbo.CatalogEntry)
GO
DELETE FROM ecfVersion WHERE ObjectTypeId = 1 AND ObjectId NOT IN (SELECT CatalogNodeId FROM dbo.CatalogNode)
GO
DELETE FROM ecfVersion WHERE ObjectTypeId = 2 AND ObjectId NOT IN (SELECT CatalogId FROM dbo.Catalog)
GO

PRINT N'Altering table [dbo].ecfVersion: adding CatalogId column...';
GO

ALTER TABLE [dbo].ecfVersion
ADD CatalogId INT
GO

PRINT N'Updating value of newly added column CatalogId for catalog entry versions...';
GO

UPDATE v
SET
	v.CatalogId = ce.CatalogId
FROM ecfVersion v
INNER JOIN CatalogEntry ce ON ce.CatalogEntryId = v.ObjectId
WHERE v.ObjectTypeId = 0
GO

PRINT N'Updating value of newly added column CatalogId for catalog node versions...';
GO

UPDATE v
SET
	v.CatalogId = cn.CatalogId
FROM ecfVersion v
INNER JOIN CatalogNode cn ON cn.CatalogNodeId = v.ObjectId
WHERE v.ObjectTypeId = 1
GO

PRINT N'Updating value of newly added column CatalogId for catalog versions...';
GO

UPDATE v
SET
	v.CatalogId = c.CatalogId
FROM ecfVersion v
INNER JOIN [Catalog] c ON c.CatalogId = v.ObjectId
WHERE v.ObjectTypeId = 2
GO

PRINT N'Making the newly added column CatalogId to be not nullable...';
GO

ALTER TABLE [dbo].ecfVersion
ALTER COLUMN CatalogId INT NOT NULL

PRINT N'Creating [dbo].[ecf_IsCurrentLanguageRemoved] function...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_IsCurrentLanguageRemoved]') AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
	DROP FUNCTION [dbo].[ecf_IsCurrentLanguageRemoved] 
GO

CREATE FUNCTION [dbo].[ecf_IsCurrentLanguageRemoved]
(
    @CatalogId INT,
	@LanguageCode NVARCHAR(40)
)
RETURNS BIT
AS
BEGIN
    DECLARE @RetVal BIT
    IF EXISTS (SELECT * FROM CatalogLanguage WHERE CatalogId = @CatalogId AND LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT)
		SET @RetVal = 0
	ELSE
		SET @RetVal = 1
    RETURN @RetVal;
END
GO

PRINT N'Removing completetly ecfVersion_UpdateCurrentLanguageRemoved and ecfVersion_UpdateVersionsCurrentLanguageRemoved SPs...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateVersionsCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_UpdateVersionsCurrentLanguageRemoved] 
GO

PRINT N'Removing other ecfVersion_... store procedures in order to modify the user-defined table type [dbo].[udttVersion] and then re-create those later...';
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Create]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_Create] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_Insert] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_List] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListDelayedPublish]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListDelayedPublish] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListFiltered]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListFiltered] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListMatchingSegments]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_ListMatchingSegments] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_Save] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncCatalogData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_SyncCatalogData] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncEntryData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_SyncEntryData] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncNodeData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_SyncNodeData] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersionCatalog_Save] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateMasterLanguage]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_UpdateMasterLanguage] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateVersionsMasterLanguage]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage] 
GO

PRINT N'Modifying the user-defined table type [dbo].[udttVersion]: add CatalogId column ...';
GO
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttVersion')
	DROP TYPE [dbo].[udttVersion]
GO

CREATE TYPE [dbo].[udttVersion] AS TABLE(
	[WorkId] [int] NULL,
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] INT NOT NULL,
	[CatalogId] INT NOT NULL, 
	[Name] [nvarchar](100) NULL,
	[Code] [nvarchar](100) NULL,
	[LanguageName] [nvarchar](20) NOT NULL,
	[MasterLanguageName] [nvarchar](20) NULL,
	[IsCommonDraft] [bit] NULL,
    [StartPublish] [datetime] NULL,
	[StopPublish] DATETIME NULL, 
	[Status] [int] NULL,	
	[CreatedBy] [nvarchar](100) NOT NULL,
	[Created] [datetime] NOT NULL,
	[ModifiedBy] [nvarchar](100) NULL,
	[Modified] [datetime] NULL,
	[SeoUri] nvarchar(255) NULL,
	[SeoTitle] nvarchar(150) NULL,
	[SeoDescription] nvarchar(355) NULL,
	[SeoKeywords] nvarchar(355) NULL,
	[SeoUriSegment] nvarchar(255) NULL
)

GO

PRINT N'Re-creating ecfVersion_... stored procedures...';
GO

CREATE PROCEDURE [dbo].[ecfVersion_UpdateMasterLanguage]
	@ObjectId			int,
	@ObjectTypeId		int
AS
BEGIN
	CREATE TABLE #RecursiveContents (ObjectId INT, ObjectTypeId INT)
	DECLARE @catalogId INT
	DECLARE @masterLanguage NVARCHAR(40)

	-- in case node content
	IF @ObjectTypeId = 1 
	BEGIN
		-- Get all nodes and entries under the @objectId
		DECLARE @catalogNodeIds udttCatalogNodeList
		INSERT INTO @catalogNodeIds VALUES (@ObjectId)

		DECLARE @hierarchy udttCatalogNodeList
		INSERT @hierarchy EXEC ecf_CatalogNode_GetAllChildNodes @catalogNodeIds

		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId) SELECT CatalogNodeId, 1 FROM @hierarchy

		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId)
		SELECT DISTINCT ce.CatalogEntryId, 0
		FROM CatalogEntry ce
		INNER JOIN NodeEntryRelation ner ON ce.CatalogEntryId = ner.CatalogEntryId
		INNER JOIN @hierarchy h ON h.CatalogNodeId = ner.CatalogNodeId

		-- get CatalogId from node content
		SELECT @catalogId = n.CatalogId, @masterLanguage = c.DefaultLanguage
		FROM CatalogNode n
		INNER JOIN Catalog c ON c.CatalogId = n.CatalogId
		WHERE CatalogNodeId = @ObjectId
	END
	ELSE
	BEGIN
		-- in case entry content, just update for only entry
		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId)
		VALUES (@ObjectId, @ObjectTypeId)

		-- get CatalogId from entry content
		SELECT @catalogId = e.CatalogId, @masterLanguage = c.DefaultLanguage 
		FROM CatalogEntry e
		INNER JOIN Catalog c ON c.CatalogId = e.CatalogId
		WHERE CatalogEntryId = @ObjectId
	END

	UPDATE v
	SET
		MasterLanguageName = @masterLanguage,
		v.CatalogId = @catalogId
	FROM	ecfVersion v
	INNER JOIN #RecursiveContents r ON r.ObjectId = v.ObjectId AND r.ObjectTypeId = v.ObjectTypeId

	DROP TABLE #RecursiveContents
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage]
	@Objects dbo.udttObjectWorkId READONLY
AS
BEGIN
	DECLARE @temp TABLE(ObjectId INT, ObjectTypeId INT, CatalogId INT, MasterLanguage NVARCHAR(40))

	INSERT INTO @temp (ObjectId, ObjectTypeId, CatalogId, MasterLanguage)
	SELECT e.CatalogEntryId ObjectId, o.ObjectTypeId, e.CatalogId, c.DefaultLanguage FROM CatalogEntry e
	INNER JOIN @Objects o ON e.CatalogEntryId = o.ObjectId and o.ObjectTypeId = 0
	INNER JOIN Catalog c ON c.CatalogId = e.CatalogId
	UNION ALL
	SELECT n.CatalogNodeId ObjectId, o.ObjectTypeId, n.CatalogId, c.DefaultLanguage FROM CatalogNode n
	INNER JOIN @Objects o ON n.CatalogNodeId = o.ObjectId and o.ObjectTypeId = 1
	INNER JOIN Catalog c ON c.CatalogId = n.CatalogId

	UPDATE v
	SET
		MasterLanguageName = t.MasterLanguage,
		CatalogId = t.CatalogId
	FROM	ecfVersion v
	INNER JOIN @temp t ON t.ObjectId = v.ObjectId AND t.ObjectTypeId = v.ObjectTypeId
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_Create]
	@Versions dbo.udttVersion READONLY
AS
BEGIN
	DECLARE @WorkIds dbo.udttObjectWorkId

	INSERT	INTO ecfVersion(
		ObjectId,
		LanguageName,
		MasterLanguageName,
		[Status],
		StartPublish,
		Name,
		Code,
		IsCommonDraft,
		CreatedBy,
		Created,
		Modified,
		ModifiedBy,
		ObjectTypeId,
		CatalogId,
		StopPublish,
		SeoUri,
		SeoTitle,
		SeoDescription,
		SeoKeywords,
		SeoUriSegment)
		OUTPUT NULL, NULL, inserted.WorkId, NULL INTO @WorkIds
	SELECT	
		ObjectId, 
		LanguageName, 
		MasterLanguageName,
		[Status], 
		StartPublish, 
		Name, 
		Code, 
		IsCommonDraft,
		CreatedBy,
		Created,
		Modified, 
		ModifiedBy, 
		ObjectTypeId,
		CatalogId,
		StopPublish,
		SeoUri,
		SeoTitle,
		SeoDescription,
		SeoKeywords,
		SeoUriSegment
	FROM	@Versions AS d

	SELECT * FROM @WorkIds
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_Insert]
	@ObjectId int,
	@ObjectTypeId int,
	@CatalogId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](20),
	@MasterLanguageName [nvarchar](20),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status int,
	@CreatedBy [nvarchar](100),
	@Created DATETIME,
	@ModifiedBy [nvarchar](100),
	@Modified DATETIME,
	@SeoUri nvarchar(255),
	@SeoTitle nvarchar(150),
	@SeoDescription nvarchar(355),
	@SeoKeywords nvarchar(355),
	@SeoUriSegment nvarchar(255),
	@WorkId int OUTPUT, 
	@MaxVersions INT = 20,
	@SkipSetCommonDraft BIT
AS
BEGIN
	-- Code and name are not culture specific, we need to copy them from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name, Code = @Code WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
	END

	INSERT INTO ecfVersion(ObjectId, 
			LanguageName, 
			MasterLanguageName, 
			[Status], 
			StartPublish, 
			Name, 
			Code, 
			CreatedBy, 
			Created, 
			ModifiedBy,
			Modified,
			ObjectTypeId,
			CatalogId,
			StopPublish,
			SeoUri,
			SeoTitle,
			SeoDescription,
			SeoKeywords,
			SeoUriSegment)
	VALUES (@ObjectId, 
			@LanguageName, 
			@MasterLanguageName, 
			@Status, 
			@StartPublish, 
			@Name, 
			@Code, 
			@CreatedBy, 
			@Created, 
			@ModifiedBy, 
			@Modified, 
			@ObjectTypeId,
			@CatalogId,
			@StopPublish,
			@SeoUri,
			@SeoTitle,
			@SeoDescription,
			@SeoKeywords,
			@SeoUriSegment)

	SET @WorkId = SCOPE_IDENTITY();
	
	IF (@Status = 4)
	BEGIN
		EXEC ecfVersion_PublishContentVersion @WorkId, @ObjectId, @ObjectTypeId, @LanguageName, @MaxVersions, 0
	END

	/* Set New Work item as Common draft version if there is no common draft or the common draft is the published version */
	IF (@SkipSetCommonDraft = 0)
	BEGIN
		EXEC ecfVersion_SetCommonDraft @WorkId = @WorkId, @Force = 0
	END
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_List]
	@ObjectIds [dbo].[udttContentList] READONLY,
	@ObjectTypeId int
AS
BEGIN
	SELECT vn.*
	FROM dbo.ecfVersion vn
	INNER JOIN @ObjectIds i ON vn.ObjectId = i.ContentId
	WHERE vn.ObjectTypeId = @ObjectTypeId 
		AND [dbo].ecf_IsCurrentLanguageRemoved(vn.CatalogId, vn.LanguageName) = 0
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*,e.ApplicationId, e.ContentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId 
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND draft.ObjectId = e.CatalogEntryId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.ApplicationId, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.ApplicationId, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND draft.ObjectId = n.CatalogNodeId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = n.MetaClassId
											AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
											AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 1 -- node

	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN CatalogNode n ON r.CatalogNodeId = n.CatalogNodeId  AND r.CatalogId = n.CatalogId
	INNER JOIN dbo.ecfVersion v ON v.ObjectTypeId = 0 
								AND v.ObjectId = r.CatalogEntryId
								AND v.CatalogId = n.CatalogId
	INNER JOIN @ContentLinks l ON l.WorkId = v.WorkId
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(v.CatalogId, v.LanguageName) = 0 
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListDelayedPublish]
	@UntilDate	DATETIME,
	@ObjectId INT = NULL,
	@ObjectTypeId INT = NULL
AS
BEGIN
	SET NOCOUNT ON

	SELECT	ObjectId, 
			ObjectTypeId, 
			WorkId
	FROM ecfVersion 
	WHERE
		[Status] = 6 
		AND [dbo].ecf_IsCurrentLanguageRemoved(CatalogId, LanguageName) = 0
		AND StartPublish <= @UntilDate
		AND ((ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId) OR @ObjectId IS NULL)		
	ORDER BY
		StartPublish
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListFiltered]
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
	
	;WITH TempResult as
	(
		SELECT ROW_NUMBER() OVER(ORDER BY vn.Modified DESC) as RowNumber, vn.*
		FROM
			dbo.ecfVersion vn
		WHERE
			[dbo].ecf_IsCurrentLanguageRemoved(vn.CatalogId, vn.LanguageName) = 0 AND
			((@ObjectId IS NULL) OR vn.ObjectId = @ObjectId) AND
			((@ObjectTypeId IS NULL) OR vn.ObjectTypeId = @ObjectTypeId) AND
			((@ModifiedBy IS NULL) OR vn.ModifiedBy = @ModifiedBy) AND
			((@StatusCount = 0) OR (vn.[Status] IN (SELECT ID FROM @Statuses))) AND
            ((@LanguageCount = 0) OR (vn.LanguageName IN (SELECT LanguageCode FROM @Languages)))
	)
	SELECT  WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status], (SELECT COUNT(*) FROM TempResult) AS TotalRows
	FROM    TempResult
	WHERE	RowNumber BETWEEN (@StartIndex + 1) AND (@MaxRows + @StartIndex)
   		
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListMatchingSegments]
	@ParentId INT,
	@CatalogId INT,
	@SeoUriSegment NVARCHAR(255)
AS
BEGIN
	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName, v.CatalogId
	FROM ecfVersion v
		INNER JOIN CatalogEntry e on e.CatalogEntryId = v.ObjectId
		LEFT OUTER JOIN NodeEntryRelation r ON v.ObjectId = r.CatalogEntryId
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 0 
		AND [dbo].ecf_IsCurrentLanguageRemoved(v.CatalogId, v.LanguageName) = 0
		AND
			((r.CatalogNodeId = @ParentId AND (r.CatalogId = @CatalogId OR @CatalogId = 0))
			OR
			(@ParentId = 0 AND r.CatalogNodeId IS NULL AND (e.CatalogId = @CatalogId OR @CatalogId = 0)))

	UNION ALL

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName, v.CatalogId
	FROM ecfVersion v
		INNER JOIN CatalogNode n ON v.ObjectId = n.CatalogNodeId
		LEFT OUTER JOIN CatalogNodeRelation nr on v.ObjectId = nr.ChildNodeId
	WHERE
		v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 1
		AND [dbo].ecf_IsCurrentLanguageRemoved(v.CatalogId, v.LanguageName) = 0
		AND
			((n.ParentNodeId = @ParentId AND (n.CatalogId = @CatalogId OR @CatalogId = 0))
			OR
			(nr.ParentNodeId = @ParentId AND (nr.CatalogId = @CatalogId OR @CatalogId = 0)))
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_Save]
	@WorkId int,
	@ObjectId int,
	@ObjectTypeId int,
	@CatalogId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](20),
	@MasterLanguageName [nvarchar](20),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status INT,
	@CreatedBy [nvarchar](100),
	@Created DATETIME,
	@ModifiedBy [nvarchar](100),
	@Modified DATETIME,
	@SeoUri nvarchar(255),
	@SeoTitle nvarchar(150),
	@SeoDescription nvarchar(355),
	@SeoKeywords nvarchar(355),
	@SeoUriSegment nvarchar(255),
	@MaxVersions INT = 20
AS
BEGIN
	-- Code and name are not culture specific, we need to copy them from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name, Code = @Code WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
	END

	UPDATE ecfVersion
	SET ObjectId = @ObjectId,
		Code = @Code,
		Name = @Name,
		ObjectTypeId = @ObjectTypeId,
		CatalogId = @CatalogId,
		LanguageName = @LanguageName,
		MasterLanguageName = @MasterLanguageName,
		StartPublish = @StartPublish,
		StopPublish = @StopPublish,
		[Status] = @Status,
		CreatedBy = @CreatedBy,
	    Created = @Created,
		Modified = @Modified,
		ModifiedBy = @ModifiedBy,
		SeoUri = @SeoUri,
		SeoTitle = @SeoTitle,
		SeoDescription = @SeoDescription,
		SeoKeywords = @SeoKeywords,
		SeoUriSegment = @SeoUriSegment
	WHERE WorkId = @WorkId

	IF (@Status = 4)
	BEGIN
		EXEC ecfVersion_PublishContentVersion @WorkId, @ObjectId, @ObjectTypeId, @LanguageName, @MaxVersions
	END
END
GO

CREATE PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, '', d.CreatedBy, d.Created, d.ModifiedBy, d.Modified,
				  c.EndDate
			FROM @ContentDraft d
			INNER JOIN dbo.Catalog c on d.ObjectId = c.CatalogId)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, [MasterLanguageName], IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish)
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
			target.StopPublish = SOURCE.StopPublish
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, StopPublish)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified, SOURCE.StopPublish)
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

CREATE PROCEDURE [dbo].[ecfVersion_SyncEntryData]
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
		SELECT w.WorkId, v.TaxCategoryId, v.TrackInventory, v.[Weight], v.MinQuantity, v.MaxQuantity, v.[Length], v.Height, v.Width, v.PackageId
		FROM @WorkIds w
		INNER JOIN Variation v on w.ObjectId = v.CatalogEntryId
		
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

CREATE PROCEDURE [dbo].[ecfVersion_SyncNodeData]
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
		INNER JOIN dbo.CatalogItemAsset a ON w.ObjectId = a.CatalogNodeId

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

CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
	MERGE dbo.ecfVersionCatalog AS TARGET
	USING @VersionCatalogs AS SOURCE
	ON (TARGET.WorkId = SOURCE.WorkId)
	WHEN MATCHED THEN 
		UPDATE SET DefaultCurrency = SOURCE.DefaultCurrency,
				   WeightBase = SOURCE.WeightBase,
				   LengthBase = SOURCE.LengthBase,
				   DefaultLanguage = SOURCE.DefaultLanguage,
				   Languages = SOURCE.Languages,
				   IsPrimary = SOURCE.IsPrimary,
				   [Owner] = SOURCE.[Owner]
	WHEN NOT MATCHED THEN
		INSERT (WorkId, DefaultCurrency, WeightBase, LengthBase, DefaultLanguage, Languages, IsPrimary, [Owner])
		VALUES (SOURCE.WorkId, SOURCE.DefaultCurrency, SOURCE.WeightBase, SOURCE.LengthBase, SOURCE.DefaultLanguage, SOURCE.Languages, SOURCE.IsPrimary, SOURCE.[Owner])
	;

	IF @PublishAction = 1
	BEGIN
		-- Gets versions which had updated on DefaultLanguage or Languages, that will be used to update versions related to them when publishing a catalog.
		DECLARE @WorkIds TABLE (WorkId INT, DefaultLanguage NVARCHAR(20), Languages NVARCHAR(512))
		INSERT INTO @WorkIds(WorkId, DefaultLanguage, Languages)
		SELECT v.WorkId, v.DefaultLanguage, v.Languages
		FROM @VersionCatalogs v

		DECLARE @NumberVersions INT, @CatalogId INT, @MasterLanguageName NVARCHAR(20), @Languages NVARCHAR(512)
		SELECT @NumberVersions = COUNT(*) FROM @WorkIds

		IF @NumberVersions = 1 -- This is the most regular case, so we can do in different way without cursor so that can gain performance
		BEGIN
			DECLARE @WorkId INT
			
			SELECT TOP 1 @WorkId = WorkId, @MasterLanguageName = DefaultLanguage, @Languages = Languages FROM @WorkIds
			SELECT @CatalogId = ObjectId FROM ecfVersion WHERE WorkId = @WorkId

			UPDATE d SET 
				d.DefaultLanguage = @MasterLanguageName
			FROM ecfVersionCatalog d
			INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId AND d.DefaultLanguage <> @MasterLanguageName

			UPDATE ecfVersion SET 
				MasterLanguageName = @MasterLanguageName
			WHERE CatalogId = @CatalogId AND MasterLanguageName <> @MasterLanguageName
		END
		ELSE
		BEGIN
			DECLARE @Catalogs udttObjectWorkId

			INSERT INTO @Catalogs(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c 
			INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
			WHERE c.ObjectTypeId = 2
			-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
			
			DECLARE @ObjectIdsTemp TABLE(ObjectId INT)
			DECLARE catalogCursor CURSOR FOR SELECT DISTINCT ObjectId FROM @Catalogs
		
			OPEN catalogCursor  
			FETCH NEXT FROM catalogCursor INTO @CatalogId
		
			WHILE @@FETCH_STATUS = 0  
			BEGIN
				SELECT @MasterLanguageName = v.DefaultLanguage
				FROM @VersionCatalogs v
				INNER JOIN @Catalogs c ON c.WorkId = v.WorkId
				WHERE c.ObjectId = @CatalogId
						
				-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
				UPDATE d SET 
					d.DefaultLanguage = @MasterLanguageName
				FROM ecfVersionCatalog d
				INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
				WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId AND d.DefaultLanguage <> @MasterLanguageName
			
				-- and also update MasterLanguageName of contents that's related to Catalog
				-- catalogs
				UPDATE ecfVersion SET 
					MasterLanguageName = @MasterLanguageName
				WHERE CatalogId = @CatalogId AND MasterLanguageName <> @MasterLanguageName
				
				FETCH NEXT FROM catalogCursor INTO @CatalogId
			END
		
			CLOSE catalogCursor  
			DEALLOCATE catalogCursor;  
		END
	END
END
GO 

PRINT N'Altering [dbo].[ecf_Inventory_GetInventory]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_GetInventory]
    @CatalogKeys udttCatalogKey readonly
AS
BEGIN
    select
        i.[ApplicationId], 
        i.[CatalogEntryCode], 
        i.[WarehouseCode], 
        i.[IsTracked], 
        i.[PurchaseAvailableQuantity], 
        i.[PreorderAvailableQuantity], 
        i.[BackorderAvailableQuantity], 
        i.[PurchaseRequestedQuantity], 
        i.[PreorderRequestedQuantity], 
        i.[BackorderRequestedQuantity], 
        i.[PurchaseAvailableUtc],
        i.[PreorderAvailableUtc],
        i.[BackorderAvailableUtc],
        i.[AdditionalQuantity],
        i.[ReorderMinQuantity]
    from [dbo].[InventoryService] i
    inner join @CatalogKeys k
    on i.[ApplicationId] = k.ApplicationId and i.[CatalogEntryCode] = k.CatalogEntryCode
END
GO
PRINT N'Creating [dbo].[CatalogContentProperty_LoadAllLanguages]...';


GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_LoadAllLanguages]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int
AS
BEGIN   
	EXEC mdpsp_sys_OpenSymmetricKey

	SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
						P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
						CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1 )
						THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
						ELSE P.LongString END AS LongString, 
						P.[Guid]  
	FROM dbo.CatalogContentProperty P
	INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
	WHERE ObjectId = @ObjectId AND
			ObjectTypeId = @ObjectTypeId AND
			MetaClassId = @MetaClassId

	EXEC mdpsp_sys_CloseSymmetricKey
	
	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
PRINT N'Creating [dbo].[ecf_ApplicationLog_DeletedEntries]...';


GO
CREATE PROCEDURE [dbo].[ecf_ApplicationLog_DeletedEntries]
	@lastBuild datetime  
AS
BEGIN

SELECT [ObjectKey]
	  ,[ObjectType]
	  ,[Username]
	  ,[Created]
  FROM [dbo].[ApplicationLog]
  WHERE 
  ObjectType = 'entry' 
  AND Source = 'catalog'
  AND Operation = 'Deleted'
  AND Created > @lastBuild

END
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 10, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
