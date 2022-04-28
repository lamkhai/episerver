--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 21    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[CatalogItemAsset].[IX_CatalogItemAsset_NodeId]...';


GO
DROP INDEX [IX_CatalogItemAsset_NodeId]
    ON [dbo].[CatalogItemAsset];


GO
PRINT N'Dropping [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';


GO
DROP INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion];


GO
PRINT N'Dropping [dbo].[ecfVersion].[IDX_ecfVersion_ModifiedBy_Modified]...';


GO
DROP INDEX [IDX_ecfVersion_ModifiedBy_Modified]
    ON [dbo].[ecfVersion];


GO
PRINT N'Dropping [dbo].[ecfVersion].[IDX_ecfVersion_Status_Modified]...';


GO
DROP INDEX [IDX_ecfVersion_Status_Modified]
    ON [dbo].[ecfVersion];


GO
PRINT N'Creating [dbo].[CatalogItemAsset].[IX_CatalogItemAsset_NodeId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogItemAsset_NodeId]
    ON [dbo].[CatalogItemAsset]([CatalogNodeId] ASC)
    INCLUDE([GroupName], [SortOrder]) WHERE CatalogNodeId > 0;


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion]([ObjectId] ASC, [ObjectTypeId] ASC, [CatalogId] ASC)
    INCLUDE([LanguageName], [MasterLanguageName], [Status], [IsCommonDraft]);


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_ModifiedBy_Modified]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_ModifiedBy_Modified]
    ON [dbo].[ecfVersion]([ModifiedBy] ASC, [Modified] DESC)
    INCLUDE([LanguageName], [CatalogId], [Status]);


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_Status_Modified]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Status_Modified]
    ON [dbo].[ecfVersion]([Status] ASC, [Modified] DESC)
    INCLUDE([LanguageName], [CatalogId]);


GO
PRINT N'Creating [dbo].[OrderGroup].[IX_OrderGroup_CustomerName]...';


GO
CREATE NONCLUSTERED INDEX [IX_OrderGroup_CustomerName]
    ON [dbo].[OrderGroup]([CustomerName] ASC);


GO
PRINT N'Creating [dbo].[OrderGroupAddress].[IX_OrderGroupAddress_Email]...';


GO
CREATE NONCLUSTERED INDEX [IX_OrderGroupAddress_Email]
    ON [dbo].[OrderGroupAddress]([Email] ASC);


GO
PRINT N'Creating [dbo].[SerializableCart].[IDX_SerializableCart_Indexed_CustomerId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_SerializableCart_Indexed_CustomerId]
    ON [dbo].[SerializableCart]([CustomerId] ASC);


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
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogNodeId AND LOWER(d.LanguageName) = LOWER(s.LanguageCode) COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND LOWER(target.LanguageName) = LOWER(SOURCE.LanguageName) COLLATE DATABASE_DEFAULT)
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
		AND LOWER(existing.LanguageName) = LOWER(updated.LanguageName) COLLATE DATABASE_DEFAULT
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
		AND a.CatalogNodeId > 0
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
PRINT N'Altering [dbo].[ecfVersionAsset_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionAsset_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	-- master language version should load asset directly from ecfVersionAsset table
	SELECT Asset.WorkId, Asset.AssetType, Asset.AssetKey, Asset.GroupName, Asset.SortOrder 
	FROM ecfVersionAsset AS Asset
		INNER JOIN @ContentLinks links ON Asset.WorkId = links.WorkId
		INNER JOIN ecfVersion v ON v.WorkId = links.WorkId
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT

	UNION ALL

	-- non-master language version should fall-back to published-master content
	SELECT links.WorkId, Asset.AssetType, Asset.AssetKey, Asset.GroupName, Asset.SortOrder 
	FROM CatalogItemAsset AS Asset
		INNER JOIN @ContentLinks links ON Asset.CatalogEntryId = links.ObjectId AND links.ObjectTypeId = 0
		INNER JOIN ecfVersion v ON v.WorkId = links.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
	UNION ALL
	SELECT links.WorkId, Asset.AssetType, Asset.AssetKey, Asset.GroupName, Asset.SortOrder 
	FROM CatalogItemAsset AS Asset
		INNER JOIN @ContentLinks links ON Asset.CatalogNodeId = links.ObjectId AND links.ObjectTypeId = 1
		INNER JOIN ecfVersion v ON v.WorkId = links.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
		AND Asset.CatalogNodeId > 0

	ORDER BY WorkId, SortOrder
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_FindCartsByCustomerEmail]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_FindCartsByCustomerEmail]
	@CustomerEmail NVARCHAR (254),
    @StartingRecord INT,
	@RecordsToRetrieve INT,
	@ReturnTotalCount BIT,
	@ExcludeNames NVARCHAR (1024) = NULL,
	@TotalRecords INT OUTPUT
AS
BEGIN
	-- Execute for record count.
	IF (@ReturnTotalCount = 1)
	BEGIN
		SET @TotalRecords = (SELECT COUNT(1) FROM SerializableCart SC
							INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
							WHERE CC.Email = @CustomerEmail
								  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames))))
	END
	ELSE 
	BEGIN
		SET @TotalRecords = 0
	END

	-- Execute for get carts.
	SELECT SC.CartId, SC.Created, SC.Modified, SC.[Data]
	FROM SerializableCart SC
	INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
	WHERE CC.Email = @CustomerEmail
		  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames)))
	ORDER BY SC.Modified DESC
	OFFSET @StartingRecord ROWS
	FETCH NEXT @RecordsToRetrieve ROWS ONLY
END
GO
PRINT N'Creating [dbo].[ecf_SerializableCart_FindCartsByCustomerName]...';


GO
CREATE PROCEDURE [dbo].[ecf_SerializableCart_FindCartsByCustomerName]
	@CustomerName NVARCHAR (200),
    @StartingRecord INT,
	@RecordsToRetrieve INT,
	@ReturnTotalCount BIT,
	@ExcludeNames NVARCHAR (1024) = NULL,
	@TotalRecords INT OUTPUT
AS
BEGIN
	-- Execute for record count.
	IF (@ReturnTotalCount = 1)
	BEGIN
		SET @TotalRecords = (SELECT COUNT(1) FROM SerializableCart SC
							INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
							WHERE CC.FullName LIKE @CustomerName + '%'
								  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames))))
	END
	ELSE 
	BEGIN
		SET @TotalRecords = 0
	END

	-- Execute for get carts.
	SELECT SC.CartId, SC.Created, SC.Modified, SC.[Data]
	FROM SerializableCart SC
	INNER JOIN cls_Contact CC ON SC.CustomerId = CC.ContactId
	WHERE CC.FullName LIKE @CustomerName + '%'
		  AND (@ExcludeNames IS NULL OR SC.[Name] NOT IN(SELECT Item FROM ecf_splitlist(@ExcludeNames)))
	ORDER BY SC.Modified DESC
	OFFSET @StartingRecord ROWS
	FETCH NEXT @RecordsToRetrieve ROWS ONLY
END
GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByCatalogWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByCatalogWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByEntryWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByEntryWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByNodeWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByNodeWorkIds]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 21, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
