--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 10    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

GO
PRINT N'Dropping [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';


GO
DROP INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion];


GO
PRINT N'Dropping [dbo].[LineItemDiscount].[IX_LineItem_OrderGroupId]...';


GO
DROP INDEX [IX_LineItem_OrderGroupId]
    ON [dbo].[LineItemDiscount];


GO
PRINT N'Dropping [dbo].[OrderGroupNote].[IX_OrderGroupNote_OrderGroupId]...';


GO
DROP INDEX [IX_OrderGroupNote_OrderGroupId]
    ON [dbo].[OrderGroupNote];


GO
PRINT N'Dropping [dbo].[CatalogContentProperty].[IDX_CatalogContentProperty_MetaFieldId]...';


GO
DROP INDEX [IDX_CatalogContentProperty_MetaFieldId]
    ON [dbo].[CatalogContentProperty];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty].[IDX_ecfVersionProperty_MetaFieldId]...';


GO
DROP INDEX [IDX_ecfVersionProperty_MetaFieldId]
    ON [dbo].[ecfVersionProperty];


GO
PRINT N'Dropping [dbo].[FK_LineItemDiscount_LineItem]...';


GO
ALTER TABLE [dbo].[LineItemDiscount] DROP CONSTRAINT [FK_LineItemDiscount_LineItem];


GO
PRINT N'Dropping [dbo].[FK_OrderGroupNote_OrderGroup]...';


GO
ALTER TABLE [dbo].[OrderGroupNote] DROP CONSTRAINT [FK_OrderGroupNote_OrderGroup];


GO
PRINT N'Dropping [dbo].[FK_ecfVersionProperty_ecfVersion]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] DROP CONSTRAINT [FK_ecfVersionProperty_ecfVersion];


GO
PRINT N'Dropping [dbo].[FK_ecfVersionProperty_MetaClass]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] DROP CONSTRAINT [FK_ecfVersionProperty_MetaClass];


GO
PRINT N'Dropping [dbo].[FK_ecfVersionProperty_MetaField]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] DROP CONSTRAINT [FK_ecfVersionProperty_MetaField];


GO
PRINT N'Dropping [dbo].[PK_ecfVersionProperty]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] DROP CONSTRAINT [PK_ecfVersionProperty];


GO
PRINT N'Dropping [dbo].[CatalogContentProperty_LoadBatch]...';


GO
DROP PROCEDURE [dbo].[CatalogContentProperty_LoadBatch];


GO
PRINT N'Dropping [dbo].[ecfVersion_ListByWorkIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds];


GO
PRINT N'Dropping [dbo].[ecfVersion_SyncCatalogData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncCatalogData];


GO
PRINT N'Dropping [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage];


GO
PRINT N'Dropping [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds];


GO
PRINT N'Dropping [dbo].[ecfVersion_Create]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_Create];


GO
PRINT N'Dropping [dbo].[ecfVersion_DeleteByObjectIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds];


GO
PRINT N'Dropping [dbo].[ecfVersion_SyncEntryData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncEntryData];


GO
PRINT N'Dropping [dbo].[ecfVersion_SyncNodeData]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_SyncNodeData];


GO
PRINT N'Dropping [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds];


GO
PRINT N'Dropping [dbo].[ecfVersionAsset_ListByWorkIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersionAsset_ListByWorkIds];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty_ListByWorkIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersionProperty_ListByWorkIds];


GO
PRINT N'Dropping [dbo].[ecfVersionVariation_ListByWorkIds]...';


GO
DROP PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds];


GO
PRINT N'Dropping [dbo].[ecfVersion_Update]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_Update];


GO
PRINT N'Dropping [dbo].[ecfVersionProperty_Save]...';


GO
DROP PROCEDURE [dbo].[ecfVersionProperty_Save];


GO
PRINT N'Dropping [dbo].[ecfVersionAsset_Save]...';


GO
DROP PROCEDURE [dbo].[ecfVersionAsset_Save];


GO
PRINT N'Dropping [dbo].[ecfVersionCatalog_Save]...';


GO
DROP PROCEDURE [dbo].[ecfVersionCatalog_Save];


GO
PRINT N'Dropping [dbo].[udttCatalogContentPropertyReference]...';


