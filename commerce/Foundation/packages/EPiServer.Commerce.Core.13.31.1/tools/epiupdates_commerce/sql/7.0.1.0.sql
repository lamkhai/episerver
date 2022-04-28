--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
	BEGIN 
	declare @major int = 7, @minor int = 0, @patch int = 1
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
		select 0,'Already correct database version' 
	ELSE 
		select 1, 'Upgrading database' 
	END 
ELSE 
	select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- Drop column SerializedData in CatalogEntry
IF EXISTS(SELECT * FROM sys.columns 
            WHERE Name = N'SerializedData' AND Object_ID = Object_ID(N'CatalogEntry'))
BEGIN
	ALTER TABLE [dbo].[CatalogEntry]
	DROP COLUMN SerializedData
END
GO

-- Add WorkId column to MetaKey table
IF NOT EXISTS(SELECT * FROM sys.columns 
            WHERE Name = N'WorkId' AND Object_ID = Object_ID(N'MetaKey'))
BEGIN
	ALTER TABLE [dbo].[MetaKey]
	ADD WorkId INT NULL
END
GO

-- create ecfVersion table
CREATE TABLE [dbo].[ecfVersion](
	[WorkId] [int] Identity(1,1),
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] INT NOT NULL, 
	[Name] [nvarchar](100) NULL,
	[Code] [nvarchar](100) NULL,
	[LanguageName] [nvarchar](20) NOT NULL,
	[MasterLanguageName] [nvarchar](20) NULL,
	[CurrentLanguageRemoved] [bit] NOT NULL DEFAULT 0,
	[IsCommonDraft] [bit] NOT NULL DEFAULT 0,
	[StartPublish] [datetime] NULL,
	[StopPublish] DATETIME NULL, 
	[Status] [int] NULL,
	[CreatedBy] [nvarchar](256) NOT NULL,
	[Created] [datetime] NOT NULL,
	[ModifiedBy] [nvarchar](256) NULL,
	[Modified] [datetime] NULL,
	[SeoUri] nvarchar(255) NULL,
	[SeoTitle] nvarchar(150) NULL,
	[SeoDescription] nvarchar(355) NULL,
	[SeoKeywords] nvarchar(355) NULL,
	[SeoUriSegment] nvarchar(255) NULL,
	CONSTRAINT [PK_ecfVersion] PRIMARY KEY CLUSTERED 
(
	[WorkId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)

GO

CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Indexed_ContentId] ON [dbo].[ecfVersion]
(
	[ObjectId] ASC,
	[ObjectTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO

CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Indexed_SeoUriSegment] ON [dbo].[ecfVersion]
(
	[SeoUriSegment] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO
-- end of creating ecfVersion table

-- create CatalogContentEx table
CREATE TABLE [dbo].[CatalogContentEx](
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] [int] NOT NULL,
	[CreatedBy] [nvarchar](256) NULL,
	[Created] [datetime] NULL,
	[ModifiedBy] [nvarchar](256) NULL,
	[Modified] [datetime] NULL,
	PRIMARY KEY ([ObjectId], [ObjectTypeId])
)

GO

CREATE NONCLUSTERED INDEX [IDX_CatalogContentEx_Indexed_Ids] ON [dbo].[CatalogContentEx]
(
	[ObjectId] ASC,
	[ObjectTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO
-- end of creating CatalogContentEx table

-- create CatalogContentProperty table
CREATE TABLE [dbo].[CatalogContentProperty](
	[pkId] [bigint] IDENTITY(1,1) NOT NULL,
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] INT NOT NULL, 
	[MetaFieldId] [int] NOT NULL,
	[MetaClassId] int NOT NULL,
	[MetaFieldName] [nvarchar](255) NULL,
	[LanguageName] nvarchar(50) NULL,
	[Boolean] [bit] NULL,
	[Number] [int] NULL,
	[FloatNumber] [float] NULL,
	[Money] [money] NULL,
	[Date] [datetime] NULL,
	[Binary] [varbinary](max) NULL,
	[String] [nvarchar](450) NULL,
	[LongString] [nvarchar](max) NULL,
	[Guid] [uniqueidentifier] NULL,
 CONSTRAINT [PK_CatalogContentProperty] PRIMARY KEY NONCLUSTERED 
(
	[pkId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)

GO

ALTER TABLE [dbo].[CatalogContentProperty] ADD  CONSTRAINT [FK_CatalogContentProperty_MetaField] FOREIGN KEY([MetaFieldId])
REFERENCES [dbo].[MetaField] ([MetaFieldId])
GO

ALTER TABLE [dbo].[CatalogContentProperty] CHECK CONSTRAINT [FK_CatalogContentProperty_MetaField]
GO

ALTER TABLE [dbo].[CatalogContentProperty] ADD  CONSTRAINT [FK_CatalogContentProperty_MetaClass] FOREIGN KEY([MetaClassId])
REFERENCES [dbo].[MetaClass] ([MetaClassId])
GO

ALTER TABLE [dbo].[CatalogContentProperty] CHECK CONSTRAINT [FK_CatalogContentProperty_MetaClass]
GO

CREATE NONCLUSTERED INDEX [IDX_CatalogContentProperty_MetaFieldId] ON [dbo].[CatalogContentProperty]
(
	[MetaFieldId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

CREATE CLUSTERED INDEX [IDX_CatalogContentProperty_ContentID] ON [dbo].[CatalogContentProperty]
(
	[ObjectId] ASC,
	[ObjectTypeId] ASC,
	[LanguageName] ASC,
	[MetaFieldId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO
-- end of creating CatalogContentProperty table

-- create ecfVersionCatalog table
CREATE TABLE [dbo].[ecfVersionCatalog] (
    [WorkId]			INT				 NOT NULL,
    [DefaultCurrency]	NVARCHAR(150)		 NULL,
    [WeightBase]		NVARCHAR(128)        NULL,
    [LengthBase]		NVARCHAR(128)        NULL,
	[DefaultLanguage]	NVARCHAR (20)        NULL,
	[Languages]			NVARCHAR (512)       NULL,
    [IsPrimary]		    BIT				 NOT NULL,
    [UriSegment]		NVARCHAR(255)		 NULL,
    [Owner]			    NVARCHAR(255)		 NULL,
    CONSTRAINT [PK_ecfVersionCatalog] PRIMARY KEY CLUSTERED ([WorkId] ASC),
    CONSTRAINT [FK_Catalog_ecfVersion] FOREIGN KEY ([WorkId]) REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE
);
GO
-- end of creating ecfVersionCatalog table

-- create ecfVersionProperty table
CREATE TABLE [dbo].[ecfVersionProperty](
	[pkId] [bigint] IDENTITY(1,1) NOT NULL,	
	[WorkId] [int] NOT NULL,
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] [int] NOT NULL,
	[MetaFieldId] [int] NOT NULL,
	[MetaClassId] int NOT NULL,
	[MetaFieldName] [nvarchar](255) NULL,
	[LanguageName] nvarchar(50) NULL,
	[Boolean] [bit] NULL,
	[Number] [int] NULL,
	[FloatNumber] [float] NULL,
	[Money] [money] NULL,
	[Date] [datetime] NULL,
	[Binary] [varbinary](max) NULL,
	[String] [nvarchar](450) NULL,
	[LongString] [nvarchar](max) NULL,
	[Guid] [uniqueidentifier] NULL,
 CONSTRAINT [PK_ecfVersionProperty] PRIMARY KEY NONCLUSTERED 
(
	[pkId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)

GO

ALTER TABLE [dbo].[ecfVersionProperty] ADD  CONSTRAINT [FK_ecfVersionProperty_ecfVersion] FOREIGN KEY([WorkId])
REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE
GO

ALTER TABLE [dbo].[ecfVersionProperty] ADD  CONSTRAINT [FK_ecfVersionProperty_MetaField] FOREIGN KEY([MetaFieldId])
REFERENCES [dbo].[MetaField] ([MetaFieldId])
GO

ALTER TABLE [dbo].[ecfVersionProperty] CHECK CONSTRAINT [FK_ecfVersionProperty_MetaField]
GO

ALTER TABLE [dbo].[ecfVersionProperty] ADD  CONSTRAINT [FK_ecfVersionProperty_MetaClass] FOREIGN KEY([MetaClassId])
REFERENCES [dbo].[MetaClass] ([MetaClassId])
GO

ALTER TABLE [dbo].[ecfVersionProperty] CHECK CONSTRAINT [FK_ecfVersionProperty_MetaClass]
GO

CREATE NONCLUSTERED INDEX [IDX_ecfVersionProperty_MetaFieldId] ON [dbo].[ecfVersionProperty]
(
	[MetaFieldId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

CREATE UNIQUE CLUSTERED INDEX [IDX_ecfVersionProperty_ContentID] ON [dbo].[ecfVersionProperty]
(
	[WorkId],
	[MetaFieldId]
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO
-- end of creating ecfVersionProperty table

-- create udttCatalogContentEx type
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttCatalogContentEx') DROP TYPE [dbo].[udttCatalogContentEx]
GO
CREATE TYPE [dbo].[udttCatalogContentEx] AS TABLE(
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] [int] NOT NULL,
	[CreatedBy] [nvarchar](256) NULL,
	[Created] [datetime] NULL,
	[ModifiedBy] [nvarchar](256) NULL,
	[Modified] [datetime] NULL
)
GO
-- end of creating udttCatalogContentEx type

-- create udttCatalogContentProperty type
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttCatalogContentProperty') DROP TYPE [dbo].[udttCatalogContentProperty]
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
	[FloatNumber] [float] NULL,
	[Money] [money] NULL,
	[Date] [datetime] NULL,
	[Binary] [varbinary](max) NULL,
	[String] [nvarchar](450) NULL,
	[LongString] [nvarchar](max) NULL,
	[Guid] [uniqueidentifier] NULL,
	UNIQUE CLUSTERED ([ObjectId], [ObjectTypeId], [WorkId], [MetaFieldId], [LanguageName])
)
GO
-- end of creating udttCatalogContentProperty type

-- create function mdpfn_sys_IsCatalogMetaDataTable
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'mdpfn_sys_IsCatalogMetaDataTable' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaDataTable]
GO
CREATE FUNCTION [dbo].[mdpfn_sys_IsCatalogMetaDataTable]
(
	@tableName nvarchar(256)
)
RETURNS BIT
AS
BEGIN
    DECLARE @RetVal BIT

	IF @tableName LIKE 'CatalogEntryEx%' OR @tableName LIKE 'CatalogNodeEx%'
		SET @RetVal = 1
	ELSE
		SET @RetVal = 0

	RETURN @RetVal;
END
GO
-- end of creating function mdpfn_sys_IsCatalogMetaDataTable

-- create SP ecfVersion_DeleteByWorkId
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByWorkId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_DeleteByWorkId] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_DeleteByWorkId]
	@WorkId int
AS
BEGIN
	DELETE FROM ecfVersion
	WHERE WorkId = @WorkId
END
GO
-- end of creating SP ecfVersion_DeleteByWorkId

-- create SP ecfVersion_SetCommonDraft
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SetCommonDraft]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_SetCommonDraft] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_SetCommonDraft]
	@WorkId INT,
	@Force BIT
AS
BEGIN
	DECLARE @LanguageName NVARCHAR(20)
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
-- end of creating SP ecfVersion_SetCommonDraft

-- create SP ecfVersion_List
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_List] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_List]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN
	IF @ObjectTypeId = 1 -- Node, join to CatalogNode table to get additional columns
		SELECT vn.*, n.CatalogId, n.ApplicationId, n.ContentGuid, NULL as ClassTypeId, n.MetaClassId, n.ParentNodeId as ParentId
		FROM dbo.ecfVersion vn
		INNER JOIN CatalogNode n ON vn.ObjectId = n.CatalogNodeId
		WHERE vn.ObjectId = @ObjectId AND vn.ObjectTypeId = 1 AND CurrentLanguageRemoved = 0

	ELSE IF @ObjectTypeId = 2 -- Catalog, join to Catalog table to additional columns
		SELECT vc.*, c.CatalogId, c.ApplicationId, c.ContentGuid, NULL as ClassTypeId, NULL as MetaClassId, NULL AS ParentId
		FROM dbo.ecfVersion vc
		INNER JOIN Catalog c ON vc.ObjectId = c.CatalogId
		WHERE ObjectId = @ObjectId AND vc.ObjectTypeId = 2 AND CurrentLanguageRemoved = 0

	ELSE -- Entry, join to CatalogEntry table to get additional columns
		SELECT ve.*, e.CatalogId, e.ApplicationId, e.ContentGuid, e.ClassTypeId, e.MetaClassId, NULL AS ParentId
		FROM dbo.ecfVersion ve
		INNER JOIN CatalogEntry e ON ve.ObjectId = e.CatalogEntryId
		WHERE ObjectId = @ObjectId AND ve.ObjectTypeId = 0 AND CurrentLanguageRemoved = 0
END
GO
-- end of creating SP ecfVersion_List

-- create type udttIdTable
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttIdTable') DROP TYPE [dbo].[udttIdTable]
GO
CREATE TYPE [dbo].[udttIdTable] AS TABLE(
	[ID] [int] NOT NULL
)
GO
-- end of creating type udttIdTable

-- create type udttObjectWorkId
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttObjectWorkId') DROP TYPE [dbo].[udttObjectWorkId]
GO
CREATE TYPE [dbo].[udttObjectWorkId] AS TABLE(
	[ObjectId] [int] NULL,
	[ObjectTypeId] [int] NULL,
	[WorkId] [int] NULL,
	[LanguageName] nvarchar(20) NULL
)
GO
-- end of creating type udttObjectWorkId

-- create SP CatalogNode_FindParentId
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogNode_FindParentId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogNode_FindParentId] 
GO
CREATE PROCEDURE [dbo].[CatalogNode_FindParentId]
	@NodeIds	[dbo].[udttIdTable] READONLY
AS
BEGIN
	SELECT n.CatalogNodeId, n.ParentNodeId FROM CatalogNode n INNER JOIN @NodeIds i ON n.CatalogNodeId = i.ID
END
GO
-- end of creating SP CatalogNode_FindParentId

-- create SP ecfVersion_ListDelayedPublish
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListDelayedPublish]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_ListDelayedPublish] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_ListDelayedPublish]
	@UntilDate	DATETIME,
	@ObjectId INT = NULL,
	@ObjectTypeId INT = NULL
AS
BEGIN
	SET NOCOUNT ON

	SELECT	ObjectId, 
			ObjectTypeId, 
			WorkId
	FROM ecfVersion 
	WHERE
		[Status] = 6 
		AND CurrentLanguageRemoved = 0
		AND StartPublish <= @UntilDate
		AND ((ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId) OR @ObjectId IS NULL)		
	ORDER BY
		StartPublish
END
GO
-- end of creating SP ecfVersion_ListDelayedPublish

