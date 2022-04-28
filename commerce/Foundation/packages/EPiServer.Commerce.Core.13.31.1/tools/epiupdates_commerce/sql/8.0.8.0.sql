--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[MetaKey].[IX_MetaKey_MetaObjectIdMetaClassId]...';


GO
DROP INDEX [IX_MetaKey_MetaObjectIdMetaClassId]
    ON [dbo].[MetaKey];


GO
PRINT N'Dropping [dbo].[PromotionInformation].[IDX_PromotionInformation_PromotionGuid_CustomerId]...';


GO
DROP INDEX [IDX_PromotionInformation_PromotionGuid_CustomerId]
    ON [dbo].[PromotionInformation];


GO
PRINT N'Creating [dbo].[MetaKey].[IX_MetaKey_MetaObjectIdMetaClassId]...';


GO
CREATE NONCLUSTERED INDEX [IX_MetaKey_MetaObjectIdMetaClassId]
    ON [dbo].[MetaKey]([MetaObjectId] ASC, [MetaClassId] ASC)
    INCLUDE([WorkId]);


GO
PRINT N'Creating [dbo].[PromotionInformation].[IDX_PromotionInformation_PromotionGuid_CustomerId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_PromotionInformation_PromotionGuid_CustomerId]
    ON [dbo].[PromotionInformation]([PromotionGuid] ASC, [CustomerId] ASC) WHERE IsRedeemed = 1;


GO
PRINT N'Creating [dbo].[mcmd_SelectedEnumValue].[IX_mcmd_SelectedEnumValue_Indexed_Key]...';


GO
CREATE NONCLUSTERED INDEX [IX_mcmd_SelectedEnumValue_Indexed_Key]
    ON [dbo].[mcmd_SelectedEnumValue]([Key] ASC);


GO
PRINT N'Altering [dbo].[ecf_SerializableCart_FindCarts]...';


GO
ALTER PROCEDURE [dbo].[ecf_SerializableCart_FindCarts]
	@CartId INT = NULL,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@Name NVARCHAR (128) = NULL,
    @MarketId NVARCHAR (16) = NULL,
	@CreatedFrom DateTime = NULL,
	@CreatedTo DateTime = NULL,
	@ModifiedFrom DateTime = NULL,
	@ModifiedTo DateTime = NULL,
	@StartingRecord INT = NULL,
	@RecordsToRetrieve INT = NULL