GO
DROP TYPE [dbo].[udttCatalogContentPropertyReference];


GO
PRINT N'Dropping [dbo].[udttObjectWorkId]...';


GO
DROP TYPE [dbo].[udttObjectWorkId];


GO
PRINT N'Dropping [dbo].[udttVersion]...';


GO
DROP TYPE [dbo].[udttVersion];


GO
PRINT N'Dropping [dbo].[udttVersionCatalog]...';


GO
DROP TYPE [dbo].[udttVersionCatalog];


GO
PRINT N'Creating [dbo].[udttCatalogContentPropertyReference]...';


GO
CREATE TYPE [dbo].[udttCatalogContentPropertyReference] AS TABLE (
    [ObjectId]     INT           NOT NULL,
    [ObjectTypeId] INT           NOT NULL,
    [MetaClassId]  INT           NOT NULL,
    [LanguageName] NVARCHAR (50) NOT NULL,
    PRIMARY KEY CLUSTERED ([ObjectId] ASC, [ObjectTypeId] ASC));


GO
PRINT N'Creating [dbo].[udttObjectWorkId]...';


GO
CREATE TYPE [dbo].[udttObjectWorkId] AS TABLE (
    [ObjectId]     INT           NULL,
    [ObjectTypeId] INT           NULL,
    [WorkId]       INT           NULL,
    [LanguageName] NVARCHAR (50) NULL);


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
    [ModifiedBy]         NVARCHAR (100) NULL,
    [Modified]           DATETIME       NULL,
    [SeoUri]             NVARCHAR (255) NULL,
    [SeoTitle]           NVARCHAR (150) NULL,
    [SeoDescription]     NVARCHAR (355) NULL,
    [SeoKeywords]        NVARCHAR (355) NULL,
    [SeoUriSegment]      NVARCHAR (255) NULL);


GO
PRINT N'Creating [dbo].[udttVersionCatalog]...';


GO
CREATE TYPE [dbo].[udttVersionCatalog] AS TABLE (
    [WorkId]          INT            NOT NULL,
    [DefaultCurrency] NVARCHAR (150) NULL,
    [WeightBase]      NVARCHAR (128) NULL,
    [LengthBase]      NVARCHAR (128) NULL,
    [DefaultLanguage] NVARCHAR (50)  NULL,
    [Languages]       NVARCHAR (512) NULL,
    [IsPrimary]       BIT            NULL,
    [Owner]           NVARCHAR (255) NULL);


GO
PRINT N'Altering [dbo].[Catalog]...';


GO
ALTER TABLE [dbo].[Catalog] ALTER COLUMN [DefaultLanguage] NVARCHAR (50) NULL;


GO
PRINT N'Altering [dbo].[ecfVersion]...';


GO
ALTER TABLE [dbo].[ecfVersion] ALTER COLUMN [LanguageName] NVARCHAR (50) NOT NULL;

ALTER TABLE [dbo].[ecfVersion] ALTER COLUMN [MasterLanguageName] NVARCHAR (50) NULL;


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_Indexed_ContentId]...';

GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Indexed_ContentId]
    ON [dbo].[ecfVersion]([ObjectId] ASC, [ObjectTypeId] ASC, [CatalogId] ASC)
    INCLUDE([LanguageName], [Status]);

GO
PRINT N'Creating [dbo].[ecfVersion].[PK_ecfVersionProperty]...';

GO
DROP INDEX [IDX_ecfVersionProperty_ContentID] ON [dbo].[ecfVersionProperty]


GO
ALTER TABLE [dbo].[ecfVersionProperty] ADD  CONSTRAINT [PK_ecfVersionProperty] PRIMARY KEY CLUSTERED 
(
    [WorkId] ASC,
    [MetaFieldId] ASC
)

GO
PRINT N'Recreating clustered index on [dbo].[LineItemDiscount]...';


GO

ALTER TABLE [dbo].[LineItemDiscount] DROP CONSTRAINT [PK_LineItemDiscount]
GO

ALTER TABLE [dbo].[LineItemDiscount] ADD  CONSTRAINT [PK_LineItemDiscount] PRIMARY KEY NONCLUSTERED 
(
    [LineItemDiscountId] ASC
)
GO

