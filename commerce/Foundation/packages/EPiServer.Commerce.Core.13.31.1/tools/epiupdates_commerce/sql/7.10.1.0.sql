--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 10, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

GO
PRINT N'Dropping FK_CatalogItemCategory_Catalog...';


GO
ALTER TABLE [dbo].[CatalogNodeRelation] DROP CONSTRAINT [FK_CatalogItemCategory_Catalog];


GO
PRINT N'Dropping FK_CatalogItemCategory_CatalogItem...';


GO
ALTER TABLE [dbo].[CatalogNodeRelation] DROP CONSTRAINT [FK_CatalogItemCategory_CatalogItem];


GO
PRINT N'Dropping FK_NodeEntryRelation_Catalog...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_Catalog];


GO
PRINT N'Dropping FK_NodeEntryRelation_CatalogEntry...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_CatalogEntry];


GO
PRINT N'Dropping FK_NodeEntryRelation_CatalogNode...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_CatalogNode];


GO
PRINT N'Starting rebuilding table [dbo].[CatalogNodeRelation]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_CatalogNodeRelation] (
    [CatalogId]    INT NOT NULL,
    [ParentNodeId] INT NOT NULL,
    [ChildNodeId]  INT NOT NULL,
    [SortOrder]    INT NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_CatalogNodeRelation] PRIMARY KEY CLUSTERED ([ChildNodeId] ASC, [ParentNodeId] ASC, [CatalogId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[CatalogNodeRelation])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_CatalogNodeRelation] ([ChildNodeId], [ParentNodeId], [CatalogId], [SortOrder])
        SELECT   [ChildNodeId],
                 [ParentNodeId],
                 [CatalogId],
                 [SortOrder]
        FROM     [dbo].[CatalogNodeRelation]
        ORDER BY [ChildNodeId] ASC, [ParentNodeId] ASC, [CatalogId] ASC;
    END

DROP TABLE [dbo].[CatalogNodeRelation];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_CatalogNodeRelation]', N'CatalogNodeRelation';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_CatalogNodeRelation]', N'PK_CatalogNodeRelation', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Starting rebuilding table [dbo].[NodeEntryRelation]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_NodeEntryRelation] (
    [CatalogId]      INT      NOT NULL,
    [CatalogEntryId] INT      NOT NULL,
    [CatalogNodeId]  INT      NOT NULL,
    [SortOrder]      INT      NOT NULL,
    [Modified]       DATETIME DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_NodeEntryRelation] PRIMARY KEY CLUSTERED ([CatalogEntryId] ASC, [CatalogNodeId] ASC, [CatalogId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[NodeEntryRelation])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_NodeEntryRelation] ([CatalogEntryId], [CatalogNodeId], [CatalogId], [SortOrder], [Modified])
        SELECT   [CatalogEntryId],
                 [CatalogNodeId],
                 [CatalogId],
                 [SortOrder],
                 [Modified]
        FROM     [dbo].[NodeEntryRelation]
        ORDER BY [CatalogEntryId] ASC, [CatalogNodeId] ASC, [CatalogId] ASC;
    END

DROP TABLE [dbo].[NodeEntryRelation];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_NodeEntryRelation]', N'NodeEntryRelation';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_NodeEntryRelation]', N'PK_NodeEntryRelation', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[NodeEntryRelation].[IX_NodeEntryRelation_Indexed_CatalogEntryId]...';


GO
CREATE NONCLUSTERED INDEX [IX_NodeEntryRelation_Indexed_CatalogEntryId]
    ON [dbo].[NodeEntryRelation]([CatalogEntryId] ASC)
    INCLUDE([CatalogId], [CatalogNodeId], [SortOrder]);


GO
PRINT N'Creating FK_CatalogItemCategory_Catalog...';


GO
ALTER TABLE [dbo].[CatalogNodeRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_CatalogItemCategory_Catalog] FOREIGN KEY ([CatalogId]) REFERENCES [dbo].[Catalog] ([CatalogId]);


GO
PRINT N'Creating FK_CatalogItemCategory_CatalogItem...';


GO
ALTER TABLE [dbo].[CatalogNodeRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_CatalogItemCategory_CatalogItem] FOREIGN KEY ([ChildNodeId]) REFERENCES [dbo].[CatalogNode] ([CatalogNodeId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating FK_NodeEntryRelation_Catalog...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_Catalog] FOREIGN KEY ([CatalogId]) REFERENCES [dbo].[Catalog] ([CatalogId]);


GO
PRINT N'Creating FK_NodeEntryRelation_CatalogEntry...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_CatalogEntry] FOREIGN KEY ([CatalogEntryId]) REFERENCES [dbo].[CatalogEntry] ([CatalogEntryId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating FK_NodeEntryRelation_CatalogNode...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_CatalogNode] FOREIGN KEY ([CatalogNodeId]) REFERENCES [dbo].[CatalogNode] ([CatalogNodeId]);


GO
PRINT N'Creating [dbo].[NodeEntryRelation_DeleteTrigger]...';


GO
CREATE trigger [dbo].[NodeEntryRelation_DeleteTrigger]
	on [dbo].[NodeEntryRelation]
	after delete
	as
	begin
		set nocount on
    
		insert into ApplicationLog ([Source], [Operation], [ObjectKey], [ObjectType], [Username], [Created], [Succeeded], [ApplicationId])
		select 'catalog', 'Modified', deleted.CatalogEntryId, 'relation', 'database-trigger', GETUTCDATE(), 1, ISNULL(app.ApplicationId, fallback_app.ApplicationId)
		from deleted
		left outer join Catalog app on deleted.CatalogEntryId = app.CatalogId
		cross join (select top 1 ApplicationId from Application) fallback_app
	end
GO
PRINT N'Creating [dbo].[NodeEntryRelation_UpsertTrigger]...';


GO
CREATE trigger [dbo].[NodeEntryRelation_UpsertTrigger]
	on [dbo].[NodeEntryRelation]
	after update, insert
	as
	begin
		set nocount on
    
		update [dbo].[NodeEntryRelation]
		set [Modified] = GETUTCDATE()
		from [dbo].[NodeEntryRelation] ner
		join inserted
			on ner.[CatalogId] = inserted.[CatalogId]
			and ner.[CatalogEntryId] = inserted.[CatalogEntryId]
			and ner.[CatalogNodeId] = inserted.[CatalogNodeId]
	end
GO
PRINT N'Altering [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncBatchPublishedVersion]
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

END
GO
PRINT N'Altering [dbo].[ecfVersionProperty_SyncPublishedVersion]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionProperty_SyncPublishedVersion]
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
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Save]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog_GetAllChildEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog_GetAllChildEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_ChildNodeCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_ChildNodeCount]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetAllChildNodes]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetAllChildNodes]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetDeleteResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetDeleteResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogRelation]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogRelation]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogRelation_NodeDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogRelation_NodeDelete]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogRelationByChildEntryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogRelationByChildEntryId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListMatchingSegments]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListMatchingSegments]';


GO
PRINT N'Refreshing [dbo].[mdpsp_GetChildBySegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_GetChildBySegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetAllChildEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetAllChildEntries]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecf_Catalog_GetChildrenEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Catalog_GetChildrenEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntrySearch_GetResults]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntrySearch_GetResults]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_ChildEntryCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_ChildEntryCount]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetChildrenEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetChildrenEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_NodeEntryRelations]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_NodeEntryRelations]';


GO
PRINT N'Refreshing [dbo].[ecf_PriceDetail_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PriceDetail_List]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogEntry]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 10, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
