--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 12    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- modifying tables udttCatalogContentProperty and ecfVersionProperty to add Decimal column
IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'Decimal' AND Object_ID = Object_ID(N'CatalogContentProperty'))
BEGIN
	ALTER TABLE CatalogContentProperty ADD [Decimal] DECIMAL(38,9) NULL;
END
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'Decimal' AND Object_ID = Object_ID(N'ecfVersionProperty'))
BEGIN
	ALTER TABLE ecfVersionProperty ADD [Decimal] DECIMAL(38,9) NULL;
END
GO
-- end modifying tables CatalogContentProoperty and ecfVersionProperty to add Decimal column

-- migrating data to new columns

UPDATE ccp
SET [Decimal] = CAST(FloatNumber as decimal(38,9)), FloatNumber = NULL
FROM CatalogContentProperty ccp
INNER JOIN MetaField F ON ccp.MetaFieldId = F.MetaFieldId
INNER JOIN MetaDataType T ON F.DataTypeId = T.DataTypeId
WHERE T.Name = 'Decimal' AND ccp.FloatNumber IS NOT NULL

GO

UPDATE ccp
SET [Decimal] = CAST(FloatNumber as decimal(38,9)), FloatNumber = NULL
FROM ecfVersionProperty ccp
INNER JOIN MetaField F ON ccp.MetaFieldId = F.MetaFieldId
INNER JOIN MetaDataType T ON F.DataTypeId = T.DataTypeId
WHERE T.Name = 'Decimal' AND ccp.FloatNumber IS NOT NULL

GO

-- end migrating data to new columns

-- modifying udt udttCatalogContentProperty
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Load]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Load]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Migrate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Migrate]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Save]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_SaveBatch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_ListByWorkIds]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_Save]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncBatchPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_Update]
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name = 'udttCatalogContentProperty')
BEGIN
	DROP TYPE udttCatalogContentProperty;
END	
GO

CREATE TYPE [dbo].[udttCatalogContentProperty] AS TABLE(
	[PropertyId] [bigint] NULL,
	[ObjectId] [int] NULL,
	[ObjectTypeId] INT NULL,
	[WorkId] [int] NULL,
	[MetaFieldId] [int] NOT NULL,
	[MetaClassId] int NOT NULL,
	[MetaFieldName] [nvarchar](255) NULL,
	[LanguageName] [nvarchar](50) NULL,
	[Boolean] [bit] NULL,
	[Number] [int] NULL,
	[FloatNumber] [decimal](38,9) NULL,
	[Money] [money] NULL,
	[Decimal] [decimal](38,9) NULL,
	[Date] [datetime] NULL,
	[Binary] [varbinary](max) NULL,
	[String] [nvarchar](450) NULL,
	[LongString] [nvarchar](max) NULL,
	[Guid] [uniqueidentifier] NULL,
	UNIQUE CLUSTERED ([ObjectId], [ObjectTypeId], [WorkId], [MetaFieldId], [LanguageName]))
GO
-- end modifying udt udttCatalogContentProperty

-- modifying stored procedure ecfVersion_Update
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
-- end modifying stored procedure ecfVersion_Update

-- modifying stored procedure CatalogContentProperty_Load
CREATE PROCEDURE [dbo].[CatalogContentProperty_Load]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int,
	@Language nvarchar(50)