-- create ecfVersion_ListByWorkIds SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*, e.CatalogId, e.ApplicationId, e.contentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId  AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.CatalogId, c.ApplicationId, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.CatalogId, n.ApplicationId, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN CatalogNode n ON links.ObjectId = n.CatalogNodeId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId 
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE CurrentLanguageRemoved = 0 AND links.ObjectTypeId = 1 -- node
	
	EXEC [ecfVersionProperty_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionAsset_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionVariation_ListByWorkIds] @ContentLinks

	EXEC [ecfVersionCatalog_ListByWorkIds] @ContentLinks

	--get relations for entry versions
	SELECT TOP 1 r.CatalogEntryId, r.CatalogNodeId, r.CatalogId
	FROM NodeEntryRelation r
	INNER JOIN CatalogNode n ON r.CatalogNodeId = n.CatalogNodeId
	INNER JOIN dbo.ecfVersion v ON v.ObjectTypeId = 0 AND v.CurrentLanguageRemoved = 0 AND v.ObjectId = r.CatalogEntryId AND r.CatalogId = n.CatalogId
	INNER JOIN @ContentLinks l ON l.WorkId = v.WorkId
END
GO
-- end of creating ecfVersion_ListByWorkIds SP

-- create udttVariantDraft type
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttVariantDraft') DROP TYPE [dbo].[udttVariantDraft]
GO
CREATE TYPE [dbo].[udttVariantDraft] AS TABLE(
	[WorkId]	INT				 NOT NULL,
    [TaxCategoryId]  INT              NULL,
    [TrackInventory] BIT              NULL,
    [Weight]         FLOAT (53)       NULL,
    [MinQuantity]    DECIMAL (38, 9)            NULL,
    [MaxQuantity]    DECIMAL (38, 9)            NULL,
    [Length]         FLOAT (53)       NULL,
    [Height]         FLOAT (53)       NULL,
    [Width]          FLOAT (53)       NULL,
	[PackageId]		 INT			  NULL
)
GO
-- end creating udttVariantDraft type

-- create udttVersionCatalog type
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
    [UriSegment]		NVARCHAR(255)		 NULL,
    [Owner]			    NVARCHAR(255)		 NULL
)
GO
-- end creating udttVersionCatalog type

-- create ecfVersionVariation table
CREATE TABLE [dbo].[ecfVersionVariation] (
	[WorkId]	INT				 NOT NULL,
    [TaxCategoryId]  INT              NULL,
    [TrackInventory] BIT              NULL,
    [Weight]         FLOAT (53)       NULL,
    [MinQuantity]    DECIMAL (38, 9)            NULL,
    [MaxQuantity]    DECIMAL (38, 9)            NULL,
    [Length]         FLOAT (53)       NULL,
    [Height]         FLOAT (53)       NULL,
    [Width]          FLOAT (53)       NULL,
	[PackageId]		 INT			  NULL,
    CONSTRAINT [PK_VariationContent] PRIMARY KEY CLUSTERED ([WorkId] ASC),
    CONSTRAINT [FK_Variation_ecfVersion] FOREIGN KEY ([WorkId]) REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE
);
-- end of creating ecfVersionVariation

-- create stored procedure ecfVersionVariation_ListByWorkIds
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionVariation_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds] 
GO
CREATE PROCEDURE [dbo].[ecfVersionVariation_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT v.* FROM ecfVersionVariation v
	INNER JOIN @ContentLinks links
	ON v.WorkId = links.WorkId
END
GO
-- end of creating stored procedure ecfVersionVariation_ListByWorkIds

-- create stored procedure ecfVersionVariation_Save
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionVariation_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionVariation_Save] 
GO
CREATE PROCEDURE [dbo].[ecfVersionVariation_Save]
	@Variants dbo.[udttVariantDraft] readonly
AS
BEGIN
	MERGE dbo.ecfVersionVariation AS target
	USING @Variants as source
	On (target.WorkId = source.WorkId)
	WHEN MATCHED THEN 
		UPDATE SET 
			TaxCategoryId = source.TaxCategoryId, 
			TrackInventory = source.TrackInventory,
			[Weight] = source.[Weight], 
			MinQuantity = source.MinQuantity, 
			MaxQuantity = source.MaxQuantity,
			[Length] = source.[Length], 
			Height = source.Height, 
			Width = source.Width,
			PackageId = source.PackageId
	WHEN NOT MATCHED THEN
		INSERT (WorkId, TaxCategoryId, TrackInventory, [Weight], MinQuantity, MaxQuantity, [Length], Height, Width, PackageId)
		VALUES (source.WorkId, source.TaxCategoryId, source.TrackInventory, source.[Weight], source.MinQuantity, source.MaxQuantity, source.[Length], source.Height, source.Width, source.PackageId);
END
GO
-- end of creating stored procedure ecfVersionVariation_Save

-- create ecfVersionAsset table
CREATE TABLE [dbo].[ecfVersionAsset](
	[pkId] [bigint] Identity(1,1),
	[WorkId] INT NOT NULL,
	[AssetType] nvarchar(190) NOT NULL,
	[AssetKey] nvarchar(254) NOT NULL,
	[GroupName] nvarchar(100) NULL,
	[SortOrder] [int] NOT NULL,

 CONSTRAINT [PK_ecfVersionAsset] PRIMARY KEY NONCLUSTERED 
(
	[pkId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)

GO

ALTER TABLE [dbo].[ecfVersionAsset] ADD  CONSTRAINT [FK_ecfVersionAsset_ecfVersion] FOREIGN KEY([WorkId])
REFERENCES [dbo].[ecfVersion] ([WorkId]) ON DELETE CASCADE ON UPDATE CASCADE
GO

CREATE NONCLUSTERED INDEX [IDX_ecfVersionAsset_WorkId] ON [dbo].[ecfVersionAsset]
(
	[WorkId]
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

CREATE UNIQUE CLUSTERED INDEX [IDX_ecfVersionAsset_ContentID] ON [dbo].[ecfVersionAsset]
(
	[WorkId],
	[AssetType],
	[AssetKey]
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO
-- end of creating ecfVersionAsset table

-- create udttCatalogContentAsset type and SP ecfVersionAsset_Save
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionAsset_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionAsset_Save] 
GO
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttCatalogContentAsset') DROP TYPE [dbo].[udttCatalogContentAsset]
GO

CREATE TYPE [dbo].[udttCatalogContentAsset] AS TABLE(
	[WorkId] [int] NOT NULL, 
	[AssetType] nvarchar(190) NOT NULL,
	[AssetKey] nvarchar(254) NOT NULL,
	[GroupName] nvarchar(100) NULL,
	[SortOrder] [int] NOT NULL
)
GO

CREATE PROCEDURE [dbo].[ecfVersionAsset_Save]
	@WorkIds dbo.[udttObjectWorkId] readonly,
	@ContentDraftAsset dbo.[udttCatalogContentAsset] readonly
AS
BEGIN
	-- delete items're not in input
	DELETE A
	FROM ecfVersionAsset A
	INNER JOIN @WorkIds W on W.WorkId = A.WorkId
	LEFT JOIN @ContentDraftAsset I ON 
				A.WorkId = I.WorkId AND 
				A.AssetType = I.AssetType COLLATE DATABASE_DEFAULT AND 
				A.AssetKey = I.AssetKey COLLATE DATABASE_DEFAULT
	WHERE 
		I.WorkId IS NULL

	-- update/insert items're not in input
	MERGE [dbo].[ecfVersionAsset] as A
	USING @ContentDraftAsset as I
	ON 
		A.WorkId = I.WorkId AND 
		A.AssetType = I.AssetType COLLATE DATABASE_DEFAULT AND 
		A.AssetKey = I.AssetKey COLLATE DATABASE_DEFAULT
	WHEN MATCHED -- update the ecfVersionAsset for existing row
		THEN UPDATE SET 
			A.GroupName = I.GroupName, 
			A.SortOrder = I.SortOrder
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in ecfVersionAsset table 
		THEN 
			INSERT 
				(WorkId, AssetType, AssetKey, GroupName, SortOrder)
			VALUES
				(I.WorkId, I.AssetType, I.AssetKey, I.GroupName, I.SortOrder)
	;
END
GO
-- end create udttCatalogContentAsset type and SP ecfVersionAsset_Save

-- create ecfVersionAsset_ListByWorkIds
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionAsset_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionAsset_ListByWorkIds] 
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
-- end ecfVersionAsset_ListByWorkIds

--begin create udttVersion
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttVersion') DROP TYPE [dbo].[udttVersion]
GO
CREATE TYPE [dbo].[udttVersion] AS TABLE(
	[WorkId] [int] NULL,
	[ObjectId] [int] NOT NULL,
	[ObjectTypeId] INT NOT NULL, 
	[Name] [nvarchar](100) NULL,
	[Code] [nvarchar](100) NULL,
	[LanguageName] [nvarchar](20) NOT NULL,
	[MasterLanguageName] [nvarchar](20) NULL,
	[IsCommonDraft] [bit] NULL,
    [StartPublish] [datetime] NULL,
	[StopPublish] DATETIME NULL, 
	[Status] [int] NULL,	
	[CreatedBy] [nvarchar](100) NOT NULL,
	[Created] [datetime] NOT NULL,
	[ModifiedBy] [nvarchar](100) NULL,
	[Modified] [datetime] NULL,
	[SeoUri] nvarchar(255) NULL,
	[SeoTitle] nvarchar(150) NULL,
	[SeoDescription] nvarchar(355) NULL,
	[SeoKeywords] nvarchar(355) NULL,
	[SeoUriSegment] nvarchar(255) NULL
)
GO
-- end create udttVersion

-- begin create SP ecfVersionProperty_Save
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionProperty_Save] 
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
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			SELECT WorkId, ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], 
						 CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						 [Guid]
			FROM @ContentDraftProperty I
			INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData(WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			SELECT WorkId, ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid]
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
				 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;
END
GO
-- end create SP ecfVersionProperty_Save

-- begin create SP ecfVersion_Create
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Create]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_Create] 
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
-- end create SP ecfVersion_Create

-- begin create SP [ecfVersion_DeleteByObjectId]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByObjectId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectId] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectId]
	@ObjectId [int],
	@ObjectTypeId [int]
AS
BEGIN
	--When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
	DELETE FROM ecfVersion
	WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
END
GO
-- end create SP [ecfVersion_DeleteByObjectId]

-- begin create SP ecfVersion_Save
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_Save] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_Save]
	@WorkId int,
	@ObjectId int,
	@ObjectTypeId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](20),
	@MasterLanguageName [nvarchar](20),
    @StartPublish [datetime],
	@StopPublish DATETIME,
	@Status INT,
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
	-- We have to treat the name field as not culture specific, so we need to copy the name from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
	END

	UPDATE ecfVersion
	SET ObjectId = @ObjectId,
		Code = @Code,
		Name = @Name,
		ObjectTypeId = @ObjectTypeId,
		LanguageName = @LanguageName,
		MasterLanguageName = @MasterLanguageName,
		StartPublish = @StartPublish,
		StopPublish = @StopPublish,
		[Status] = @Status,
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
-- end create SP ecfVersion_Save

-- begin create SP ecfVersion_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_Insert] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_Insert]
	@ObjectId int,
	@ObjectTypeId int,
	@Name [nvarchar](100),
	@Code [nvarchar](100),
	@LanguageName [nvarchar](20),
	@MasterLanguageName [nvarchar](20),
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
	-- We have to treat the name field as not culture specific, so we need to copy the name from the master language to all other languages.
	IF @LanguageName = @MasterLanguageName COLLATE DATABASE_DEFAULT
	BEGIN
		UPDATE ecfVersion SET Name = @Name WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId AND LanguageName <> @MasterLanguageName COLLATE DATABASE_DEFAULT
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
-- end create SP ecfVersion_Insert

-- begin create SP ecfVersion_Update
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_Update] 
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
-- end create SP ecfVersion_Update

-- begin create SP ecfVersion_PublishContentVersion
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_PublishContentVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_PublishContentVersion] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_PublishContentVersion]
	@WorkId			INT,
	@ObjectId		INT,
	@ObjectTypeId	INT,
	@LanguageName	NVARCHAR(20),
	@MaxVersions	INT,
	@ResetCommonDraft BIT = 1
AS
BEGIN
	-- Update old published version status to previously published
	UPDATE	ecfVersion
	SET		[Status] = 5 -- previously published = 5		
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
-- end create SP ecfVersion_PublishContentVersion

-- begin create SP ecfVersionProperty_ListByWorkIds
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionProperty_ListByWorkIds] 
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
	SELECT draftProperty.pkId, draftProperty.WorkId, draftProperty.ObjectId, draftProperty.ObjectTypeId, draftProperty.MetaFieldId, draftProperty.MetaClassId, draftProperty.MetaFieldName, draftProperty.LanguageName,
			draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], [Money], [Date], [Binary], [String], 
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
			draftProperty.[Boolean], draftProperty.[Number], draftProperty.[FloatNumber], [Money], [Date], [Binary], [String], 
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
-- end create SP ecfVersionProperty_ListByWorkIds

