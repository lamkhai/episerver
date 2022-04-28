--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 6    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[CatalogContentProperty_EnsureCultureSpecific]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_EnsureCultureSpecific]
	@MetaFieldId INT,
	@CultureSpecific BIT
AS
BEGIN
	UPDATE [CatalogContentProperty]
	SET [CatalogContentProperty].CultureSpecific = @CultureSpecific
	WHERE MetaFieldId = @MetaFieldId AND CultureSpecific <> @CultureSpecific
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
PRINT N'Altering [dbo].[ecfVersion_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.ContentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND links.ObjectTypeId = 0
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	
	UNION ALL

	SELECT draft.*, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId AND links.ObjectTypeId = 2
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT

	UNION ALL

	SELECT draft.*, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId AND draft.ObjectId = links.ObjectId AND draft.ObjectTypeId = links.ObjectTypeId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND links.ObjectTypeId = 1
	INNER JOIN CatalogLanguage cl ON draft.CatalogId = cl.CatalogId AND draft.LanguageName = cl.LanguageCode
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = n.MetaClassId
											AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
											AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT

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
PRINT N'Altering [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage]
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
	FROM ecfVersion v
	INNER JOIN @temp t ON t.ObjectId = v.ObjectId AND t.ObjectTypeId = v.ObjectTypeId

	MERGE ecfVersionAsset AS TARGET
	USING
	(SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN @Objects o ON o.ObjectId = v.ObjectId and v.ObjectTypeId = 0
		INNER JOIN CatalogItemAsset a ON v.ObjectId = a.CatalogEntryId
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT
		AND (v.Status = 4 OR v.IsCommonDraft = 1)) AS SOURCE (WorkId, AssetType, AssetKey, GroupName, SortOrder)
	ON 
	    TARGET.WorkId = SOURCE.WorkId
		AND TARGET.AssetType = SOURCE.AssetType
		AND TARGET.AssetKey = SOURCE.AssetKey
	WHEN MATCHED THEN
		UPDATE SET GroupName = SOURCE.GroupName, SortOrder = SOURCE.SortOrder
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (WorkId, AssetType, AssetKey, GroupName, SortOrder) VALUES (WorkId, AssetType, AssetKey, GroupName, SortOrder);

	MERGE ecfVersionAsset AS TARGET
	USING
	(SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN @Objects o ON o.ObjectId = v.ObjectId and v.ObjectTypeId = 1
		INNER JOIN CatalogItemAsset a ON v.ObjectId = a.CatalogNodeId
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT
		AND (v.Status = 4 OR v.IsCommonDraft = 1)) AS SOURCE (WorkId, AssetType, AssetKey, GroupName, SortOrder)
	ON 
	    TARGET.WorkId = SOURCE.WorkId
		AND TARGET.AssetType = SOURCE.AssetType
		AND TARGET.AssetKey = SOURCE.AssetKey
	WHEN MATCHED THEN
		UPDATE SET GroupName = SOURCE.GroupName, SortOrder = SOURCE.SortOrder
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (WorkId, AssetType, AssetKey, GroupName, SortOrder) VALUES (WorkId, AssetType, AssetKey, GroupName, SortOrder);
END
GO
PRINT N'Altering [dbo].[ecfVersionProperty_EnsureCultureSpecific]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_EnsureCultureSpecific]
	@MetaFieldId INT,
	@CultureSpecific BIT
AS
BEGIN
	UPDATE [ecfVersionProperty]
	SET [ecfVersionProperty].CultureSpecific = @CultureSpecific
	WHERE MetaFieldId = @MetaFieldId AND CultureSpecific <> @CultureSpecific
END
GO

PRINT N'Creating [dbo].[ecfVersion_ListObsolete]...';

GO

CREATE PROCEDURE [dbo].[ecfVersion_ListObsolete]
(
	@MaxVersions INT,
    @MaxCount INT = 100
)
AS
BEGIN
	DECLARE @PreviouslyPublished TABLE
    (
        ObjectId INT, 
        LanguageName NVARCHAR(50),
        PreviouslyPublishedCount INT,
		RowNumber INT
    )

	DECLARE @ObsoleteVersions TABLE
    (
	    WorkId INT,
        ObjectId INT,
		ObjectTypeId INT,
        Name NVARCHAR(100),
        Status INT,
        StartPublish DATETIME,
		Modified DATETIME,
        ModifiedBy NVARCHAR(256),
		LanguageName NVARCHAR(50),
		MasterLanguageName NVARCHAR(50),
        IsCommonDraft BIT
    )

	INSERT INTO @PreviouslyPublished 
		SELECT ObjectId, LanguageName, COUNT(WorkId),
			ROW_NUMBER() OVER(ORDER BY ObjectId DESC) AS ROW
        FROM ecfVersion WHERE Status = 5
        GROUP BY ObjectId, LanguageName 
        HAVING COUNT(WorkId) > @MaxVersions

	DECLARE @COUNTER INT = (SELECT MAX(RowNumber) FROM @PreviouslyPublished);
	DECLARE @CURRENTVERSIONS INT;
    DECLARE @CURRENTCONTENT INT;
    DECLARE @CURRENTLANGUAGE NVARCHAR(50);

	WHILE (@COUNTER != 0 AND (SELECT COUNT(*) FROM @ObsoleteVersions) < @MaxCount)
	BEGIN
		SELECT @CURRENTVERSIONS = PreviouslyPublishedCount,
            @CURRENTCONTENT = ObjectId,
            @CURRENTLANGUAGE = LanguageName
        FROM @PreviouslyPublished WHERE RowNumber = @COUNTER

		INSERT INTO @ObsoleteVersions
		SELECT TOP(@CURRENTVERSIONS - @MaxVersions) 
            WorkId,
            ObjectId,
			ObjectTypeId,
            Name,
            Status, 
            StartPublish,
            Modified,
            ModifiedBy,
            LanguageName,
            MasterLanguageName, 
            IsCommonDraft
		FROM ecfVersion
		WHERE ObjectId = @CURRENTCONTENT AND Status = 5 AND LanguageName = @CURRENTLANGUAGE COLLATE DATABASE_DEFAULT
		ORDER BY WorkId ASC

		SET @COUNTER = @COUNTER -1
	END
	
	SELECT * FROM @ObsoleteVersions

    SELECT SUM(PreviouslyPublishedCount - @MaxVersions) AS TotalCount FROM @PreviouslyPublished
END
GO

GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
