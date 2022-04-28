--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[ecfVersion_SyncCatalogData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncCatalogData];


GO
PRINT N'Dropping [dbo].[ecf_Warehouse_Save]...';


GO
DROP PROCEDURE [dbo].[ecf_Warehouse_Save];


GO
PRINT N'Dropping [dbo].[ecfVersion_Create]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_Create];


GO
PRINT N'Dropping [dbo].[ecfVersion_SyncEntryData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncEntryData];


GO
PRINT N'Dropping [dbo].[ecfVersion_SyncNodeData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncNodeData];


GO
PRINT N'Dropping [dbo].[udttWarehouse]...';


GO
DROP TYPE [dbo].[udttWarehouse];


GO
PRINT N'Dropping [dbo].[udttVersion]...';


GO
DROP TYPE [dbo].[udttVersion];


GO
PRINT N'Creating [dbo].[udttWarehouse]...';


GO
CREATE TYPE [dbo].[udttWarehouse] AS TABLE (
    [WarehouseId]         INT            NULL,
    [Name]                NVARCHAR (255) NOT NULL,
    [CreatorId]           NVARCHAR (256) NOT NULL,
    [Created]             DATETIME       NOT NULL,
    [ModifierId]          NVARCHAR (256) NOT NULL,
    [Modified]            DATETIME       NOT NULL,
    [IsActive]            BIT            NOT NULL,
    [IsPrimary]           BIT            NOT NULL,
    [SortOrder]           INT            NOT NULL,
    [Code]                NVARCHAR (50)  NOT NULL,
    [IsFulfillmentCenter] BIT            NOT NULL,
    [IsPickupLocation]    BIT            NOT NULL,
    [IsDeliveryLocation]  BIT            NOT NULL,
    [FirstName]           NVARCHAR (64)  NULL,
    [LastName]            NVARCHAR (64)  NULL,
    [Organization]        NVARCHAR (80)  NULL,
    [Line1]               NVARCHAR (80)  NULL,
    [Line2]               NVARCHAR (64)  NULL,
    [City]                NVARCHAR (64)  NULL,
    [State]               NVARCHAR (64)  NULL,
    [CountryCode]         NVARCHAR (50)  NULL,
    [CountryName]         NVARCHAR (50)  NULL,
    [PostalCode]          NVARCHAR (20)  NULL,
    [RegionCode]          NVARCHAR (50)  NULL,
    [RegionName]          NVARCHAR (64)  NULL,
    [DaytimePhoneNumber]  NVARCHAR (32)  NULL,
    [EveningPhoneNumber]  NVARCHAR (32)  NULL,
    [FaxNumber]           NVARCHAR (32)  NULL,
    [Email]               NVARCHAR (64)  NULL);


GO
PRINT N'Creating [dbo].[udttVersion]...';


GO
CREATE TYPE [dbo].[udttVersion] AS TABLE (
    [WorkId]             INT            NULL,
    [ObjectId]           INT            NOT NULL,
    [ObjectTypeId]       INT            NOT NULL,
    [CatalogId]          INT            NOT NULL,
    [Name]               NVARCHAR (100) NULL,
    [Code]               NVARCHAR (100) NULL,
    [LanguageName]       NVARCHAR (50)  NOT NULL,
    [MasterLanguageName] NVARCHAR (50)  NULL,
    [IsCommonDraft]      BIT            NULL,
    [StartPublish]       DATETIME       NULL,
    [StopPublish]        DATETIME       NULL,
    [Status]             INT            NULL,
    [CreatedBy]          NVARCHAR (100) NOT NULL,
    [Created]            DATETIME       NOT NULL,
    [ModifiedBy]         NVARCHAR (256) NULL,
    [Modified]           DATETIME       NULL,
    [SeoUri]             NVARCHAR (255) NULL,
    [SeoTitle]           NVARCHAR (150) NULL,
    [SeoDescription]     NVARCHAR (355) NULL,
    [SeoKeywords]        NVARCHAR (355) NULL,
    [SeoUriSegment]      NVARCHAR (255) NULL);


GO
PRINT N'Altering [dbo].[Catalog]...';


GO
ALTER TABLE [dbo].[Catalog] ALTER COLUMN [CreatorId] NVARCHAR (256) NULL;

ALTER TABLE [dbo].[Catalog] ALTER COLUMN [ModifierId] NVARCHAR (256) NULL;


GO
PRINT N'Altering [dbo].[Warehouse]...';


GO
ALTER TABLE [dbo].[Warehouse] ALTER COLUMN [CreatorId] NVARCHAR (256) NULL;

ALTER TABLE [dbo].[Warehouse] ALTER COLUMN [ModifierId] NVARCHAR (256) NULL;


GO
PRINT N'Altering [dbo].[ecf_Catalog_Update]...';