-- begin create SP [ecfVersionCatalog_ListByWorkIds]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds] 
GO
CREATE PROCEDURE [dbo].[ecfVersionCatalog_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT c.* FROM ecfVersionCatalog c
	INNER JOIN @ContentLinks l 	ON l.WorkId = c.WorkId
END
GO
-- end create SP [ecfVersionCatalog_ListByWorkIds]

-- begin create SP [ecfVersionCatalog_Save]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionCatalog_Save] 
GO
CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, DefaultLanguage nvarchar(20))

	MERGE dbo.ecfVersionCatalog AS TARGET
	USING @VersionCatalogs AS SOURCE
	On (TARGET.WorkId = SOURCE.WorkId)
	WHEN MATCHED THEN 
		UPDATE SET DefaultCurrency = SOURCE.DefaultCurrency,
				   WeightBase = SOURCE.WeightBase,
				   LengthBase = SOURCE.LengthBase,
				   DefaultLanguage = SOURCE.DefaultLanguage,
				   Languages = SOURCE.Languages,
				   IsPrimary = SOURCE.IsPrimary,
				   UriSegment = SOURCE.UriSegment,
				   [Owner] = SOURCE.[Owner]
	WHEN NOT MATCHED THEN
		INSERT (WorkId, DefaultCurrency, WeightBase, LengthBase, DefaultLanguage, Languages, IsPrimary, UriSegment, [Owner])
		VALUES (SOURCE.WorkId, SOURCE.DefaultCurrency, SOURCE.WeightBase, SOURCE.LengthBase, SOURCE.DefaultLanguage, SOURCE.Languages, SOURCE.IsPrimary, SOURCE.UriSegment, SOURCE.[Owner])
	OUTPUT inserted.WorkId, inserted.DefaultLanguage INTO @WorkIds;

	IF @PublishAction = 1
	BEGIN
		DECLARE @Catalogs udttObjectWorkId

		INSERT INTO @Catalogs
			(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
		-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
			
		-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
		UPDATE d SET 
			d.DefaultLanguage = c.LanguageName
		FROM ecfVersionCatalog d
		INNER JOIN ecfVersion cd ON d.WorkId = cd.WorkId
		INNER JOIN @Catalogs c ON c.ObjectId = cd.ObjectId AND c.ObjectTypeId = cd.ObjectTypeId

		-- and also update MasterLanguageName and CurrentLanguageRemovedFlag of contents that's related to Catalog
		-- catalogs
		UPDATE d SET 
			CurrentLanguageRemoved = CASE WHEN CHARINDEX(d.LanguageName + ';', l.Languages + ';') > 0 THEN 0 ELSE 1 END,
			MasterLanguageName = c.LanguageName
		FROM ecfVersion d
		INNER JOIN @Catalogs c ON (c.ObjectId = d.ObjectId AND d.ObjectTypeId = 2)
		LEFT JOIN @VersionCatalogs l ON l.WorkId = c.WorkId

		--nodes
		UPDATE d SET 
			CurrentLanguageRemoved = CASE WHEN CHARINDEX(d.LanguageName + ';', l.Languages + ';') > 0 THEN 0 ELSE 1 END,
			MasterLanguageName = c.LanguageName
		FROM ecfVersion d
		INNER JOIN CatalogNode n ON (n.CatalogNodeId = d.ObjectId AND d.ObjectTypeId = 1)
		INNER JOIN @Catalogs c ON c.ObjectId = n.CatalogId
		LEFT JOIN @VersionCatalogs l ON l.WorkId = c.WorkId

		--entries
		UPDATE d SET 
			CurrentLanguageRemoved = CASE WHEN CHARINDEX(d.LanguageName + ';', l.Languages + ';') > 0 THEN 0 ELSE 1 END,
			MasterLanguageName = c.LanguageName
		FROM ecfVersion d
		INNER JOIN CatalogEntry e ON (e.CatalogEntryId = d.ObjectId AND d.ObjectTypeId = 0)
		INNER JOIN @Catalogs c ON c.ObjectId = e.CatalogId
		LEFT JOIN @VersionCatalogs l ON l.WorkId = c.WorkId
	END
END
GO
-- end create SP [ecfVersionCatalog_Save]

-- create function fn_JoinCatalogLanguages
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fn_JoinCatalogLanguages' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[fn_JoinCatalogLanguages]
GO
CREATE FUNCTION [dbo].[fn_JoinCatalogLanguages]
(
    @catalogId int
)
RETURNS nvarchar(512)
AS
BEGIN
    DECLARE @RetVal nvarchar(512)
    SELECT @RetVal = COALESCE(@RetVal + ';', '') + LanguageCode FROM CatalogLanguage cl
	INNER JOIN [Catalog] c ON cl.CatalogId = c.CatalogId
	WHERE cl.CatalogId = @catalogId

    RETURN @RetVal;
END
GO
-- end of creating SP fn_JoinCatalogLanguages

-- Stored procedures for syncing drafts from DTOs
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncCatalogData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_SyncCatalogData] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table ( WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

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
		UPDATE SET target.MasterLanguageName = SOURCE.MasterLanguageName, target.IsCommonDraft = SOURCE.IsCommonDraft,
				target.StartPublish = SOURCE.StartPublish, target.Name = SOURCE.Name, target.Code = SOURCE.Code,
				target.Modified = SOURCE.Modified, target.ModifiedBy = SOURCE.ModifiedBy,
				target.StopPublish = SOURCE.StopPublish
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, 
				StopPublish)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;

	-- Insert/Update Catalog draft table
	DECLARE @catalogs AS dbo.[udttVersionCatalog]
	INSERT INTO @catalogs
		SELECT w.WorkId, c.DefaultCurrency, c.WeightBase, c.LengthBase, c.DefaultLanguage, [dbo].[fn_JoinCatalogLanguages](c.CatalogId) as Languages, c.IsPrimary, cl.UriSegment, c.[Owner]
		FROM @WorkIds w
		INNER JOIN dbo.Catalog c ON w.ObjectId = c.CatalogId AND w.MasterLanguageName = c.DefaultLanguage COLLATE DATABASE_DEFAULT
		INNER JOIN dbo.CatalogLanguage cl ON w.ObjectId = cl.CatalogId AND w.LanguageName = cl.LanguageCode COLLATE DATABASE_DEFAULT
		
	EXEC [ecfVersionCatalog_Save] @VersionCatalogs = @catalogs, @PublishAction = 1

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncNodeData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_SyncNodeData] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_SyncNodeData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status], 
				  c.StartDate, c.Name, c.Code, d.CreatedBy, d.Created, d.ModifiedBy, d.Modified, c.CatalogId,
				  c.EndDate, s.Uri, s.Title, s.[Description], s.Keywords, s.UriSegment
			FROM	@ContentDraft d
			INNER JOIN dbo.CatalogNode c on d.ObjectId = c.CatalogNodeId
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogNodeId AND d.LanguageName = s.LanguageCode COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, CatalogId,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET target.IsCommonDraft = SOURCE.IsCommonDraft, target.[Status] = SOURCE.[Status], 
				target.StartPublish = SOURCE.StartPublish, target.Name = SOURCE.Name, 
				target.Code = SOURCE.Code, target.Modified = SOURCE.Modified, target.ModifiedBy = SOURCE.ModifiedBy,
				target.StopPublish = SOURCE.StopPublish,
				target.SeoUri = SOURCE.SeoUri, target.SeoTitle = SOURCE.SeoTitle, target.SeoDescription = SOURCE.SeoDescription, 
				target.SeoKeywords = SOURCE.SeoKeywords, target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			    StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
				StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish, SOURCE.SeoUri, SOURCE.SeoTitle, SOURCE.SeoDescription, SOURCE.SeoKeywords, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;
	
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
	INNER JOIN CatalogNode n ON n.CatalogNodeId = w.ObjectId AND n.IsActive = 1
	LEFT JOIN CatalogItemAsset a ON a.CatalogNodeId = n.CatalogNodeId
	
	EXEC [ecfVersionAsset_Save] @workIdList, @draftAsset

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_SyncEntryData]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_SyncEntryData] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_SyncEntryData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table ( WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))
	
	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, c.Code, d.CreatedBy, d.Created, d.ModifiedBy, d.Modified, c.CatalogId, 
				  c.EndDate, s.Uri, s.Title, s.[Description], s.Keywords, s.UriSegment
			FROM	@ContentDraft d
			INNER JOIN dbo.CatalogEntry c on d.ObjectId = c.CatalogEntryId
			INNER JOIN dbo.CatalogItemSeo s on d.ObjectId = s.CatalogEntryId AND d.LanguageName = s.LanguageCode COLLATE DATABASE_DEFAULT)
	AS SOURCE(ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, CatalogId,
			  StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
	ON (target.ObjectId = SOURCE.ObjectId AND target.ObjectTypeId = SOURCE.ObjectTypeId AND target.[Status] = SOURCE.[Status] AND target.LanguageName = SOURCE.LanguageName COLLATE DATABASE_DEFAULT)
	WHEN MATCHED THEN 
		UPDATE SET target.IsCommonDraft = SOURCE.IsCommonDraft, target.[Status] = SOURCE.[Status],
				target.StartPublish = SOURCE.StartPublish, target.Name = SOURCE.Name, target.Code = SOURCE.Code,
				target.Modified = SOURCE.Modified, target.ModifiedBy = SOURCE.ModifiedBy, 
				target.StopPublish = SOURCE.StopPublish,
				target.SeoUri = SOURCE.SeoUri, target.SeoTitle = SOURCE.SeoTitle, 
				target.SeoDescription = SOURCE.SeoDescription, target.SeoKeywords = SOURCE.SeoKeywords, 
				target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
				StopPublish, SeoUri, SeoTitle, SeoDescription, SeoKeywords, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified,
				SOURCE.StopPublish, SOURCE.SeoUri, SOURCE.SeoTitle, SOURCE.SeoDescription, SOURCE.SeoKeywords, SOURCE.SeoUriSegment)
	OUTPUT inserted.WorkId, inserted.ObjectId, inserted.LanguageName, inserted.MasterLanguageName INTO @WorkIds;
	
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
	INNER JOIN CatalogEntry e ON e.CatalogEntryId = w.ObjectId AND e.IsActive = 1
	LEFT JOIN CatalogItemAsset a ON a.CatalogEntryId = e.CatalogEntryId
	
	EXEC [ecfVersionAsset_Save] @workIdList, @draftAsset

	-- Insert/Update Draft Variation
	DECLARE @draftVariant dbo.[udttVariantDraft]
	INSERT INTO @draftVariant
	SELECT w.WorkId, v.TaxCategoryId, v.TrackInventory, v.[Weight], v.MinQuantity, v.MaxQuantity, v.[Length], v.Height, v.Width, v.PackageId
	FROM @WorkIds w
	INNER JOIN Variation v on w.ObjectId = v.CatalogEntryId
		
	EXEC [ecfVersionVariation_Save] @draftVariant

	IF @SelectOutput = 1
		SELECT * FROM @WorkIds
END
GO
-- End stored procedures for syncing drafts from DTOs

-- Begin create SP [ecfVersionProperty_SyncPublishedVersion]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion] 
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
								[Money] Money, [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Date], cdp.[Binary], cdp.String, 
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
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, @LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Date], cdp.[Binary], cdp.String, 
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
				 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	DROP TABLE #TempProp
END
GO
-- End create SP [ecfVersionProperty_SyncPublishedVersion]

-- Begin create SP [CatalogContentProperty_Save]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_Save] 
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
						FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
		SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, I.MetaFieldName, @LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Date], [Binary], [String], 
						CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						[Guid]
		FROM @ContentProperty I
		INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
		SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
						FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid]
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
				 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
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
-- End create SP [CatalogContentProperty_Save]

-- Begin create SP [CatalogContentProperty_SaveBatch]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_SaveBatch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_SaveBatch] 
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
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, I.MetaFieldName, I.[LanguageName], Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], 
						 CASE WHEN F.IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(I.LongString, 1) ELSE I.LongString END AS LongString, 
						 [Guid]
			FROM @ContentProperty I
			INNER JOIN MetaField F ON F.MetaFieldId = I.MetaFieldId

			EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
			INSERT INTO @propertyData(ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			SELECT ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, I.LanguageName, Boolean, Number, 
						 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid]
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
				 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
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
-- End create SP [CatalogContentProperty_SaveBatch]


-- Begin create SP [ecfVersionProperty_SyncBatchPublishedVersion]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionProperty_SyncBatchPublishedVersion]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion] 
GO
CREATE PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
	@ContentDraftProperty dbo.udttCatalogContentProperty READONLY
AS
BEGIN	
	CREATE TABLE #TempProp(WorkId INT, ObjectId INT, ObjectTypeId INT, MetaFieldId INT, MetaClassId INT, MetaFieldName NVARCHAR(510), LanguageName NVARCHAR(100), Boolean BIT, Number INT, FloatNumber FLOAT,
								[Money] Money, [Date] DATE, [Binary] BINARY, [String] NVARCHAR(900), LongString NVARCHAR(MAX), [Guid] UNIQUEIDENTIFIER) 

	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		--update encrypted field: support only LongString field
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO #TempProp
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Date], cdp.[Binary], cdp.String, 
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
		SELECT ccd.WorkId, ccd.ObjectId, ccd.ObjectTypeId, cdp.MetaFieldId, cdp.MetaClassId, cdp.MetaFieldName, cdp.LanguageName, cdp.Boolean, cdp.Number, cdp.FloatNumber, cdp.[Money], cdp.[Date], cdp.[Binary], cdp.String, 
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
				 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
			VALUES
				(I.WorkId, I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				 I.FloatNumber, I.[Money], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	DROP TABLE #TempProp
END
GO
-- End create SP [ecfVersionProperty_SyncBatchPublishedVersion]

-- Begin create SP [CatalogContentProperty_Migrate]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Migrate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_Migrate] 
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
			 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, I.MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Date], [Binary], [String], 
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
			 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, [Boolean], [Number], 
			 FloatNumber, [Money], [Date], [Binary], [String], LongString, [Guid] FROM @ContentProperty
	END

	EXEC CatalogContentEx_Save @ContentExData
END
GO
-- End create SP [CatalogContentProperty_Migrate]

-- Begin create SP [CatalogContentProperty_Load]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Load]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_Load] 
GO
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
						P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Date], P.[Binary], P.[String], 
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
-- End create SP [CatalogContentProperty_Load]

-- Begin create SP [CatalogContentProperty_DeleteByObjectId]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_DeleteByObjectId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_DeleteByObjectId] 
GO
CREATE PROCEDURE [dbo].[CatalogContentProperty_DeleteByObjectId]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN
	--Delete published version
	DELETE CatalogContentProperty WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
END
GO
-- End create SP [CatalogContentProperty_DeleteByObjectId]

-- create SP mdpsp_sys_CreateMetaClassProcedure
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CreateMetaClassProcedure]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CreateMetaClassProcedure] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_CreateMetaClassProcedure]
    @MetaClassId int