CREATE CLUSTERED INDEX [IX_LineItem_OrderGroupId] ON [dbo].[LineItemDiscount]
(
    [OrderGroupId] ASC
)


GO
PRINT N'Recreating clustered index on [dbo].[OrderGroupNote]...';


GO

ALTER TABLE [dbo].[OrderGroupNote] DROP CONSTRAINT [PK_OrderGroupNote]
GO

ALTER TABLE [dbo].[OrderGroupNote] ADD  CONSTRAINT [PK_OrderGroupNote] PRIMARY KEY NONCLUSTERED 
(
    [OrderNoteId] ASC
)
GO

CREATE CLUSTERED INDEX [IX_OrderGroupNote_OrderGroupId] ON [dbo].[OrderGroupNote]
(
    [OrderGroupId] ASC
)

GO
PRINT N'Creating [dbo].[FK_LineItemDiscount_LineItem]...';


GO
ALTER TABLE [dbo].[LineItemDiscount] WITH NOCHECK
    ADD CONSTRAINT [FK_LineItemDiscount_LineItem] FOREIGN KEY ([LineItemId]) REFERENCES [dbo].[LineItem] ([LineItemId]);


GO
PRINT N'Creating [dbo].[FK_OrderGroupNote_OrderGroup]...';


GO
ALTER TABLE [dbo].[OrderGroupNote] WITH NOCHECK
    ADD CONSTRAINT [FK_OrderGroupNote_OrderGroup] FOREIGN KEY ([OrderGroupId]) REFERENCES [dbo].[OrderGroup] ([OrderGroupId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_ecfVersionProperty_ecfVersion]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] WITH NOCHECK
    ADD CONSTRAINT [FK_ecfVersionProperty_ecfVersion] FOREIGN KEY ([WorkId]) REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_ecfVersionProperty_MetaClass]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] WITH NOCHECK
    ADD CONSTRAINT [FK_ecfVersionProperty_MetaClass] FOREIGN KEY ([MetaClassId]) REFERENCES [dbo].[MetaClass] ([MetaClassId]);


GO
PRINT N'Creating [dbo].[FK_ecfVersionProperty_MetaField]...';


GO
ALTER TABLE [dbo].[ecfVersionProperty] WITH NOCHECK
    ADD CONSTRAINT [FK_ecfVersionProperty_MetaField] FOREIGN KEY ([MetaFieldId]) REFERENCES [dbo].[MetaField] ([MetaFieldId]);


GO
PRINT N'Creating [dbo].[CatalogContentProperty_LoadBatch]...';


GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_LoadBatch]
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
			((F.MultiLanguageValue = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))

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
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		INNER JOIN CTE2 ON
			P.ObjectId = CTE2.ObjectId AND
			P.ObjectTypeId = CTE2.ObjectTypeId AND
			P.MetaClassId = CTE2.MetaClassId AND
			((F.MultiLanguageValue = 1 AND P.LanguageName = CTE2.LanguageName COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND P.LanguageName = CTE2.DefaultLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	SELECT *
	FROM dbo.CatalogContentEx Ex 
	INNER JOIN @PropertyReferences R ON Ex.ObjectId = R.ObjectId AND Ex.ObjectTypeId = R.ObjectTypeId
END
GO
PRINT N'Creating [dbo].[ecfVersion_UpdateVersionsMasterLanguage]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_UpdateVersionsMasterLanguage]
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
	FROM	ecfVersion v
	INNER JOIN @temp t ON t.ObjectId = v.ObjectId AND t.ObjectTypeId = v.ObjectTypeId
END
GO
PRINT N'Creating [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
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
PRINT N'Creating [dbo].[ecfVersion_DeleteByObjectIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds]
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
PRINT N'Altering [dbo].[ecfVersion_IsNonPublishedContent]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_IsNonPublishedContent]
(
	@WorkId INT,
    @ObjectId INT,
	@ObjectTypeId INT,
	@LanguageName NVARCHAR(50) = NULL,
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
PRINT N'Altering [dbo].[ecfVersion_SetCommonDraft]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SetCommonDraft]
	@WorkId INT,
	@Force BIT
AS
BEGIN
	DECLARE @LanguageName NVARCHAR(50)
	DECLARE @ObjectId INT
	DECLARE @ObjectTypeId INT

	-- Find the Language, ObjectId, ObjectType for the Content Work ID 
	SELECT @LanguageName = LanguageName, @ObjectId = ObjectId, @ObjectTypeId = ObjectTypeId FROM ecfVersion WHERE WorkId = @WorkId

	-- If @Force = 1, we turn all other drafts to be not common draft, and the @WorkId must be common draft
	-- Else, if there is not any common draft, set @WorkId as common draft
	--			Else, if the common draft is not Published, then exit
	--					Else, we turn all other drafts to be not common draft, and the @WorkId must be common draft

	IF @Force = 1
	BEGIN
		UPDATE ecfVersion SET IsCommonDraft = CASE WHEN WorkId = @WorkId THEN 1 ELSE 0 END FROM ecfVersion
		WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
	END
	ELSE
	BEGIN
		DECLARE @Status INT
		SET @Status = -1
		SELECT @Status = [Status] FROM ecfVersion WHERE @ObjectId = ObjectId AND @ObjectTypeId = ObjectTypeId AND IsCommonDraft = 1 AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
		IF @Status = -1 -- there is no common draft
		BEGIN
			UPDATE ecfVersion SET IsCommonDraft = 1 WHERE WorkId = @WorkId
		END
		ELSE
		BEGIN
			IF @Status = 4 -- Published
			BEGIN
				UPDATE ecfVersion SET IsCommonDraft = CASE WHEN WorkId = @WorkId THEN 1 ELSE 0 END FROM ecfVersion
				WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
			END
		END
	END
END
GO
PRINT N'Creating [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
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
PRINT N'Creating [dbo].[ecfVersionAsset_ListByWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionAsset_ListByWorkIds]
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

	ORDER BY WorkId, SortOrder
END
GO
PRINT N'Creating [dbo].[ecfVersionCatalog_Save]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
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
	;

	IF @PublishAction = 1
	BEGIN
		-- Gets versions which had updated on DefaultLanguage or Languages, that will be used to update versions related to them when publishing a catalog.
		DECLARE @WorkIds TABLE (WorkId INT, DefaultLanguage NVARCHAR(20), Languages NVARCHAR(512))
		INSERT INTO @WorkIds(WorkId, DefaultLanguage, Languages)
		SELECT v.WorkId, v.DefaultLanguage, v.Languages
		FROM @VersionCatalogs v

		DECLARE @NumberVersions INT, @CatalogId INT, @MasterLanguageName NVARCHAR(20), @Languages NVARCHAR(512)
		SELECT @NumberVersions = COUNT(*) FROM @WorkIds

		IF @NumberVersions = 1 -- This is the most regular case, so we can do in different way without cursor so that can gain performance
		BEGIN
			DECLARE @WorkId INT
			
			SELECT TOP 1 @WorkId = WorkId, @MasterLanguageName = DefaultLanguage, @Languages = Languages FROM @WorkIds
			SELECT @CatalogId = ObjectId FROM ecfVersion WHERE WorkId = @WorkId

			UPDATE d SET 
				d.DefaultLanguage = @MasterLanguageName
			FROM ecfVersionCatalog d
			INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId AND d.DefaultLanguage <> @MasterLanguageName

			UPDATE ecfVersion SET 
				MasterLanguageName = @MasterLanguageName
			WHERE CatalogId = @CatalogId AND MasterLanguageName <> @MasterLanguageName
		END
		ELSE
		BEGIN
			DECLARE @Catalogs udttObjectWorkId

			INSERT INTO @Catalogs(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c 
			INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
			WHERE c.ObjectTypeId = 2
			-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
			
			DECLARE @ObjectIdsTemp TABLE(ObjectId INT)
			DECLARE catalogCursor CURSOR FOR SELECT DISTINCT ObjectId FROM @Catalogs
		
			OPEN catalogCursor  
			FETCH NEXT FROM catalogCursor INTO @CatalogId
		
			WHILE @@FETCH_STATUS = 0  
			BEGIN
				SELECT @MasterLanguageName = v.DefaultLanguage
				FROM @VersionCatalogs v
				INNER JOIN @Catalogs c ON c.WorkId = v.WorkId
				WHERE c.ObjectId = @CatalogId
						
				-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
				UPDATE d SET 
					d.DefaultLanguage = @MasterLanguageName
				FROM ecfVersionCatalog d
				INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
				WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId AND d.DefaultLanguage <> @MasterLanguageName
			
				-- and also update MasterLanguageName of contents that's related to Catalog
				-- catalogs
				UPDATE ecfVersion SET 
					MasterLanguageName = @MasterLanguageName
				WHERE CatalogId = @CatalogId AND MasterLanguageName <> @MasterLanguageName
				
				FETCH NEXT FROM catalogCursor INTO @CatalogId
			END
		
			CLOSE catalogCursor  
			DEALLOCATE catalogCursor;  
		END
	END
END
GO
PRINT N'Creating [dbo].[ecfVersionProperty_ListByWorkIds]...';


GO
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
	SELECT draftProperty.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
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
	SELECT draftProperty.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
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
PRINT N'Creating [dbo].[ecfVersionVariation_ListByWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	
	-- master language version should load variation info directly from ecfVersionVariation table
	SELECT
		va.WorkId,
		va.TaxCategoryId,
		va.TrackInventory,
		va.[Weight],
		va.MinQuantity,
		va.MaxQuantity,
		va.[Length],
		va.Height,
		va.Width,
		va.PackageId 
	FROM ecfVersionVariation va
	INNER JOIN @ContentLinks links ON va.WorkId = links.WorkId
	INNER JOIN ecfVersion ve ON ve.WorkId = links.WorkId
	WHERE ve.LanguageName = ve.MasterLanguageName COLLATE DATABASE_DEFAULT

	UNION ALL

	-- non-master language version should fall-back to published-master content
	SELECT 
		v.WorkId,
		va.TaxCategoryId,
		va.TrackInventory,
		va.[Weight],
		va.MinQuantity,
		va.MaxQuantity,
		va.[Length],
		va.Height,
		va.Width,
		va.PackageId  
	FROM Variation AS va
	INNER JOIN @ContentLinks links ON va.CatalogEntryId = links.ObjectId AND links.ObjectTypeId = 0
	INNER JOIN ecfVersion v ON v.WorkId = links.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId
	
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
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
				LongString,
				[Guid])
			SELECT
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
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
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			SELECT
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
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
				WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;
END
GO
PRINT N'Creating [dbo].[ecfVersionAsset_Save]...';


GO
CREATE PROCEDURE [dbo].[ecfVersionAsset_Save]
	@WorkIds dbo.[udttObjectWorkId] readonly,
	@ContentDraftAsset dbo.[udttCatalogContentAsset] readonly
AS
BEGIN
	DELETE A
	FROM ecfVersionAsset A
	INNER JOIN @WorkIds W on W.WorkId = A.WorkId

	INSERT INTO ecfVersionAsset 
	SELECT * FROM @ContentDraftAsset
END
GO
PRINT N'Creating [dbo].[ecf_Search_Payment]...';


GO
CREATE PROCEDURE [dbo].[ecf_Search_Payment]
    @results udttOrderGroupId readonly
AS
BEGIN

DECLARE @search_condition nvarchar(max)

-- Return Order Form Payment Collection

CREATE TABLE #OrderSearchResults (PaymentId int)
insert into #OrderSearchResults (PaymentId) select PaymentId from OrderFormPayment P INNER JOIN @results R ON R.OrderGroupId = P.OrderGroupId

SET @search_condition = N'''INNER JOIN OrderFormPayment O ON O.PaymentId = T.ObjectId INNER JOIN #OrderSearchResults R ON O.PaymentId = R.PaymentId '''

DECLARE @parentmetaclassid int
DECLARE @rowNum int
DECLARE @maxrows int
DECLARE @tablename nvarchar(120)
DECLARE @procedurefull nvarchar(max)

SET @parentmetaclassid = (SELECT MetaClassId from [MetaClass] WHERE Name = N'orderformpayment' and TableName = N'orderformpayment')

DECLARE @PaymentClasses TABLE
(
  query nvarchar(max),
  RowIndex int
)

INSERT INTO @PaymentClasses 
SELECT query = N'mdpsp_avto_' + TableName + N'_Search NULL, ' + N'''''''' + TableName + N''''''+  ' TableName, [O].*'' ,'  + @search_condition,
ROW_NUMBER() OVER (ORDER BY MetaClassId)
FROM [MetaClass] 
WHERE ParentClassId = @parentmetaclassid

SET @rowNum = 1
SET @maxrows = (SELECT COUNT(RowIndex) FROM @PaymentClasses)

WHILE @rowNum <= @maxrows
BEGIN 
	SELECT @procedurefull = query FROM @PaymentClasses WHERE RowIndex = @rowNum
	EXEC (@procedurefull)
	SET @rowNum = @rowNum + 1
END


DROP TABLE #OrderSearchResults

END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_Save]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_Save]
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
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
			LongString,
			[Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
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
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
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

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
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
PRINT N'Creating [dbo].[ecfVersion_ListByWorkIds]...';


GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.ContentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId 
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND draft.ObjectId = e.CatalogEntryId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId AND draft.ObjectId = n.CatalogNodeId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = n.MetaClassId
											AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
											AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 1 -- node

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
	WHERE r.IsPrimary = 1 AND [dbo].ecf_IsCurrentLanguageRemoved(v.CatalogId, v.LanguageName) = 0 
END
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
				  c.EndDate
			FROM @ContentDraft d
			INNER JOIN dbo.Catalog c on d.ObjectId = c.CatalogId)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, [MasterLanguageName], IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish)
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
			target.StopPublish = SOURCE.StopPublish
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, StopPublish)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified, SOURCE.StopPublish)
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
PRINT N'Altering [dbo].[ecfVersion_PublishContentVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_PublishContentVersion]
	@WorkId			INT,
	@ObjectId		INT,
	@ObjectTypeId	INT,
	@LanguageName	NVARCHAR(50),
	@MaxVersions	INT,
	@ResetCommonDraft BIT = 1
