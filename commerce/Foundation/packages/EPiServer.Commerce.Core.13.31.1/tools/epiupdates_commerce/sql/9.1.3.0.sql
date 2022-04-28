--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

GO
PRINT N'Adding CultureSpecific column to CatalogContentProperty'



GO
DECLARE @totalCultureSpecificCount INT;
DECLARE @totalCount INT;
SET @totalCultureSpecificCount = (select count(pkId) from CatalogContentProperty p
	inner join metafield f on p.MetaFieldId = f.MetaFieldId
	where f.MultiLanguageValue = 1)

SET @totalCount = (select count(pkId) from CatalogContentProperty)

IF (@totalCount > @totalCultureSpecificCount * 2)
BEGIN
	ALTER TABLE CatalogContentProperty ADD CultureSpecific BIT NOT NULL DEFAULT(0)
END
ELSE
BEGIN
	ALTER TABLE CatalogContentProperty ADD CultureSpecific BIT NOT NULL DEFAULT(1)
END

GO
PRINT N'Adding CultureSpecific column to ecfVersionProperty'

GO

DECLARE @totalCultureSpecificCount INT;
DECLARE @totalCount INT;
SET @totalCultureSpecificCount = (select count(WorkId) from ecfVersionProperty p
	inner join metafield f on p.MetaFieldId = f.MetaFieldId
	where f.MultiLanguageValue = 1)

SET @totalCount = (select count(WorkId) from ecfVersionProperty)

IF (@totalCount > @totalCultureSpecificCount * 2)
BEGIN
	ALTER TABLE ecfVersionProperty ADD CultureSpecific BIT NOT NULL DEFAULT(0)
END
ELSE
BEGIN
	ALTER TABLE ecfVersionProperty ADD CultureSpecific BIT NOT NULL DEFAULT(1)
END

GO
PRINT N'Dropping [dbo].[CatalogContentProperty_Migrate]...';


GO
DROP PROCEDURE [dbo].[CatalogContentProperty_Migrate];


GO
PRINT N'Dropping [dbo].[CatalogContentProperty_Save]...';


GO
DROP PROCEDURE [dbo].[CatalogContentProperty_Save];


GO
PRINT N'Dropping [dbo].[CatalogContentProperty_SaveBatch]...';


GO
DROP PROCEDURE [dbo].[CatalogContentProperty_SaveBatch];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty_SyncPublishedVersion]...';


GO
DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion];


GO
PRINT N'Dropping [dbo].[ecfVersion_Update]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_Update];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty_Save]...';


GO
DROP PROCEDURE [dbo].[ecfVersionProperty_Save];


GO
PRINT N'Dropping [dbo].[udttCatalogContentProperty]...';


GO
DROP TYPE [dbo].[udttCatalogContentProperty];


GO
PRINT N'Creating [dbo].[udttCatalogContentProperty]...';


GO
CREATE TYPE [dbo].[udttCatalogContentProperty] AS TABLE (
    [PropertyId]      BIGINT           NULL,
    [ObjectId]        INT              NULL,
    [ObjectTypeId]    INT              NULL,
    [WorkId]          INT              NULL,
    [MetaFieldId]     INT              NOT NULL,
    [MetaClassId]     INT              NOT NULL,
    [MetaFieldName]   NVARCHAR (255)   NULL,
    [LanguageName]    NVARCHAR (50)    NULL,
    [CultureSpecific] BIT              NULL,
    [Boolean]         BIT              NULL,
    [Number]          INT              NULL,
    [FloatNumber]     DECIMAL (38, 9)  NULL,
    [Money]           MONEY            NULL,
    [Decimal]         DECIMAL (38, 9)  NULL,
    [Date]            DATETIME         NULL,
    [Binary]          VARBINARY (MAX)  NULL,
    [String]          NVARCHAR (450)   NULL,
    [LongString]      NVARCHAR (MAX)   NULL,
    [Guid]            UNIQUEIDENTIFIER NULL,
    [IsNull]          BIT              NULL,
    [IsEncrypted]     BIT              NULL UNIQUE CLUSTERED ([ObjectId] ASC, [ObjectTypeId] ASC, [WorkId] ASC, [MetaFieldId] ASC, [LanguageName] ASC));


GO

GO
PRINT N'Altering [dbo].[CatalogContentProperty_LoadBatch]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_LoadBatch]
	@PropertyReferences [udttCatalogContentPropertyReference] READONLY