AS
BEGIN
	DECLARE @query nvarchar(4000);
	SET @query = 'SELECT CartId, Created, Modified, [Data] FROM SerializableCart WHERE 1 = 1 '

	IF (@CartId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CartId = @CartId '
	END
	IF (@CustomerId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CustomerId = @CustomerId '
	END
	IF (@Name IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Name = @Name '
	END
	IF (@CartId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND CartId = @CartId '
	END
	IF (@MarketId IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND MarketId = @MarketId '
	END
	IF (@CreatedFrom IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Created >= @CreatedFrom '
	END
	IF (@CreatedTo IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Created <= @CreatedTo '
	END
	IF (@ModifiedFrom IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Modified >= @ModifiedFrom '
	END
	IF (@ModifiedTo IS NOT NULL)
	BEGIN
	SET @query = @query + ' AND Modified <= @ModifiedTo '
	END

	SET @query = @query +
	' ORDER BY  CartId DESC
        OFFSET '  + CAST(@StartingRecord AS NVARCHAR(50)) + '  ROWS 
        FETCH NEXT ' + CAST(@RecordsToRetrieve AS NVARCHAR(50)) + ' ROWS ONLY'

	exec sp_executesql @query, 
	N'@CartId INT,
	@CustomerId UNIQUEIDENTIFIER,
	@Name nvarchar(128),
    @MarketId nvarchar(16),
	@CreatedFrom DateTime,
	@CreatedTo DateTime,
	@ModifiedFrom DateTime,
	@ModifiedTo DateTime,
	@StartingRecord INT,
	@RecordsToRetrieve INT',
	@CartId = @CartId, @CustomerId= @CustomerId, @Name=@Name, @MarketId = @MarketId,
	@CreatedFrom = @CreatedFrom, @CreatedTo=@CreatedTo, @ModifiedFrom=@ModifiedFrom, @ModifiedTo=@ModifiedTo, 
	@StartingRecord = @StartingRecord, @RecordsToRetrieve =@RecordsToRetrieve
END
GO
PRINT N'Altering [dbo].[ecfVersion_DeleteByObjectId]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_DeleteByObjectId]
	@ObjectId [int],
	@ObjectTypeId [int]
AS
BEGIN
	-- Get affected meta keys, this needs to be done before deleting rows in ecfVersion
	DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT, WorkId INT)

	INSERT INTO @AffectedMetaKeys
	SELECT T.MetaClassId, V.ObjectId, V.WorkId
	FROM ecfVersion V
		INNER JOIN
		(SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
			UNION ALL
		SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
		ON V.ObjectId = T.ObjectId AND V.ObjectTypeId = T.ObjectTypeId
	 WHERE V.ObjectId = @ObjectId AND V.ObjectTypeId = @ObjectTypeId

	--When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
	DELETE FROM ecfVersion
	WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

	CREATE TABLE #MetaKeysToRemove (MetaKey INT)
	INSERT INTO #MetaKeysToRemove (MetaKey)
		SELECT MK.MetaKey FROM  @AffectedMetaKeys A
		INNER JOIN MetaKey MK
		ON 
		MK.MetaObjectId = A.MetaObjectId AND
		MK.MetaClassId = A.MetaClassId AND
		MK.WorkId = A.WorkId

	IF EXISTS (SELECT 1 FROM #MetaKeysToRemove)
	BEGIN
		-- Delete MetaObjectValue
		DELETE MO FROM MetaObjectValue MO INNER JOIN #MetaKeysToRemove M ON MO.MetaKey = M.MetaKey
		
		-- Delete MetaStringDictionaryValue
		DELETE MSD FROM MetaStringDictionaryValue MSD INNER JOIN #MetaKeysToRemove M ON MSD.MetaKey = M.MetaKey 
		
		--Delete MetaMultiValueDictionary
		DELETE MV FROM MetaMultiValueDictionary MV INNER JOIN #MetaKeysToRemove M ON MV.MetaKey = M.MetaKey
		
		--Delete MetaFileValue
		DELETE MF FROM MetaFileValue MF INNER JOIN #MetaKeysToRemove M ON MF.MetaKey = M.MetaKey
		
		--Delete MetaKey
		DELETE MK FROM MetaKey MK INNER JOIN #MetaKeysToRemove M ON MK.MetaKey = M.MetaKey		
	END
END
GO
PRINT N'Altering [dbo].[ecfVersion_DeleteByObjectIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds]
	@ObjectIds udttObjectWorkId readonly,
	@DeleteOnlyPublishedVersions BIT
AS
BEGIN
	-- Get affected meta keys, this needs to be done before deleting rows in ecfVersion
	DECLARE @AffectedMetaKeys TABLE (MetaClassId INT, MetaObjectId INT, WorkId INT)
	
	INSERT INTO @AffectedMetaKeys
	SELECT T.MetaClassId, V.ObjectId, V.WorkId
	FROM ecfVersion V
		INNER JOIN
		(SELECT CatalogEntryId AS ObjectId, 0 AS ObjectTypeId, MetaClassId FROM CatalogEntry
			UNION ALL
		SELECT CatalogNodeId AS ObjectId, 1 AS ObjectTypeId, MetaClassId FROM CatalogNode) T
		ON V.ObjectId = T.ObjectId AND V.ObjectTypeId = T.ObjectTypeId
		INNER JOIN @ObjectIds I
		ON I.ObjectId = V.ObjectId AND I.ObjectTypeId = V.ObjectTypeId
	WHERE (@DeleteOnlyPublishedVersions = 1 AND V.Status = 4) OR (@DeleteOnlyPublishedVersions = 0)

	--When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
	DELETE v FROM ecfVersion v
	INNER JOIN @ObjectIds i
		ON i.ObjectId = v.ObjectId AND i.ObjectTypeId = v.ObjectTypeId
	WHERE (@DeleteOnlyPublishedVersions = 1 AND v.Status = 4) OR (@DeleteOnlyPublishedVersions = 0)

	-- Delete data for all reference type meta fields (dictionaries etc)
	CREATE TABLE #MetaKeysToRemove (MetaKey INT)
	INSERT INTO #MetaKeysToRemove (MetaKey)
		SELECT MK.MetaKey FROM  @AffectedMetaKeys A
		INNER JOIN MetaKey MK
		ON 
		MK.MetaObjectId = A.MetaObjectId AND
		MK.MetaClassId = A.MetaClassId AND
		MK.WorkId = A.WorkId

	IF EXISTS (SELECT 1 FROM #MetaKeysToRemove)
	BEGIN
		-- Delete MetaObjectValue
		DELETE MO FROM MetaObjectValue MO INNER JOIN #MetaKeysToRemove M ON MO.MetaKey = M.MetaKey
		
		-- Delete MetaStringDictionaryValue
		DELETE MSD FROM MetaStringDictionaryValue MSD INNER JOIN #MetaKeysToRemove M ON MSD.MetaKey = M.MetaKey 
		
		--Delete MetaMultiValueDictionary
		DELETE MV FROM MetaMultiValueDictionary MV INNER JOIN #MetaKeysToRemove M ON MV.MetaKey = M.MetaKey
		
		--Delete MetaFileValue
		DELETE MF FROM MetaFileValue MF INNER JOIN #MetaKeysToRemove M ON MF.MetaKey = M.MetaKey
		
		--Delete MetaKey
		DELETE MK FROM MetaKey MK INNER JOIN #MetaKeysToRemove M ON MK.MetaKey = M.MetaKey		
	END
END
GO
PRINT N'Altering [dbo].[mdpsp_sys_LoadMultiValueDictionary]...';


GO
ALTER PROCEDURE [dbo].[mdpsp_sys_LoadMultiValueDictionary]
	@MetaKey	INT
AS

SELECT MVD.MetaDictionaryId FROM MetaMultiValueDictionary MVD
	WHERE MVD.MetaKey = @MetaKey
GO

GO
PRINT N'Altering [dbo].[ecfVersion_UpdateSeoByObjectIds]...';

GO


ALTER PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
	@ObjectIds udttObjectWorkId readonly
AS
BEGIN
DECLARE @WorkIds TABLE (WorkId INT)
	INSERT INTO @WorkIds (WorkId)
		SELECT v.WorkId
		FROM ecfVersion v
		INNER JOIN @ObjectIds c ON v.ObjectId = c.ObjectId AND v.ObjectTypeId = c.ObjectTypeId
		WHERE (v.Status = 4)
	UNION
		SELECT v.WorkId
		FROM ecfVersion v
		INNER JOIN @ObjectIds c ON v.ObjectId = c.ObjectId AND v.ObjectTypeId = c.ObjectTypeId
		WHERE (v.IsCommonDraft = 1 AND 
		NOT EXISTS(SELECT 1 FROM ecfVersion ev WHERE ev.ObjectId = c.ObjectId AND ev.ObjectTypeId = c.ObjectTypeId AND ev.Status = 4 ))
		
	UPDATE v 
	SET v.SeoUri = s.Uri,
	    v.SeoUriSegment = s.UriSegment
	FROM ecfVersion v
	INNER JOIN @WorkIds w on v.WorkId = w.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogEntryId = v.ObjectId AND v.ObjectTypeId = 0) --update entry versions
	
	UPDATE v 
	SET v.SeoUri = s.Uri,
	    v.SeoUriSegment = s.UriSegment
	FROM ecfVersion v
	INNER JOIN @WorkIds w on v.WorkId = w.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogNodeId = v.ObjectId AND v.ObjectTypeId = 1) --update node versions
END

GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