AS
BEGIN
	-- Update old published version status to previously published
	UPDATE	ecfVersion
	SET		[Status] = 5, -- previously published = 5
	        IsCommonDraft = 0		
	WHERE	[Status] = 4 -- published = 4
			AND ObjectId = @ObjectId
			AND ObjectTypeId = @ObjectTypeId
			AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
			AND WorkId != @WorkId

	-- Update is common draft
	IF @ResetCommonDraft = 1
		EXEC ecfVersion_SetCommonDraft @WorkId = @WorkId, @Force = 1

	-- Delete previously published version. The number of previous published version must be <= maxVersions.
	-- This only take effect by language
	CREATE TABLE #WorkIds(Id INT IDENTITY(1,1) NOT NULL, WorkId INT NOT NULL)
	INSERT INTO #WorkIds(WorkId)
	SELECT WorkId
	FROM ecfVersion
	WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND [Status] = 5 AND LanguageName = @LanguageName COLLATE DATABASE_DEFAULT
	ORDER BY WorkId DESC
	
	-- Delete all previously published version that older than @MaxVersions of this content
	DELETE FROM ecfVersion
	WHERE WorkId IN (SELECT WorkId 
					 FROM  #WorkIds 
					 WHERE Id > @MaxVersions - 1)
	
	DROP TABLE #WorkIds
END
GO
PRINT N'Altering [dbo].[ecfVersion_Save]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_Save]
	@WorkId int,
	@ObjectId int,
	@ObjectTypeId int,
	@CatalogId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](50),
	@MasterLanguageName [nvarchar](50),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status INT,
	@CreatedBy [nvarchar](100),
	@Created DATETIME,
	@ModifiedBy [nvarchar](100),
	@Modified DATETIME,
	@SeoUri nvarchar(255),
	@SeoTitle nvarchar(150),
	@SeoDescription nvarchar(355),
	@SeoKeywords nvarchar(355),
	@SeoUriSegment nvarchar(255),
	@MaxVersions INT = 20
AS
BEGIN
	-- Code and name are not culture specific, we need to copy them from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name, Code = @Code WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
	END

	UPDATE ecfVersion
	SET ObjectId = @ObjectId,
		Code = @Code,
		Name = @Name,
		ObjectTypeId = @ObjectTypeId,
		CatalogId = @CatalogId,
		LanguageName = @LanguageName,
		MasterLanguageName = @MasterLanguageName,
		StartPublish = @StartPublish,
		StopPublish = @StopPublish,
		[Status] = @Status,
		CreatedBy = @CreatedBy,
	    Created = @Created,
		Modified = @Modified,
		ModifiedBy = @ModifiedBy,
		SeoUri = @SeoUri,
		SeoTitle = @SeoTitle,
		SeoDescription = @SeoDescription,
		SeoKeywords = @SeoKeywords,
		SeoUriSegment = @SeoUriSegment
	WHERE WorkId = @WorkId

	IF (@Status = 4)
	BEGIN
		EXEC ecfVersion_PublishContentVersion @WorkId, @ObjectId, @ObjectTypeId, @LanguageName, @MaxVersions
	END
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
PRINT N'Altering [dbo].[ecf_Load_OrderGroup]...';


