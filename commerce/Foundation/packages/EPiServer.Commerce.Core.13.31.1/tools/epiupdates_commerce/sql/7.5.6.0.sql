--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 6    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByObjectIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds] 
GO

CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds]
	@ObjectIds udttObjectWorkId readonly,
	@InactiveOnly BIT
AS
BEGIN

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
	WHERE (@InactiveOnly = 1 AND V.Status = 4) OR (@InactiveOnly = 0)

	--When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
	DELETE V FROM ecfVersion V
	INNER JOIN @ObjectIds i
		ON i.ObjectId = V.ObjectId AND i.ObjectTypeId = V.ObjectTypeId
	WHERE (@InactiveOnly = 1 AND V.Status = 4) OR (@InactiveOnly = 0)

	-- Delete data for all reference type meta fields (dictionaries etc)
	DECLARE @ClassId INT
	DECLARE @ObjectId INT
	DECLARE @WId INT
	DECLARE cur CURSOR LOCAL FOR SELECT MetaClassId, MetaObjectId, WorkId FROM @AffectedMetaKeys

	OPEN cur
	FETCH NEXT FROM cur INTO @ClassId, @ObjectId, @WId

	WHILE @@FETCH_STATUS = 0 BEGIN
		EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId = @ClassId, @MetaObjectId = @ObjectId, @WorkId = @WId
		FETCH NEXT FROM cur INTO @ClassId, @ObjectId, @WId
	END

	CLOSE cur
	DEALLOCATE cur
END
GO


-- drop sprocs that use the udttVersionCatalog and the ecfVersionCatalog table
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionCatalog_Save]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncCatalogData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_Update]
GO

-- recreate udttVersionCatalog
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttVersionCatalog') DROP TYPE [dbo].[udttVersionCatalog]
GO

CREATE TYPE [dbo].[udttVersionCatalog] AS TABLE(
    [WorkId]			INT				 NOT NULL,
    [DefaultCurrency]	NVARCHAR(150)		 NULL,
    [WeightBase]		NVARCHAR(128)        NULL,
    [LengthBase]		NVARCHAR(128)        NULL,
	[DefaultLanguage]	NVARCHAR (20)        NULL,
	[Languages]			NVARCHAR (512)       NULL,
    [IsPrimary]		    BIT				 	 NULL,
    [Owner]			    NVARCHAR(255)		 NULL
)
GO

-- begin creating ecfVersionCatalog_Save sproc
CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, DefaultLanguage nvarchar(20))

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
	OUTPUT inserted.WorkId, inserted.DefaultLanguage INTO @WorkIds;

	IF @PublishAction = 1
	BEGIN
		DECLARE @Catalogs udttObjectWorkId

		INSERT INTO @Catalogs
			(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
			WHERE c.ObjectTypeId = 2
		-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
		
		DECLARE @CatalogId int, @MasterLanguageName nvarchar(20), @Languages nvarchar(512)
		DECLARE @ObjectIdsTemp TABLE(ObjectId INT)
		DECLARE catalogCursor CURSOR FOR SELECT DISTINCT ObjectId FROM @Catalogs
		
		OPEN catalogCursor  
		FETCH NEXT FROM catalogCursor INTO @CatalogId
		
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			SELECT @MasterLanguageName = v.DefaultLanguage, @Languages = v.Languages
			FROM @VersionCatalogs v
			INNER JOIN @Catalogs c ON c.WorkId = v.WorkId
			WHERE c.ObjectId = @CatalogId
						
			-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
			UPDATE d SET 
				d.DefaultLanguage = @MasterLanguageName
			FROM ecfVersionCatalog d
			INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
			
			-- and also update MasterLanguageName and CurrentLanguageRemovedFlag of contents that's related to Catalog
			-- catalogs
			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
						
			--nodes
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT n.CatalogNodeId
				FROM CatalogNode n
				WHERE n.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 1
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			--entries
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT e.CatalogEntryId
				FROM CatalogEntry e
				WHERE e.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 0
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			
			FETCH NEXT FROM catalogCursor INTO @CatalogId
		END
		
		CLOSE catalogCursor  
		DEALLOCATE catalogCursor;  
	END
END
GO
-- end creating ecfVersionCatalog_Save sproc

-- begin creating ecfVersionCatalog_ListByWorkIds sproc
CREATE PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
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
-- end creating ecfVersionCatalog_ListByWorkIds sproc

-- begin creating ecfVersion_SyncCatalogData sproc
CREATE PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, '', d.CreatedBy, d.Created, d.ModifiedBy, d.Modified, c.CatalogId,
				  c.EndDate
			FROM @ContentDraft d
			INNER JOIN dbo.Catalog c on d.ObjectId = c.CatalogId)
	AS SOURCE(ObjectId, ObjectTypeId, LanguageName, [MasterLanguageName], IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, CatalogId,
			  StopPublish)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET 
			target.MasterLanguageName = SOURCE.MasterLanguageName, 
			target.IsCommonDraft = SOURCE.IsCommonDraft,
			target.StartPublish = SOURCE.StartPublish, 
			target.Name = SOURCE.Name, 
			target.Code = SOURCE.Code,
			target.Modified = SOURCE.Modified, 
			target.ModifiedBy = SOURCE.ModifiedBy,
			target.StopPublish = SOURCE.StopPublish
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, 
				StopPublish)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish)
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
-- end creating ecfVersion_SyncCatalogData sproc

-- begin creating ecfVersion_Update sproc
CREATE PROCEDURE [dbo].[ecfVersion_Update]
	@WorkIds dbo.udttObjectWorkId readonly,
	@PublishAction bit,
	@ContentDraftProperty dbo.[udttCatalogContentProperty] readonly,
	@ContentDraftAsset dbo.[udttCatalogContentAsset] readonly,
	@AssetWorkIds dbo.[udttObjectWorkId] readonly,
	@Variants dbo.[udttVariantDraft] readonly,
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@IsVariant bit = 0,
	@IsCatalog bit = 0
AS
BEGIN
	-- Save draft properties
	EXEC [ecfVersionProperty_Save] @WorkIds = @WorkIds, @ContentDraftProperty = @ContentDraftProperty

	-- Save asset draft
	EXEC [ecfVersionAsset_Save] @WorkIds = @AssetWorkIds, @ContentDraftAsset = @ContentDraftAsset

	-- Save variation
	IF @IsVariant = 1
		EXEC [ecfVersionVariation_Save] @Variants = @Variants

	-- Save catalog draft
	IF @IsCatalog = 1
		EXEC [ecfVersionCatalog_Save] @VersionCatalogs = @VersionCatalogs, @PublishAction = @PublishAction
END
GO
-- end creating ecfVersion_Update sproc

-- update SeoUriSegment for catalog versions
UPDATE ver
SET ver.SeoUriSegment = cat.UriSegment
FROM ecfVersion ver
INNER JOIN ecfVersionCatalog cat ON cat.WorkId = ver.WorkId
WHERE ver.ObjectTypeId = 2
GO

-- update ecfVersionCatalog table
ALTER TABLE ecfVersionCatalog
DROP COLUMN UriSegment
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