AS
BEGIN
    set nocount on
    begin try
        declare @CRLF nchar(1) = CHAR(10)
        declare @MetaClassName nvarchar(256)
        declare @TableName sysname
        select @MetaClassName = Name, @TableName = TableName from MetaClass where MetaClassId = @MetaClassId
        if @MetaClassName is null raiserror('Metaclass not found.',16,1)

        declare @azureCompatible bit
        SET @azureCompatible = (SELECT TOP 1 AzureCompatible FROM dbo.AzureCompatible)
		
        -- get required info for each field
        declare @ParameterIndex int
        declare @ColumnName sysname
        declare @FieldIsMultilanguage bit
        declare @FieldIsEncrypted bit
        declare @FieldIsNullable bit
        declare @ColumnDataType sysname
        declare fields cursor local for
            select
                mfindex.ParameterIndex,
                mf.Name as ColumnName,
                mf.MultiLanguageValue as FieldIsMultilanguage,
                mf.IsEncrypted as FieldIsEncrypted,
                mf.AllowNulls,
                mdt.SqlName + case
                        when mdt.Variable = 1 then '(' + CAST(mf.Length as nvarchar) + ')'
                        when mf.DataTypeId in (5,24) and mfprecis.Value is not null and mfscale.Value is not null then '(' + cast(mfprecis.Value as nvarchar) + ',' + cast(mfscale.Value as nvarchar) + ')'
                        else '' end as ColumnDataType
            from (
                select ROW_NUMBER() over (order by innermf.Name) as ParameterIndex, innermf.MetaFieldId
                from MetaField innermf
                where innermf.SystemMetaClassId = 0
                  and exists (select 1 from MetaClassMetaFieldRelation cfr where cfr.MetaClassId = @MetaClassId and cfr.MetaFieldId = innermf.MetaFieldId)) mfindex
            join MetaField mf on mfindex.MetaFieldId = mf.MetaFieldId
            join MetaDataType mdt on mf.DataTypeId = mdt.DataTypeId
            left outer join MetaAttribute mfprecis on mf.MetaFieldId = mfprecis.AttrOwnerId and mfprecis.AttrOwnerType = 2 and mfprecis.[Key] = 'MdpPrecision'
            left outer join MetaAttribute mfscale on mf.MetaFieldId = mfscale.AttrOwnerId and mfscale.AttrOwnerType = 2 and mfscale.[Key] = 'MdpScale'

        -- aggregate field parts into lists for stored procedures
        declare @ParameterName nvarchar(max)
        declare @ColumnReadBase nvarchar(max)
        declare @ColumnReadLocal nvarchar(max)
        declare @WriteValue nvarchar(max)
        declare @ParameterDefinitions nvarchar(max) = ''
        declare @UnlocalizedSelectValues nvarchar(max) = ''
        declare @LocalizedSelectValues nvarchar(max) = ''
        declare @AllInsertColumns nvarchar(max) = ''
        declare @AllInsertValues nvarchar(max) = ''
        declare @BaseInsertColumns nvarchar(max) = ''
        declare @BaseInsertValues nvarchar(max) = ''
        declare @LocalInsertColumns nvarchar(max) = ''
        declare @LocalInsertValues nvarchar(max) = ''
        declare @AllUpdateActions nvarchar(max) = ''
        declare @BaseUpdateActions nvarchar(max) = ''
        declare @LocalUpdateActions nvarchar(max) = ''
        open fields
        while 1=1
        begin
            fetch next from fields into @ParameterIndex, @ColumnName, @FieldIsMultilanguage, @FieldIsEncrypted, @FieldIsNullable, @ColumnDataType
            if @@FETCH_STATUS != 0 break

            set @ParameterName = '@f' + cast(@ParameterIndex as nvarchar(10))
            set @ColumnReadBase = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(T.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'T.[' + @ColumnName + ']' end
            set @ColumnReadLocal = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(L.[' + @ColumnName + '],0)' + ' as [' + @ColumnName + ']' else 'L.[' + @ColumnName + ']' end
            set @WriteValue = case when @azureCompatible <> 1 and @FieldIsEncrypted = 1 then 'dbo.mdpfn_sys_EncryptDecryptString(' + @ParameterName + ',1)' else @ParameterName end

            set @ParameterDefinitions = @ParameterDefinitions + ',' + @ParameterName + ' ' + @ColumnDataType
            set @UnlocalizedSelectValues = @UnlocalizedSelectValues + ',' + @ColumnReadBase
            set @LocalizedSelectValues = @LocalizedSelectValues + ',' + case when @FieldIsMultilanguage = 1 then @ColumnReadLocal else @ColumnReadBase end
            set @AllInsertColumns = @AllInsertColumns + ',[' + @ColumnName + ']'
            set @AllInsertValues = @AllInsertValues + ',' + @WriteValue
            set @BaseInsertColumns = @BaseInsertColumns + case when @FieldIsMultilanguage = 0 then ',[' + @ColumnName + ']' else '' end
            set @BaseInsertValues = @BaseInsertValues + case when @FieldIsMultilanguage = 0 then ',' + @WriteValue else '' end
            set @LocalInsertColumns = @LocalInsertColumns + case when @FieldIsMultilanguage = 1 then ',[' + @ColumnName + ']' else '' end
            set @LocalInsertValues = @LocalInsertValues + case when @FieldIsMultilanguage = 1 then ',' + @WriteValue else '' end
            set @AllUpdateActions = @AllUpdateActions + ',[' + @ColumnName + ']=' + @WriteValue
            set @BaseUpdateActions = @BaseUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 0 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
            set @LocalUpdateActions = @LocalUpdateActions + ',[' + @ColumnName + ']=' + case when @FieldIsMultilanguage = 1 then @WriteValue when @FieldIsNullable = 1 then 'null' else 'default' end
        end
        close fields

        declare @OpenEncryptionKey nvarchar(max)
        declare @CloseEncryptionKey nvarchar(max)
        if exists(  select 1
                    from MetaField mf
                    join MetaClassMetaFieldRelation cfr on mf.MetaFieldId = cfr.MetaFieldId
                    where cfr.MetaClassId = @MetaClassId and mf.SystemMetaClassId = 0 and mf.IsEncrypted = 1) and @azureCompatible <> 1
        begin
            set @OpenEncryptionKey = 'exec mdpsp_sys_OpenSymmetricKey' + @CRLF
            set @CloseEncryptionKey = 'exec mdpsp_sys_CloseSymmetricKey' + @CRLF
        end
        else
        begin
            set @OpenEncryptionKey = ''
            set @CloseEncryptionKey = ''
        end

        -- create stored procedures
        declare @procedures table (name sysname, defn nvarchar(max), verb nvarchar(max))

		IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@TableName) = 1
		BEGIN
			declare @isEntry bit
			set @isEntry = CASE WHEN @TableName LIKE 'CatalogEntryEx%' THEN 1 ELSE 0 END

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_ListSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_ListSpecificRecord] @Language nvarchar(20),@Count int as' + @CRLF +
				'begin' + @CRLF +
					'if exists (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N''' + @TableName + ''') ' + @CRLF +
					'begin' + @CRLF +
						@OpenEncryptionKey +
						'select TOP(@Count) T.ObjectId,C.IsActive,C.StartDate StartPublish,C.EndDate StopPublish,C.CatalogId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
						'from [' + @TableName + '] T' + @CRLF +
						'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ' + @CRLF +
						'inner join Catalog' + CASE WHEN @isEntry = 1 THEN 'Entry' ELSE 'Node' END + ' C on T.ObjectId = C.Catalog' + CASE WHEN @isEntry = 1 THEN 'Entry' ELSE 'Node' END + 'Id' + @CRLF +
						'order by T.ObjectId ASC ' + @CRLF +
						@CloseEncryptionKey +
					'end' + @CRLF +
				'end' + @CRLF)

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_DeleteSpecificRecord',
                'procedure dbo.[mdpsp_avto_' + @TableName + '_DeleteSpecificRecord] @IdsToDelete dbo.udttIdTable readonly as' + @CRLF +
				'begin' + @CRLF +
                'DELETE M FROM [' + @TableName + '] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
				'DELETE M FROM [' + @TableName + '_Localization] M INNER JOIN @IdsToDelete I ON M.ObjectId = I.ID' + @CRLF +
				'end' + @CRLF)
		END
		ELSE
		BEGIN
			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_Get',
				'procedure dbo.[mdpsp_avto_' + @TableName + '_Get] @ObjectId int,@Language nvarchar(20)=null as ' + @CRLF +
				'begin' + @CRLF +
				@OpenEncryptionKey +
				'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + @CRLF +
				'from [' + @TableName + '] T where ObjectId=@ObjectId' + @CRLF +
				'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
				'from [' + @TableName + '] T' + @CRLF +
				'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
				'where T.ObjectId= @ObjectId' + @CRLF +
				@CloseEncryptionKey +
				'end' + @CRLF)

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_Update',
				'procedure dbo.[mdpsp_avto_' + @TableName + '_Update]' + @CRLF +
				'@ObjectId int,@Language nvarchar(20)=null,@CreatorId nvarchar(100),@Created datetime,@ModifierId nvarchar(100),@Modified datetime,@Retval int out' + @ParameterDefinitions + ' as' + @CRLF +
				'begin' + @CRLF +
				'set nocount on' + @CRLF +
				'declare @ins bit' + @CRLF +
				'begin try' + @CRLF +
				'begin transaction' + @CRLF +
				@OpenEncryptionKey +
				'if @ObjectId=-1 select @ObjectId=isnull(MAX(ObjectId),0)+1, @Retval=@ObjectId, @ins=0 from [' + @TableName + ']' + @CRLF +
				'else set @ins=case when exists(select 1 from [' + @TableName + '] where ObjectId=@ObjectId) then 0 else 1 end' + @CRLF +
				'if @Language is null' + @CRLF +
				'begin' + @CRLF +
				'  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @AllInsertColumns + ')' + @CRLF +
				'  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @AllInsertValues + ')' + @CRLF +
				'  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @AllUpdateActions + @CRLF +
				'  where ObjectId=@ObjectId' + @CRLF +
				'end' + @CRLF +
				'else' + @CRLF +
				'begin' + @CRLF +
				'  if @ins=1 insert [' + @TableName + '] (ObjectId,CreatorId,Created,ModifierId,Modified' + @BaseInsertColumns + ')' + @CRLF +
				'  values (@ObjectId,@CreatorId,@Created,@ModifierId,@Modified' + @BaseInsertValues + ')' + @CRLF +
				'  else update [' + @TableName + '] set CreatorId=@CreatorId,Created=@Created,ModifierId=@ModifierId,Modified=@Modified' + @BaseUpdateActions + @CRLF +
				'  where ObjectId=@ObjectId' + @CRLF +
				'  if not exists (select 1 from [' + @TableName + '_Localization] where ObjectId=@ObjectId and Language=@Language)' + @CRLF +
				'  insert [' + @TableName + '_Localization] (ObjectId,Language,ModifierId,Modified' + @LocalInsertColumns + ')' + @CRLF +
				'  values (@ObjectId,@Language,@ModifierId,@Modified' + @LocalInsertValues + ')' + @CRLF +
				'  else update [' + @TableName + '_Localization] set ModifierId=@ModifierId,Modified=@Modified' + @LocalUpdateActions + @CRLF +
				'  where ObjectId=@ObjectId and Language=@language' + @CRLF +
				'end' + @CRLF +
				@CloseEncryptionKey +
				'commit transaction' + @CRLF +
				'end try' + @CRLF +
				'begin catch' + @CRLF +
				'  declare @m nvarchar(4000),@v int,@t int' + @CRLF +
				'  select @m=ERROR_MESSAGE(),@v=ERROR_SEVERITY(),@t=ERROR_STATE()' + @CRLF +
				'  rollback transaction' + @CRLF +
				'  raiserror(@m, @v, @t)' + @CRLF +
				'end catch' + @CRLF +
				'end' + @CRLF)

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_Delete',
				'procedure dbo.[mdpsp_avto_' + @TableName + '_Delete] @ObjectId int as' + @CRLF +
				'begin' + @CRLF +
				'delete [' + @TableName + '] where ObjectId=@ObjectId' + @CRLF +
				'delete [' + @TableName + '_Localization] where ObjectId=@ObjectId' + @CRLF +
				'exec mdpsp_sys_DeleteMetaKeyObjects ' + CAST(@MetaClassId as nvarchar(10)) + ',-1,@ObjectId' + @CRLF +
				'end' + @CRLF)

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_List',
				'procedure dbo.[mdpsp_avto_' + @TableName + '_List] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
				'begin' + @CRLF +
				@OpenEncryptionKey +
				'if @Language is null select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + ' from [' + @TableName + '] T' + @CRLF +
				'else select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + @CRLF +
				'from [' + @TableName + '] T' + @CRLF +
				'left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language' + @CRLF +
				@CloseEncryptionKey +
				'end' + @CRLF)

			insert into @procedures (name, defn)
			values ('mdpsp_avto_' + @TableName + '_Search',
				'procedure dbo.[mdpsp_avto_' + @TableName + '_Search] @Language nvarchar(20)=null,@select_list nvarchar(max)='''',@search_condition nvarchar(max)='''' as' + @CRLF +
				'begin' + @CRLF +
				'if len(@select_list)>0 set @select_list='',''+@select_list' + @CRLF +
				@OpenEncryptionKey +
				'if @Language is null exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @UnlocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T ''+@search_condition)' + @CRLF +
				'else exec(''select T.ObjectId,T.CreatorId,T.Created,T.ModifierId,T.Modified' + @LocalizedSelectValues + '''+@select_list+'' from [' + @TableName + '] T left join [' + @TableName + '_Localization] L on T.ObjectId=L.ObjectId and L.Language=@Language ''+@search_condition)' + @CRLF +
				@CloseEncryptionKey +
				'end' + @CRLF)
		END

        update tgt
        set verb = case when r.ROUTINE_NAME is null then 'create ' else 'alter ' end
        from @procedures tgt
        left outer join INFORMATION_SCHEMA.ROUTINES r on r.ROUTINE_SCHEMA COLLATE DATABASE_DEFAULT = 'dbo' and r.ROUTINE_NAME COLLATE DATABASE_DEFAULT = tgt.name COLLATE DATABASE_DEFAULT

        -- install procedures
        declare @sqlstatement nvarchar(max)
        declare procedure_cursor cursor local for select verb + defn from @procedures
        open procedure_cursor
        while 1=1
        begin
            fetch next from procedure_cursor into @sqlstatement
            if @@FETCH_STATUS != 0 break
            exec(@sqlstatement)
        end
        close procedure_cursor
    end try
    begin catch
        declare @m nvarchar(4000), @v int, @t int
        select @m = ERROR_MESSAGE(), @v = ERROR_SEVERITY(), @t = ERROR_STATE()
        raiserror(@m,@v,@t)
    end catch
END
GO
-- end of creating SP mdpsp_sys_CreateMetaClassProcedure

-- create SP mdpsp_sys_CreateMetaClass
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CreateMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CreateMetaClass] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_CreateMetaClass]
	@Namespace 		NVARCHAR(1024),
	@Name 		NVARCHAR(256),
	@FriendlyName		NVARCHAR(256),
	@TableName 		NVARCHAR(256),
	@ParentClassId 		INT,
	@IsSystem		BIT,
	@IsAbstract		BIT	=	0,
	@Description 		NTEXT,
	@Retval 		INT OUTPUT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON
	SET @Retval = -1