GO
ALTER PROCEDURE [dbo].[ecf_Load_OrderGroup]
    @OrderGroupId int
AS
BEGIN

DECLARE @search_condition nvarchar(max)

-- Return GroupIds.
SELECT @OrderGroupId AS [OrderGroupId]

-- Prevent any queries if order group doesn't exist
IF NOT EXISTS(SELECT OrderGroupId from OrderGroup G WHERE G.OrderGroupId = @OrderGroupId)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderForm' TableName, OE.*, O.*
	FROM [OrderFormEx] OE 
		INNER JOIN OrderForm O ON O.OrderFormId = OE.ObjectId 
		WHERE O.OrderGroupId = @OrderGroupId

if(@@ROWCOUNT = 0)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderGroupAddress' TableName, OE.*, O.*
	FROM [OrderGroupAddressEx] OE 
		INNER JOIN OrderGroupAddress O ON O.OrderGroupAddressId = OE.ObjectId  
		WHERE O.OrderGroupId = @OrderGroupId

-- Return Shipment Collection
SELECT 'Shipment' TableName, SE.*, S.*
	FROM [ShipmentEx] SE 
		INNER JOIN Shipment S ON S.ShipmentId = SE.ObjectId 
		WHERE S.OrderGroupId = @OrderGroupId

-- Return Line Item Collection
SELECT 'LineItem' TableName, LE.*, L.*
	FROM [LineItemEx] LE 
		INNER JOIN LineItem L ON L.LineItemId = LE.ObjectId 
		WHERE L.OrderGroupId = @OrderGroupId

-- Return Order Form Payment Collection
DECLARE @ids udttOrderGroupId
INSERT INTO @ids VALUES(@OrderGroupId)
EXEC dbo.ecf_Search_Payment @ids

