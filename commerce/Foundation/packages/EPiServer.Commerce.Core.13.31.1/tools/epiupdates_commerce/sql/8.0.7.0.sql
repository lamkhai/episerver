--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 7    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
CREATE FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]
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
    DECLARE @Count int
    DECLARE @parentId int
	DECLARE @CatalogId int
    
    -- get the parentId and CatalogId, based on entityId and the entity type
    IF @type = 0
	BEGIN
		SELECT @parentId = ParentNodeId, @CatalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @entityId
	END
    ELSE
	BEGIN
        SET @parentId = (SELECT CatalogNodeId FROM NodeEntryRelation WHERE CatalogEntryId = @entityId)
		SET @CatalogId = (SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @entityId)
	END

    SET @RetVal = 0

    -- check if the UriSegment exists on sibling node
    SET @Count = (
                    SELECT COUNT(S.CatalogNodeId)
                    FROM CatalogItemSeo S WITH (NOLOCK) 
                    INNER JOIN CatalogNode N on N.CatalogNodeId = S.CatalogNodeId
                    LEFT JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId 
                    WHERE LanguageCode = @LanguageCode COLLATE DATABASE_DEFAULT 
                        AND S.CatalogNodeId <> @entityId
                        AND ((@parentId = 0 AND N.CatalogId = @CatalogId) OR (@parentId <> 0 AND (N.ParentNodeId = @parentId OR NR.ParentNodeId = @parentId)))
                        AND UriSegment = @UriSegment COLLATE DATABASE_DEFAULT 
                        AND N.IsActive = 1
                )
                
    IF @Count = 0 -- check against sibling entry if only UriSegment does not exist on sibling node
    BEGIN
        -- check if the UriSegment exists on sibling entry
        SET @Count = (
                        SELECT COUNT(S.CatalogEntryId)
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
    END

    IF @Count <> 0
    BEGIN
        SET @RetVal = 1
    END

    RETURN @RetVal;
END
GO
PRINT N'Creating [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri segment and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], '' AS [UriSegment] 
	FROM @CatalogItemSeo t
	WHERE (t.CatalogNodeId > 0 AND dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogNodeId, 0, t.UriSegment, t.LanguageCode) = 1)
			OR
			(t.CatalogEntryId > 0 AND dbo.fn_UriSegmentExistsOnSiblingNodeOrEntry(t.CatalogEntryId, 1, t.UriSegment, t.LanguageCode) = 1)
END
GO
PRINT N'Creating [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
	@ObjectIds udttObjectWorkId readonly
AS
BEGIN
	DECLARE @Contents TABLE (ObjectId INT, ObjectTypeId INT, Published BIT)
	INSERT INTO @Contents (ObjectId, ObjectTypeId, Published)
	SELECT c.ObjectId, 
		   c.ObjectTypeId,
		   CASE WHEN EXISTS(SELECT 1 FROM ecfVersion v WHERE v.ObjectId = c.ObjectId AND v.ObjectTypeId = c.ObjectTypeId AND v.[Status] = 4) THEN 1 ELSE 0 END
	FROM @ObjectIds c
	
	UPDATE v 
	SET v.SeoUri = s.Uri,
	    v.SeoUriSegment = s.UriSegment
	FROM ecfVersion v
	INNER JOIN @Contents i ON i.ObjectId = v.ObjectId AND i.ObjectTypeId = v.ObjectTypeId
	INNER JOIN CatalogItemSeo s ON (s.CatalogEntryId = v.ObjectId AND v.ObjectTypeId = 0)
								OR (s.CatalogNodeId = v.ObjectId AND v.ObjectTypeId = 1)
	WHERE (v.[Status] = 4 AND i.Published = 1) -- update SeoUri and SeoUriSegment for published version if the content is published
	   OR (v.IsCommonDraft = 1 AND i.Published = 0) -- or for common draft version if the content hasn't been published yet
END
GO
PRINT N'Creating [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]
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

--Update PromotionInformation.IsRedeemed to false for cancelled Purchase Order
UPDATE P
SET IsRedeemed = 0
FROM dbo.PromotionInformation P
INNER JOIN dbo.OrderForm F ON P.OrderFormId = F.OrderFormId
INNER JOIN dbo.OrderGroup G ON F.OrderGroupId = G.OrderGroupId
WHERE G.Status = 'Cancelled'

GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 7, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