AS
BEGIN
	DECLARE @catalogId INT
	DECLARE @FallbackLanguage nvarchar(50)

	SET @catalogId = CASE WHEN @ObjectTypeId = 0 THEN
							(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
							WHEN @ObjectTypeId = 1 THEN							
							(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
						END
	SELECT @FallbackLanguage = DefaultLanguage FROM dbo.[Catalog] WHERE CatalogId = @catalogId

	-- load from fallback language only if @Language is not existing language of catalog.
	-- in other work, fallback language is used for invalid @Language value only.
	IF @Language NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
		SET @Language = @FallbackLanguage

	-- update encrypted field: support only LongString field
	-- Open and Close SymmetricKey do nothing if the system does not support encryption
	EXEC mdpsp_sys_OpenSymmetricKey

	SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
						P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
						CASE WHEN (dbo.mdpfn_sys_IsAzureCompatible() = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
							THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
							ELSE P.LongString END 
						AS LongString,
						P.[Guid]  
	FROM dbo.CatalogContentProperty P
	INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
	WHERE ObjectId = @ObjectId AND
			ObjectTypeId = @ObjectTypeId AND
			MetaClassId = @MetaClassId AND
			((F.MultiLanguageValue = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))

	EXEC mdpsp_sys_CloseSymmetricKey


	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
-- end modifying stored procedure CatalogContentProperty_Load

-- modifying stored procedure CatalogContentProperty_Migrate
CREATE PROCEDURE [dbo].[CatalogContentProperty_Migrate]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ContentExData dbo.udttCatalogContentEx readonly
AS
BEGIN
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO CatalogContentProperty
			(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			 CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString,
			 [Guid] 
		FROM @ContentProperty I
		INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO CatalogContentProperty
			(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid] FROM @ContentProperty
	END

	EXEC CatalogContentEx_Save @ContentExData
END
GO
-- end modifying stored procedure CatalogContentProperty_Migrate

-- modifying stored procedure CatalogContentProperty_Save
CREATE PROCEDURE [dbo].[CatalogContentProperty_Save]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ObjectId int,
	@ObjectTypeId int,
	@LanguageName NVARCHAR(20),
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	DECLARE @catalogId INT
	SET @catalogId = CASE WHEN @ObjectTypeId = 0 THEN
							(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
							WHEN @ObjectTypeId = 1 THEN							
							(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
						END
	IF @LanguageName NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
	BEGIN
		SET @LanguageName = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @catalogId)
	END

	IF ((SELECT COUNT(*) FROM @ContentProperty) = 0)
	BEGIN 
		DELETE [CatalogContentProperty] WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

		IF (@SyncVersion = 1)
		BEGIN
			EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
		END

		RETURN
	END

	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I ON	A.ObjectId = I.ObjectId AND 
									A.ObjectTypeId = I.ObjectTypeId AND
									A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
									A.MetaFieldId <> I.MetaFieldId

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, I.MetaFieldName, @LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
						CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						[Guid]
		FROM @ContentProperty I
		INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty I
	END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND 
			A.ObjectTypeId = I.ObjectTypeId AND 
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED 
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT 
				(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END
GO
-- end modifying stored procedure CatalogContentProperty_Save

-- modifying stored procedure CatalogContentProperty_SaveBatch
CREATE PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I ON	A.ObjectId = I.ObjectId AND 
									A.ObjectTypeId = I.ObjectTypeId AND
									A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
									A.MetaFieldId <> I.MetaFieldId

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, I.MetaFieldName, I.[LanguageName], Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
						 CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						 [Guid]
			FROM @ContentProperty I
			INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, I.LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentProperty I
		END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND 
			A.ObjectTypeId = I.ObjectTypeId AND 
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED 
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT 
				(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncBatchPublishedVersion] @ContentProperty
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END

GO
-- end modifying stored procedure CatalogContentProperty_SaveBatch

-- modifying stored procedure ecfVersionProperty_ListByWorkIds
CREATE PROCEDURE [dbo].[ecfVersionProperty_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	CREATE TABLE #nonMasterLinks (
		ObjectId INT, 
		ObjectTypeId INT, 
		WorkId INT,
		DefaultLanguage NVARCHAR(50),
		[Status] INT,
		MasterWorkId INT
	)

	INSERT INTO #nonMasterLinks
	SELECT l.ObjectId, l.ObjectTypeId, l.WorkId, d.MasterLanguageName, d.[Status], NULL
	FROM @ContentLinks l
	INNER JOIN ecfVersion d ON l.WorkId = d.WorkId
	WHERE d.LanguageName <> d.MasterLanguageName COLLATE DATABASE_DEFAULT

	UPDATE l SET MasterWorkId = d.WorkId
	FROM #nonMasterLinks l
	INNER JOIN ecfVersion d ON d.ObjectId = l.ObjectId AND d.ObjectTypeId = l.ObjectTypeId
	WHERE d.[Status] = 4 AND l.DefaultLanguage = d.LanguageName COLLATE DATABASE_DEFAULT

	DECLARE @IsAzureCompatible BIT
	SET @IsAzureCompatible = dbo.mdpfn_sys_IsAzureCompatible()

	-- Open and Close SymmetricKey do nothing if the system does not support encryption
	EXEC mdpsp_sys_OpenSymmetricKey
	-- select property for draft that is master language one or multi language property
	SELECT draftProperty.pkId, draftProperty.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
			draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN (@IsAzureCompatible = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
				THEN dbo.mdpfn_sys_EncryptDecryptString(draftProperty.LongString, 0) 
				ELSE draftProperty.LongString END as LongString, 
			draftProperty.[Guid]
	FROM ecfVersionProperty draftProperty
	INNER JOIN MetaField F ON F.MetaFieldId = draftProperty.MetaFieldId
	INNER JOIN @ContentLinks links ON links.WorkId = draftProperty.WorkId
	
	-- and fall back property
	UNION ALL
	SELECT draftProperty.pkId, draftProperty.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
			draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN (@IsAzureCompatible = 0 AND F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
				THEN dbo.mdpfn_sys_EncryptDecryptString(draftProperty.LongString, 0) 
				ELSE draftProperty.LongString END as LongString, 
			draftProperty.[Guid]
	FROM ecfVersionProperty draftProperty
	INNER JOIN MetaField F ON F.MetaFieldId = draftProperty.MetaFieldId
	INNER JOIN #nonMasterLinks links ON links.MasterWorkId = draftProperty.WorkId
	WHERE F.MultiLanguageValue = 0
	
	EXEC mdpsp_sys_CloseSymmetricKey

	DROP TABLE #nonMasterLinks
END
GO
-- end modifying stored procedure ecfVersionProperty_ListByWorkIds

-- modifying stored procedure ecfVersionProperty_Save
CREATE PROCEDURE [dbo].[ecfVersionProperty_Save]
	@WorkIds dbo.udttObjectWorkId READONLY,
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN
	IF ((SELECT COUNT(*) FROM @ContentDraftProperty) = 0)
	BEGIN 
		DELETE [ecfVersionProperty] 
		FROM [ecfVersionProperty] A
		INNER JOIN @WorkIds W ON W.WorkId = A.WorkId
		RETURN
	END

	-- delete items which are not in input
	DELETE A
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @WorkIds W on W.WorkId = A.WorkId
	LEFT JOIN @ContentDraftProperty I 	ON	A.WorkId = I.WorkId AND 
											A.MetaFieldId = I.MetaFieldId 
	WHERE (I.WorkId IS NULL OR
			I.MetaFieldId IS NULL )

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT WorkId, ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
						 CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						 [Guid]
			FROM @ContentDraftProperty I
			INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentDraftProperty
		END

	-- update/insert items
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
	ON		A.WorkId = I.WorkId AND 
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 			
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT 
				(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;
END

GO
-- end modifying stored procedure ecfVersionProperty_Save

-- modifying stored procedure ecfVersionProperty_SyncBatchPublishedVersion
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	CREATE TABLE #TempProp(WorkId INT, ObjectId INT, ObjectTypeId INT, MetaFieldId INT, MetaClassId INT, MetaFieldName NVARCHAR(510), LanguageName NVARCHAR(100), Boolean BIT, Number INT, FloatNumber FLOAT,
								[Money] Money, [Decimal] Decimal(38,9), [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				CASE WHEN F.IsEncrypted	= 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
				cdp.[Guid]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		INNER JOIN MetaField F ON F.MetaFieldId = cdp.MetaFieldId
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				cdp.LongString, cdp.[Guid]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
	END

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	#TempProp as I
	ON		A.WorkId = I.WorkId AND
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 		
			A.LanguageName = I.LanguageName,	
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT 
				(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	DROP TABLE #TempProp
END

GO
-- end modifying stored procedure ecfVersionProperty_SyncBatchPublishedVersion

-- modifying stored procedure ecfVersionProperty_SyncPublishedVersion
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY,
	@ObjectId INT,
	@ObjectTypeId INT,
	@LanguageName NVARCHAR(20)
AS
BEGIN
	IF ((SELECT COUNT(*) FROM @ContentDraftProperty) = 0)
	BEGIN 
		DELETE [ecfVersionProperty] WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
		RETURN
	END

	CREATE TABLE #TempProp(WorkId INT, ObjectId INT, ObjectTypeId INT, MetaFieldId INT, MetaClassId INT, MetaFieldName NVARCHAR(510), LanguageName NVARCHAR(100), Boolean BIT, Number INT, FloatNumber FLOAT,
								[Money] Money, [Decimal] Decimal(38,9), [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				CASE WHEN F.IsEncrypted	= 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
				cdp.[Guid]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		INNER JOIN MetaField F ON F.MetaFieldId = cdp.MetaFieldId
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				cdp.LongString, cdp.[Guid]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
	END

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	#TempProp as I
	ON		A.WorkId = I.WorkId AND
			A.MetaFieldId = I.MetaFieldId 
	WHEN	MATCHED 
		-- update the ecfVersionProperty for existing row
		THEN UPDATE SET 		
			A.LanguageName = I.LanguageName,	
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record is does not exist in ecfVersionProperty table
		THEN 
			INSERT 
				(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				 FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	DROP TABLE #TempProp
END

GO
-- end modifying stored procedure ecfVersionProperty_SyncPublishedVersion
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 12, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