-- Return Order Form Discount Collection
SELECT 'OrderFormDiscount' TableName, D.* 
	FROM [OrderFormDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId

-- Return Line Item Discount Collection
SELECT 'LineItemDiscount' TableName, D.* 
	FROM [LineItemDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId

-- Return Shipment Discount Collection
SELECT 'ShipmentDiscount' TableName, D.* 
	FROM [ShipmentDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId
		
-- Return OrderGroupNote Collection
SELECT 'OrderGroupNote' TableName, 
		G.OrderNoteId, 
		G.CustomerId, 
		G.Created, 
		G.OrderGroupId, 
		G.Detail,
		G.LineItemId,
		G.Title,
		G.Type 
	FROM [OrderGroupNote] G
		WHERE G.OrderGroupId = @OrderGroupId

DECLARE @OrderGroupIds as udttOrderGroupId
INSERT INTO @OrderGroupIds(OrderGroupId) VALUES(@OrderGroupId)

EXEC dbo.PromotionInformationLoad @OrderGroupIds

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END
GO
PRINT N'Altering [dbo].[ecf_Search_OrderGroup]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_OrderGroup]
    @results udttOrderGroupId readonly
AS
BEGIN

-- Return GroupIds.
SELECT [OrderGroupId] FROM @results


-- Prevent any queries if order group doesn't exist
IF NOT EXISTS(SELECT * from OrderGroup G INNER JOIN @results R ON G.OrderGroupId = R.OrderGroupId)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderForm' TableName, OE.*, O.*
	FROM [OrderFormEx] OE 
		INNER JOIN OrderForm O ON O.OrderFormId = OE.ObjectId 
		INNER JOIN @results R ON O.OrderGroupId = R.OrderGroupId 

if(@@ROWCOUNT = 0)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderGroupAddress' TableName, OE.*, O.*
	FROM [OrderGroupAddressEx] OE 
		INNER JOIN OrderGroupAddress O ON O.OrderGroupAddressId = OE.ObjectId  
		INNER JOIN @results R ON O.OrderGroupId = R.OrderGroupId 

-- Return Shipment Collection
SELECT 'Shipment' TableName, SE.*, S.*
	FROM [ShipmentEx] SE 
		INNER JOIN Shipment S ON S.ShipmentId = SE.ObjectId 
		INNER JOIN @results R ON S.OrderGroupId = R.OrderGroupId 

-- Return Line Item Collection
SELECT 'LineItem' TableName, LE.*, L.*
	FROM [LineItemEx] LE 
		INNER JOIN LineItem L ON L.LineItemId = LE.ObjectId 
		INNER JOIN @results R ON L.OrderGroupId = R.OrderGroupId 

-- Return Order Form Payment Collection
EXEC dbo.ecf_Search_Payment @results

-- Return Order Form Discount Collection
SELECT 'OrderFormDiscount' TableName, D.* 
	FROM [OrderFormDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 

-- Return Line Item Discount Collection
SELECT 'LineItemDiscount' TableName, D.* 
	FROM [LineItemDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 

-- Return Shipment Discount Collection
SELECT 'ShipmentDiscount' TableName, D.* 
	FROM [ShipmentDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 
		
-- Return OrderGroupNote Collection
SELECT 'OrderGroupNote' TableName, 
		G.OrderNoteId, 
		G.CustomerId, 
		G.Created, 
		G.OrderGroupId, 
		G.Detail,
		G.LineItemId,
		G.Title,
		G.Type 
	FROM [OrderGroupNote] G INNER JOIN @results R ON G.OrderGroupId = R.OrderGroupId

EXEC dbo.PromotionInformationLoad @results

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

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
	@ModifiedBy [nvarchar](100),
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
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog_Update]';


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
PRINT N'Refreshing [dbo].[mdpsp_sys_GetMetaKey]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByWorkId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByWorkId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_List]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByContentId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByContentId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListDelayedPublish]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListDelayedPublish]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListMatchingSegments]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListMatchingSegments]';


GO
PRINT N'Refreshing [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionProperty_SyncBatchPublishedVersion]';


GO
PRINT N'Refreshing [dbo].[ecfVersionProperty_SyncPublishedVersion]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionProperty_SyncPublishedVersion]';


GO
PRINT N'Refreshing [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]';


GO
PRINT N'Refreshing [dbo].[ecf_LineItem_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItem_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_LineItemDiscount_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItemDiscount_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_LineItemDiscount_Insert]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItemDiscount_Insert]';


GO
PRINT N'Refreshing [dbo].[ecf_LineItemDiscount_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItemDiscount_Update]';


GO
PRINT N'Refreshing [dbo].[ecf_OrderForm_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderForm_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_OrderGroup_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderGroup_Delete]';


GO
PRINT N'Refreshing [dbo].[mc_OrderGroupNoteDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mc_OrderGroupNoteDelete]';


GO
PRINT N'Refreshing [dbo].[mc_OrderGroupNotesUpdate]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mc_OrderGroupNotesUpdate]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_PaymentPlan_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_PaymentPlan_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_PurchaseOrder_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_PurchaseOrder_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_ShoppingCart_OrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_ShoppingCart_OrderGroupId]';


GO
PRINT N'Refreshing [dbo].[ecf_GetMostRecentOrder]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GetMostRecentOrder]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PaymentPlan_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PaymentPlan_CustomerAndName]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_PurchaseOrder_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_PurchaseOrder_CustomerAndName]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart_Customer]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart_Customer]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_ShoppingCart_CustomerAndName]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_ShoppingCart_CustomerAndName]';


GO

GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Index_Automatic_Rebuild]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_Index_Automatic_Rebuild] 
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 10, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
