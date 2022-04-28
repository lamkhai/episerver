--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[ecfVersion_ListByContentId]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByContentId]
  @ObjectId int,
  @ObjectTypeId int
AS
BEGIN
  SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status]
  FROM dbo.ecfVersion v
  WHERE v.ObjectId = @ObjectId 
  AND v.ObjectTypeId = @ObjectTypeId 
  AND [dbo].ecf_IsCurrentLanguageRemoved(v.CatalogId, v.LanguageName) = 0
END
GO
PRINT N'Dropping [dbo].[NodeEntryRelation].[IX_NodeEntryRelation_Indexed_CatalogEntryId]...';


GO
DROP INDEX [IX_NodeEntryRelation_Indexed_CatalogEntryId]
    ON [dbo].[NodeEntryRelation];


GO
PRINT N'Creating [dbo].[NodeEntryRelation].[IX_NodeEntryRelation_Indexed_CatalogEntryId]...';


GO
CREATE NONCLUSTERED INDEX [IX_NodeEntryRelation_Indexed_CatalogEntryId]
    ON [dbo].[NodeEntryRelation]([CatalogEntryId] ASC)
    INCLUDE([CatalogId], [CatalogNodeId], [SortOrder], [IsPrimary]);


GO
PRINT N'Creating [dbo].[CatalogEntry].[IX_CatalogEntry_Indexed_ContentGuid]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogEntry_Indexed_ContentGuid]
    ON [dbo].[CatalogEntry]([ContentGuid] ASC);


GO
PRINT N'Creating [dbo].[NodeEntryRelation].[IX_NodeEntryRelation_Indexed_CatalogNodeId]...';


GO
CREATE NONCLUSTERED INDEX [IX_NodeEntryRelation_Indexed_CatalogNodeId]
    ON [dbo].[NodeEntryRelation]([CatalogNodeId] ASC)
    INCLUDE([SortOrder], [IsPrimary]);


GO
PRINT N'Altering [dbo].[ecf_CatalogNode_CatalogParentNode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_CatalogParentNode]
    @CatalogId int,
	@ParentNodeId int,
	@ReturnInactive bit = 0
AS
BEGIN
	SELECT N.[CatalogNodeId]
      ,N.[CatalogId]
      ,N.[StartDate]
      ,N.[EndDate]
      ,N.[Name]
      ,N.[TemplateName]
      ,N.[Code]
      ,N.[ParentNodeId]
      ,N.[MetaClassId]
      ,N.[IsActive]
      ,N.[ContentAssetsID]
      ,N.[ContentGuid]
	  ,N.SortOrder AS SortOrder
	INTO #ChildNodes
	FROM [CatalogNode] N 
	WHERE 
		(N.CatalogId = @CatalogId AND N.ParentNodeId = @ParentNodeId) AND
		(N.IsActive = 1 OR @ReturnInactive = 1)
	
	SELECT * FROM #ChildNodes
	UNION ALL
	SELECT N.[CatalogNodeId]
      ,N.[CatalogId]
      ,N.[StartDate]
      ,N.[EndDate]
      ,N.[Name]
      ,N.[TemplateName]
      ,N.[Code]
      ,N.[ParentNodeId]
      ,N.[MetaClassId]
      ,N.[IsActive]
      ,N.[ContentAssetsID]
      ,N.[ContentGuid]
	  ,NR.SortOrder AS SortOrder 
	FROM [CatalogNode] N 
	LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
	LEFT OUTER JOIN #ChildNodes CN ON N.CatalogNodeId = CN.CatalogNodeId
	WHERE 
		(NR.CatalogId = @CatalogId AND NR.ParentNodeId = @ParentNodeId) AND 
		(N.IsActive = 1 OR @ReturnInactive = 1) AND 
		CN.CatalogNodeId IS NULL
	ORDER BY SortOrder

	SELECT S.* FROM CatalogItemSeo S 
	WHERE CatalogNodeId IN
		(SELECT DISTINCT N.CatalogNodeId 
		FROM [CatalogNode] N 
		LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
		WHERE
			((N.CatalogId = @CatalogId AND N.ParentNodeId = @ParentNodeId) OR (NR.CatalogId = @CatalogId AND NR.ParentNodeId = @ParentNodeId)) AND 
			(N.IsActive = 1 OR @ReturnInactive = 1))
END
GO
PRINT N'Altering [dbo].[ecf_SerializableCart_Load]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_Load]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL
AS
BEGIN
	if (@CartId IS NOT NULL AND @CartId > 0)
	BEGIN
		SELECT CartId, Created, Modified, [Data]
		FROM SerializableCart
		WHERE CartId = @CartId
	END
	ELSE
	BEGIN
		SELECT CartId, Created, Modified, [Data]
		FROM SerializableCart
		WHERE
			CustomerId = @CustomerId
			AND (@Name IS NULL OR Name = @Name)
	END
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
    
    IF @StartIndex = 0 AND @MaxRows = 2147483646
    BEGIN
        SELECT WorkId, ObjectId, ObjectTypeId, Name, LanguageName, MasterLanguageName, IsCommonDraft, StartPublish, ModifiedBy, Modified, [Status]
        FROM
            dbo.ecfVersion vn
        WHERE
            [dbo].ecf_IsCurrentLanguageRemoved(vn.CatalogId, vn.LanguageName) = 0 AND
            ((@ObjectId IS NULL) OR vn.ObjectId = @ObjectId) AND
            ((@ObjectTypeId IS NULL) OR vn.ObjectTypeId = @ObjectTypeId) AND
            ((@ModifiedBy IS NULL) OR vn.ModifiedBy = @ModifiedBy) AND
            ((@StatusCount = 0) OR (vn.[Status] IN (SELECT ID FROM @Statuses))) AND
            ((@LanguageCount = 0) OR (vn.LanguageName IN (SELECT LanguageCode FROM @Languages)))
    END
    ELSE
    BEGIN
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
    WHERE    RowNumber BETWEEN (@StartIndex + 1) AND (@MaxRows + @StartIndex)
    END
           
END
GO
PRINT N'Creating [dbo].[ecfVersion_IsNonPublishedContent]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_IsNonPublishedContent]
(
	@WorkId INT,
    @ObjectId INT,
	@ObjectTypeId INT,
	@LanguageName NVARCHAR(20) = NULL,
	@Result BIT OUTPUT
)
AS
BEGIN	
	SET NOCOUNT ON

	DECLARE @TempResult TABLE(WorkId INT, [Status] INT, IsCommonDraft BIT)
	INSERT INTO @TempResult (WorkId, [Status], IsCommonDraft)
	SELECT WorkId, [Status], IsCommonDraft 
	FROM dbo.ecfVersion
	WHERE ObjectId = @ObjectId
	  AND ObjectTypeId = @ObjectTypeId
	  AND [dbo].ecf_IsCurrentLanguageRemoved(CatalogId, LanguageName) = 0
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
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNodeCode]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