GO
ALTER PROCEDURE [dbo].[ecf_Catalog_Update]
(
	@CatalogId int,
	@Name nvarchar(150),
	@StartDate datetime,
	@EndDate datetime,
	@DefaultCurrency nvarchar(128),
	@WeightBase nvarchar(128),
	@DefaultLanguage nvarchar(10),
	@IsPrimary bit,
	@IsActive bit,
	@Created datetime,
	@Modified datetime,
	@CreatorId nvarchar(256),
	@ModifierId nvarchar(256),
	@SortOrder int
)
AS
	SET NOCOUNT OFF;
	UPDATE [Catalog]
	SET
		[Name] = @Name,
		[StartDate] = @StartDate,
		[EndDate] = @EndDate,
		[DefaultCurrency] = @DefaultCurrency,
		[WeightBase] = @WeightBase,
		[DefaultLanguage] = @DefaultLanguage,
		[IsPrimary] = @IsPrimary,
		[IsActive] = @IsActive,
		[Created] = @Created,
		[Modified] = @Modified,
		[CreatorId] = @CreatorId,
		[ModifierId] = @ModifierId,
		[SortOrder] = @SortOrder
	WHERE 
		[CatalogId] = @CatalogId

	RETURN @@Error
GO
PRINT N'Creating [dbo].[ecfVersion_SyncCatalogData]...';


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
PRINT N'Creating [dbo].[ecf_Warehouse_Save]...';


GO
CREATE PROCEDURE dbo.ecf_Warehouse_Save
	@Warehouse udttWarehouse READONLY
AS
BEGIN
	BEGIN TRY
	DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION

    IF (SELECT arg.WarehouseId FROM @Warehouse arg) IS NULL
		BEGIN 
			SET IDENTITY_INSERT dbo.Warehouse OFF
			INSERT INTO dbo.Warehouse
			(Name, CreatorId, Created, ModifierId, Modified, IsActive, IsPrimary, SortOrder, Code,
			 IsFulfillmentCenter, IsPickupLocation, IsDeliveryLocation,
			 FirstName, LastName, Organization, Line1, Line2, City, [State], CountryCode, CountryName,
			 PostalCode, RegionCode, RegionName, DaytimePhoneNumber, EveningPhoneNumber, FaxNumber, Email)
			SELECT arg.Name, arg.CreatorId, arg.Created, arg.ModifierId, arg.Modified,
				arg.IsActive, arg.IsPrimary, arg.SortOrder, arg.Code, arg.IsFulfillmentCenter, arg.IsPickupLocation, arg.IsDeliveryLocation, 
				arg.FirstName, arg.LastName, arg.Organization, arg.Line1, arg.Line2, arg.City, arg.[State], arg.CountryCode, arg.CountryName,
				arg.PostalCode, arg.RegionCode, arg.RegionName, arg.DaytimePhoneNumber, arg.EveningPhoneNumber,
				arg.FaxNumber, arg.Email
			FROM @Warehouse AS arg
		END
    ELSE
		BEGIN    
			UPDATE [dbo].[Warehouse]
			SET Name = arg.Name, Code = arg.Code, ModifierId = arg.ModifierId, Modified = arg.Modified,
			SortOrder = arg.SortOrder, IsActive = arg.IsActive, IsPrimary = arg.IsPrimary,
			IsFulfillmentCenter = arg.IsFulfillmentCenter, IsPickupLocation = arg.IsPickupLocation, IsDeliveryLocation = arg.IsDeliveryLocation, 
			FirstName = arg.FirstName, LastName = arg.LastName, Organization = arg.Organization, Line1 = arg.Line1, Line2 = arg.Line2, City = arg.City,
			[State] = arg.[State], CountryCode = arg.CountryCode, CountryName = arg.CountryName,
			PostalCode = arg.PostalCode, RegionCode = arg.RegionCode, RegionName = arg.RegionName,
			DaytimePhoneNumber = arg.DaytimePhoneNumber, EveningPhoneNumber = arg.EveningPhoneNumber,
			FaxNumber = arg.FaxNumber, Email = arg.Email
			FROM @Warehouse arg
			INNER JOIN dbo.Warehouse w
			ON w.WarehouseId = arg.WarehouseId
		END
		
    IF @initialTranCount = 0 COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
    DECLARE @msg NVARCHAR(4000), @severity INT, @state INT
    SELECT @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()    
    IF @initialTranCount = 0 ROLLBACK TRANSACTION   
    RAISERROR(@msg, @severity, @state)
	END CATCH
END
GO
PRINT N'Altering [dbo].[ecfVersion_Insert]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_Insert]
	@ObjectId int,
	@ObjectTypeId int,
	@CatalogId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](50),
	@MasterLanguageName [nvarchar](50),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status int,
	@CreatedBy [nvarchar](100),
	@Created DATETIME,
	@ModifiedBy [nvarchar](256),
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
PRINT N'Creating [dbo].[ecfVersion_Create]...';


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
PRINT N'Creating [dbo].[ecfVersion_SyncEntryData]...';


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
PRINT N'Creating [dbo].[ecfVersion_SyncNodeData]...';


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
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadBatch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadBatch]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Save]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogName]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogName]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_Guid_FindEntity]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Guid_FindEntity]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidCatalog_Find]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidCatalog_Find]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidCatalog_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidCatalog_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_LowStock]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_LowStock]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateVersionsMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionCatalog_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_GetMetaKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_DeleteWarehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_DeleteWarehouse]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_GetWarehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_GetWarehouse]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_InsertWarehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_InsertWarehouse]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_ListWarehouses]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_ListWarehouses]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_UpdateWarehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_UpdateWarehouse]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_Language]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_Language]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_Market]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_Market]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse_GetByCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse_GetByCode]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse_GetById]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse_GetById]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse_List]';


GO
PRINT N'Refreshing [dbo].[ecf_Warehouse_WarehouseId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Warehouse_WarehouseId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecf_Inventory_SaveWarehouse]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Inventory_SaveWarehouse]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