BEGIN TRAN
	-- Step 1. Insert a new record in to the MetaClass table
	INSERT INTO [MetaClass] ([Namespace],[Name], [FriendlyName],[Description], [TableName], [ParentClassId], [PrimaryKeyName], [IsSystem], [IsAbstract])
		VALUES (@Namespace, @Name, @FriendlyName, @Description, @TableName, @ParentClassId, 'undefined', @IsSystem, @IsAbstract)

	IF @@ERROR <> 0 GOTO ERR

	SET @Retval = @@IDENTITY
	
	IF @IsSystem = 1
	BEGIN
		IF NOT EXISTS(SELECT * FROM sysobjects WHERE [name] = @TableName AND [type] = 'U')
		BEGIN
			RAISERROR ('Wrong System TableName.', 16,1 )
			GOTO ERR
		END

		-- Step 3-2. Insert a new record in to the MetaField table
		INSERT INTO [MetaField]  ([Namespace], [Name], [FriendlyName], [SystemMetaClassId], [DataTypeId], [Length], [AllowNulls],  [MultiLanguageValue], [AllowSearch], [IsEncrypted])
			 SELECT @Namespace+ N'.' + @Name, SC .[name] , SC .[name] , @Retval ,MDT .[DataTypeId], SC .[length], SC .[isnullable], 0, 0, 0  FROM syscolumns AS SC
				INNER JOIN sysobjects SO ON SO.[id] = SC.[id]
				INNER JOIN systypes ST ON ST.[xtype] = SC.[xtype]
				INNER JOIN MetaDataType MDT ON MDT.[Name] = ST.[name] COLLATE DATABASE_DEFAULT
			WHERE SO.[id]  = object_id( @TableName) and OBJECTPROPERTY( SO.[id], N'IsTable') = 1 and ST.name<>'sysname'
			ORDER BY colorder

		IF @@ERROR<> 0 GOTO ERR

		-- Step 3-2. Insert a new record in to the MetaClassMetaFieldRelation table
		INSERT INTO [MetaClassMetaFieldRelation]  (MetaClassId, MetaFieldId)
			SELECT @Retval, MetaFieldId FROM MetaField WHERE [SystemMetaClassId] = @Retval
	END
	ELSE
	BEGIN
		IF @IsAbstract = 0
		BEGIN
			DECLARE @IsCatalogMetaClass BIT
			SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsCatalogMetaDataTable(@TableName)
			
			IF EXISTS(SELECT * FROM MetaClass WHERE MetaClassId = @ParentClassId /* AND @IsSystem = 1 */ )
			BEGIN
				-- Step 3-2. Insert a new record in to the MetaClassMetaFieldRelation table
				INSERT INTO [MetaClassMetaFieldRelation]  (MetaClassId, MetaFieldId)
					SELECT @Retval, MetaFieldId FROM MetaField WHERE [SystemMetaClassId] = @ParentClassId
			END

			IF @@ERROR<> 0 GOTO ERR
			
			IF @IsCatalogMetaClass = 0
			BEGIN
				-- Step 2. Create the @TableName table.
				EXEC('CREATE TABLE [dbo].[' + @TableName  + '] ([ObjectId] [int] NOT NULL , [CreatorId] [nvarchar](100), [Created] [datetime], [ModifierId] [nvarchar](100) , [Modified] [datetime] )')

				IF @@ERROR <> 0 GOTO ERR

				EXEC('ALTER TABLE [dbo].[' + @TableName  + '] WITH NOCHECK ADD CONSTRAINT [PK_' + @TableName  + '] PRIMARY KEY  CLUSTERED ([ObjectId])')

				IF @@ERROR <> 0 GOTO ERR

				-- Step 2-2. Create the @TableName_Localization table
				EXEC('CREATE TABLE [dbo].[' + @TableName + '_Localization] ([Id] [int] IDENTITY (1, 1)  NOT NULL, [ObjectId] [int] NOT NULL , [ModifierId] [nvarchar](100), [Modified] [datetime], [Language] nvarchar(20) NOT NULL)')

				IF @@ERROR<> 0 GOTO ERR

				EXEC('ALTER TABLE [dbo].[' + @TableName  + '_Localization] WITH NOCHECK ADD CONSTRAINT [PK_' + @TableName  + '_Localization] PRIMARY KEY  CLUSTERED ([Id])')

				IF @@ERROR<> 0 GOTO ERR

				EXEC ('CREATE NONCLUSTERED INDEX IX_' + @TableName + '_Localization_Language ON dbo.' + @TableName + '_Localization ([Language])')

				IF @@ERROR<> 0 GOTO ERR

				EXEC ('CREATE UNIQUE NONCLUSTERED INDEX IX_' + @TableName + '_Localization_ObjectId ON dbo.' + @TableName + '_Localization (ObjectId,[Language])')

				IF @@ERROR<> 0 GOTO ERR
				
				declare @system_root_class_id int
				;with cte as (
					select MetaClassId, ParentClassId, IsSystem
					from MetaClass
					where MetaClassId = @ParentClassId
					union all
					select mc.MetaClassId, mc.ParentClassId, mc.IsSystem
					from cte
					join MetaClass mc on cte.ParentClassId = mc.MetaClassId and cte.IsSystem = 0
				)
				select @system_root_class_id = MetaClassId
				from cte
				where IsSystem = 1

				if exists (select 1 from MetaClass where MetaClassId = @ParentClassId and IsSystem = 1)
				begin
					declare @parent_table sysname
					declare @parent_key_column sysname
					select @parent_table = mc.TableName, @parent_key_column = c.name
					from MetaClass mc
					join sys.key_constraints kc on kc.parent_object_id = OBJECT_ID('[dbo].[' + mc.TableName + ']', 'U')
					join sys.index_columns ic on kc.parent_object_id = ic.object_id and kc.unique_index_id = ic.index_id
					join sys.columns c on ic.object_id = c.object_id and ic.column_id = c.column_id
					where mc.MetaClassId = @system_root_class_id
						and kc.type = 'PK'
						and ic.index_column_id = 1
					
					declare @child_table nvarchar(4000)
					declare child_tables cursor local for select @TableName as table_name union all select @TableName + '_Localization'
					open child_tables
					while 1=1
					begin
						fetch next from child_tables into @child_table
						if @@FETCH_STATUS != 0 break
						
						declare @fk_name nvarchar(4000) = 'FK_' + @child_table + '_' + @parent_table
						
						declare @pdeletecascade nvarchar(30) = ' on delete cascade'
						if (@child_table like '%_Localization'
							and @Namespace = 'Mediachase.Commerce.Orders.System') 
							begin
							set @pdeletecascade = ''
							end

						declare @fk_sql nvarchar(4000) =
							'alter table [dbo].[' + @child_table + '] add ' +
							case when LEN(@fk_name) <= 128 then 'constraint [' + @fk_name + '] ' else '' end +
							'foreign key (ObjectId) references [dbo].[' + @parent_table + '] ([' + @parent_key_column + '])'+ @pdeletecascade + ' on update cascade'
													
						execute dbo.sp_executesql @fk_sql
					end
					close child_tables
					
					if @@ERROR != 0 goto ERR
				end

				EXEC mdpsp_sys_CreateMetaClassProcedure @Retval
				IF @@ERROR <> 0 GOTO ERR
			END
		END
	END

	-- Update PK Value
	DECLARE @PrimaryKeyName	NVARCHAR(256)
	SELECT @PrimaryKeyName = name FROM sysobjects WHERE OBJECTPROPERTY(id, N'IsPrimaryKey') = 1 and parent_obj = OBJECT_ID(@TableName) and OBJECTPROPERTY(parent_obj, N'IsUserTable') = 1

	IF @PrimaryKeyName IS NOT NULL
		UPDATE [MetaClass] SET PrimaryKeyName = @PrimaryKeyName WHERE MetaClassId = @Retval

	COMMIT TRAN
RETURN

ERR:
	ROLLBACK TRAN
	SET @Retval = -1
RETURN
END

GO
-- end of creating SP mdpsp_sys_CreateMetaClass

-- create SP mdpsp_sys_AddMetaFieldToMetaClass
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_AddMetaFieldToMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_AddMetaFieldToMetaClass] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_AddMetaFieldToMetaClass]
	@MetaClassId	INT,
	@MetaFieldId	INT,
	@Weight	INT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON

	DECLARE @IsAbstractClass	BIT
	SELECT @IsAbstractClass = IsAbstract FROM MetaClass WHERE MetaClassId = @MetaClassId

    BEGIN TRAN
	IF NOT EXISTS( SELECT * FROM MetaClass WHERE MetaClassId = @MetaClassId AND IsSystem = 0)
	BEGIN
		RAISERROR ('Wrong @MetaClassId. The class is system or not exists.', 16,1)
		GOTO ERR
	END

	IF NOT EXISTS( SELECT * FROM MetaField WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0)
	BEGIN
		RAISERROR ('Wrong @MetaFieldId. The field is system or not exists.', 16,1)
		GOTO ERR
	END

	DECLARE @IsCatalogMetaClass BIT
	SET @IsCatalogMetaClass = 0

	IF @IsAbstractClass = 0
	BEGIN
		-- Step 1. Insert a new column.
		DECLARE @Name		NVARCHAR(256)
		DECLARE @DataTypeId	INT
		DECLARE @Length		INT
		DECLARE @AllowNulls		BIT
		DECLARE @MultiLanguageValue BIT
		DECLARE @AllowSearch	BIT
		DECLARE @IsEncrypted	BIT

		SELECT @Name = [Name], @DataTypeId = DataTypeId,  @Length = [Length], @AllowNulls = AllowNulls, @MultiLanguageValue = MultiLanguageValue, @AllowSearch = AllowSearch, @IsEncrypted = IsEncrypted
		FROM [MetaField]
        WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0

		-- Step 1-1. Create a new column query.

		DECLARE @MetaClassTableName NVARCHAR(256)
		DECLARE @SqlDataTypeName NVARCHAR(256)
		DECLARE @IsVariableDataType BIT
		DECLARE @DefaultValue	NVARCHAR(50)

		SELECT @MetaClassTableName = TableName FROM MetaClass WHERE MetaClassId = @MetaClassId

		IF @@ERROR<> 0 GOTO ERR

		SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaClassTableName)

		IF @IsCatalogMetaClass = 0
		BEGIN
			SELECT @SqlDataTypeName = SqlName,  @IsVariableDataType = Variable, @DefaultValue = DefaultValue FROM MetaDataType WHERE DataTypeId= @DataTypeId

			IF @@ERROR<> 0 GOTO ERR

			DECLARE @ExecLine 			NVARCHAR(1024)
			DECLARE @ExecLineLocalization 	NVARCHAR(1024)

			SET @ExecLine = 'ALTER TABLE [dbo].['+@MetaClassTableName+'] ADD ['+@Name+'] ' + @SqlDataTypeName
			SET @ExecLineLocalization = 'ALTER TABLE [dbo].['+@MetaClassTableName+'_Localization] ADD ['+@Name+'] ' + @SqlDataTypeName

			IF @IsVariableDataType = 1
			BEGIN
				SET @ExecLine = @ExecLine + ' (' + STR(@Length) + ')'
				SET @ExecLineLocalization = @ExecLineLocalization + ' (' + STR(@Length) + ')'
			END
			ELSE
			BEGIN
				IF @DataTypeId = 5 OR @DataTypeId = 24
				BEGIN
					DECLARE @MdpPrecision NVARCHAR(10)
					DECLARE @MdpScale NVARCHAR(10)

					SET @MdpPrecision = NULL
					SET @MdpScale = NULL

					SELECT @MdpPrecision = [Value] FROM MetaAttribute
					WHERE
						AttrOwnerId = @MetaFieldId AND
						AttrOwnerType = 2 AND
						[Key] = 'MdpPrecision'

					SELECT @MdpScale = [Value] FROM MetaAttribute
					WHERE
						AttrOwnerId = @MetaFieldId AND
						AttrOwnerType = 2 AND
						[Key] = 'MdpScale'

					IF @MdpPrecision IS NOT NULL AND @MdpScale IS NOT NULL
					BEGIN
						SET @ExecLine = @ExecLine + ' (' + @MdpPrecision + ',' + @MdpScale + ')'
						SET @ExecLineLocalization = @ExecLineLocalization + ' (' + @MdpPrecision + ',' + @MdpScale + ')'
					END
				END
			END

			SET @ExecLineLocalization = @ExecLineLocalization + ' NULL'

			IF @AllowNulls = 1
			BEGIN
				SET @ExecLine = @ExecLine + ' NULL'
			END
			ELSE
				BEGIN
					SET @ExecLine = @ExecLine + ' NOT NULL DEFAULT ' + @DefaultValue

					--IF @IsVariableDataType = 1
					--BEGIN
						--SET @ExecLine = @ExecLine + ' (' + STR(@Length) + ')'
					--END

					SET @ExecLine = @ExecLine  +'  WITH VALUES'
				END

			--PRINT (@ExecLine)

			-- Step 1-2. Create a new column.
			EXEC (@ExecLine)

			IF @@ERROR<> 0 GOTO ERR

			-- Step 1-3. Create a new localization column.
			EXEC (@ExecLineLocalization)

			IF @@ERROR <> 0 GOTO ERR
		END
	END

	-- Step 2. Insert a record in to MetaClassMetaFieldRelation table.
	INSERT INTO [MetaClassMetaFieldRelation] (MetaClassId, MetaFieldId, Weight) VALUES(@MetaClassId, @MetaFieldId, @Weight)

	IF @@ERROR <> 0 GOTO ERR

	IF @IsAbstractClass = 0 AND @IsCatalogMetaClass = 0
	BEGIN
		EXEC mdpsp_sys_CreateMetaClassProcedure @MetaClassId

		IF @@ERROR <> 0 GOTO ERR
	END

	--IF @@ERROR <> 0 GOTO ERR

	COMMIT TRAN

    RETURN

ERR:
	ROLLBACK TRAN
    RETURN
END

GO
-- end of creating SP mdpsp_sys_AddMetaFieldToMetaClass

-- create udttMetaFieldMapping type and SP mdpsp_sys_CreateMetaClassView
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_CreateMetaClassView]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_CreateMetaClassView] 
GO
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttMetaFieldMapping') DROP TYPE [dbo].[udttMetaFieldMapping]
GO
CREATE TYPE [dbo].[udttMetaFieldMapping] AS TABLE(
	[MetaFieldName] nvarchar(256) NOT NULL,
	[DataTypeName] nvarchar(256) NOT NULL
)
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_CreateMetaClassView]
	@ViewName NVARCHAR(256),
	@MetaClassId INT,
	@ColumnMappings dbo.[udttMetaFieldMapping] readonly