AS
BEGIN
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0  --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, ISNULL(L.LanguageCode, C.DefaultLanguage) AS LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			LEFT OUTER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)
		-- Select CatalogContentProperty data
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1) 
								THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
								ELSE P.LongString END 
							AS LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		
		;WITH CTE1 AS (
			SELECT R.*, E.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogEntry E ON E.CatalogEntryId = R.ObjectId AND R.ObjectTypeId = 0
		UNION ALL
			SELECT R.*, N.CatalogId
			FROM @PropertyReferences R
			INNER JOIN CatalogNode N ON N.CatalogNodeId = R.ObjectId AND R.ObjectTypeId = 1
		),
		CTE2 AS (
			SELECT CTE1.ObjectId, CTE1.ObjectTypeId, CTE1.MetaClassId, ISNULL(L.LanguageCode, C.DefaultLanguage) AS LanguageName, C.DefaultLanguage
			FROM CTE1
			INNER JOIN [Catalog] C ON C.CatalogId = CTE1.CatalogId
			LEFT OUTER JOIN CatalogLanguage L ON L.CatalogId = CTE1.CatalogId AND L.LanguageCode = CTE1.LanguageName
		)	
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], P.LongString LongString,
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((P.CultureSpecific = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
END
GO
PRINT N'Creating [dbo].[CatalogContentProperty_Migrate]...';


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

		INSERT INTO CatalogContentProperty (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, [Boolean], [Number], 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, [Boolean], [Number], 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString,
			[Guid] 
		FROM @ContentProperty
		WHERE [IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO CatalogContentProperty (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, [Boolean], [Number], 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, [Boolean], [Number], 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0
	END

	EXEC CatalogContentEx_Save @ContentExData
END
GO
PRINT N'Creating [dbo].[CatalogContentProperty_SaveBatch]...';


GO

CREATE PROCEDURE [dbo].[CatalogContentProperty_SaveBatch]
	@ContentProperty dbo.udttCatalogContentProperty readonly
AS
BEGIN
	--delete items which are not in input
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString,
				[Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentProperty
			WHERE [IsNull] = 0
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
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
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

	WHEN NOT MATCHED BY TARGET
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number,
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number,
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

END
GO
PRINT N'Creating [dbo].[ecfVersionProperty_Save]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_Save]
	@WorkIds dbo.udttObjectWorkId READONLY,
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN
	-- delete items which are not in input
	DELETE A
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @WorkIds W ON W.WorkId = A.WorkId
	LEFT JOIN @ContentDraftProperty I ON A.WorkId = I.WorkId AND A.MetaFieldId = I.MetaFieldId 
	WHERE (I.WorkId IS NULL OR I.[IsNull] = 1)

	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
		BEGIN
			EXEC mdpsp_sys_OpenSymmetricKey

			INSERT INTO @propertyData (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
				CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString, 
				[Guid]
			FROM @ContentDraftProperty
			WHERE [IsNull] = 0

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
			FROM @ContentDraftProperty
			WHERE [IsNull] = 0
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
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;
END
GO
PRINT N'Creating [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	
	DECLARE @propertyData udttCatalogContentProperty

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString, [Guid], [IsNull])
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = cdp.LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync
	END

	-- delete rows where values have been nulled out
	DELETE A 
	FROM [dbo].[ecfVersionProperty] A
	INNER JOIN @propertyData T
	ON	A.WorkId = T.WorkId AND 
		A.MetaFieldId = T.MetaFieldId AND
		T.[IsNull] = 1

	-- now null rows are handled, so remove them to not insert empty rows
	DELETE FROM @propertyData
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
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
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Sync version properties with version
	UPDATE [dbo].[ecfversion]
     SET [StartPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E 
		ON E.[WorkId] = I.[WorkId] 
	WHERE I.[MetaFieldName] = 'Epi_StartPublish'
	 
	  
	UPDATE [dbo].[ecfversion]
     SET [StopPublish] = I.[Date]
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_StopPublish'

	UPDATE [dbo].[ecfversion]
     SET [Status] = CASE when I.[Boolean] = 0 THEN 2
					ELSE 4 END
	FROM @PropertyData as I
	INNER JOIN [dbo].[ecfversion] E
		ON E.[WorkId] = I.[WorkId]
	WHERE I.[MetaFieldName] = 'Epi_IsPublished'

END
GO
PRINT N'Creating [dbo].[ecfVersionProperty_SyncPublishedVersion]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY,
	@LanguageName NVARCHAR(20)
AS
BEGIN
	DECLARE @propertyData udttCatalogContentProperty
	DECLARE @propertiesToSyncCount INT

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String,
			LongString,
			[Guid], [IsNull]) 
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, 
			CASE WHEN cdp.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(cdp.LongString, 1) ELSE cdp.LongString END AS LongString, 
			cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync
		
		SET @propertiesToSyncCount = @@ROWCOUNT

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName,Boolean, Number,
			FloatNumber, [Money], [Decimal], [Date], [Binary], String, LongString,[Guid], [IsNull])
		SELECT
			ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number,
			cdp.FloatNumber, cdp.[Money], cdp.[Decimal], cdp.[Date], cdp.[Binary], cdp.String, cdp.LongString, cdp.[Guid], cdp.[IsNull]
		FROM @ContentDraftProperty cdp
		INNER JOIN ecfVersion ccd
		ON	ccd.ObjectId = cdp.ObjectId AND
			ccd.ObjectTypeId = cdp.ObjectTypeId AND
			ccd.LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		WHERE ccd.[Status] = 4 OR ccd.IsCommonDraft = 1 --Draft properties of published version/common draft will be sync

		SET @propertiesToSyncCount = @@ROWCOUNT
	END

	IF @propertiesToSyncCount > 0
		BEGIN
			-- delete rows where values have been nulled out
			DELETE A 
				FROM [dbo].[ecfVersionProperty] A
				INNER JOIN @propertyData T
				ON	A.WorkId = T.WorkId AND 
					A.MetaFieldId = T.MetaFieldId AND
					T.[IsNull] = 1
		END
	ELSE
		BEGIN
			-- nothing to update
			RETURN
		END

	-- Now null rows are handled, so remove them to not insert empty rows
	DELETE FROM @propertyData
	WHERE [IsNull] = 1

	-- update/insert items which are not in input
	MERGE	[dbo].[ecfVersionProperty] as A
	USING	@propertyData as I
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
			INSERT (
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

END
GO
PRINT N'Creating [dbo].[ecfVersion_Update]...';


GO
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
PRINT N'Creating [dbo].[CatalogContentProperty_EnsureCultureSpecific]...';


GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_EnsureCultureSpecific]
AS
BEGIN
	UPDATE [CatalogContentProperty]
	SET [CatalogContentProperty].CultureSpecific = f.MultiLanguageValue
	FROM [CatalogContentProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE p.CultureSpecific <> f.MultiLanguageValue
END
GO
PRINT N'Creating [dbo].[ecfVersionProperty_EnsureCultureSpecific]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_EnsureCultureSpecific]
AS
BEGIN
	UPDATE [ecfVersionProperty]
	SET [ecfVersionProperty].CultureSpecific = f.MultiLanguageValue
	FROM [ecfVersionProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE p.CultureSpecific <> f.MultiLanguageValue
END
GO
PRINT N'Creating [dbo].[CatalogContentProperty_Save]...';


GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_Save]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ObjectId int,
	@ObjectTypeId int,
	@LanguageName NVARCHAR(50),
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	DECLARE @catalogId INT
	SET @catalogId =
		CASE
			WHEN @ObjectTypeId = 0 THEN
				(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
			WHEN @ObjectTypeId = 1 THEN
				(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
		END
	IF @LanguageName NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
	BEGIN
		SET @LanguageName = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @catalogId)
	END

	--delete properties where is null in input table
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND 
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1
	
	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
			LongString,
			[Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString, 
			[Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, CultureSpecific, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

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
			A.MetaClassId = I.MetaClassId,
			A.MetaFieldName = I.MetaFieldName,
			A.CultureSpecific = I.CultureSpecific,
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
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, CultureSpecific, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.CultureSpecific, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END

GO

-- Update CultureSpecific for CatalogContentProperty and ecfVersionProperty table
DECLARE @totalCultureSpecificCount INT;
DECLARE @totalCount INT;
SET @totalCultureSpecificCount = (select count(pkId) from CatalogContentProperty p
	inner join metafield f on p.MetaFieldId = f.MetaFieldId
	where f.MultiLanguageValue = 1)

SET @totalCount = (select count(pkId) from CatalogContentProperty)

IF (@totalCount > @totalCultureSpecificCount * 2)
BEGIN
	UPDATE [dbo].[CatalogContentProperty] 
	SET [CatalogContentProperty].CultureSpecific = 1
	FROM [CatalogContentProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE f.MultiLanguageValue = 1
END
ELSE
BEGIN
	UPDATE [dbo].[CatalogContentProperty] 
	SET [CatalogContentProperty].CultureSpecific = 0
	FROM [CatalogContentProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE f.MultiLanguageValue = 0
END

GO
DECLARE @totalCultureSpecificCount INT;
DECLARE @totalCount INT;
SET @totalCultureSpecificCount = (select count(WorkId) from ecfVersionProperty p
	inner join metafield f on p.MetaFieldId = f.MetaFieldId
	where f.MultiLanguageValue = 1)

SET @totalCount = (select count(WorkId) from ecfVersionProperty)

IF (@totalCount > @totalCultureSpecificCount * 2)
BEGIN
	UPDATE [dbo].[ecfVersionProperty] 
	SET [ecfVersionProperty].CultureSpecific = 0
	FROM [ecfVersionProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE f.MultiLanguageValue = 0
END
ELSE
BEGIN
	UPDATE [dbo].[ecfVersionProperty] 
	SET [ecfVersionProperty].CultureSpecific = 1
	FROM [ecfVersionProperty] p
	INNER JOIN [dbo].MetaField f ON p.MetaFieldId = f.MetaFieldId
	WHERE f.MultiLanguageValue = 1
END
GO

PRINT N'Altering the CultureSpecific column of CatalogContentProperty'
GO
ALTER TABLE CatalogContentProperty ALTER COLUMN CultureSpecific BIT NULL
GO

PRINT N'Altering the CultureSpecific column of ecfVersionProperty'
GO
ALTER TABLE ecfVersionProperty ALTER COLUMN CultureSpecific BIT NULL
GO

PRINT N'Refreshing [dbo].[CatalogContentProperty_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadAllLanguages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadAllLanguages]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogContentTypeGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogContentTypeGetUsage]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionGetUsage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionGetUsage]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]';


GO
PRINT N'Refreshing [dbo].[ecfVersionProperty_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionProperty_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
