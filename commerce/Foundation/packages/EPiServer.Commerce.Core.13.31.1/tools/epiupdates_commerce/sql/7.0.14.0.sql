--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 14    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- modify store procedure ecfVersion_UpdateCurrentLanguageRemoved
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_UpdateCurrentLanguageRemoved]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved]
GO

CREATE PROCEDURE [dbo].[ecfVersion_UpdateCurrentLanguageRemoved]
	@ObjectId			int,
	@ObjectTypeId		int
AS
BEGIN
	CREATE TABLE #RecursiveContents (ObjectId INT, ObjectTypeId INT)
	DECLARE @catalogId INT

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
		SELECT @catalogId = CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId
	END
	ELSE
	BEGIN
		-- in case entry content, just update for only entry
		INSERT INTO #RecursiveContents (ObjectId, ObjectTypeId)
		VALUES (@ObjectId, @ObjectTypeId)

		-- get CatalogId from entry content
		SELECT @catalogId = CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId
	END

	UPDATE v
	SET
		CurrentLanguageRemoved = CASE WHEN cl.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT THEN 0 ELSE 1 END,
		MasterLanguageName = c.DefaultLanguage
	FROM	ecfVersion v
	INNER JOIN #RecursiveContents r 
				ON r.ObjectId = v.ObjectId and r.ObjectTypeId = v.ObjectTypeId
	INNER JOIN Catalog c ON c.CatalogId = @catalogId
	LEFT JOIN CatalogLanguage cl ON v.LanguageName = cl.LanguageCode AND cl.CatalogId = @catalogId

	DROP TABLE #RecursiveContents
END
GO

-- end modify store procedure ecfVersion_UpdateCurrentLanguageRemoved

-- drop stored procedures using the udtt
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Save]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_SaveBatch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersion_Update]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Migrate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Migrate]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_Save]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncBatchPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttCatalogContentProperty') DROP TYPE [dbo].[udttCatalogContentProperty]
GO

--recreate udttCatalogContentProperty with new column
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
	[IsNull] [bit] NULL
	UNIQUE CLUSTERED ([ObjectId], [ObjectTypeId], [WorkId], [MetaFieldId], [LanguageName])
)
GO
--end recreate udttCatalogContentProperty with new column

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
								[Money] Money, [Decimal] Decimal(38,9), [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER, [IsNull] BIT) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		DECLARE @RowInsertedCount INT
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				CASE WHEN F.IsEncrypted	= 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
				cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		INNER JOIN MetaField F ON F.MetaFieldId = cdp.MetaFieldId
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
		
		SET @RowInsertedCount = @@ROWCOUNT

		EXEC mdpsp_sys_CloseSymmetricKey
		
		IF @RowInsertedCount > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
										  A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
		
	END
	ELSE
	BEGIN
		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		IF @@ROWCOUNT > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
									      A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
	END

	DELETE FROM #TempProp
	WHERE [IsNull] = 1

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
   WHEN	NOT  MATCHED BY TARGET
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
GO
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
								[Money] Money, [Decimal] Decimal(38,9), [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER, [IsNull] BIT) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				CASE WHEN F.IsEncrypted	= 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
				cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		INNER JOIN MetaField F ON F.MetaFieldId = cdp.MetaFieldId
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync
		
		EXEC mdpsp_sys_CloseSymmetricKey
		
		IF @@ROWCOUNT > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
										  A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
		
	END
	ELSE
	BEGIN
		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
				cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd ON ccd.ObjectId = cdp.ObjectId 
										  AND ccd.ObjectTypeId = cdp.ObjectTypeId 
										  AND ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 --Draft properties of published version will be sync

		IF @@ROWCOUNT > 0
			BEGIN
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN #TempProp T ON A.WorkId = T.WorkId AND 
										  A.MetaFieldId = T.MetaFieldId AND
										  T.[IsNull] = 1
			END
		ELSE--return if there is no publish version
			BEGIN
			 RETURN
			END
	END

	DELETE FROM #TempProp
	WHERE [IsNull] = 1

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
   WHEN	NOT  MATCHED BY TARGET
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[CatalogContentProperty_Save]
GO

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
	--delete properties where is null in input table
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I ON	A.ObjectId = I.ObjectId AND 
									A.ObjectTypeId = I.ObjectTypeId AND
									A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
									A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1
	
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
		AND I.[IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty I
		WHERE I.[IsNull] = 0

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


-- adding user table type
IF NOT EXISTS (SELECT 1 FROM sys.types WHERE is_table_type = 1 AND name = 'udttCatalogCodeId')
CREATE TYPE [dbo].[udttCatalogCodeId] AS TABLE (
    [ApplicationId]    UNIQUEIDENTIFIER NOT NULL,
	[ObjectId] INT   NULL,
	[Code] NVARCHAR (100)   NULL );
GO 
-- end adding user table type

-- adding stored procedures 
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogEntryCodesByIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogEntryCodesByIds]
GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryCodesByIds]
	@CatalogIds udttCatalogCodeId READONLY
AS
BEGIN
	SELECT e.Code, e.CatalogEntryId from [CatalogEntry] e
	INNER JOIN @CatalogIds k  ON e.ApplicationId = k.ApplicationId AND e.CatalogEntryId = k.ObjectId
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogEntryIdsByCodes]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogEntryIdsByCodes]
GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryIdsByCodes]
	@CatalogCodes udttCatalogCodeId READONLY
AS
BEGIN
	SELECT e.Code, e.CatalogEntryId from [CatalogEntry] e
	INNER JOIN @CatalogCodes k ON e.ApplicationId = k.ApplicationId AND e.Code = k.Code
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogNodeCodesByIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogNodeCodesByIds]
GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogNodeCodesByIds]
	@CatalogIds udttCatalogCodeId READONLY
AS
BEGIN
	SELECT n.Code, n.CatalogNodeId from [CatalogNode] n
	INNER JOIN @CatalogIds k ON n.ApplicationId = k.ApplicationId AND n.CatalogNodeId = k.ObjectId
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogNodeIdsByCodes]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogNodeIdsByCodes]
GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogNodeIdsByCodes]
	@CatalogCodes udttCatalogCodeId READONLY
AS
BEGIN
	SELECT n.Code, n.CatalogNodeId from [CatalogNode] n
	INNER JOIN @CatalogCodes k ON n.ApplicationId = k.ApplicationId AND n.Code = k.Code
END
GO
-- end adding stored procedures

-- remove unused stored procedures
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCodeByCatalogEntryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCodeByCatalogEntryId]
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCodeByCatalogNodeId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCodeByCatalogNodeId]
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogEntryIdByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogEntryIdByCode]
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogNodeIdByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCatalogNodeIdByCode]
GO
-- end remove unused stored procedures


--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 14, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