AS
BEGIN
	-- Create meta class view only if the meta class table does not exist
	-- If the table does exist, it means that it still has data that was not migrated.

	IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME = @ViewName)
			OR EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME = @ViewName + '_Localization')
	BEGIN
		RETURN
	END

	DECLARE @Script NVARCHAR(MAX)
	DECLARE @ScriptLocalization NVARCHAR(MAX)
	DECLARE @MetaFieldName NVARCHAR(256)
	DECLARE @DataTypeName NVARCHAR(256)
	DECLARE @ColumnExpression NVARCHAR(MAX)
	
	SET @Script = 'IF EXISTS (SELECT * FROM sys.views WHERE name =''' + @ViewName + ''') DROP VIEW [dbo].[' + @ViewName + ']'
	SET @ScriptLocalization = 'IF EXISTS (SELECT * FROM sys.views WHERE name =''' + @ViewName + '_Localization'') DROP VIEW [dbo].[' + @ViewName + '_Localization]'
	
	EXEC (@Script)
	EXEC (@ScriptLocalization)

	SET @Script = 'CREATE VIEW [dbo].[' + @ViewName + '] AS '
	SET @ScriptLocalization = 'CREATE VIEW [dbo].[' + @ViewName + '_Localization] AS '
	
	SET @Script = @Script + ' SELECT C.ObjectId, E.CreatedBy as CreatorId, E.Created, E.ModifiedBy as ModifierId, E.Modified '
	SET @ScriptLocalization = @ScriptLocalization + ' SELECT C.ObjectId, E.CreatedBy as CreatorId, E.Created, E.ModifiedBy as ModifierId, E.Modified, C.LanguageName as [Language] '
	
	DECLARE columns_cursor CURSOR LOCAL FAST_FORWARD FOR
		SELECT MetaFieldName, DataTypeName FROM @ColumnMappings

	OPEN columns_cursor
	FETCH NEXT FROM columns_cursor INTO @MetaFieldName, @DataTypeName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @ColumnExpression = CASE WHEN @DataTypeName = 'Boolean' THEN 'CONVERT(INT,[' + @DataTypeName + '])' ELSE '[' + @DataTypeName + ']' END
		SET @Script = @Script + ', MAX(CASE WHEN MetaFieldName = ''' + @MetaFieldName + ''' THEN ' + @ColumnExpression + ' ELSE NULL END) as [' + @MetaFieldName + '] '
		SET @ScriptLocalization = @ScriptLocalization + ', MAX(CASE WHEN MetaFieldName = ''' + @MetaFieldName + ''' THEN ' + @ColumnExpression + ' ELSE NULL END) as [' + @MetaFieldName + '] '

	FETCH NEXT FROM columns_cursor INTO @MetaFieldName, @DataTypeName
	END

	CLOSE columns_cursor
	DEALLOCATE columns_cursor

	SET @Script = @Script + ' FROM [dbo].[CatalogContentProperty] C INNER JOIN [dbo].[CatalogContentEx] E ON C.ObjectId = E.ObjectId AND C.ObjectTypeId = E.ObjectTypeId '
	SET @ScriptLocalization = @ScriptLocalization + ' FROM [dbo].[CatalogContentProperty] C INNER JOIN [dbo].[CatalogContentEx] E ON C.ObjectId = E.ObjectId AND C.ObjectTypeId = E.ObjectTypeId '
	
	SET @Script = @Script + ' GROUP BY C.ObjectId, C.MetaClassId, E.CreatedBy, E.Created, E.ModifiedBy, E.Modified HAVING C.MetaClassId = ' + CAST(@MetaClassId AS VARCHAR)
	SET @ScriptLocalization = @ScriptLocalization + ' GROUP BY C.ObjectId, C.MetaClassId, E.CreatedBy, E.Created, E.ModifiedBy, E.Modified, C.LanguageName HAVING C.MetaClassId = ' + CAST(@MetaClassId AS VARCHAR)
	
	EXEC (@Script)
	EXEC (@ScriptLocalization)
END
GO
-- end of creating udttMetaFieldMapping type and SP mdpsp_sys_CreateMetaClassView

-- create SP mdpsp_sys_DeleteMetaClass
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_DeleteMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_DeleteMetaClass] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_DeleteMetaClass]
	@MetaClassId	INT
AS
BEGIN
	-- Step 0. Prepare
	SET NOCOUNT ON

	BEGIN TRAN

	DECLARE @MetaFieldOwnerTable	NVARCHAR(256)

	-- Check Childs Table
	IF EXISTS(SELECT *  FROM MetaClass MC WHERE ParentClassId = @MetaClassId)
	BEGIN
		RAISERROR ('The class have childs.', 16, 1)
		GOTO ERR
	END

	-- Step 1. Find a TableName
	IF EXISTS(SELECT *  FROM MetaClass MC WHERE MetaClassId = @MetaClassId)
	BEGIN
		IF EXISTS(SELECT *  FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0 AND IsAbstract = 0)
		BEGIN
			SELECT @MetaFieldOwnerTable = TableName  FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0 AND IsAbstract = 0

			IF @@ERROR <> 0 GOTO ERR

			EXEC mdpsp_sys_DeleteMetaClassProcedure @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 2. Delete Table or View
			IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaFieldOwnerTable) = 1
			BEGIN
				EXEC('DROP VIEW [dbo].[' + @MetaFieldOwnerTable + ']')
				IF @@ERROR <> 0 GOTO ERR

				EXEC('DROP VIEW [dbo].[' + @MetaFieldOwnerTable + '_Localization]')
				IF @@ERROR <> 0 GOTO ERR
			END
			ELSE
			BEGIN
				EXEC('DROP TABLE [dbo].[' + @MetaFieldOwnerTable + ']')
				IF @@ERROR <> 0 GOTO ERR

				EXEC('DROP TABLE [dbo].[' + @MetaFieldOwnerTable + '_Localization]')
				IF @@ERROR <> 0 GOTO ERR
			END

			EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId
			 IF @@ERROR <> 0 GOTO ERR

			-- Delete Meta Attribute
			EXEC mdpsp_sys_ClearMetaAttribute @MetaClassId, 1

			 IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField Relations
			DELETE FROM MetaClassMetaFieldRelation WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaClass
			DELETE FROM MetaClass WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR
		END
		ELSE
		BEGIN
			-- Delete Meta Attribute
			EXEC mdpsp_sys_ClearMetaAttribute @MetaClassId, 1

			 IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField Relations
			DELETE FROM MetaClassMetaFieldRelation WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaField
			DELETE FROM MetaField WHERE SystemMetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

			-- Step 3. Delete MetaClass
			DELETE FROM MetaClass WHERE MetaClassId = @MetaClassId

			IF @@ERROR <> 0 GOTO ERR

		END
		
		
	END
	ELSE
	BEGIN
		RAISERROR ('Wrong @MetaClassId.', 16, 1)
		GOTO ERR
	END

	COMMIT TRAN
	RETURN

ERR:
	ROLLBACK TRAN
	RETURN
END

GO
-- end of creating SP mdpsp_sys_DeleteMetaClass

-- create SP mdpsp_sys_DeleteMetaFieldFromMetaClass
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_DeleteMetaFieldFromMetaClass]
	@MetaClassId	INT,
	@MetaFieldId	INT
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM MetaClassMetaFieldRelation WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId)
	BEGIN
		--RAISERROR ('Wrong @MetaFieldId and @MetaClassId.', 16, 1)
		-- GOTO ERR
		RETURN
	END

	-- Step 0. Prepare
	SET NOCOUNT ON

	DECLARE @MetaFieldName NVARCHAR(256)
	DECLARE @MetaFieldOwnerTable NVARCHAR(256)
	DECLARE @BaseMetaFieldOwnerTable NVARCHAR(256)
	DECLARE @IsAbstractClass BIT

	-- Step 1. Find a Field Name
	-- Step 2. Find a TableName
	IF NOT EXISTS(SELECT * FROM MetaField MF WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0 )
	BEGIN
		RAISERROR ('Wrong @MetaFieldId.', 16, 1)
		GOTO ERR
	END

	SELECT @MetaFieldName = MF.[Name] FROM MetaField MF WHERE MetaFieldId = @MetaFieldId AND SystemMetaClassId = 0

	IF NOT EXISTS(SELECT * FROM MetaClass MC WHERE MetaClassId = @MetaClassId AND IsSystem = 0)
	BEGIN
		RAISERROR ('Wrong @MetaClassId.', 16, 1)
		GOTO ERR
	END

	SELECT @BaseMetaFieldOwnerTable = MC.TableName, @IsAbstractClass = MC.IsAbstract FROM MetaClass MC
		WHERE MetaClassId = @MetaClassId AND IsSystem = 0

	SET @MetaFieldOwnerTable = @BaseMetaFieldOwnerTable
	
	DECLARE @IsCatalogMetaClass BIT
	SET @IsCatalogMetaClass = dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaFieldOwnerTable)

	IF @@ERROR <> 0 GOTO ERR

	BEGIN TRAN

	IF @IsAbstractClass = 0
	BEGIN
		EXEC mdpsp_sys_DeleteMetaKeyObjects @MetaClassId, @MetaFieldId
		IF @@ERROR <> 0 GOTO ERR

		IF @IsCatalogMetaClass = 0
		BEGIN
			-- Step 3. Delete Constrains
			EXEC mdpsp_sys_DeleteDContrainByTableAndField @MetaFieldOwnerTable, @MetaFieldName

			IF @@ERROR <> 0 GOTO ERR
			
			-- Step 4. Delete Field
			EXEC ('ALTER TABLE ['+@MetaFieldOwnerTable+'] DROP COLUMN [' + @MetaFieldName + ']')

			IF @@ERROR <> 0 GOTO ERR
			
			-- Update 2007/10/05: Remove meta field from Localization table (if table exists)
			SET @MetaFieldOwnerTable = @BaseMetaFieldOwnerTable + '_Localization'

			if exists (select * from dbo.sysobjects where id = object_id(@MetaFieldOwnerTable) and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			begin
				-- a). Delete constraints
				EXEC mdpsp_sys_DeleteDContrainByTableAndField @MetaFieldOwnerTable, @MetaFieldName
				-- a). Drop column
				EXEC ('ALTER TABLE ['+@MetaFieldOwnerTable+'] DROP COLUMN [' + @MetaFieldName + ']')
			end
		END
		ELSE
		BEGIN
			-- Delete the appropriated property from both Property and Draft Property tables.
			DELETE FROM CatalogContentProperty WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
			DELETE FROM ecfVersionProperty WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
		END
	END

	-- Step 5. Delete Field Info Record
	DELETE FROM MetaClassMetaFieldRelation WHERE MetaFieldId = @MetaFieldId AND MetaClassId = @MetaClassId
	IF @@ERROR <> 0 GOTO ERR

	IF @IsAbstractClass = 0 AND @IsCatalogMetaClass = 0
	BEGIN
		EXEC mdpsp_sys_CreateMetaClassProcedure @MetaClassId

		IF @@ERROR <> 0 GOTO ERR
	END

	COMMIT TRAN
	RETURN
ERR:
	ROLLBACK TRAN

	RETURN @@Error
END

GO
-- end of creating SP mdpsp_sys_DeleteMetaFieldFromMetaClass

-- create SP mdpsp_sys_LoadDictionarySingleItemUsages
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_LoadDictionarySingleItemUsages]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_LoadDictionarySingleItemUsages] 
GO
CREATE PROCEDURE dbo.[mdpsp_sys_LoadDictionarySingleItemUsages]
	@MetaFieldId int,
	@MetaDictionaryId int
as
begin

DECLARE @metaClassTableName nvarchar(256)
DECLARE @sqlQuery nvarchar(max)
DECLARE @metaFieldName nvarchar(256)
DECLARE @multipleLanguage bit
DECLARE @rowcount int

SET @metaFieldName = (SELECT top 1 Name from dbo.MetaField where MetaFieldId = @MetaFieldId)
SET @multipleLanguage = (SELECT top 1 MultiLanguageValue from dbo.MetaField where MetaFieldId = @MetaFieldId)

DECLARE metaclass_table CURSOR FOR 
SELECT TableName
FROM dbo.MetaClass m
INNER JOIN dbo.MetaClassMetaFieldRelation r
ON m.MetaClassId = r.MetaClassId
WHERE r.MetaFieldId = @MetaFieldId

SET @sqlQuery = ''
SET @rowcount = 0

OPEN metaclass_table

FETCH NEXT FROM metaclass_table 
INTO @metaClassTableName


WHILE @@FETCH_STATUS = 0
BEGIN
	IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@MetaClassTableName) = 1
	BEGIN
		SELECT @rowcount = COUNT(ObjectId) FROM CatalogContentProperty WHERE MetaFieldId = @MetaFieldId and [Number] = @MetaDictionaryId
	END
	ELSE
	BEGIN
		IF (@multipleLanguage = 1)
			SET @metaClassTableName = @metaClassTableName + '_Localization'
		SET @sqlQuery = 'SELECT @rowcount = Count(ObjectId) FROM ' + @metaClassTableName + ' where [' +  @metaFieldName +  '] =  ''' + cast(@MetaDictionaryId as varchar(20)) + ''''
		EXEC sp_executesql @sqlQuery, N'@rowcount int output', @rowcount output
		
		IF (@rowcount > 0)
			BREAK
	END

FETCH NEXT FROM metaclass_table 
    INTO @metaClassTableName
	
END 
CLOSE metaclass_table;
DEALLOCATE metaclass_table;

SELECT @rowcount

END 

GO
-- end of creating SP mdpsp_sys_LoadDictionarySingleItemUsages

-- create SP CatalogContentEx_Load
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentEx_Load]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentEx_Load] 
GO

CREATE PROCEDURE [dbo].[CatalogContentEx_Load]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN
	SELECT * FROM dbo.CatalogContentEx 
	WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId
END
GO
-- end of creating SP CatalogContentEx_Load

-- create SP CatalogContentEx_Load
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentEx_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentEx_Save] 
GO

CREATE PROCEDURE [dbo].[CatalogContentEx_Save]
	@Data dbo.[udttCatalogContentEx] readonly
AS
BEGIN
	MERGE dbo.CatalogContentEx AS TARGET
	USING @Data AS SOURCE
	On (TARGET.ObjectId = SOURCE.ObjectId AND TARGET.ObjectTypeId = SOURCE.ObjectTypeId)
	WHEN MATCHED THEN 
		UPDATE SET CreatedBy = SOURCE.CreatedBy,
				   Created = SOURCE.Created,
				   ModifiedBy = SOURCE.ModifiedBy,
				   Modified = SOURCE.Modified
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CreatedBy, Created, ModifiedBy, Modified)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified);
END
GO
-- end of creating SP CatalogContentEx_Save

-- create CatalogEntry_Delete trigger
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogEntry_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogEntry_Delete]
GO 
CREATE TRIGGER [dbo].[CatalogEntry_Delete] ON CatalogEntry FOR DELETE
AS
	--Delete all draft of deleted entry
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogEntryId AND d.ObjectTypeId = 0

	--Delete all extra info of this entry
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogEntryId AND c.ObjectTypeId = 0
GO
-- end of creating CatalogEntry_Delete trigger

-- create CatalogNode_Delete trigger
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogNode_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[CatalogNode_Delete]
GO 
CREATE TRIGGER [dbo].[CatalogNode_Delete] ON CatalogNode FOR DELETE
AS
	--Delete all draft of deleted entry
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogNodeId AND d.ObjectTypeId = 1

	--Delete all extra info of this entry
	DELETE c FROM CatalogContentEx c 
	INNER JOIN deleted ON c.ObjectId = deleted.CatalogNodeId AND c.ObjectTypeId = 1
GO
-- end of creating CatalogNode_Delete trigger

-- create Catalog_Delete trigger
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[Catalog_Delete]') AND OBJECTPROPERTY(id, N'IsTrigger') = 1) DROP TRIGGER [dbo].[Catalog_Delete]
GO 
CREATE TRIGGER [dbo].[Catalog_Delete] ON [Catalog] FOR DELETE
AS
	--Delete all draft of deleted catalog
	DELETE d FROM ecfVersion d
	INNER JOIN deleted ON d.ObjectId = deleted.CatalogId AND d.ObjectTypeId = 2
GO
-- end of creating Catalog_Delete trigger

-- creating [mdpfn_sys_IsLongStringMetaField] function
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'mdpfn_sys_IsLongStringMetaField' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[mdpfn_sys_IsLongStringMetaField]
GO
CREATE FUNCTION [dbo].[mdpfn_sys_IsLongStringMetaField]
(
	@dataTypeId INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @RetVal BIT

	IF @dataTypeId IN (31, --ShortString
					   32, --LongString
					   33 --LongHtmlString 
					  )
		SET @RetVal = 1
	ELSE
		SET @RetVal = 0

	RETURN @RetVal;
END
GO
-- end creating [mdpfn_sys_IsLongStringMetaField] function

-- creating [mdpfn_sys_IsAzureCompatible] function
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'mdpfn_sys_IsAzureCompatible' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[mdpfn_sys_IsAzureCompatible]
GO
CREATE FUNCTION [dbo].[mdpfn_sys_IsAzureCompatible]()
RETURNS BIT
AS
BEGIN
	DECLARE @RetVal BIT
	SET @RetVal = ISNULL((SELECT AzureCompatible FROM dbo.AzureCompatible), 0)
	RETURN @RetVal;
END
GO
-- end creating [mdpfn_sys_IsAzureCompatible] function

-- create SP mdpsp_sys_GetMetaKey
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_GetMetaKey]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_GetMetaKey] 
GO
CREATE PROCEDURE [dbo].[mdpsp_sys_GetMetaKey]
	@MetaObjectId	INT,
	@WorkId			INT = NULL,
	@MetaClassId	INT,
	@MetaFieldId	INT,
	@Language NVARCHAR(20) = NULL,
	@Retval	INT	OUT
AS
SET NOCOUNT ON

DECLARE @TableName NVARCHAR(256)
SET @TableName = (SELECT TableName FROM MetaClass WHERE MetaClassId = @MetaClassId)

IF dbo.mdpfn_sys_IsCatalogMetaDataTable(@TableName) = 0
BEGIN
	DECLARE @IsMultiLanguage BIT
	SET @IsMultiLanguage = (SELECT MultiLanguageValue FROM MetaField WHERE MetaFieldId = @MetaFieldId)

	IF @IsMultiLanguage = 0 OR ISNULL(@Language, '') = ''
	BEGIN
		SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId
		
		IF @Retval IS NULL
		BEGIN
			INSERT INTO MetaKey (MetaObjectId, MetaClassId, MetaFieldId) VALUES (@MetaObjectId, @MetaClassId, @MetaFieldId)
			SET @Retval = SCOPE_IDENTITY()
		END
	END
	ELSE
	BEGIN
		SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId AND Language=@Language COLLATE DATABASE_DEFAULT
		
		IF @Retval IS NULL
		BEGIN
			INSERT INTO MetaKey (MetaObjectId, MetaClassId, MetaFieldId, Language) VALUES (@MetaObjectId, @MetaClassId, @MetaFieldId, @Language)
			SET @Retval = SCOPE_IDENTITY()
		END
	END
END
ELSE
BEGIN
	IF ISNULL(@Language, '') = ''
	BEGIN
		DECLARE @CatalogId INT
		SET @CatalogId = CASE WHEN @TableName LIKE 'CatalogEntryEx%' THEN
								(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @MetaObjectId)
								WHEN @TableName LIKE 'CatalogNodeEx%' THEN							
								(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @MetaObjectId)
							END
		SET @Language = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @CatalogId)
	END

	SELECT @Retval = MetaKey FROM MetaKey WHERE MetaObjectId = @MetaObjectId AND MetaClassId = @MetaClassId AND MetaFieldId = @MetaFieldId AND (@WorkId = NULL OR WorkId = @WorkId) AND Language=@Language COLLATE DATABASE_DEFAULT
		
	IF @Retval IS NULL
	BEGIN
		INSERT INTO MetaKey (MetaObjectId, WorkId, MetaClassId, MetaFieldId, Language) VALUES (@MetaObjectId, @WorkId, @MetaClassId, @MetaFieldId, @Language)
		SET @Retval = SCOPE_IDENTITY()
	END
END
GO
--end creating [mdpsp_sys_GetMetaKey]

-- create SP [ecf_CheckExistEntryNodeByCode]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CheckExistEntryNodeByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CheckExistEntryNodeByCode] 
GO
CREATE PROCEDURE [dbo].[ecf_CheckExistEntryNodeByCode]
	@ApplicationId uniqueidentifier,
	@EntryNodeCode nvarchar(100)
AS
BEGIN
	DECLARE @exist BIT
	SET @exist = 0
	IF EXISTS (SELECT * FROM [CatalogEntry] WHERE ApplicationId = @ApplicationId AND Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END
	
	IF @exist = 0 AND EXISTS (SELECT * FROM [CatalogNode] WHERE ApplicationId = @ApplicationId AND Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END

	SELECT @exist
END
GO
--end creating [ecf_CheckExistEntryNodeByCode]

-- create SP [ecf_GetCatalogEntryIdByCode]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCatalogEntryIdByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogEntryIdByCode] 
GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryIdByCode]
	@ApplicationId uniqueidentifier,
	@CatalogEntryCode nvarchar(100)
AS
BEGIN
	SELECT TOP 1 CatalogEntryId from [CatalogEntry]
	WHERE ApplicationId = @ApplicationId AND
		  Code = @CatalogEntryCode
END
GO
--end creating [ecf_GetCatalogEntryIdByCode]

-- begin create SP [ecfVersion_DeleteByObjectIds]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersion_DeleteByObjectIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds] 
GO
CREATE PROCEDURE [dbo].[ecfVersion_DeleteByObjectIds]
	@ObjectIds udttObjectWorkId readonly
AS
BEGIN
	--When deleting content draft, it will delete automatically Asset, SEO, Property, Variation, Catalog draft by Cascade
	DELETE v FROM ecfVersion v
	INNER JOIN @ObjectIds i
		ON i.ObjectId = v.ObjectId AND i.ObjectTypeId = v.ObjectTypeId
END
GO
-- end create SP [ecfVersion_DeleteByObjectIds]

-- create ecf_CatalogEntrySearch_Init sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntrySearch_Init]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch_Init]
GO
CREATE procedure [dbo].[ecf_CatalogEntrySearch_Init]
    @ApplicationId uniqueidentifier,
    @CatalogId int,
    @SearchSetId uniqueidentifier,
    @IncludeInactive bit,
    @EarliestModifiedDate datetime = null,
    @LatestModifiedDate datetime = null,
    @DatabaseClockOffsetMS int = null
as
begin
	declare @purgedate datetime
	begin try
		set @purgedate = datediff(day, 3, GETUTCDATE())
		delete from [CatalogEntrySearchResults_SingleSort] where Created < @purgedate
	end try
	begin catch
	end catch

    declare @ModifiedCondition nvarchar(max)
    declare @ModifiedFilter nvarchar(4000)
    declare @query nvarchar(max)
	declare @AppLogQuery nvarchar(4000)

	set @ModifiedCondition = ''
    
    -- @ModifiedFilter: if there is a filter, build the where clause for it here.
    if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null) set @ModifiedFilter = ' Modified between cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime) and cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
    else if (@EarliestModifiedDate is not null) set @ModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
    else if (@LatestModifiedDate is not null) set @ModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
    else set @ModifiedFilter = ''

	-- applying the catalogContentEx.
	set @ModifiedCondition = @ModifiedCondition + ' select ObjectId from CatalogContentEx where ObjectTypeId = 0 and ' + @ModifiedFilter
	
    -- find all the catalog entries that have modified relations in NodeEntryRelation, or deleted relations in ApplicationLog
    if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null)
    begin
        -- adjust modified date filters to account for clock difference between database server and application server clocks    
        if (@EarliestModifiedDate is not null and isnull(@DatabaseClockOffsetMS, 0) > 0)
        begin
            set @EarliestModifiedDate = DATEADD(MS, -@DatabaseClockOffsetMS, @EarliestModifiedDate)
        
            if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null) set @ModifiedFilter = ' Modified between cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime) and cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
            else if (@EarliestModifiedDate is not null) set @ModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
            else if (@LatestModifiedDate is not null) set @ModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
            else set @ModifiedFilter = ''    
        end

		-- applying the NodeEntryRelation.
		set @ModifiedCondition = @ModifiedCondition + ' union all select CatalogEntryId from NodeEntryRelation where ' + @ModifiedFilter
	
		declare @AppLogFilter nvarchar(4000)
		set @AppLogFilter = REPLACE(@ModifiedFilter, 'Modified', 'Created')	
		set @AppLogQuery = ' union all select cast(ObjectKey as int) as CatalogEntryId from ApplicationLog where [Source] = ''catalog'' and [Operation] = ''Modified'' and [ObjectType] = ''relation'' and ' + @AppLogFilter

		-- applying the ApplicationLog.
		set @ModifiedCondition = @ModifiedCondition + @AppLogQuery
    end

    set @query = 
    'insert into CatalogEntrySearchResults_SingleSort (SearchSetId, ResultIndex, CatalogEntryId, ApplicationId) ' +
    'select distinct ''' + cast(@SearchSetId as nvarchar(36)) + ''', ROW_NUMBER() over (order by e.CatalogEntryId), e.CatalogEntryId, e.ApplicationId from CatalogEntry e where ' +
	' e.ApplicationId = ''' + cast(@ApplicationId as nvarchar(36)) + ''' ' +
      'and e.CatalogId = ' + cast(@CatalogId as nvarchar) + ' ' +
	  ' and e.CatalogEntryId in (' + @ModifiedCondition + ')'
      
    if @IncludeInactive = 0 set @query = @query + ' and e.IsActive = 1'

    execute dbo.sp_executesql @query
    
    select @@ROWCOUNT
end
GO
-- end of creating ecf_CatalogEntrySearch_Init sp

-- begin create SP [ecf_CatalogNodesList]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNodesList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodesList] 
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodesList]
(
	@CatalogId int,
	@CatalogNodeId int,
	@EntryMetaSQLClause nvarchar(max),
	@OrderClause nvarchar(100),
	@StartingRec int,
	@NumRecords int,
	@ReturnInactive bit = 0,
	@ReturnTotalCount bit = 1
)
AS

BEGIN
	SET NOCOUNT ON

	declare @execStmtString nvarchar(max)
	declare @selectStmtString nvarchar(max)
	declare @EntryMetaSQLClauseLength bigint
	declare @SelectEntryMetaQuery_tmp nvarchar(max)
	set @EntryMetaSQLClauseLength = LEN(@EntryMetaSQLClause)

	set @execStmtString=N''

	-- assign ORDER BY statement if it is empty
	if(Len(RTrim(LTrim(@OrderClause))) = 0)
		set @OrderClause = N'ID ASC'

    -- Construct meta class joins for CatalogEntry table if a WHERE clause has been specified for Entry Meta data
    IF(@EntryMetaSQLClauseLength>0)
    BEGIN
    	-- If there is a meta SQL clause provided, join to CatalogContentProperty table
    	-- Similar to [ecf_CatalogEntrySearch], but simpler due to fewer variations, i.e.:
    	--   No @Classes parameter
    	--   No @Namespace
		set @SelectEntryMetaQuery_tmp = 'select META.ObjectId as ''Key'', 100 as ''Rank'' from CatalogContentProperty META ' + 
						' WHERE META.ObjectTypeId = 0 AND ' + @EntryMetaSQLClause

		set @SelectEntryMetaQuery_tmp = N' INNER JOIN (select distinct U.[Key], MIN(U.Rank) AS Rank from (' + @SelectEntryMetaQuery_tmp + N') U GROUP BY U.[Key]) META ON CE.[CatalogEntryId] = META.[Key] '
    END
    ELSE
    BEGIN
        set @SelectEntryMetaQuery_tmp = N''
    END

	if (COALESCE(@CatalogNodeId, 0)=0)
	begin
		-- if @CatalogNodeId=0
		set @selectStmtString=N'select SEL.*, row_number() over(order by '+ @OrderClause +N') as RowNumber
				from
				(
					-- select Catalog Nodes
					SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[NAME] as Owner
						FROM [CatalogNode] CN 
							JOIN Catalog C ON (CN.CatalogId = C.CatalogId)
                            LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
						WHERE CatalogNodeId IN
						(SELECT DISTINCT N.CatalogNodeId from [CatalogNode] N
							LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
							WHERE
							(
								(N.CatalogId = @CatalogId AND N.ParentNodeId = @CatalogNodeId)
								OR
								(NR.CatalogId = @CatalogId AND NR.ParentNodeId = @CatalogNodeId)
							)
							AND
							((N.IsActive = 1) or @ReturnInactive = 1)
						)

					UNION

					-- select Catalog Entries
					SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], 0, OG.[NAME] as Owner
						FROM [CatalogEntry] CE
							JOIN Catalog C ON (CE.CatalogId = C.CatalogId)'
							+ @SelectEntryMetaQuery_tmp
							+ N'
                            LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
					WHERE
						CE.CatalogId = @CatalogId AND
						NOT EXISTS(SELECT 1 FROM NodeEntryRelation R WHERE R.CatalogId = @CatalogId and CE.CatalogEntryId = R.CatalogEntryId) AND
						((CE.IsActive = 1) or @ReturnInactive = 1)
				) SEL'
	end
	else
	begin
		-- if @CatalogNodeId!=0

		-- Get the original catalog id for the given catalog node
		SELECT @CatalogId = [CatalogId] FROM [CatalogNode] WHERE [CatalogNodeId] = @CatalogNodeId

		set @selectStmtString=N'select SEL.*, row_number() over(order by '+ @OrderClause +N') as RowNumber
			from
			(
				-- select Catalog Nodes
				SELECT CN.[CatalogNodeId] as ID, CN.[Name], ''Node'' as Type, CN.[Code], CN.[StartDate], CN.[EndDate], CN.[IsActive], CN.[SortOrder], OG.[NAME] as Owner
					FROM [CatalogNode] CN 
						JOIN Catalog C ON (CN.CatalogId = C.CatalogId)
						--We actually dont need to join NodeEntryRelation to get the SortOrder because it is always 0
                        --JOIN CatalogEntry CE ON CE.CatalogId = C.CatalogId
						--LEFT JOIN NodeEntryRelation NER ON (NER.CatalogId = CN.CatalogId And NER.CatalogNodeId = CN.CatalogNodeId  AND CE.CatalogEntryId = NER.CatalogEntryId ) 
                        LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
					WHERE CN.CatalogNodeId IN
				(SELECT DISTINCT N.CatalogNodeId from [CatalogNode] N
				LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
				WHERE
					((N.CatalogId = @CatalogId AND N.ParentNodeId = @CatalogNodeId) OR (NR.CatalogId = @CatalogId AND NR.ParentNodeId = @CatalogNodeId)) AND
					((N.IsActive = 1) or @ReturnInactive = 1))

				UNION
				
				-- select Catalog Entries
				SELECT CE.[CatalogEntryId] as ID, CE.[Name], CE.ClassTypeId as Type, CE.[Code], CE.[StartDate], CE.[EndDate], CE.[IsActive], R.[SortOrder], OG.[NAME] as Owner
					FROM [CatalogEntry] CE
						JOIN Catalog C ON (CE.CatalogId = C.CatalogId)
						JOIN NodeEntryRelation R ON R.CatalogEntryId = CE.CatalogEntryId'
							+ @SelectEntryMetaQuery_tmp
							+ N'
                        LEFT JOIN cls_Organization OG ON (OG.OrganizationId = C.Owner)
				WHERE
					R.CatalogNodeId = @CatalogNodeId AND
					R.CatalogId = @CatalogId AND
						((CE.IsActive = 1) or @ReturnInactive = 1)
			) SEL'
	end

	if(@ReturnTotalCount = 1) -- Only return count if we requested it
		set @execStmtString=N'with SelNodes(ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber)
			as
			(' + @selectStmtString +
			N'),
			SelNodesCount(TotalCount)
			as
			(
				select count(ID) from SelNodes
			)
			select  TOP ' + cast(@NumRecords as nvarchar(50)) + ' ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber, C.TotalCount as RecordCount
			from SelNodes, SelNodesCount C
			where RowNumber >= ' + cast(@StartingRec as nvarchar(50)) + 
			' order by '+ @OrderClause
	else
		set @execStmtString=N'with SelNodes(ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber)
			as
			(' + @selectStmtString +
			N')
			select  TOP ' + cast(@NumRecords as nvarchar(50)) + ' ID, Name, Type, Code, StartDate, EndDate, IsActive, SortOrder, Owner, RowNumber
			from SelNodes
			where RowNumber >= ' + cast(@StartingRec as nvarchar(50)) +
			' order by '+ @OrderClause
	
	declare @ParamDefinition nvarchar(500)
	set @ParamDefinition = N'@CatalogId int,
						@CatalogNodeId int,
						@StartingRec int,
						@NumRecords int,
						@ReturnInactive bit';
	exec sp_executesql @execStmtString, @ParamDefinition,
			@CatalogId = @CatalogId,
			@CatalogNodeId = @CatalogNodeId,
			@StartingRec = @StartingRec,
			@NumRecords = @NumRecords,
			@ReturnInactive = @ReturnInactive

	SET NOCOUNT OFF
END
GO
-- end create SP [ecf_CatalogNodesList]

-- create SP [ecf_CatalogNodeSearch]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogNodeSearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeSearch] 
GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeSearch]
(
	@ApplicationId			uniqueidentifier,
	@SearchSetId			uniqueidentifier,
	@Language 				nvarchar(50),
	@Catalogs 				nvarchar(max),
	@CatalogNodes 			nvarchar(max),
	@SQLClause 				nvarchar(max),
	@MetaSQLClause 			nvarchar(max),
	@OrderBy 				nvarchar(max),
	@Namespace				nvarchar(1024) = N'',
	@Classes				nvarchar(max) = N'',
	@StartingRec 			int,
	@NumRecords   			int,
	@RecordCount			int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @FilterQuery_tmp nvarchar(max)
	DECLARE @SelectMetaQuery_tmp nvarchar(max)
	DECLARE @FromQuery_tmp nvarchar(max)
	DECLARE @FullQuery nvarchar(max)

	set @SelectMetaQuery_tmp = 'select 100 as ''Rank'', META.ObjectId as ''Key'' from CatalogContentProperty META WHERE META.ObjectTypeId = 1 '
	
	-- Add meta Where clause
	if(LEN(@MetaSQLClause)>0)
		set @SelectMetaQuery_tmp = @SelectMetaQuery_tmp + ' AND ' + @MetaSQLClause + ' '

	-- Create from command
	SET @FromQuery_tmp = N'FROM CatalogNode' + N' INNER JOIN (select distinct U.[Key], U.Rank from (' + @SelectMetaQuery_tmp + N') U) META ON CatalogNode.CatalogNodeId = META.[Key] '

	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN CatalogNodeRelation NR ON CatalogNode.CatalogNodeId = NR.ChildNodeId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [Catalog] CR ON NR.CatalogId = NR.CatalogId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [Catalog] C ON C.CatalogId = CatalogNode.CatalogId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [CatalogNode] CN ON CatalogNode.ParentNodeId = CN.CatalogNodeId'
	set @FromQuery_tmp = @FromQuery_tmp + N' LEFT OUTER JOIN [CatalogNode] CNR ON NR.ParentNodeId = CNR.CatalogNodeId'

	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'CatalogNode.CatalogNodeId'
	end

	/* CATALOG AND NODE FILTERING */
	set @FilterQuery_tmp =  N' WHERE CatalogNode.ApplicationId = ''' + cast(@ApplicationId as nvarchar(100)) + ''' AND ((1=1'
	if(Len(@Catalogs) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (C.[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'

	if(Len(@CatalogNodes) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + REPLACE(@CatalogNodes,N'''',N'''''') + '''))))'
	else
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'

	set @FilterQuery_tmp = @FilterQuery_tmp + N' OR (1=1'
	if(Len(@Catalogs) != 0)
		set @FilterQuery_tmp = '' + @FilterQuery_tmp + N' AND (CR.[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'

	if(Len(@CatalogNodes) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (CNR.[Code] in (select Item from ecf_splitlist(''' + REPLACE(@CatalogNodes,N'''',N'''''') + '''))))'
	else
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'

	set @FilterQuery_tmp = @FilterQuery_tmp + N')'
	
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'

	set @FullQuery = N'SELECT count(CatalogNode.CatalogNodeId) OVER() TotalRecords, CatalogNode.CatalogNodeId, Rank, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, CatalogNodeId) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, CatalogNodeId FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
	set @FullQuery = 'declare @Page_temp table (TotalRecords int, CatalogNodeId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;INSERT INTO CatalogNodeSearchResults (SearchSetId, CatalogNodeId) SELECT ''' + cast(@SearchSetId as nvarchar(100)) + N''', CatalogNodeId from @Page_temp;'
	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
GO
--end creating [ecf_CatalogNodeSearch]

-- begin create SP [ecf_CatalogEntrySearch]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntrySearch]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntrySearch] 
GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntrySearch]
(
	@ApplicationId				uniqueidentifier,
	@SearchSetId				uniqueidentifier,
	@Language 					nvarchar(50),
	@Catalogs 					nvarchar(max),
	@CatalogNodes 				nvarchar(max),
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
	@KeywordPhrase				nvarchar(max),
	@OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
	@StartingRec				int,
	@NumRecords					int,
	@JoinType					nvarchar(50),
	@SourceTableName			sysname,
	@TargetQuery				nvarchar(max),
	@SourceJoinKey				sysname,
	@TargetJoinKey				sysname,
	@RecordCount				int OUTPUT,
	@ReturnTotalCount			bit = 1
)
AS
/*
	Last Updated: 
	September 2, 2008
		- corrected order for queries, should be ObjectId, Rank instead of Rank, ObjectId
	April 24, 2008
		- added support for joining tables
		- added language filters for meta fields
	April 8, 2008
		- added support for multiple catalog nodes, so when multiple nodes are specified,
		NodeEntryRelation table is not inner joined since that will produce repetetive entries
	April 2, 2008
		- fixed issue with entry in multiple categories and search done within multiple catalogs
		Now 3 types of queries recognized
		 - when only catalogs are specified, no NodeRelation table is joined and no soring is done
         - when one node filter is specified, sorting is enforced
         - when more than one node filter is specified, sort order is not available and
           noderelation table is not joined
	April 1, 2008 (Happy fools day!)
	    - added support for searching within localized table
	March 31, 2008
		- search couldn't display results with text type of data due to distinct statement,
		changed it '*' to U.[Key], U.[Rank]
	March 20, 2008
		- Added inner join for NodeRelation so we sort by SortOrder by default
	February 5, 2008
		- removed Meta.*, since it caused errors when multiple different meta classes were used
	Known issues:
		if item exists in two nodes and filter is requested for both nodes, the constraints error might happen
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @FilterVariables_tmp 		nvarchar(max)
	DECLARE @query_tmp 		nvarchar(max)
	DECLARE @FilterQuery_tmp 		nvarchar(max)
	declare @SelectMetaQuery_tmp nvarchar(max)
	declare @FromQuery_tmp nvarchar(max)
	declare @SelectCountQuery_tmp nvarchar(max)
	declare @FullQuery nvarchar(max)
	DECLARE @JoinQuery_tmp 		nvarchar(max)

	-- Precalculate length for constant strings
	DECLARE @MetaSQLClauseLength bigint
	DECLARE @KeywordPhraseLength bigint
	SET @MetaSQLClauseLength = LEN(@MetaSQLClause)
	SET @KeywordPhraseLength = LEN(@KeywordPhrase)

	set @RecordCount = -1

	-- ######## CREATE FILTER QUERY
	-- CREATE "JOINS" NEEDED
	-- Create filter query
	set @FilterQuery_tmp = N''
	--set @FilterQuery_tmp = N' INNER JOIN Catalog [Catalog] ON [Catalog].CatalogId = CatalogEntry.CatalogId'

	-- Only add NodeEntryRelation table join if one Node filter is specified, if more than one then we can't inner join it
	if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) <= 1)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN NodeEntryRelation NodeEntryRelation ON CatalogEntry.CatalogEntryId = NodeEntryRelation.CatalogEntryId'
	end
	
	-- If nodes specified, no need to filter by catalog since that is done in node filter
	if(Len(@CatalogNodes) = 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN @Catalogs_temp catalogs ON CatalogEntry.CatalogId = catalogs.CatalogId '
	end

	-- CREATE "WHERE" NEEDED
	set @FilterQuery_tmp = @FilterQuery_tmp + N' WHERE CatalogEntry.ApplicationId = ''' + cast(@ApplicationId as nvarchar(100)) + ''' '

	-- Search by Name in CatalogEntry
	IF(@KeywordPhraseLength>0)
		SET @FilterQuery_tmp = @FilterQuery_tmp + N' AND CatalogEntry.Name LIKE N''%' + @KeywordPhrase + '%'' ';	

	-- Different filter if more than one category is specified
	if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND CatalogEntry.CatalogEntryId in (select NodeEntryRelation.CatalogEntryId from NodeEntryRelation NodeEntryRelation where '
	end

	-- Add node filter, have to do this way to not produce multiple entry items
	if(Len(@CatalogNodes) != 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND NodeEntryRelation.CatalogNodeId IN (select CatalogNode.CatalogNodeId from CatalogNode CatalogNode'
		set @FilterQuery_tmp = @FilterQuery_tmp + N' WHERE (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + @CatalogNodes + '''))) AND NodeEntryRelation.CatalogId in (select * from @Catalogs_temp)'
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'
		--set @FilterQuery_tmp = @FilterQuery_tmp; + N' WHERE (CatalogNode.[Code] in (select Item from ecf_splitlist(''' + @CatalogNodes + ''')))'
	end

	-- Different filter if more than one category is specified
	if(Len(@CatalogNodes) != 0 and (select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N')'
	end

	--set @FilterQuery_tmp = @FilterQuery_tmp + N')'

	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'
	end

	-- Create from command	
	SET @FromQuery_tmp = N'FROM [CatalogEntry] CatalogEntry' 
	
	IF(@MetaSQLClauseLength>0)
	BEGIN
		SET @SelectMetaQuery_tmp = 'SELECT META.ObjectId AS ''Key'', 100 AS ''Rank'' FROM CatalogContentProperty META JOIN CatalogEntry ON CatalogEntry.CatalogEntryId = META.ObjectId WHERE META.ObjectTypeId = 0 AND ' + @MetaSQLClause
		SET @FromQuery_tmp = @FromQuery_tmp + N' INNER JOIN (select distinct U.[Key], MIN(U.Rank) AS Rank from (' + @SelectMetaQuery_tmp  + N') U GROUP BY U.[Key]) META ON CatalogEntry.[CatalogEntryId] = META.[Key] '
	END
			

	-- attach inner join if needed
	if(@JoinType is not null and Len(@JoinType) > 0)
	begin
		set @Query_tmp = ''
		EXEC [ecf_CreateTableJoinQuery] @SourceTableName, @TargetQuery, @SourceJoinKey, @TargetJoinKey, @JoinType, @Query_tmp OUT
		print(@Query_tmp)
		set @FromQuery_tmp = @FromQuery_tmp + N' ' + @Query_tmp
	end
	--print(@FromQuery_tmp)
	
	-- order by statement here
	if(Len(@OrderBy) = 0 and Len(@CatalogNodes) != 0 and CHARINDEX(',', @CatalogNodes) = 0)
	begin
		set @OrderBy = 'NodeEntryRelation.SortOrder'
	end
	else if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'CatalogEntry.CatalogEntryId'
	end

	--print(@FilterQuery_tmp)
	-- add catalogs temp variable that will be used to filter out catalogs
	set @FilterVariables_tmp = 'declare @Catalogs_temp table (CatalogId int);'
	set @FilterVariables_tmp = @FilterVariables_tmp + 'INSERT INTO @Catalogs_temp select CatalogId from Catalog'
	if(Len(RTrim(LTrim(@Catalogs)))>0)
		set @FilterVariables_tmp = @FilterVariables_tmp + ' WHERE ([Catalog].[Name] in (select Item from ecf_splitlist(''' + @Catalogs + ''')))'
	set @FilterVariables_tmp = @FilterVariables_tmp + ';'

	if(@ReturnTotalCount = 1) -- Only return count if we requested it
		begin
			set @FullQuery = N'SELECT count([CatalogEntry].CatalogEntryId) OVER() TotalRecords, [CatalogEntry].CatalogEntryId,  ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp
			-- use temp table variable
			set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, ObjectId, SortOrder) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, CatalogEntryId, RowNumber FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
			--print(@FullQuery)
			set @FullQuery = @FilterVariables_tmp + 'declare @Page_temp table (TotalRecords int,ObjectId int,SortOrder int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;INSERT INTO CatalogEntrySearchResults (SearchSetId, CatalogEntryId, SortOrder) SELECT ''' + cast(@SearchSetId as nvarchar(100)) + N''', ObjectId, SortOrder from @Page_temp;'
			exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT
			
			--print @FullQuery
			--exec(@FullQuery)			
		end
	else
		begin
			-- simplified query with no TotalRecords, should give some performance gain
			set @FullQuery = N'SELECT [CatalogEntry].CatalogEntryId, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp
			
			set @FullQuery = @FilterVariables_tmp + N'with OrderedResults as (' + @FullQuery +') INSERT INTO CatalogEntrySearchResults (SearchSetId, CatalogEntryId, SortOrder) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') ''' + cast(@SearchSetId as nvarchar(100)) + N''', CatalogEntryId, RowNumber FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
			--print(@FullQuery)
			--select * from CatalogEntrySearchResults
			exec(@FullQuery)
		end

	--print(@FullQuery)
	SET NOCOUNT OFF
END
GO
-- end create SP [ecf_CatalogEntrySearch]

-- create ecfVersion_ListMatchingSegments sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecfVersion_ListMatchingSegments]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_ListMatchingSegments]
GO
CREATE PROCEDURE [dbo].[ecfVersion_ListMatchingSegments]
	@ParentId INT,
	@SeoUriSegment NVARCHAR(255)
AS
BEGIN

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName
	FROM ecfVersion v
	INNER JOIN NodeEntryRelation r ON v.ObjectId = r.CatalogEntryId
	WHERE v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 0 AND v.CurrentLanguageRemoved = 0 AND r.CatalogNodeId = @ParentId

	UNION ALL

	SELECT v.ObjectId, v.ObjectTypeId, v.WorkId, v.LanguageName
	FROM ecfVersion v INNER JOIN CatalogNode n ON v.ObjectId = n.CatalogNodeId
	WHERE v.SeoUriSegment = @SeoUriSegment AND v.ObjectTypeId = 1 AND v.CurrentLanguageRemoved = 0 AND n.ParentNodeId = @ParentId

END
GO
-- end of creating ecfVersion_ListMatchingSegments sp

-- create CatalogContent_GetDefaultIndividualPublishStatus sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[CatalogContent_GetDefaultIndividualPublishStatus]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContent_GetDefaultIndividualPublishStatus]
GO
CREATE PROCEDURE [dbo].[CatalogContent_GetDefaultIndividualPublishStatus]
	@ObjectId int,
	@ObjectTypeId int
AS
BEGIN
	IF @ObjectTypeId = 0
		SELECT IsActive Epi_IsPublished, StartDate Epi_StartPublish, EndDate Epi_StopPublish FROM CatalogEntry WHERE CatalogEntryId = @ObjectId
	ELSE IF @ObjectTypeId = 1
		SELECT IsActive Epi_IsPublished, StartDate Epi_StartPublish, EndDate Epi_StopPublish FROM CatalogNode WHERE CatalogNodeId = @ObjectId
END
GO
-- end of creating CatalogContent_GetDefaultIndividualPublishStatus sp

-- Last statements block
-- execute mdpsp_sys_CreateMetaClassProcedureAll so we can generate ListSpecificRecord SPs, which will be used later when migrating data
EXECUTE dbo.mdpsp_sys_CreateMetaClassProcedureAll
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion
