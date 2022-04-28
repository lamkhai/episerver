--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 8, @minor int = 0, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery  

GO

-- add IsPrimary column to NodeEntryRelation table
IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'IsPrimary' AND Object_ID = Object_ID(N'NodeEntryRelation'))
	
BEGIN
	ALTER TABLE [dbo].[NodeEntryRelation]
	ADD	[IsPrimary] BIT NOT NULL DEFAULT 0
END
GO
-- end add IsPrimary column to NodeEntryRelation table

-- recreate NodeEntryRelation_UpsertTrigger
-- make sure QUOTED_IDENTIFIER is true to support partial index
SET QUOTED_IDENTIFIER ON

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[NodeEntryRelation_UpsertTrigger]'))
DROP TRIGGER [dbo].[NodeEntryRelation_UpsertTrigger]
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
-- end recreate NodeEntryRelation_UpsertTrigger

-- recreate NodeEntryRelation_DeleteTrigger
-- make sure QUOTED_IDENTIFIER is true to support partial index
SET QUOTED_IDENTIFIER ON

IF EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N'[dbo].[NodeEntryRelation_DeleteTrigger]'))
DROP TRIGGER [dbo].[NodeEntryRelation_DeleteTrigger]
GO

CREATE trigger [dbo].[NodeEntryRelation_DeleteTrigger]
	on [dbo].[NodeEntryRelation]
	after delete
	as
	begin
		set nocount on
    
		insert into ApplicationLog ([Source], [Operation], [ObjectKey], [ObjectType], [Username], [Created], [Succeeded])
		select 'catalog', 'Modified', deleted.CatalogEntryId, 'relation', 'database-trigger', GETUTCDATE(), 1
		from deleted 
	end
GO
-- end recreate NodeEntryRelation_DeleteTrigger

-- add IX_NodeEntryRelation_PrimaryRelation index
IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('dbo.NodeEntryRelation') AND NAME ='IX_NodeEntryRelation_PrimaryRelation')
    DROP INDEX [IX_NodeEntryRelation_PrimaryRelation] ON [dbo].[NodeEntryRelation]
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_NodeEntryRelation_PrimaryRelation]
    ON [dbo].[NodeEntryRelation] ([CatalogEntryId] ASC)
    WHERE [IsPrimary] = 1
GO
-- end add IX_NodeEntryRelation_PrimaryRelation index

-- set IsPrimary with value from relations with lowest sort order
;WITH cte AS
	(SELECT
		CatalogEntryId,
		CatalogNodeId,
		SortOrder,
        ROW_NUMBER() OVER (PARTITION BY CatalogEntryId ORDER BY SortOrder) AS RowNumber
    FROM
		NodeEntryRelation)
UPDATE
	NodeEntryRelation
SET
	IsPrimary = 1
FROM
	NodeEntryRelation R
INNER JOIN
	cte
ON
	R.CatalogEntryId = cte.CatalogEntryId AND
	R.CatalogNodeId = cte.CatalogNodeId AND
	cte.RowNumber = 1
GO
-- end set IsPrimary

-- update procedure ecf_Catalog_GetChildrenEntries
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Catalog_GetChildrenEntries]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Catalog_GetChildrenEntries]
GO

CREATE PROCEDURE [dbo].[ecf_Catalog_GetChildrenEntries]
	@CatalogId int
AS
BEGIN
	SELECT CE.CatalogId, CE.MetaClassId, CE.CatalogEntryId, ClassTypeId, 0 as CatalogNodeId, 0 as SortOrder
	FROM [dbo].CatalogEntry CE
	WHERE CE.CatalogId = @CatalogId
		AND NOT EXISTS(SELECT 1 FROM NodeEntryRelation R WHERE CE.CatalogEntryId = R.CatalogEntryId AND R.IsPrimary = 1)
	ORDER BY CE.Name
END
GO
-- end update procedure ecf_Catalog_GetChildrenEntries

-- update procedure ecf_CatalogEntry_List
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntry_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_List]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_List]
    @CatalogEntries dbo.udttEntityList READONLY,
	@ResponseGroup INT = NULL
AS
BEGIN
	SELECT n.*
	FROM CatalogEntry n
	JOIN @CatalogEntries r ON n.CatalogEntryId = r.EntityId
	ORDER BY r.SortOrder
	
	SELECT s.*
	FROM CatalogItemSeo s
	JOIN @CatalogEntries r ON s.CatalogEntryId = r.EntityId

	IF @ResponseGroup IS NULL
	BEGIN
		SELECT er.CatalogId, er.CatalogEntryId, er.CatalogNodeId, er.SortOrder, er.IsPrimary
		FROM NodeEntryRelation er
		JOIN @CatalogEntries r ON er.CatalogEntryId = r.EntityId
	END
	
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT EntityId from @CatalogEntries

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
-- end update procedure ecf_CatalogEntry_List

-- update procedure ecf_CatalogNode_CatalogParentNode
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNode_CatalogParentNode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNode_CatalogParentNode]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogNode_CatalogParentNode]
    @CatalogId int,
	@ParentNodeId int,
	@ReturnInactive bit = 0
AS
BEGIN

	SELECT N.[CatalogNodeId]
      ,N.[CatalogId]
      ,N.[StartDate]
      ,N.[EndDate]
      ,N.[Name]
      ,N.[TemplateName]
      ,N.[Code]
      ,N.[ParentNodeId]
      ,N.[MetaClassId]
      ,N.[IsActive]
      ,N.[ContentAssetsID]
      ,N.[ContentGuid], N.SortOrder AS SortOrder FROM [CatalogNode] N 
		WHERE (N.CatalogId = @CatalogId AND N.ParentNodeId = @ParentNodeId) AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	UNION 
	SELECT N.[CatalogNodeId]
      ,N.[CatalogId]
      ,N.[StartDate]
      ,N.[EndDate]
      ,N.[Name]
      ,N.[TemplateName]
      ,N.[Code]
      ,N.[ParentNodeId]
      ,N.[MetaClassId]
      ,N.[IsActive]
      ,N.[ContentAssetsID]
      ,N.[ContentGuid], NR.SortOrder AS SortOrder FROM [CatalogNode] N LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
		WHERE 		(NR.CatalogId = @CatalogId AND NR.ParentNodeId = @ParentNodeId) AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY SortOrder

	SELECT S.* from CatalogItemSeo S WHERE CatalogNodeId IN
	(SELECT DISTINCT N.CatalogNodeId from [CatalogNode] N
		LEFT OUTER JOIN CatalogNodeRelation NR ON N.CatalogNodeId = NR.ChildNodeId
		WHERE
			((N.CatalogId = @CatalogId AND N.ParentNodeId = @ParentNodeId) OR (NR.CatalogId = @CatalogId AND NR.ParentNodeId = @ParentNodeId)) AND
			((N.IsActive = 1) or @ReturnInactive = 1))

END
GO
-- end update procedure ecf_CatalogNode_CatalogParentNode


-- update procedure ecf_CatalogRelation
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogRelation]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogRelation]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogRelation]
	@ApplicationId UNIQUEIDENTIFIER,
	@CatalogId INT,
	@CatalogNodeId INT,
	@CatalogEntryId INT,
	@GroupName NVARCHAR(100),
	@ResponseGroup INT
AS
BEGIN
	DECLARE @CatalogNode AS INT
	DECLARE @CatalogEntry AS INT
	DECLARE @NodeEntry AS INT

	SET @CatalogNode = 1
	SET @CatalogEntry = 2
	SET @NodeEntry = 4

	IF(@ResponseGroup & @CatalogNode = @CatalogNode)
		SELECT CNR.* FROM CatalogNodeRelation CNR
		INNER JOIN CatalogNode CN ON CN.CatalogNodeId = CNR.ParentNodeId AND (CN.CatalogId = @CatalogId OR @CatalogId = 0)
		WHERE CN.ApplicationId = @ApplicationId AND (@CatalogNodeId = 0 OR CNR.ParentNodeId = @CatalogNodeId)
		ORDER BY CNR.SortOrder
	ELSE
		SELECT TOP 0 * FROM CatalogNodeRelation

	IF(@ResponseGroup & @CatalogEntry = @CatalogEntry)
	BEGIN
		IF (@CatalogNodeId = 0)
		BEGIN
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE CE.ApplicationId = @ApplicationId AND (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE CE.ApplicationId = @ApplicationId AND
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
		ELSE --We must filter by CatalogNodeId when getting CatalogEntryRelation if the @CatalogNodeId is different from zero, so that we don't get redundant data.
		BEGIN		
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE CE.ApplicationId = @ApplicationId AND (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE CE.ApplicationId = @ApplicationId AND
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
	END
	ELSE
		SELECT TOP 0 * FROM CatalogEntryRelation

	IF(@ResponseGroup & @NodeEntry = @NodeEntry)
	BEGIN
		DECLARE @execStmt NVARCHAR(1000)
		SET @execStmt = 'SELECT NER.CatalogId, NER.CatalogEntryId, NER.CatalogNodeId, NER.SortOrder, NER.IsPrimary FROM NodeEntryRelation NER
						 INNER JOIN [Catalog] C ON C.CatalogId = NER.CatalogId
						 WHERE C.ApplicationId = @ApplicationId '
		
		IF @CatalogId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogId = @CatalogId) '
		IF @CatalogNodeId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogNodeId = @CatalogNodeId) '
		IF @CatalogEntryId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogEntryId = @CatalogEntryId) '

		SET @execStmt = @execStmt + ' ORDER BY NER.SortOrder'
		
		DECLARE @pars NVARCHAR(500)
		SET @pars = '@ApplicationId uniqueidentifier, @CatalogId int, @CatalogNodeId int, @CatalogEntryId int'
		EXEC sp_executesql @execStmt, @pars,
			@ApplicationId=@ApplicationId, @CatalogId=@CatalogId, @CatalogNodeId=@CatalogNodeId, @CatalogEntryId=@CatalogEntryId
	END
	ELSE
		SELECT TOP 0 CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary FROM NodeEntryRelation
END
GO
-- end update procedure ecf_CatalogRelation

-- update procedure ecf_CatalogRelationByChildEntryId
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogRelationByChildEntryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogRelationByChildEntryId]
GO

CREATE PROCEDURE [dbo].[ecf_CatalogRelationByChildEntryId]
	@ApplicationId uniqueidentifier,
	@ChildEntryId int
AS
BEGIN
    select top 0 * from CatalogNodeRelation

	SELECT CER.* FROM CatalogEntryRelation CER
	INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ChildEntryId
	WHERE
		CE.ApplicationId = @ApplicationId AND
		CER.ChildEntryId = @ChildEntryId
	ORDER BY CER.SortOrder
	
	SELECT CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary FROM NodeEntryRelation
	WHERE CatalogEntryId=@ChildEntryId
END
GO
-- end update procedure ecf_CatalogRelationByChildEntryId

-- update procedure ecf_CatalogRelation_NodeDelete
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogRelation_NodeDelete]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogRelation_NodeDelete]
GO

create procedure [dbo].[ecf_CatalogRelation_NodeDelete]
    @CatalogEntries dbo.udttEntityList readonly,
    @CatalogNodes dbo.udttEntityList readonly
as
begin
    select * from CatalogNodeRelation cnr where 0=1
    
    select *
    from CatalogEntryRelation
    where ParentEntryId in (select EntityId from @CatalogEntries)
       or ChildEntryId in (select EntityId from @CatalogEntries)
       
    select CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary
    from NodeEntryRelation
    where CatalogEntryId in (select EntityId from @CatalogEntries)
       or CatalogNodeId in (select EntityId from @CatalogNodes)
end
GO
-- end update procedure ecf_CatalogRelation_NodeDelete

-- update procedure ecf_NodeEntryRelations
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_NodeEntryRelations]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_NodeEntryRelations]
GO

CREATE PROCEDURE [dbo].[ecf_NodeEntryRelations]
	@ContentList udttContentList readonly
AS
BEGIN
	Select NodeEntryRelation.CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary
	FROM NodeEntryRelation
	INNER JOIN @ContentList as idTable on idTable.ContentId = NodeEntryRelation.CatalogEntryId
END
GO
-- end update procedure ecf_NodeEntryRelations

-- update procedure ecfVersion_ListByWorkIds
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecfVersion_ListByWorkIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
GO

CREATE PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
	@ContentLinks dbo.udttObjectWorkId readonly
AS
BEGIN
	SELECT draft.*,e.ApplicationId, e.ContentGuid, e.ClassTypeId, e.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId 
	INNER JOIN CatalogEntry e ON links.ObjectId = e.CatalogEntryId AND draft.ObjectId = e.CatalogEntryId
	LEFT JOIN CatalogContentProperty p ON p.ObjectId = draft.ObjectId AND p.ObjectTypeId = draft.ObjectTypeId AND p.MetaClassId = e.MetaClassId
										AND p.LanguageName = draft.LanguageName COLLATE DATABASE_DEFAULT 
										AND p.MetaFieldName = 'Epi_IsPublished' COLLATE DATABASE_DEFAULT
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 0 -- entry

	UNION ALL

	SELECT draft.*, c.ApplicationId, c.ContentGuid, NULL AS ClassTypeId, NULL AS MetaClassId, c.IsActive AS IsPublished, NULL AS ParentId 
	FROM ecfVersion AS draft
	INNER JOIN @ContentLinks links ON draft.WorkId = links.WorkId
	INNER JOIN [Catalog] c ON c.CatalogId = links.ObjectId
	WHERE [dbo].ecf_IsCurrentLanguageRemoved(draft.CatalogId, draft.LanguageName) = 0 AND links.ObjectTypeId = 2  -- catalog

	UNION ALL

	SELECT draft.*, n.ApplicationId, n.ContentGuid, NULL AS ClassTypeId, n.MetaClassId, ISNULL(p.Boolean, 0) AS IsPublished, n.ParentNodeId AS ParentId 
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
-- end update procedure ecfVersion_ListByWorkIds

-- add procedure ecf_GetCatalogEntryIdsByContentGuids
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryIdsByContentGuids]
	@CatalogGuids udttContentGuidList READONLY
AS
BEGIN
	SELECT e.ContentGuid, e.CatalogEntryId from [CatalogEntry] e
	INNER JOIN @CatalogGuids k ON e.ContentGuid = k.ContentGuid
END
-- end add procedure ecf_GetCatalogEntryIdsByContentGuids

PRINT N'Altering [dbo].[PromotionInformationGetOrders]...';

GO

ALTER PROCEDURE [dbo].[PromotionInformationGetOrders]
	@ContentGuidList [dbo].[udttContentGuidList] READONLY
AS
BEGIN
	SELECT P.PromotionGuid, COUNT(DISTINCT(F.OrderGroupId)) AS OrderGroupCount
	FROM PromotionInformation P
		INNER JOIN OrderForm F
		ON F.OrderFormId = P.OrderFormId 
		INNER JOIN @ContentGuidList C ON C.ContentGuid = P.PromotionGuid
	WHERE P.IsRedeemed = 1
	GROUP BY P.PromotionGuid
	WITH ROLLUP
END

GO

PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';

GO

EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogParentNodeCode]';

GO

PRINT N'Dropping [dbo].[CatalogItemSeo].[IX_CatalogItemSeo_UniqueSegment_CatalogEntry]...';


GO
DROP INDEX [IX_CatalogItemSeo_UniqueSegment_CatalogEntry] ON [dbo].[CatalogItemSeo];


GO
PRINT N'Dropping [dbo].[OrderGroup].[IX_OrderGroup_CustomerIdName]...';


GO
DROP INDEX [IX_OrderGroup_CustomerIdName] ON [dbo].[OrderGroup];


GO
PRINT N'Dropping [dbo].[OrderGroup].[IX_OrderGroup_ApplicationId]...';


GO
DROP INDEX [IX_OrderGroup_ApplicationId] ON [dbo].[OrderGroup];


GO

GO
PRINT N'Dropping [dbo].[DF_PriceDetail_PriceCode]...';


GO
ALTER TABLE [dbo].[PriceDetail] DROP CONSTRAINT [DF_PriceDetail_PriceCode];


GO
PRINT N'Dropping [dbo].[DF_PriceGroup_PriceCode]...';


GO
ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [DF_PriceGroup_PriceCode];


GO
PRINT N'Dropping [dbo].[FK_NodeEntryRelation_Catalog]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_Catalog];


GO
PRINT N'Dropping [dbo].[FK_NodeEntryRelation_CatalogEntry]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_CatalogEntry];


GO
PRINT N'Dropping [dbo].[FK_NodeEntryRelation_CatalogNode]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] DROP CONSTRAINT [FK_NodeEntryRelation_CatalogNode];


GO
PRINT N'Dropping [dbo].[FK_ManagedInventory_CatalogEntry]...';


GO
ALTER TABLE [dbo].[InventoryService] DROP CONSTRAINT [FK_ManagedInventory_CatalogEntry];


GO
PRINT N'Dropping [dbo].[FK_PriceDetail_CatalogEntry]...';


GO
ALTER TABLE [dbo].[PriceDetail] DROP CONSTRAINT [FK_PriceDetail_CatalogEntry];


GO
PRINT N'Dropping [dbo].[FK_PriceGroup_CatalogEntry]...';


GO
ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [FK_PriceGroup_CatalogEntry];


GO
PRINT N'Dropping [dbo].[FK_ManagedInventory_Warehouse]...';


GO
ALTER TABLE [dbo].[InventoryService] DROP CONSTRAINT [FK_ManagedInventory_Warehouse];


GO
PRINT N'Dropping [dbo].[FK_WarehouseInventory_Warehouse]...';


GO
ALTER TABLE [dbo].[WarehouseInventory] DROP CONSTRAINT [FK_WarehouseInventory_Warehouse];


GO
PRINT N'Dropping [dbo].[FK_PriceDetail_Currency]...';


GO
ALTER TABLE [dbo].[PriceDetail] DROP CONSTRAINT [FK_PriceDetail_Currency];


GO
PRINT N'Dropping [dbo].[FK_PriceDetail_Market]...';


GO
ALTER TABLE [dbo].[PriceDetail] DROP CONSTRAINT [FK_PriceDetail_Market];


GO
PRINT N'Dropping [dbo].[FK_PriceDetail_PriceType]...';


GO
ALTER TABLE [dbo].[PriceDetail] DROP CONSTRAINT [FK_PriceDetail_PriceType];


GO
PRINT N'Dropping [dbo].[FK_PriceGroup_Currency]...';


GO
ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [FK_PriceGroup_Currency];


GO
PRINT N'Dropping [dbo].[FK_PriceGroup_Market]...';


GO
ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [FK_PriceGroup_Market];


GO
PRINT N'Dropping [dbo].[FK_PriceGroup_PriceType]...';


GO
ALTER TABLE [dbo].[PriceGroup] DROP CONSTRAINT [FK_PriceGroup_PriceType];


GO
PRINT N'Dropping [dbo].[FK_PriceValue_PriceGroup]...';


GO
ALTER TABLE [dbo].[PriceValue] DROP CONSTRAINT [FK_PriceValue_PriceGroup];


GO
PRINT N'Dropping [dbo].[FK_ApplicationLog_Application]...';


GO
ALTER TABLE [dbo].[ApplicationLog] DROP CONSTRAINT [FK_ApplicationLog_Application];


GO
PRINT N'Dropping [dbo].[IX_CatalogEntity]...';


GO
ALTER TABLE [dbo].[CatalogEntry] DROP CONSTRAINT [IX_CatalogEntity];


GO
PRINT N'Dropping [dbo].[IX_CatalogItem]...';


GO
ALTER TABLE [dbo].[CatalogNode] DROP CONSTRAINT [IX_CatalogItem];


GO
PRINT N'Dropping [dbo].[IX_PaymentMethod]...';


GO
ALTER TABLE [dbo].[PaymentMethod] DROP CONSTRAINT [IX_PaymentMethod];


GO
PRINT N'Dropping [dbo].[IX_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethod] DROP CONSTRAINT [IX_ShippingMethod];


GO
PRINT N'Dropping [dbo].[IX_ShippingOption]...';


GO
ALTER TABLE [dbo].[ShippingOption] DROP CONSTRAINT [IX_ShippingOption];


GO
PRINT N'Dropping [dbo].[IX_Tax]...';


GO
ALTER TABLE [dbo].[Tax] DROP CONSTRAINT [IX_Tax];


GO
PRINT N'Dropping [dbo].[IX_Warehouse]...';


GO
ALTER TABLE [dbo].[Warehouse] DROP CONSTRAINT [IX_Warehouse];


GO
PRINT N'Dropping [dbo].[AX_Application_Name]...';


GO
ALTER TABLE [dbo].[Application] DROP CONSTRAINT [AX_Application_Name];


GO
PRINT N'Dropping [dbo].[ecf_GetCatalogEntryCodesByIds]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_GetCatalogEntryCodesByIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogEntryCodesByIds];


GO
PRINT N'Dropping [dbo].[ecf_GetCatalogEntryIdsByCodes]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_GetCatalogEntryIdsByCodes]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogEntryIdsByCodes];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment];


GO
PRINT N'Dropping [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriAndUriSegment];


GO
PRINT N'Dropping [dbo].[ecf_GetCatalogNodeCodesByIds]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_GetCatalogNodeCodesByIds]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogNodeCodesByIds];


GO
PRINT N'Dropping [dbo].[ecf_GetCatalogNodeIdsByCodes]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_GetCatalogNodeIdsByCodes]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GetCatalogNodeIdsByCodes];


GO
PRINT N'Dropping [dbo].[ecf_Currency_Modify]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Currency_Modify]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Currency_Modify];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_AdjustInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_AdjustInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_AdjustInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_DeleteInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_DeleteInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_DeleteInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_GetInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_GetInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_GetInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_InsertInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_InsertInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_InsertInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_QueryInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_QueryInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_QueryInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_QueryInventoryPaged]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_QueryInventoryPaged]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_QueryInventoryPaged];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_SaveInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_SaveInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_SaveInventory];


GO
PRINT N'Dropping [dbo].[ecf_Inventory_UpdateInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Inventory_UpdateInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Inventory_UpdateInventory];


GO
PRINT N'Dropping [dbo].[ecf_PriceDetail_ReplacePrices]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_PriceDetail_ReplacePrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_PriceDetail_ReplacePrices];


GO
PRINT N'Dropping [dbo].[ecf_PriceDetail_Save]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_PriceDetail_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_PriceDetail_Save];


GO
PRINT N'Dropping [dbo].[ecf_Pricing_GetCatalogEntryPrices]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Pricing_GetCatalogEntryPrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Pricing_GetCatalogEntryPrices];


GO
PRINT N'Dropping [dbo].[ecf_Pricing_GetPrices]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Pricing_GetPrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Pricing_GetPrices];


GO
PRINT N'Dropping [dbo].[ecf_Pricing_SetCatalogEntryPrices]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Pricing_SetCatalogEntryPrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Pricing_SetCatalogEntryPrices];


GO
PRINT N'Dropping [dbo].[ecf_Warehouse_Save]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_Warehouse_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Warehouse_Save];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetInventories]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_GetInventories]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_GetInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetInventory];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteInventories]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_DeleteInventories]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteInventory]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_DeleteInventory]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteInventory];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_SaveInventories]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_WarehouseInventory_SaveInventories]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_WarehouseInventory_SaveInventories];


GO
PRINT N'Dropping [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUriSegment];


GO
PRINT N'Dropping [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry]...';


GO
IF EXISTS (SELECT * FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fn_UriSegmentExistsOnSiblingNodeOrEntry' AND Routine_Type = 'FUNCTION' ) DROP FUNCTION [dbo].[fn_UriSegmentExistsOnSiblingNodeOrEntry];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUri]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment];


GO
PRINT N'Dropping [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]...';


GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_CatalogNodeItemSeo_ValidateUri]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri];


GO
PRINT N'Dropping [dbo].[udttCatalogCodeId]...';


GO
DROP TYPE [dbo].[udttCatalogCodeId];


GO
PRINT N'Dropping [dbo].[udttCatalogEntryPrice]...';


GO
DROP TYPE [dbo].[udttCatalogEntryPrice];


GO
PRINT N'Dropping [dbo].[udttCatalogItemSeo]...';


GO
DROP TYPE [dbo].[udttCatalogItemSeo];


GO
PRINT N'Dropping [dbo].[udttCatalogKey]...';


GO
DROP TYPE [dbo].[udttCatalogKey];


GO
PRINT N'Dropping [dbo].[udttCatalogKeyAndQuantity]...';


GO
DROP TYPE [dbo].[udttCatalogKeyAndQuantity];


GO
PRINT N'Dropping [dbo].[udttCompatCurrency]...';


GO
DROP TYPE [dbo].[udttCompatCurrency];


GO
PRINT N'Dropping [dbo].[udttInventory]...';


GO
DROP TYPE [dbo].[udttInventory];


GO
PRINT N'Dropping [dbo].[udttInventoryCode]...';


GO
DROP TYPE [dbo].[udttInventoryCode];


GO
PRINT N'Dropping [dbo].[udttPriceDetail]...';


GO
DROP TYPE [dbo].[udttPriceDetail];


GO
PRINT N'Dropping [dbo].[udttWarehouse]...';


GO
DROP TYPE [dbo].[udttWarehouse];


GO
PRINT N'Dropping [dbo].[udttWarehouseInventory]...';


GO
DROP TYPE [dbo].[udttWarehouseInventory];


GO
PRINT N'Creating [dbo].[udttCatalogCodeId]...';


GO
CREATE TYPE [dbo].[udttCatalogCodeId] AS TABLE (
    [ObjectId] INT            NULL,
    [Code]     NVARCHAR (100) NULL);


GO
PRINT N'Creating [dbo].[udttCatalogEntryPrice]...';


GO
CREATE TYPE [dbo].[udttCatalogEntryPrice] AS TABLE (
    [CatalogEntryCode] NVARCHAR (100)  NOT NULL,
    [MarketId]         NVARCHAR (8)    NOT NULL,
    [CurrencyCode]     NVARCHAR (8)    NOT NULL,
    [PriceTypeId]      INT             NOT NULL,
    [PriceCode]        NVARCHAR (256)  NOT NULL,
    [ValidFrom]        DATETIME        NOT NULL,
    [ValidUntil]       DATETIME        NULL,
    [MinQuantity]      DECIMAL (38, 9) NOT NULL,
    [MaxQuantity]      DECIMAL (38, 9) NULL,
    [UnitPrice]        DECIMAL (38, 9) NOT NULL);


GO
PRINT N'Creating [dbo].[udttCatalogItemSeo]...';


GO
CREATE TYPE [dbo].[udttCatalogItemSeo] AS TABLE (
    [LanguageCode]   NVARCHAR (50)  NOT NULL,
    [CatalogNodeId]  INT            NULL,
    [CatalogEntryId] INT            NULL,
    [Uri]            NVARCHAR (255) NOT NULL,
    [UriSegment]     NVARCHAR (255) NULL);


GO
PRINT N'Creating [dbo].[udttCatalogKey]...';


GO
CREATE TYPE [dbo].[udttCatalogKey] AS TABLE (
    [CatalogEntryCode] NVARCHAR (100) NOT NULL);


GO
PRINT N'Creating [dbo].[udttCatalogKeyAndQuantity]...';


GO
CREATE TYPE [dbo].[udttCatalogKeyAndQuantity] AS TABLE (
    [CatalogEntryCode] NVARCHAR (100)  NOT NULL,
    [Quantity]         DECIMAL (38, 9) NOT NULL);


GO
PRINT N'Creating [dbo].[udttCompatCurrency]...';


GO
CREATE TYPE [dbo].[udttCompatCurrency] AS TABLE (
    [Operation]    CHAR (1)      NULL,
    [CurrencyId]   INT           NULL,
    [CurrencyCode] NVARCHAR (8)  NULL,
    [Name]         NVARCHAR (50) NULL,
    [ModifiedDate] DATETIME      NULL);


GO
PRINT N'Creating [dbo].[udttInventory]...';


GO
CREATE TYPE [dbo].[udttInventory] AS TABLE (
    [CatalogEntryCode]           NVARCHAR (100)  NULL,
    [WarehouseCode]              NVARCHAR (50)   NULL,
    [IsTracked]                  BIT             NULL,
    [PurchaseAvailableQuantity]  DECIMAL (38, 9) NULL,
    [PreorderAvailableQuantity]  DECIMAL (38, 9) NULL,
    [BackorderAvailableQuantity] DECIMAL (38, 9) NULL,
    [PurchaseRequestedQuantity]  DECIMAL (38, 9) NULL,
    [PreorderRequestedQuantity]  DECIMAL (38, 9) NULL,
    [BackorderRequestedQuantity] DECIMAL (38, 9) NULL,
    [PurchaseAvailableUtc]       DATETIME2 (7)   NULL,
    [PreorderAvailableUtc]       DATETIME2 (7)   NULL,
    [BackorderAvailableUtc]      DATETIME2 (7)   NULL,
    [AdditionalQuantity]         DECIMAL (38, 9) NULL,
    [ReorderMinQuantity]         DECIMAL (38, 9) NULL);


GO
PRINT N'Creating [dbo].[udttInventoryCode]...';


GO
CREATE TYPE [dbo].[udttInventoryCode] AS TABLE (
    [Code] NVARCHAR (100) NOT NULL,
    PRIMARY KEY CLUSTERED ([Code] ASC));


GO
PRINT N'Creating [dbo].[udttPriceDetail]...';


GO
CREATE TYPE [dbo].[udttPriceDetail] AS TABLE (
    [PriceValueId]     BIGINT          NOT NULL,
    [CatalogEntryCode] NVARCHAR (100)  NULL,
    [MarketId]         NVARCHAR (8)    NULL,
    [CurrencyCode]     NVARCHAR (8)    NULL,
    [PriceTypeId]      INT             NULL,
    [PriceCode]        NVARCHAR (256)  NULL,
    [ValidFrom]        DATETIME        NULL,
    [ValidUntil]       DATETIME        NULL,
    [MinQuantity]      DECIMAL (38, 9) NULL,
    [UnitPrice]        DECIMAL (38, 9) NULL);


GO
PRINT N'Creating [dbo].[udttWarehouse]...';


GO
CREATE TYPE [dbo].[udttWarehouse] AS TABLE (
    [WarehouseId]         INT            NULL,
    [Name]                NVARCHAR (255) NOT NULL,
    [CreatorId]           NVARCHAR (100) NOT NULL,
    [Created]             DATETIME       NOT NULL,
    [ModifierId]          NVARCHAR (100) NOT NULL,
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
PRINT N'Creating [dbo].[udttWarehouseInventory]...';


GO
CREATE TYPE [dbo].[udttWarehouseInventory] AS TABLE (
    [WarehouseCode]             NVARCHAR (50)  NOT NULL,
    [CatalogEntryCode]          NVARCHAR (100) NOT NULL,
    [InStockQuantity]           DECIMAL (18)   NOT NULL,
    [ReservedQuantity]          DECIMAL (18)   NOT NULL,
    [ReorderMinQuantity]        DECIMAL (18)   NOT NULL,
    [PreorderQuantity]          DECIMAL (18)   NOT NULL,
    [BackorderQuantity]         DECIMAL (18)   NOT NULL,
    [AllowPreorder]             BIT            NOT NULL,
    [AllowBackorder]            BIT            NOT NULL,
    [InventoryStatus]           INT            NOT NULL,
    [PreorderAvailabilityDate]  DATETIME       NOT NULL,
    [BackorderAvailabilityDate] DATETIME       NOT NULL);


GO
PRINT N'Starting rebuilding table [dbo].[Application]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_Application] (
    [Name]     NVARCHAR (200) NOT NULL,
    [IsActive] BIT            NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_Application_Name1] PRIMARY KEY CLUSTERED ([Name] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[Application])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_Application] ([Name], [IsActive])
        SELECT   [Name],
                 [IsActive]
        FROM     [dbo].[Application]
        ORDER BY [Name] ASC;
    END

DROP TABLE [dbo].[Application];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_Application]', N'Application';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_Application_Name1]', N'PK_Application_Name', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[ApplicationLog]...';


GO
ALTER TABLE [dbo].[ApplicationLog] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Campaign]...';


GO
ALTER TABLE [dbo].[Campaign] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Catalog]...';


GO
ALTER TABLE [dbo].[Catalog] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[CatalogEntry]...';


GO
ALTER TABLE [dbo].[CatalogEntry] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_CatalogEntity]...';


GO
ALTER TABLE [dbo].[CatalogEntry]
    ADD CONSTRAINT [IX_CatalogEntity] UNIQUE NONCLUSTERED ([Code] ASC);


GO
PRINT N'Altering [dbo].[CatalogEntrySearchResults_SingleSort]...';


GO
ALTER TABLE [dbo].[CatalogEntrySearchResults_SingleSort] DROP COLUMN [ApplicationId];


GO
PRINT N'Starting rebuilding table [dbo].[CatalogItemSeo]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_CatalogItemSeo] (
    [LanguageCode]   NVARCHAR (50)  NOT NULL,
    [CatalogNodeId]  INT            NULL,
    [CatalogEntryId] INT            NULL,
    [Uri]            NVARCHAR (255) NOT NULL,
    [Title]          NVARCHAR (150) NULL,
    [Description]    NVARCHAR (355) NULL,
    [Keywords]       NVARCHAR (355) NULL,
    [UriSegment]     NVARCHAR (255) NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_CatalogItemSeo1] PRIMARY KEY CLUSTERED ([Uri] ASC, [LanguageCode] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[CatalogItemSeo])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_CatalogItemSeo] ([Uri], [LanguageCode], [CatalogNodeId], [CatalogEntryId], [Title], [Description], [Keywords], [UriSegment])
        SELECT   [Uri],
                 [LanguageCode],
                 [CatalogNodeId],
                 [CatalogEntryId],
                 [Title],
                 [Description],
                 [Keywords],
                 [UriSegment]
        FROM     [dbo].[CatalogItemSeo]
        ORDER BY [Uri] ASC, [LanguageCode] ASC;
    END

DROP TABLE [dbo].[CatalogItemSeo];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_CatalogItemSeo]', N'CatalogItemSeo';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_CatalogItemSeo1]', N'PK_CatalogItemSeo', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[CatalogItemSeo].[IX_CatalogItemSeo_UniqueSegment_CatalogEntry]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogItemSeo_UniqueSegment_CatalogEntry]
    ON [dbo].[CatalogItemSeo]([UriSegment] ASC, [CatalogEntryId] ASC);


GO
PRINT N'Creating [dbo].[CatalogItemSeo].[IX_CatalogItemSeo_CatalogEntryId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogItemSeo_CatalogEntryId]
    ON [dbo].[CatalogItemSeo]([CatalogEntryId] ASC);


GO
PRINT N'Creating [dbo].[CatalogItemSeo].[IX_CatalogItemSeo_CatalogNodeId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogItemSeo_CatalogNodeId]
    ON [dbo].[CatalogItemSeo]([CatalogNodeId] ASC);


GO
PRINT N'Altering [dbo].[CatalogLog]...';


GO
ALTER TABLE [dbo].[CatalogLog] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[CatalogNode]...';


GO
ALTER TABLE [dbo].[CatalogNode] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_CatalogItem]...';


GO
ALTER TABLE [dbo].[CatalogNode]
    ADD CONSTRAINT [IX_CatalogItem] UNIQUE NONCLUSTERED ([Code] ASC);


GO
PRINT N'Altering [dbo].[CommonSettings]...';


GO
ALTER TABLE [dbo].[CommonSettings] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Country]...';


GO
ALTER TABLE [dbo].[Country] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Currency]...';


GO
ALTER TABLE [dbo].[Currency] DROP COLUMN [CompatApplicationId];


GO
PRINT N'Altering [dbo].[Expression]...';


GO
ALTER TABLE [dbo].[Expression] DROP COLUMN [ApplicationId];


GO
PRINT N'Starting rebuilding table [dbo].[InventoryService]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_InventoryService] (
    [CatalogEntryCode]           NVARCHAR (100)  NOT NULL,
    [WarehouseCode]              NVARCHAR (50)   NOT NULL,
    [IsTracked]                  BIT             NOT NULL,
    [PurchaseAvailableQuantity]  DECIMAL (38, 9) NOT NULL,
    [PreorderAvailableQuantity]  DECIMAL (38, 9) NOT NULL,
    [BackorderAvailableQuantity] DECIMAL (38, 9) NOT NULL,
    [PurchaseRequestedQuantity]  DECIMAL (38, 9) NOT NULL,
    [PreorderRequestedQuantity]  DECIMAL (38, 9) NOT NULL,
    [BackorderRequestedQuantity] DECIMAL (38, 9) NOT NULL,
    [PreorderAvailableUtc]       DATETIME2 (7)   NOT NULL,
    [PurchaseAvailableUtc]       DATETIME2 (7)   NOT NULL,
    [BackorderAvailableUtc]      DATETIME2 (7)   NOT NULL,
    [AdditionalQuantity]         DECIMAL (38, 9) NOT NULL,
    [ReorderMinQuantity]         DECIMAL (38, 9) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_ManagedInventory1] PRIMARY KEY CLUSTERED ([CatalogEntryCode] ASC, [WarehouseCode] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[InventoryService])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_InventoryService] ([CatalogEntryCode], [WarehouseCode], [IsTracked], [PurchaseAvailableQuantity], [PreorderAvailableQuantity], [BackorderAvailableQuantity], [PurchaseRequestedQuantity], [PreorderRequestedQuantity], [BackorderRequestedQuantity], [PreorderAvailableUtc], [PurchaseAvailableUtc], [BackorderAvailableUtc], [AdditionalQuantity], [ReorderMinQuantity])
        SELECT   [CatalogEntryCode],
                 [WarehouseCode],
                 [IsTracked],
                 [PurchaseAvailableQuantity],
                 [PreorderAvailableQuantity],
                 [BackorderAvailableQuantity],
                 [PurchaseRequestedQuantity],
                 [PreorderRequestedQuantity],
                 [BackorderRequestedQuantity],
                 [PreorderAvailableUtc],
                 [PurchaseAvailableUtc],
                 [BackorderAvailableUtc],
                 [AdditionalQuantity],
                 [ReorderMinQuantity]
        FROM     [dbo].[InventoryService]
        ORDER BY [CatalogEntryCode] ASC, [WarehouseCode] ASC;
    END

DROP TABLE [dbo].[InventoryService];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_InventoryService]', N'InventoryService';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_ManagedInventory1]', N'PK_ManagedInventory', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[Jurisdiction]...';


GO
ALTER TABLE [dbo].[Jurisdiction] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[JurisdictionGroup]...';


GO
ALTER TABLE [dbo].[JurisdictionGroup] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Merchant]...';


GO
ALTER TABLE [dbo].[Merchant] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[OrderGroup]...';


GO
ALTER TABLE [dbo].[OrderGroup] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[OrderGroup].[IX_OrderGroup_CustomerIdName]...';


GO
CREATE NONCLUSTERED INDEX [IX_OrderGroup_CustomerIdName]
    ON [dbo].[OrderGroup]([CustomerId] ASC, [Name] ASC);


GO
PRINT N'Starting rebuilding table [dbo].[OrderNoteType]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_OrderNoteType] (
    [OrderNoteTypeId] INT           NOT NULL,
    [Name]            NVARCHAR (50) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_OrderNoteType1] PRIMARY KEY CLUSTERED ([OrderNoteTypeId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[OrderNoteType])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_OrderNoteType] ([OrderNoteTypeId], [Name])
        SELECT   [OrderNoteTypeId],
                 [Name]
        FROM     [dbo].[OrderNoteType]
        ORDER BY [OrderNoteTypeId] ASC;
    END

DROP TABLE [dbo].[OrderNoteType];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_OrderNoteType]', N'OrderNoteType';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_OrderNoteType1]', N'PK_OrderNoteType', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Starting rebuilding table [dbo].[OrderShipmentStatus]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_OrderShipmentStatus] (
    [OrderShipmentStatusId] INT           NOT NULL,
    [Name]                  NVARCHAR (50) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_OrderShipmentStatus1] PRIMARY KEY CLUSTERED ([OrderShipmentStatusId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[OrderShipmentStatus])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_OrderShipmentStatus] ([OrderShipmentStatusId], [Name])
        SELECT   [OrderShipmentStatusId],
                 [Name]
        FROM     [dbo].[OrderShipmentStatus]
        ORDER BY [OrderShipmentStatusId] ASC;
    END

DROP TABLE [dbo].[OrderShipmentStatus];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_OrderShipmentStatus]', N'OrderShipmentStatus';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_OrderShipmentStatus1]', N'PK_OrderShipmentStatus', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Starting rebuilding table [dbo].[OrderStatus]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_OrderStatus] (
    [OrderStatusId] INT           NOT NULL,
    [Name]          NVARCHAR (50) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_OrderStatus1] PRIMARY KEY CLUSTERED ([OrderStatusId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[OrderStatus])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_OrderStatus] ([OrderStatusId], [Name])
        SELECT   [OrderStatusId],
                 [Name]
        FROM     [dbo].[OrderStatus]
        ORDER BY [OrderStatusId] ASC;
    END

DROP TABLE [dbo].[OrderStatus];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_OrderStatus]', N'OrderStatus';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_OrderStatus1]', N'PK_OrderStatus', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[Package]...';


GO
ALTER TABLE [dbo].[Package] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[PaymentMethod]...';


GO
ALTER TABLE [dbo].[PaymentMethod] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_PaymentMethod]...';


GO
ALTER TABLE [dbo].[PaymentMethod]
    ADD CONSTRAINT [IX_PaymentMethod] UNIQUE NONCLUSTERED ([LanguageId] ASC, [SystemKeyword] ASC);


GO
PRINT N'Altering [dbo].[Policy]...';


GO
ALTER TABLE [dbo].[Policy] DROP COLUMN [ApplicationId];


GO
PRINT N'Starting rebuilding table [dbo].[PriceDetail]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_PriceDetail] (
    [PriceValueId]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [Created]          DATETIME2 (7)   NOT NULL,
    [Modified]         DATETIME2 (7)   NOT NULL,
    [CatalogEntryCode] NVARCHAR (100)  NOT NULL,
    [MarketId]         NVARCHAR (8)    NOT NULL,
    [CurrencyCode]     NVARCHAR (8)    NOT NULL,
    [PriceTypeId]      INT             NOT NULL,
    [PriceCode]        NVARCHAR (256)  CONSTRAINT [DF_PriceDetail_PriceCode] DEFAULT ('') NOT NULL,
    [ValidFrom]        DATETIME2 (7)   NOT NULL,
    [ValidUntil]       DATETIME2 (7)   NULL,
    [MinQuantity]      DECIMAL (38, 9) NOT NULL,
    [UnitPrice]        DECIMAL (38, 9) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_PriceDetail1] PRIMARY KEY NONCLUSTERED ([PriceValueId] ASC)
);

CREATE CLUSTERED INDEX [tmp_ms_xx_index_IX_PriceDetail_CatalogEntry1]
    ON [dbo].[tmp_ms_xx_PriceDetail]([CatalogEntryCode] ASC);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[PriceDetail])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_PriceDetail] ON;
        INSERT INTO [dbo].[tmp_ms_xx_PriceDetail] ([CatalogEntryCode], [PriceValueId], [Created], [Modified], [MarketId], [CurrencyCode], [PriceTypeId], [PriceCode], [ValidFrom], [ValidUntil], [MinQuantity], [UnitPrice])
        SELECT   [CatalogEntryCode],
                 [PriceValueId],
                 [Created],
                 [Modified],
                 [MarketId],
                 [CurrencyCode],
                 [PriceTypeId],
                 [PriceCode],
                 [ValidFrom],
                 [ValidUntil],
                 [MinQuantity],
                 [UnitPrice]
        FROM     [dbo].[PriceDetail]
        ORDER BY [CatalogEntryCode] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_PriceDetail] OFF;
    END

DROP TABLE [dbo].[PriceDetail];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_PriceDetail]', N'PriceDetail';

EXECUTE sp_rename N'[dbo].[PriceDetail].[tmp_ms_xx_index_IX_PriceDetail_CatalogEntry1]', N'IX_PriceDetail_CatalogEntry', N'INDEX';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_PriceDetail1]', N'PK_PriceDetail', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Starting rebuilding table [dbo].[PriceGroup]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_PriceGroup] (
    [PriceGroupId]     INT            IDENTITY (1, 1) NOT NULL,
    [Created]          DATETIME       NOT NULL,
    [Modified]         DATETIME       NOT NULL,
    [CatalogEntryCode] NVARCHAR (100) NOT NULL,
    [MarketId]         NVARCHAR (8)   NOT NULL,
    [CurrencyCode]     NVARCHAR (8)   NOT NULL,
    [PriceTypeId]      INT            NOT NULL,
    [PriceCode]        NVARCHAR (256) CONSTRAINT [DF_PriceGroup_PriceCode] DEFAULT ('') NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_AX_PriceGroup_PriceGroupId1] UNIQUE NONCLUSTERED ([PriceGroupId] ASC),
    CONSTRAINT [tmp_ms_xx_constraint_PK_PriceGroup1] PRIMARY KEY CLUSTERED ([CatalogEntryCode] ASC, [MarketId] ASC, [CurrencyCode] ASC, [PriceTypeId] ASC, [PriceCode] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[PriceGroup])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_PriceGroup] ON;
        INSERT INTO [dbo].[tmp_ms_xx_PriceGroup] ([CatalogEntryCode], [MarketId], [CurrencyCode], [PriceTypeId], [PriceCode], [PriceGroupId], [Created], [Modified])
        SELECT   [CatalogEntryCode],
                 [MarketId],
                 [CurrencyCode],
                 [PriceTypeId],
                 [PriceCode],
                 [PriceGroupId],
                 [Created],
                 [Modified]
        FROM     [dbo].[PriceGroup]
        ORDER BY [CatalogEntryCode] ASC, [MarketId] ASC, [CurrencyCode] ASC, [PriceTypeId] ASC, [PriceCode] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_PriceGroup] OFF;
    END

DROP TABLE [dbo].[PriceGroup];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_PriceGroup]', N'PriceGroup';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_AX_PriceGroup_PriceGroupId1]', N'AX_PriceGroup_PriceGroupId', N'OBJECT';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_PriceGroup1]', N'PK_PriceGroup', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[Promotion]...';


GO
ALTER TABLE [dbo].[Promotion] DROP COLUMN [ApplicationId];


GO
PRINT N'Starting rebuilding table [dbo].[ReturnFormStatus]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_ReturnFormStatus] (
    [ReturnFormStatusId] INT           NOT NULL,
    [Name]               NVARCHAR (50) NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_ReturnFormStatus1] PRIMARY KEY CLUSTERED ([ReturnFormStatusId] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[ReturnFormStatus])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_ReturnFormStatus] ([ReturnFormStatusId], [Name])
        SELECT   [ReturnFormStatusId],
                 [Name]
        FROM     [dbo].[ReturnFormStatus]
        ORDER BY [ReturnFormStatusId] ASC;
    END

DROP TABLE [dbo].[ReturnFormStatus];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_ReturnFormStatus]', N'ReturnFormStatus';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_ReturnFormStatus1]', N'PK_ReturnFormStatus', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Starting rebuilding table [dbo].[ReturnReasonDictionary]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_ReturnReasonDictionary] (
    [ReturnReasonId]   INT           IDENTITY (1, 1) NOT NULL,
    [ReturnReasonText] NVARCHAR (50) NOT NULL,
    [Ordering]         INT           NOT NULL,
    [Visible]          BIT           NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_ReturnReasonDictionary1] PRIMARY KEY CLUSTERED ([ReturnReasonText] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[ReturnReasonDictionary])
    BEGIN
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_ReturnReasonDictionary] ON;
        INSERT INTO [dbo].[tmp_ms_xx_ReturnReasonDictionary] ([ReturnReasonText], [ReturnReasonId], [Ordering], [Visible])
        SELECT   [ReturnReasonText],
                 [ReturnReasonId],
                 [Ordering],
                 [Visible]
        FROM     [dbo].[ReturnReasonDictionary]
        ORDER BY [ReturnReasonText] ASC;
        SET IDENTITY_INSERT [dbo].[tmp_ms_xx_ReturnReasonDictionary] OFF;
    END

DROP TABLE [dbo].[ReturnReasonDictionary];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_ReturnReasonDictionary]', N'ReturnReasonDictionary';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_ReturnReasonDictionary1]', N'PK_ReturnReasonDictionary', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Altering [dbo].[RolePermission]...';


GO
ALTER TABLE [dbo].[RolePermission] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Segment]...';


GO
ALTER TABLE [dbo].[Segment] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethod] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_ShippingMethod]...';


GO
ALTER TABLE [dbo].[ShippingMethod]
    ADD CONSTRAINT [IX_ShippingMethod] UNIQUE NONCLUSTERED ([LanguageId] ASC, [Name] ASC);


GO
PRINT N'Altering [dbo].[ShippingOption]...';


GO
ALTER TABLE [dbo].[ShippingOption] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_ShippingOption]...';


GO
ALTER TABLE [dbo].[ShippingOption]
    ADD CONSTRAINT [IX_ShippingOption] UNIQUE NONCLUSTERED ([SystemKeyword] ASC);


GO
PRINT N'Altering [dbo].[Tax]...';


GO
ALTER TABLE [dbo].[Tax] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_Tax]...';


GO
ALTER TABLE [dbo].[Tax]
    ADD CONSTRAINT [IX_Tax] UNIQUE NONCLUSTERED ([Name] ASC);


GO
PRINT N'Altering [dbo].[TaxCategory]...';


GO
ALTER TABLE [dbo].[TaxCategory] DROP COLUMN [ApplicationId];


GO
PRINT N'Altering [dbo].[Warehouse]...';


GO
ALTER TABLE [dbo].[Warehouse] DROP COLUMN [ApplicationId];


GO
PRINT N'Creating [dbo].[IX_Warehouse]...';


GO
ALTER TABLE [dbo].[Warehouse]
    ADD CONSTRAINT [IX_Warehouse] UNIQUE NONCLUSTERED ([Code] ASC);


GO
PRINT N'Starting rebuilding table [dbo].[WarehouseInventory]...';


GO
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SET XACT_ABORT ON;

CREATE TABLE [dbo].[tmp_ms_xx_WarehouseInventory] (
    [WarehouseCode]             NVARCHAR (50)  NOT NULL,
    [CatalogEntryCode]          NVARCHAR (100) NOT NULL,
    [InStockQuantity]           DECIMAL (18)   NOT NULL,
    [ReservedQuantity]          DECIMAL (18)   NOT NULL,
    [ReorderMinQuantity]        DECIMAL (18)   NOT NULL,
    [PreorderQuantity]          DECIMAL (18)   NOT NULL,
    [BackorderQuantity]         DECIMAL (18)   NOT NULL,
    [AllowPreorder]             BIT            NOT NULL,
    [AllowBackorder]            BIT            NOT NULL,
    [InventoryStatus]           INT            NOT NULL,
    [PreorderAvailabilityDate]  DATETIME       NOT NULL,
    [BackorderAvailabilityDate] DATETIME       NOT NULL,
    CONSTRAINT [tmp_ms_xx_constraint_PK_WarehouseInventory1] PRIMARY KEY CLUSTERED ([WarehouseCode] ASC, [CatalogEntryCode] ASC)
);

IF EXISTS (SELECT TOP 1 1 
           FROM   [dbo].[WarehouseInventory])
    BEGIN
        INSERT INTO [dbo].[tmp_ms_xx_WarehouseInventory] ([WarehouseCode], [CatalogEntryCode], [InStockQuantity], [ReservedQuantity], [ReorderMinQuantity], [PreorderQuantity], [BackorderQuantity], [AllowPreorder], [AllowBackorder], [InventoryStatus], [PreorderAvailabilityDate], [BackorderAvailabilityDate])
        SELECT   [WarehouseCode],
                 [CatalogEntryCode],
                 [InStockQuantity],
                 [ReservedQuantity],
                 [ReorderMinQuantity],
                 [PreorderQuantity],
                 [BackorderQuantity],
                 [AllowPreorder],
                 [AllowBackorder],
                 [InventoryStatus],
                 [PreorderAvailabilityDate],
                 [BackorderAvailabilityDate]
        FROM     [dbo].[WarehouseInventory]
        ORDER BY [WarehouseCode] ASC, [CatalogEntryCode] ASC;
    END

DROP TABLE [dbo].[WarehouseInventory];

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_WarehouseInventory]', N'WarehouseInventory';

EXECUTE sp_rename N'[dbo].[tmp_ms_xx_constraint_PK_WarehouseInventory1]', N'PK_WarehouseInventory', N'OBJECT';

COMMIT TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


GO
PRINT N'Creating [dbo].[FK_NodeEntryRelation_Catalog]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_Catalog] FOREIGN KEY ([CatalogId]) REFERENCES [dbo].[Catalog] ([CatalogId]);


GO
PRINT N'Creating [dbo].[FK_NodeEntryRelation_CatalogEntry]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_CatalogEntry] FOREIGN KEY ([CatalogEntryId]) REFERENCES [dbo].[CatalogEntry] ([CatalogEntryId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_NodeEntryRelation_CatalogNode]...';


GO
ALTER TABLE [dbo].[NodeEntryRelation] WITH NOCHECK
    ADD CONSTRAINT [FK_NodeEntryRelation_CatalogNode] FOREIGN KEY ([CatalogNodeId]) REFERENCES [dbo].[CatalogNode] ([CatalogNodeId]);


GO
PRINT N'Creating [dbo].[FK_ManagedInventory_CatalogEntry]...';


GO
ALTER TABLE [dbo].[InventoryService] WITH NOCHECK
    ADD CONSTRAINT [FK_ManagedInventory_CatalogEntry] FOREIGN KEY ([CatalogEntryCode]) REFERENCES [dbo].[CatalogEntry] ([Code]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceDetail_CatalogEntry]...';


GO
ALTER TABLE [dbo].[PriceDetail] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceDetail_CatalogEntry] FOREIGN KEY ([CatalogEntryCode]) REFERENCES [dbo].[CatalogEntry] ([Code]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceGroup_CatalogEntry]...';


GO
ALTER TABLE [dbo].[PriceGroup] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceGroup_CatalogEntry] FOREIGN KEY ([CatalogEntryCode]) REFERENCES [dbo].[CatalogEntry] ([Code]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_ManagedInventory_Warehouse]...';


GO
ALTER TABLE [dbo].[InventoryService] WITH NOCHECK
    ADD CONSTRAINT [FK_ManagedInventory_Warehouse] FOREIGN KEY ([WarehouseCode]) REFERENCES [dbo].[Warehouse] ([Code]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [dbo].[FK_WarehouseInventory_Warehouse]...';


GO
ALTER TABLE [dbo].[WarehouseInventory] WITH NOCHECK
    ADD CONSTRAINT [FK_WarehouseInventory_Warehouse] FOREIGN KEY ([WarehouseCode]) REFERENCES [dbo].[Warehouse] ([Code]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceDetail_Currency]...';


GO
ALTER TABLE [dbo].[PriceDetail] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceDetail_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [dbo].[Currency] ([CurrencyCode]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceDetail_Market]...';


GO
ALTER TABLE [dbo].[PriceDetail] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceDetail_Market] FOREIGN KEY ([MarketId]) REFERENCES [dbo].[Market] ([MarketId]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceDetail_PriceType]...';


GO
ALTER TABLE [dbo].[PriceDetail] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceDetail_PriceType] FOREIGN KEY ([PriceTypeId]) REFERENCES [dbo].[PriceType] ([PriceTypeId]);


GO
PRINT N'Creating [dbo].[FK_PriceGroup_Currency]...';


GO
ALTER TABLE [dbo].[PriceGroup] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceGroup_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [dbo].[Currency] ([CurrencyCode]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceGroup_Market]...';


GO
ALTER TABLE [dbo].[PriceGroup] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceGroup_Market] FOREIGN KEY ([MarketId]) REFERENCES [dbo].[Market] ([MarketId]) ON DELETE CASCADE;


GO
PRINT N'Creating [dbo].[FK_PriceGroup_PriceType]...';


GO
ALTER TABLE [dbo].[PriceGroup] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceGroup_PriceType] FOREIGN KEY ([PriceTypeId]) REFERENCES [dbo].[PriceType] ([PriceTypeId]);


GO
PRINT N'Creating [dbo].[FK_PriceValue_PriceGroup]...';


GO
ALTER TABLE [dbo].[PriceValue] WITH NOCHECK
    ADD CONSTRAINT [FK_PriceValue_PriceGroup] FOREIGN KEY ([PriceGroupId]) REFERENCES [dbo].[PriceGroup] ([PriceGroupId]) ON DELETE CASCADE;


GO

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
PRINT N'Altering [dbo].[ecf_Application]...';


GO
ALTER PROCEDURE [dbo].[ecf_Application]
    @ApplicationName nvarchar(200) = null,
    @IsActive bit = null
AS
begin
    select Name, IsActive
    from [Application]
    where isnull(@ApplicationName, Name) = Name
      and isnull(@IsActive, IsActive) = IsActive
end
GO
PRINT N'Altering [dbo].[ecf_Currency_Create]...';


GO

ALTER procedure dbo.ecf_Currency_Create
    @CurrencyCode nvarchar(8),
    @CurrencyName nvarchar(50)
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction
        
        if (select COUNT(*) from Application) != 1 raiserror('Multiple applications are not supported.', 10, 0)
        
        insert into dbo.Currency (CurrencyCode, Created, Modified, CurrencyName)
        select @CurrencyCode, GETUTCDATE(), GETUTCDATE(), @CurrencyName
        from Application a

        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Altering [dbo].[ecf_ApplicationLog]...';


GO
ALTER PROCEDURE [dbo].[ecf_ApplicationLog]
	@IsSystemLog bit = 0,
	@Source nvarchar(100) = null,
	@Created datetime = null,
	@Operation nvarchar(50) = null,
	@ObjectType nvarchar(50) = null,
    @StartingRec int,
	@NumRecords int
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SystemLogKey nvarchar(100)
	SET @SystemLogKey = 'system'; 

	WITH OrderedLogs AS 
	(
		select *, row_number() over(order by LogId desc) as RowNumber from ApplicationLog 
			where ((@IsSystemLog = 1 AND Source = @SystemLogKey) OR (@IsSystemLog = 0 AND NOT Source = @SystemLogKey))
				AND COALESCE(@Source, Source) = Source 
				AND COALESCE(@Operation, Operation) = Operation 
				AND COALESCE(@ObjectType, ObjectType) = ObjectType 
				AND COALESCE(@Created, Created) >= Created
	),
	OrderedLogsCount(TotalCount) as
	(
		select count(LogId) from OrderedLogs
	)
	select LogId, Source, Operation, ObjectKey, ObjectType, Username, Created, Succeeded, IPAddress, Notes, TotalCount from OrderedLogs, OrderedLogsCount
	where RowNumber between @StartingRec and @StartingRec + @NumRecords
	SET NOCOUNT OFF;
END
GO
PRINT N'Altering [dbo].[ecf_mktg_Campaign]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Campaign]
    @CampaignId int
AS
BEGIN
	
	if(@CampaignId = 0)
		set @CampaignId = null

	SELECT C.* from [Campaign] C
	WHERE
		C.CampaignId = COALESCE(@CampaignId,C.CampaignId)

	SELECT CS.* from [CampaignSegment] CS
	INNER JOIN [Campaign] C ON C.CampaignId = CS.CampaignId
	WHERE
		CS.CampaignId = COALESCE(@CampaignId,CS.CampaignId)

	SELECT MC.* from [MarketCampaigns] MC
	INNER JOIN [Campaign] C on C.CampaignId = MC.CampaignId
	WHERE
		MC.CampaignId = COALESCE(@CampaignId,MC.CampaignId)

END
GO
PRINT N'Altering [dbo].[ecf_mktg_CampaignMarket]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_CampaignMarket]
    @MarketId nvarchar(8)
AS
BEGIN

	SELECT C.* from [Campaign] C
	INNER JOIN [MarketCampaigns] MC on C.CampaignId = MC.CampaignId
	WHERE
		MC.[MarketId] = COALESCE(@MarketId, MC.[MarketId])

	SELECT CS.* from [CampaignSegment] CS
	INNER JOIN [Campaign] C ON C.CampaignId = CS.CampaignId
	INNER JOIN [MarketCampaigns] MC on MC.[CampaignId] = C.[CampaignId] 
	WHERE
		MC.[MarketId] = COALESCE(@MarketId, MC.[MarketId])

	SELECT MC.* from [MarketCampaigns] MC
	INNER JOIN [Campaign] C on C.CampaignId = MC.CampaignId
	WHERE
		MC.MarketId = @MarketId

END
GO
PRINT N'Altering [dbo].[ecf_mktg_PromotionByDate]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_PromotionByDate]
    @DateTime datetime
AS
BEGIN
	SELECT P.* from [Promotion] P 
	INNER JOIN Campaign C ON C.CampaignId = P.CampaignId
	WHERE
		(@DateTime between P.StartDate and DATEADD(week, 1, P.EndDate))	and
		P.Status = 'active' and
		(@DateTime between C.StartDate and DATEADD(week, 1, C.EndDate))	and
		C.IsActive = 1		
	ORDER BY
		P.Priority  DESC, P.CouponCode DESC, P.PromotionGroup

	SELECT PC.* from [PromotionCondition] PC
	INNER JOIN [Promotion] P ON P.PromotionId = PC.PromotionId
	INNER JOIN Campaign C ON C.CampaignId = P.CampaignId
	WHERE
		(@DateTime between P.StartDate and DATEADD(week, 1, P.EndDate))	and
		P.Status = 'active' and
		(@DateTime between C.StartDate and DATEADD(week, 1, C.EndDate))	and
		C.IsActive = 1	

	SELECT PG.* from [PromotionLanguage] PG
	INNER JOIN [Promotion] P ON P.PromotionId = PG.PromotionId
	INNER JOIN Campaign C ON C.CampaignId = P.CampaignId
	WHERE
		(@DateTime between P.StartDate and DATEADD(week, 1, P.EndDate))	and
		P.Status = 'active' and
		(@DateTime between C.StartDate and DATEADD(week, 1, C.EndDate))	and
		C.IsActive = 1	

	SELECT PP.* from [PromotionPolicy] PP
	INNER JOIN [Promotion] P ON P.PromotionId = PP.PromotionId
	INNER JOIN Campaign C ON C.CampaignId = P.CampaignId
	WHERE
		(@DateTime between P.StartDate and DATEADD(week, 1, P.EndDate))	and
		P.Status = 'active' and
		(@DateTime between C.StartDate and DATEADD(week, 1, C.EndDate))	and
		C.IsActive = 1	
END
GO
PRINT N'Altering [dbo].[ecf_Catalog]...';


GO
ALTER PROCEDURE [dbo].[ecf_Catalog]
	@SiteId uniqueidentifier = null,
	@CatalogId int = null,
	@ReturnInactive bit = 0
AS
BEGIN
	
	SELECT DISTINCT C.* from [Catalog] C
		LEFT OUTER JOIN SiteCatalog SC ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(SC.SiteId = COALESCE(@SiteId,SC.SiteId) or (@SiteId is null and SC.SiteId is null)) 
			AND 
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)

	SELECT DISTINCT L.* from [CatalogLanguage] L
		LEFT OUTER JOIN [Catalog] C ON C.CatalogId = L.CatalogId
		LEFT OUTER JOIN SiteCatalog SC ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(SC.SiteId = COALESCE(@SiteId,SC.SiteId) or (@SiteId is null and SC.SiteId is null)) 
			AND 
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)

	SELECT DISTINCT SC.* from SiteCatalog SC
		INNER JOIN [Catalog] C ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(SC.SiteId = COALESCE(@SiteId,SC.SiteId)) 
			AND 
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNode_CatalogName]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_CatalogName]
	@CatalogName nvarchar(150),
	@ReturnInactive bit = 0
AS
BEGIN
	SELECT N.* from [CatalogNode] N
	INNER JOIN [Catalog] C ON C.CatalogId = N.CatalogId
	WHERE
		C.[Name] = @CatalogName AND N.ParentNodeId = 0 AND 
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY N.SortOrder

	SELECT S.* from CatalogItemSeo S
	INNER JOIN CatalogNode N ON N.CatalogNodeId = S.CatalogNodeId
	INNER JOIN [Catalog] C ON C.CatalogId = N.CatalogId
	WHERE
		C.[Name] = @CatalogName AND N.ParentNodeId = 0 AND 
		((N.IsActive = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_reporting_LowStock]...';


GO
ALTER PROCEDURE [dbo].[ecf_reporting_LowStock] 
As

BEGIN

    SELECT E.[Name], E.Code as SkuId, I.BackorderAvailableUtc as [BackorderAvailabilityDate],
    I.PreorderAvailableUtc as [PreorderAvailabilityDate],
    I.IsTracked as [InventoryStatus],
    [AllowBackorder] = 
        CASE 
            WHEN I.BackorderAvailableQuantity > 0 THEN 1
            ELSE 0
        END,
    [AllowPreOrder] = 
        CASE 
            WHEN I.PreorderAvailableUtc > convert(datetime,0x0000000000000000) THEN 1
            ELSE 0
        END,
    I.BackorderAvailableQuantity as [BackorderQuantity],
    I.PreorderAvailableQuantity as [PreorderQuantity],
    I.ReorderMinQuantity,
    I.WarehouseCode,
    I.AdditionalQuantity as [ReservedQuantity],
    I.PurchaseAvailableQuantity + I.AdditionalQuantity as [InstockQuantity],
    W.Name as WarehouseName from [InventoryService] I
    INNER JOIN [CatalogEntry] E ON E.Code = I.CatalogEntryCode 
    INNER JOIN Catalog C ON C.CatalogId = E.CatalogId
    INNER JOIN [Warehouse] W ON I.WarehouseCode = W.Code
    WHERE I.PurchaseAvailableQuantity <= I.ReorderMinQuantity AND I.IsTracked <> 0 

END
GO
PRINT N'Altering [dbo].[ecf_Catalog_GetAllChildEntries]...';


GO

ALTER procedure dbo.ecf_Catalog_GetAllChildEntries
	@catalogIds udttCatalogList readonly
as
begin
	select distinct ce.CatalogEntryId, ce.Code
	from CatalogEntry ce
	join NodeEntryRelation ner on ce.CatalogEntryId = ner.CatalogEntryId
	where ner.CatalogNodeId in (
		select CatalogNodeId
		from CatalogNode
		where CatalogId in (select CatalogId from @catalogIds)
		union
		select ChildNodeId
		from CatalogNodeRelation
		where CatalogId in (select CatalogId from @catalogIds)
	)
end
GO
PRINT N'Altering [dbo].[ecf_Catalog_GetChildrenEntries]...';


GO
ALTER PROCEDURE [dbo].[ecf_Catalog_GetChildrenEntries]
	@CatalogId int
AS
BEGIN
	SELECT CE.CatalogId, CE.MetaClassId, CE.CatalogEntryId, ClassTypeId, 0 as CatalogNodeId, 0 as SortOrder
	FROM [dbo].CatalogEntry CE
	WHERE CE.CatalogId = @CatalogId
		AND NOT EXISTS(SELECT 1 FROM NodeEntryRelation R WHERE CE.CatalogEntryId = R.CatalogEntryId AND R.IsPrimary = 1)
	ORDER BY CE.Name
END
GO
PRINT N'Altering [dbo].[ecf_CatalogAssociation_CatalogEntryCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogAssociation_CatalogEntryCode]
	@CatalogId int,
	@CatalogEntryCode nvarchar(100)
AS
BEGIN
	SELECT CA.* from [CatalogAssociation] CA
		INNER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		CE.Code = @CatalogEntryCode AND
		CE.CatalogId = @CatalogId
	ORDER BY CA.SortOrder

	SELECT CEA.* from [CatalogEntryAssociation] CEA
		INNER JOIN [CatalogAssociation] CA ON CA.CatalogAssociationId = CEA.CatalogAssociationId
		INNER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		CE.Code = @CatalogEntryCode AND
		CE.CatalogId = @CatalogId
	ORDER BY CA.SortOrder, CEA.SortOrder
		
	SELECT * FROM [AssociationType]
END
GO
PRINT N'Altering [dbo].[ecf_CatalogAssociationByName]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogAssociationByName]
	@AssociationName nvarchar(150)
AS
BEGIN
	SELECT CA.* from [CatalogAssociation] CA
		INNER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		CA.AssociationName = @AssociationName
	ORDER BY CA.SortOrder

	SELECT CEA.* from [CatalogEntryAssociation] CEA
		INNER JOIN [CatalogAssociation] CA ON CA.CatalogAssociationId = CEA.CatalogAssociationId
		INNER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		(CA.AssociationName = @AssociationName OR (CA.AssociationName IS NULL AND @AssociationName IS NULL))
	ORDER BY CA.SortOrder, CEA.SortOrder
		
	SELECT * FROM [AssociationType]
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_AssetKey]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_AssetKey]
	@AssetKey nvarchar(254)
AS
BEGIN
	SELECT A.* from [CatalogItemAsset] A
		INNER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = A.CatalogEntryId
	WHERE
		A.AssetKey = @AssetKey
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_UriSegment]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_UriSegment]
	@UriSegment nvarchar(255),
	@CatalogEntryId int,
	@ReturnInactive bit = 0
AS
BEGIN
	SELECT COUNT(*) from CatalogItemSeo S
	INNER JOIN CatalogEntry N ON N.CatalogEntryId = S.CatalogEntryId
	WHERE
		S.UriSegment = @UriSegment AND
		S.CatalogEntryId <> @CatalogEntryId AND
		((N.IsActive = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntrySearch_GetResults]...';


GO
ALTER procedure [dbo].[ecf_CatalogEntrySearch_GetResults]
    @SearchSetId uniqueidentifier,
    @FirstResultIndex int,
    @MaxResultCount int
as
begin
    declare @LastResultIndex int
    set @LastResultIndex = @FirstResultIndex + @MaxResultCount - 1
    
    declare @keyset table (CatalogEntryId int)
    insert into @keyset 
    select CatalogEntryId
    from CatalogEntrySearchResults_SingleSort ix
    where ix.SearchSetId = @SearchSetId
      and ix.ResultIndex between @FirstResultIndex and @LastResultIndex
    
    select ce.*
    from CatalogEntry ce
    join @keyset ks on ce.CatalogEntryId = ks.CatalogEntryId
    order by ce.CatalogEntryId
    
    select cis.*
    from CatalogItemSeo cis
    join @keyset ks on cis.CatalogEntryId = ks.CatalogEntryId
    order by cis.CatalogEntryId
    
    select v.*
    from Variation v
    join @keyset ks on v.CatalogEntryId = ks.CatalogEntryId
    order by v.CatalogEntryId
                    
    select distinct m.*
    from Merchant m
    join Variation v on m.MerchantId = v.MerchantId
    join @keyset ks on v.CatalogEntryId = ks.CatalogEntryId
   	    
   	select ca.*
   	from CatalogAssociation ca
   	join @keyset ks on ca.CatalogEntryId = ks.CatalogEntryId
    order by ca.CatalogEntryId

   	select cia.*
   	from CatalogItemAsset cia
   	join @keyset ks on cia.CatalogEntryId = ks.CatalogEntryId
    order by cia.CatalogEntryId

   	select ner.*
   	from NodeEntryRelation ner
   	join @keyset ks on ner.CatalogEntryId = ks.CatalogEntryId
    order by ner.CatalogEntryId

	-- Cleanup the loaded OrderGroupIds from SearchResults.
	delete from CatalogEntrySearchResults_SingleSort
	where @SearchSetId = SearchSetId and ResultIndex between @FirstResultIndex and @LastResultIndex
end
GO
PRINT N'Altering [dbo].[ecf_CatalogItem_AssetKey]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogItem_AssetKey]
	@AssetKey nvarchar(254)
AS
BEGIN
	SELECT A.* from [CatalogItemAsset] A
		LEFT OUTER JOIN [CatalogEntry] CE ON CE.CatalogEntryId = A.CatalogEntryId
		LEFT OUTER JOIN [CatalogNode] CN ON CN.CatalogNodeId = A.CatalogNodeId
	WHERE
		A.AssetKey = @AssetKey
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNode_GetDeleteResults]...';


GO

ALTER procedure dbo.ecf_CatalogNode_GetDeleteResults
    @CatalogId int,
    @CatalogNodeId int
as
begin
    declare @affectedNodes table (CatalogNodeId int, IsDelete int)
    declare @affectedEntries table (CatalogEntryId int, IsDelete int)
    
    ;with all_catalog_relations as
    (
        select ParentNodeId, CatalogNodeId as ChildNodeId, 1 as IsDelete from CatalogNode where CatalogId = @CatalogId
        union
        select ParentNodeId, ChildNodeId, 0 as IsDelete from CatalogNodeRelation where CatalogId = @CatalogId
    ),
    affected_nodes as
    (
        select
            cn.CatalogNodeId,
            1 as IsDelete,
            '|' + CAST(@CatalogNodeId as nvarchar(4000)) + '|' as CurrentNodePath
        from CatalogNode cn
        where cn.CatalogNodeId = @CatalogNodeId
        union all
        select 
            cn.CatalogNodeId,          
            case when cte.IsDelete = 1 and r.IsDelete = 1 then 1 else 0 end,            
            cte.CurrentNodePath + CAST(r.ChildNodeId as nvarchar(4000)) + '|'
        from affected_nodes cte
        join all_catalog_relations r on cte.CatalogNodeId = r.ParentNodeId and CHARINDEX(cast(r.ChildNodeId as nvarchar(4000)), cte.CurrentNodePath) = 0
        join CatalogNode cn on r.ChildNodeId = cn.CatalogNodeId
    )
    insert into @affectedNodes (CatalogNodeId, IsDelete)
    select n.CatalogNodeId, MAX(n.IsDelete)
    from affected_nodes n
    group by n.CatalogNodeId

    -- @result.IsCatalogEntry is always 0 at this point, joins do not need to specify that they are joining to nodes.
    insert into @affectedEntries (CatalogEntryId, IsDelete)
    select
        ce.CatalogEntryId, 
        MIN(isnull(ce_parent_nodeinfo.IsDelete, 0)) as IsDelete
    from @affectedNodes ns
    join NodeEntryRelation all_affected_node_relations on ns.CatalogNodeId = all_affected_node_relations.CatalogNodeId
    join CatalogEntry ce on all_affected_node_relations.CatalogEntryId = ce.CatalogEntryId
    join NodeEntryRelation ce_parents on ce.CatalogEntryId = ce_parents.CatalogEntryId
    left outer join @affectedNodes ce_parent_nodeinfo on ce_parents.CatalogNodeId = ce_parent_nodeinfo.CatalogNodeId
    group by ce.CatalogEntryId, ce.MetaClassId

    -- return entry updates, entry deletes, and node deletes; not node updates.
    -- node update rows only exist to populate the entry updates.
    select CatalogEntryId as EntityId, cast(1 as bit) as IsCatalogEntry, cast(IsDelete as bit) as IsDelete
    from @affectedEntries
    union all
    select CatalogNodeId, cast(0 as bit) as IsCatalogEntry, cast(IsDelete as bit) as IsDelete
    from @affectedNodes
    where IsDelete = 1    
end
GO
PRINT N'Altering [dbo].[ecf_CatalogRelation]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogRelation]
	@CatalogId INT,
	@CatalogNodeId INT,
	@CatalogEntryId INT,
	@GroupName NVARCHAR(100),
	@ResponseGroup INT
AS
BEGIN
	DECLARE @CatalogNode AS INT
	DECLARE @CatalogEntry AS INT
	DECLARE @NodeEntry AS INT

	SET @CatalogNode = 1
	SET @CatalogEntry = 2
	SET @NodeEntry = 4

	IF(@ResponseGroup & @CatalogNode = @CatalogNode)
		SELECT CNR.* FROM CatalogNodeRelation CNR
		INNER JOIN CatalogNode CN ON CN.CatalogNodeId = CNR.ParentNodeId AND (CN.CatalogId = @CatalogId OR @CatalogId = 0)
		WHERE (@CatalogNodeId = 0 OR CNR.ParentNodeId = @CatalogNodeId)
		ORDER BY CNR.SortOrder
	ELSE
		SELECT TOP 0 * FROM CatalogNodeRelation

	IF(@ResponseGroup & @CatalogEntry = @CatalogEntry)
	BEGIN
		IF (@CatalogNodeId = 0)
		BEGIN
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE 
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
		ELSE --We must filter by CatalogNodeId when getting CatalogEntryRelation if the @CatalogNodeId is different from zero, so that we don't get redundant data.
		BEGIN		
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
	END
	ELSE
		SELECT TOP 0 * FROM CatalogEntryRelation

	IF(@ResponseGroup & @NodeEntry = @NodeEntry)
	BEGIN
		DECLARE @execStmt NVARCHAR(1000)
		SET @execStmt = 'SELECT NER.CatalogId, NER.CatalogEntryId, NER.CatalogNodeId, NER.SortOrder, NER.IsPrimary FROM NodeEntryRelation NER'
		
		IF @CatalogId != 0 OR @CatalogNodeId != 0 OR @CatalogEntryId != 0
			SET @execStmt = @execStmt + ' WHERE 0=0 '
		IF @CatalogId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogId = @CatalogId) '
		IF @CatalogNodeId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogNodeId = @CatalogNodeId) '
		IF @CatalogEntryId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogEntryId = @CatalogEntryId) '

		SET @execStmt = @execStmt + ' ORDER BY NER.SortOrder'
		
		DECLARE @pars NVARCHAR(500)
		SET @pars = '@CatalogId int, @CatalogNodeId int, @CatalogEntryId int'
		EXEC sp_executesql @execStmt, @pars,
			@CatalogId=@CatalogId, @CatalogNodeId=@CatalogNodeId, @CatalogEntryId=@CatalogEntryId
	END
	ELSE
		SELECT TOP 0 CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary FROM NodeEntryRelation
END
GO
PRINT N'Altering [dbo].[ecf_CatalogRelationByChildEntryId]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogRelationByChildEntryId]
	@ChildEntryId int
AS
BEGIN
    select top 0 * from CatalogNodeRelation

	SELECT CER.* FROM CatalogEntryRelation CER
	INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ChildEntryId
	WHERE
		CER.ChildEntryId = @ChildEntryId
	ORDER BY CER.SortOrder
	
	SELECT CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary FROM NodeEntryRelation
	WHERE CatalogEntryId=@ChildEntryId
END
GO
PRINT N'Altering [dbo].[ecf_CheckExistEntryNodeByCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CheckExistEntryNodeByCode]
	@EntryNodeCode nvarchar(100)
AS
BEGIN
	DECLARE @exist BIT
	SET @exist = 0
	IF EXISTS (SELECT * FROM [CatalogEntry] WHERE Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END
	
	IF @exist = 0 AND EXISTS (SELECT * FROM [CatalogNode] WHERE Code = @EntryNodeCode COLLATE DATABASE_DEFAULT)
	BEGIN
		SET @exist = 1
	END

	SELECT @exist
END
GO
PRINT N'Creating [dbo].[ecf_GetCatalogEntryCodesByIds]...';


GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryCodesByIds]
	@CatalogIds udttCatalogCodeId READONLY
AS
BEGIN
	SELECT e.Code, e.CatalogEntryId from [CatalogEntry] e
	INNER JOIN @CatalogIds k  ON e.CatalogEntryId = k.ObjectId
END
GO
PRINT N'Creating [dbo].[ecf_GetCatalogEntryIdsByCodes]...';


GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogEntryIdsByCodes]
	@CatalogCodes udttCatalogCodeId READONLY
AS
BEGIN
	SELECT e.Code, e.CatalogEntryId from [CatalogEntry] e
	INNER JOIN @CatalogCodes k ON e.Code = k.Code
END
GO
PRINT N'Altering [dbo].[ecf_PriceDetail_List]...';


GO
ALTER procedure [dbo].[ecf_PriceDetail_List]
    @catalogEntryId int = null,
    @catalogNodeId int = null,
    @MarketId nvarchar(8),
    @CurrencyCodes udttCurrencyCode readonly,
    @CustomerPricing udttCustomerPricing readonly,
    @totalCount int output,
    @pagingOffset int = null,
    @pagingCount int = null
as
begin
    declare @filterCurrencies bit = case when exists (select 1 from @CurrencyCodes) then 1 else 0 end
    declare @filterCustomerPricing bit = case when exists (select 1 from @CustomerPricing) then 1 else 0 end
    if (@pagingOffset is null and @pagingCount is null)
    begin
        set @totalCount = -1

        ;with specified_entries as (
            select @catalogEntryId as CatalogEntryId
            where @catalogEntryId is not null
            union
            select CatalogEntryId
            from NodeEntryRelation
            where CatalogNodeId = @catalogNodeId
        ),
        returned_entries as (
            select ce.CatalogEntryId, ce.Code
            from specified_entries se
            join CatalogEntry ce on se.CatalogEntryId = ce.CatalogEntryId
            union all
            select ce.CatalogEntryId, ce.Code
            from specified_entries se
            join CatalogEntryRelation cer
                on se.CatalogEntryId = cer.ParentEntryId
                and cer.RelationTypeId in ('ProductVariation')
            join CatalogEntry ce on cer.ChildEntryId = ce.CatalogEntryId
        )
        select
            pd.PriceValueId,
            pd.Created,
            pd.Modified,
            pd.CatalogEntryCode,
            pd.MarketId,
            pd.CurrencyCode,
            pd.PriceTypeId,
            pd.PriceCode,
            pd.ValidFrom,
            pd.ValidUntil,
            pd.MinQuantity,
            pd.UnitPrice
        from PriceDetail pd
        where exists (select 1 from returned_entries re where pd.CatalogEntryCode = re.Code)
        and (@MarketId = '' or pd.MarketId = @MarketId)
        and (@filterCurrencies = 0 or pd.CurrencyCode in (select CurrencyCode from @CurrencyCodes))
        and (@filterCustomerPricing = 0 or exists (select 1 from @CustomerPricing cp where cp.PriceTypeId = pd.PriceTypeId and cp.PriceCode = pd.PriceCode))
        order by CatalogEntryCode
    end
    else
    begin
        declare @ordered_results table (
            ordering int not null,
            PriceValueId bigint not null,
            Created datetime not null,
            Modified datetime not null,
            CatalogEntryCode nvarchar(100) not null,
            MarketId nvarchar(8) not null,
            CurrencyCode nvarchar(8) not null,
            PriceTypeId int not null,
            PriceCode nvarchar(256) not null,
            ValidFrom datetime not null,
            ValidUntil datetime null,
            MinQuantity decimal(38,9) not null,
            UnitPrice DECIMAL (38, 9) not null
        )

        ;with specified_entries as (
            select @catalogEntryId as CatalogEntryId
            where @catalogEntryId is not null
            union
            select CatalogEntryId
            from NodeEntryRelation
            where CatalogNodeId = @catalogNodeId
        ),
        returned_entries as (
            select ce.CatalogEntryId, ce.Code
            from specified_entries se
            join CatalogEntry ce on se.CatalogEntryId = ce.CatalogEntryId
            union all
            select ce.CatalogEntryId, ce.Code
            from specified_entries se
            join CatalogEntryRelation cer
                on se.CatalogEntryId = cer.ParentEntryId
                and cer.RelationTypeId in ('ProductVariation')
            join CatalogEntry ce on cer.ChildEntryId = ce.CatalogEntryId
        )
        insert into @ordered_results (
            ordering,
            PriceValueId,
            Created,
            Modified,
            CatalogEntryCode,
            MarketId,
            CurrencyCode,
            PriceTypeId,
            PriceCode,
            ValidFrom,
            ValidUntil,
            MinQuantity,
            UnitPrice
        )
        select
            --we order by price code, market id and currency code to make the similar prices near each others.
            ROW_NUMBER() over (ORDER BY pd.CatalogEntryCode, pd.PriceCode, pd.MarketId, pd.CurrencyCode) - 1, -- arguments are zero-based.
            pd.PriceValueId,
            pd.Created,
            pd.Modified,
            pd.CatalogEntryCode,
            pd.MarketId,
            pd.CurrencyCode,
            pd.PriceTypeId,
            pd.PriceCode,
            pd.ValidFrom,
            pd.ValidUntil,
            pd.MinQuantity,
            pd.UnitPrice
        from PriceDetail pd
        where exists (select 1 from returned_entries re where pd.CatalogEntryCode = re.Code)
        and (@MarketId = '' or pd.MarketId = @MarketId)
        and (@filterCurrencies = 0 or pd.CurrencyCode in (select CurrencyCode from @CurrencyCodes))
        and (@filterCustomerPricing = 0 or exists (select 1 from @CustomerPricing cp where cp.PriceTypeId = pd.PriceTypeId and cp.PriceCode = pd.PriceCode))
        select @totalCount = count(*) from @ordered_results

        select
            PriceValueId,
            Created,
            Modified,
            CatalogEntryCode,
            MarketId,
            CurrencyCode,
            PriceTypeId,
            PriceCode,
            ValidFrom,
            ValidUntil,
            MinQuantity,
            UnitPrice
        from @ordered_results
        where @pagingOffset <= ordering and ordering < (@pagingOffset + @pagingCount)
        order by ordering
    end
end
GO
PRINT N'Altering [dbo].[ecf_reporting_ProductBestSellers]...';


GO
ALTER PROCEDURE [dbo].[ecf_reporting_ProductBestSellers] 
	@MarketId nvarchar(8),
	@CurrencyCode NVARCHAR(8),
	@interval VARCHAR(20),
	@startdate DATETIME, -- parameter expected in UTC
	@enddate DATETIME, -- parameter expected in UTC
	@offset_st INT,
	@offset_dt INT
AS

BEGIN

	SELECT	z.Period, 
			z.ProductName, 
			z.Price, 
			z.Ordered,
			z.Code
	FROM
	(
		SELECT	x.Period as Period,  
				ISNULL(y.ProductName, 'NONE') AS ProductName,
				ISNULL(y.Price,0) AS Price,
				ISNULL(y.ItemsOrdered, 0) AS Ordered,
				RANK() OVER (PARTITION BY x.Period
						ORDER BY y.price DESC) AS PriceRank,
				y.Code
		FROM 
		(
			SELECT	DISTINCT (CASE WHEN @interval = 'Day'
								THEN CONVERT(VARCHAR(10), D.DateFull, 101)
								WHEN @interval = 'Month'
								THEN (DATENAME(MM, D.DateFull) + ', ' + CAST(YEAR(D.DateFull) AS VARCHAR(20))) 
								ElSE CAST(YEAR(D.DateFull) AS VARCHAR(20))  
								End) AS Period 
			FROM ReportingDates D LEFT OUTER JOIN OrderFormEx FEX ON D.DateFull = FEX.Created
		WHERE 
			-- convert back from UTC using offset to generate a list of WEBSERVER datetimes
			D.DateFull BETWEEN 
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@startdate, @offset_st, @offset_dt) as float)) as datetime) AND
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@enddate, @offset_st, @offset_dt) as float)) as datetime)
		) AS x

		LEFT JOIN

		(
			SELECT  DISTINCT (CASE WHEN @interval = 'Day'
								THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
								WHEN @interval = 'Month'
								THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
								ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   End) as period, 
					
				 E.Name AS ProductName,
					L.ListPrice AS Price,
					SUM(L.Quantity) AS ItemsOrdered,
					RANK() OVER (PARTITION BY (CASE WHEN @interval = 'Day'
													THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
													WHEN @interval = 'Month'
													THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
													ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
												END) 
								ORDER BY SUM(L.Quantity) DESC) AS PeriodRank,
					E.Code
			FROM 
				LineItem AS L INNER JOIN OrderFormEx AS FEX ON L.OrderFormId = Fex.ObjectId 
				INNER JOIN OrderForm AS F ON L.OrderFormId = F.OrderFormId
				INNER JOIN CatalogEntry E ON L.CatalogEntryId = E.Code
				INNER JOIN OrderGroup AS OG ON F.OrderGroupId = OG.OrderGroupId AND isnull (OG.Status, '') = 'Completed'
			WHERE CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101) >=  @startdate AND CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101) < @enddate +1 
				AND (FEX.RMANumber = '' OR FEX.RMANumber IS NULL)
				AND OG.Name <> 'Exchange'
				AND OG.BillingCurrency = @CurrencyCode 
				AND (LEN(@MarketId) = 0 OR OG.MarketId = @MarketId)
			GROUP BY (Case WHEN @interval = 'Day'
						THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
						WHEN @interval = 'Month'
						THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  )
						ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
					END) ,E.Name, L.ListPrice, E.Code
				
		
					
		) AS y

ON x.Period = y.Period
WHERE y.PeriodRank IS NULL 
OR y.PeriodRank = 1



	)AS z

WHERE z.PriceRank = 1
ORDER BY CONVERT(datetime, z.Period, 101)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntrySearch_Init]...';


GO
ALTER procedure [dbo].[ecf_CatalogEntrySearch_Init]
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
    declare @EarliestModifiedFilter nvarchar(4000) = ''
	declare @LatestModifiedFilter nvarchar(4000) = ''
	declare @query nvarchar(max)
	declare @AppLogQuery nvarchar(4000)

	set @ModifiedCondition = 'select ObjectId from CatalogContentEx where ObjectTypeId = 0'
    
    -- @ModifiedFilter: if there is a filter, build the where clause for it here.
    if (@EarliestModifiedDate is not null)
    begin
	  	set @EarliestModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
	  	set @ModifiedCondition = @ModifiedCondition + ' and ' + @EarliestModifiedFilter
	end
    if (@LatestModifiedDate is not null)
    begin
    	set @LatestModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
	 	set @ModifiedCondition = @ModifiedCondition + ' and ' + @LatestModifiedFilter
	end

    -- find all the catalog entries that have modified relations in NodeEntryRelation, or deleted relations in ApplicationLog
    if (@EarliestModifiedDate is not null and @LatestModifiedDate is not null)
    begin

		set @EarliestModifiedFilter = ' Modified >= cast(''' + CONVERT(nvarchar(100), @EarliestModifiedDate, 127) + ''' as datetime)'
		set @LatestModifiedFilter = ' Modified <= cast('''  + CONVERT(nvarchar(100), @LatestModifiedDate, 127) + ''' as datetime)'
		
		declare @EarliestModifiedFilterPadded nvarchar(4000) =  @EarliestModifiedFilter
		declare @LatestModifiedFilterPadded nvarchar(4000) = @LatestModifiedFilter

        -- adjust modified date filters to account for clock difference between database server and application server clocks    
        if (isnull(@DatabaseClockOffsetMS, 0) > 0)
        begin
            set @EarliestModifiedFilterPadded = ' Modified >= cast(''' + CONVERT(nvarchar(100), DATEADD(MS, -@DatabaseClockOffsetMS, @EarliestModifiedDate), 127) + ''' as datetime)'
			set @LatestModifiedFilterPadded = ' Modified <= cast('''  + CONVERT(nvarchar(100), DATEADD(MS, -@DatabaseClockOffsetMS, @LatestModifiedDate), 127) + ''' as datetime)'
		end

		-- applying the NodeEntryRelation.
		set @ModifiedCondition = @ModifiedCondition + ' union select CatalogEntryId from NodeEntryRelation where ' + @EarliestModifiedFilterPadded + ' and ' + @LatestModifiedFilterPadded
	
		set @EarliestModifiedFilter = REPLACE( @EarliestModifiedFilter, 'Modified', 'Created')
		set @LatestModifiedFilter = REPLACE( @LatestModifiedFilter, 'Modified', 'Created')
			
		set @AppLogQuery = ' union select cast(ObjectKey as int) as CatalogEntryId from ApplicationLog where [Source] = ''catalog'' and [Operation] = ''Modified'' and [ObjectType] = ''relation'' and ' + @EarliestModifiedFilter + ' and ' + @LatestModifiedFilter

		-- applying the ApplicationLog.
		set @ModifiedCondition = @ModifiedCondition + @AppLogQuery
    end

    set @query = 'insert into CatalogEntrySearchResults_SingleSort (SearchSetId, ResultIndex, CatalogEntryId) ' +
    'select distinct ''' + cast(@SearchSetId as nvarchar(36)) + ''', ROW_NUMBER() over (order by e.CatalogEntryId), e.CatalogEntryId from CatalogEntry e ' +
    ' inner join (' + @ModifiedCondition + ') o on e.CatalogEntryId = o.ObjectId' + 
	' where e.CatalogId = ' + cast(@CatalogId as nvarchar) + ' ' 	 
      
    if @IncludeInactive = 0 set @query = @query + ' and e.IsActive = 1'

    execute dbo.sp_executesql @query
    
    select @@ROWCOUNT
end
GO
PRINT N'Creating [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogNodeId > 0 OR t.CatalogEntryId <> c.CatalogEntryId
END
GO
PRINT N'Creating [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri Segment and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], t.[Uri], '' AS [UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.CatalogEntryId <> c.CatalogEntryId -- check against entry only
		AND t.UriSegment = c.UriSegment COLLATE DATABASE_DEFAULT
END

GO
PRINT N'Altering [dbo].[ecf_CatalogNode_Code]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_Code]
	@CatalogNodeCode nvarchar(100),
	@ReturnInactive bit = 0
AS
BEGIN	
	SELECT N.* from [CatalogNode] N
	WHERE
		N.Code = @CatalogNodeCode AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT S.* from CatalogItemSeo S
	INNER JOIN CatalogNode N ON N.CatalogNodeId = S.CatalogNodeId
	WHERE
		N.Code = @CatalogNodeCode AND
		((N.IsActive = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNode_UriLanguage]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_UriLanguage]
	@Uri nvarchar(255),
	@LanguageCode nvarchar(50),
	@ReturnInactive bit = 0
AS
BEGIN
	
	SELECT N.* from [CatalogNode] N 
	INNER JOIN CatalogItemSeo S ON N.CatalogNodeId = S.CatalogNodeId
	WHERE
		S.Uri = @Uri AND (S.LanguageCode = @LanguageCode OR @LanguageCode is NULL) AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT S.* from CatalogItemSeo S
	INNER JOIN CatalogNode N ON N.CatalogNodeId = S.CatalogNodeId
	WHERE
		S.Uri = @Uri AND (S.LanguageCode = @LanguageCode OR @LanguageCode is NULL) AND
		((N.IsActive = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Creating [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogNodeItemSeo_ValidateUri]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Node Uri and return invalid record
	SELECT t.[LanguageCode], t.[CatalogNodeId], t.[CatalogEntryId], '' AS [Uri], t.[UriSegment] 
	FROM @CatalogItemSeo t
	INNER JOIN CatalogItemSeo c ON
		t.LanguageCode = c.LanguageCode COLLATE DATABASE_DEFAULT
		AND t.Uri = c.Uri COLLATE DATABASE_DEFAULT
	-- check against both entry and node
	WHERE c.CatalogEntryId > 0 OR t.CatalogNodeId <> c.CatalogNodeId
END
GO
PRINT N'Creating [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]...';


GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntryItemSeo_ValidateUriAndUriSegment]
	@CatalogItemSeo dbo.udttCatalogItemSeo readonly
AS
BEGIN
	-- validate Entry Uri and Uri Segment, then return invalid record
	DECLARE @ValidSeoUri dbo.udttCatalogItemSeo
	DECLARE @ValidUriSegment dbo.udttCatalogItemSeo
	
	INSERT INTO @ValidSeoUri ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment] ) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUri] @CatalogItemSeo		
	
	INSERT INTO @ValidUriSegment ([LanguageCode], [CatalogNodeId], [CatalogEntryId], [Uri], [UriSegment] ) 
		EXEC [ecf_CatalogEntryItemSeo_ValidateUriSegment] @CatalogItemSeo

	MERGE @ValidSeoUri as U
	USING @ValidUriSegment as S
	ON 
		U.LanguageCode = S.LanguageCode COLLATE DATABASE_DEFAULT AND 
		U.CatalogEntryId = S.CatalogEntryId
	WHEN MATCHED -- update the UriSegment for existing row in #ValidSeoUri
		THEN UPDATE SET U.UriSegment = S.UriSegment
	WHEN NOT MATCHED BY TARGET -- insert new record if the record is does not exist in #ValidSeoUri table (source table)
		THEN INSERT VALUES(S.LanguageCode, S.CatalogNodeId, S.CatalogEntryId, S.Uri, S.UriSegment)
	;

	SELECT * FROM @ValidSeoUri
END
GO
PRINT N'Altering [dbo].[ecf_CatalogLog]...';


GO
ALTER PROCEDURE ecf_CatalogLog
	@Created datetime = null,
	@Operation nvarchar(50) = null,
	@ObjectType nvarchar(50) = null,
    @StartingRec int,
	@NumRecords int
AS
BEGIN
	SET NOCOUNT ON;
	WITH OrderedLogs AS 
	(
		select *, row_number() over(order by LogId) as RowNumber from CatalogLog where COALESCE(@Operation, Operation) = Operation and COALESCE(@ObjectType, ObjectType) = ObjectType and COALESCE(@Created, Created) <= Created
	),
	OrderedLogsCount(TotalCount) as
	(
		select count(LogId) from OrderedLogs
	)
	select LogId, Operation, ObjectKey, ObjectType, Username, Created, Succeeded, Notes, TotalCount from OrderedLogs, OrderedLogsCount
	where RowNumber between @StartingRec and @StartingRec+@NumRecords-1
	SET NOCOUNT OFF;
END
GO
PRINT N'Creating [dbo].[ecf_GetCatalogNodeCodesByIds]...';


GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogNodeCodesByIds]
	@CatalogIds udttCatalogCodeId READONLY
AS
BEGIN
	SELECT n.Code, n.CatalogNodeId from [CatalogNode] n
	INNER JOIN @CatalogIds k ON n.CatalogNodeId = k.ObjectId
END
GO
PRINT N'Creating [dbo].[ecf_GetCatalogNodeIdsByCodes]...';


GO
CREATE PROCEDURE [dbo].[ecf_GetCatalogNodeIdsByCodes]
	@CatalogCodes udttCatalogCodeId READONLY
AS
BEGIN
	SELECT n.Code, n.CatalogNodeId from [CatalogNode] n
	INNER JOIN @CatalogCodes k ON n.Code = k.Code
END
GO
PRINT N'Altering [dbo].[ecf_Setting_Name]...';


GO
ALTER PROCEDURE [dbo].[ecf_Setting_Name]
	@Name nvarchar(100)
AS
BEGIN
	select * from [CommonSettings] 
		where [Name] = @Name
END
GO
PRINT N'Altering [dbo].[ecf_Setting_SettingId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Setting_SettingId]
	@SettingId int
AS
BEGIN
	select * from [CommonSettings] 
		where [SettingId] = @SettingId
END
GO
PRINT N'Altering [dbo].[ecf_Settings]...';


GO
ALTER PROCEDURE [dbo].[ecf_Settings]
AS
BEGIN
	select * from [CommonSettings] 
END
GO
PRINT N'Altering [dbo].[ecf_Country]...';


GO
ALTER PROCEDURE [dbo].[ecf_Country]
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [Country] C 
		where
			(([Visible] = 1) or @ReturnInactive = 1)
		order by C.[Ordering], C.[Name]

	select SP.* from [StateProvince] SP 
		inner join [Country] C on C.[CountryId] = SP.[CountryId]
		where
			((C.[Visible] = 1) or @ReturnInactive = 1) and 
			((SP.[Visible] = 1) or @ReturnInactive = 1)
		order by SP.[Ordering], SP.[Name]
END
GO
PRINT N'Altering [dbo].[ecf_Country_Code]...';


GO
ALTER PROCEDURE [dbo].[ecf_Country_Code]
	@Code nvarchar(3),
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [Country] C 
		where [Code] = @Code and
			((C.[Visible] = 1) or @ReturnInactive = 1)

	select SP.* from [StateProvince] SP 
		inner join [Country] C on C.[CountryId] = SP.[CountryId]
		where C.[Code] = @Code and
			((C.[Visible] = 1) or @ReturnInactive = 1) and 
			((SP.[Visible] = 1) or @ReturnInactive = 1)
		order by SP.[Ordering], SP.[Name]
END
GO
PRINT N'Altering [dbo].[ecf_Country_CountryId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Country_CountryId]
	@CountryId int,
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [Country] C 
		where [CountryId] = @CountryId and 
			((C.[Visible] = 1) or @ReturnInactive = 1)

	select SP.* from [StateProvince] SP 
		inner join [Country] C on C.[CountryId] = SP.[CountryId]
		where SP.[CountryId] = @CountryId and 
			((C.[Visible] = 1) or @ReturnInactive = 1) and 
			((SP.[Visible] = 1) or @ReturnInactive = 1)
		order by SP.[Ordering], SP.[Name]
END
GO
PRINT N'Altering [dbo].[ecf_Currency]...';


GO

ALTER procedure dbo.ecf_Currency
as
begin
    select
        CompatCurrencyId as CurrencyId,
        CurrencyCode,
        CurrencyName as Name,
        Modified as ModifiedDate
    from Currency
    
    select
        cr.CurrencyRateId,
        cr.AverageRate,
        cr.EndOfDayRate,
        cr.ModifiedDate,
        cr.FromCurrencyId,
        cr.ToCurrencyId,
        cr.CurrencyRateDate
    from CurrencyRate cr
    where exists (select 1 from Currency c where c.CompatCurrencyId = cr.FromCurrencyId)
      and exists (select 1 from Currency c where c.CompatCurrencyId = cr.ToCurrencyId)
end
GO
PRINT N'Altering [dbo].[ecf_Currency_Code]...';


GO

ALTER procedure dbo.ecf_Currency_Code
    @CurrencyCode nvarchar(8)
as
begin
    select
        CompatCurrencyId as CurrencyId,
        CurrencyCode,
        CurrencyName as Name,
        Modified as ModifiedDate
    from dbo.Currency
    where CurrencyCode = @CurrencyCode

    select
        cr.CurrencyRateId,
        cr.AverageRate,
        cr.EndOfDayRate,
        cr.ModifiedDate,
        cr.FromCurrencyId,
        cr.ToCurrencyId,
        cr.CurrencyRateDate
    from dbo.CurrencyRate cr    
    where exists (select 1 from dbo.Currency c where c.CompatCurrencyId = cr.FromCurrencyId and c.CurrencyCode = @CurrencyCode)
       or exists (select 1 from dbo.Currency c where c.CompatCurrencyId = cr.ToCurrencyId and c.CurrencyCode = @CurrencyCode)
end
GO
PRINT N'Altering [dbo].[ecf_Currency_CurrencyId]...';


GO

ALTER procedure dbo.ecf_Currency_CurrencyId
    @CurrencyId int
as
begin
    select
        CompatCurrencyId as CurrencyId,
        CurrencyCode,
        CurrencyName as Name,
        Modified as ModifiedDate
    from dbo.Currency
    where CompatCurrencyId = @CurrencyId

    select
        cr.CurrencyRateId,
        cr.AverageRate,
        cr.EndOfDayRate,
        cr.ModifiedDate,
        cr.FromCurrencyId,
        cr.ToCurrencyId,
        cr.CurrencyRateDate
    from dbo.CurrencyRate cr        
    where (FromCurrencyId = @CurrencyId or ToCurrencyId = @CurrencyId)
      and exists (select 1 from dbo.Currency c where c.CompatCurrencyId = @CurrencyId)
end
GO
PRINT N'Creating [dbo].[ecf_Currency_Modify]...';


GO

create procedure dbo.ecf_Currency_Modify
    @Currency udttCompatCurrency readonly,
    @CurrencyRate udttCompatCurrencyRate readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction
        
        declare @identitymap table (Placeholder int, Actual int)

        delete from CurrencyRate
        where CurrencyRateId in (select CurrencyRateId from @CurrencyRate where Operation = 'D')

        delete from Currency
        where CompatCurrencyId in (select CurrencyId from @Currency where Operation = 'D')

        update tgt
        set
            Modified = isnull(src.ModifiedDate, GETUTCDATE()),
            CurrencyName = src.Name
        from @Currency src
        join Currency tgt on src.CurrencyId = tgt.CompatCurrencyId
        where src.Operation = 'U'

        insert into Currency (CurrencyCode, Created, Modified, CurrencyName)
        select CurrencyCode, isnull(ModifiedDate, GETUTCDATE()), isnull(ModifiedDate, GETUTCDATE()), Name
        from @Currency
        where Operation = 'I'

        if (@@rowcount > 0)
        begin
            insert into @identitymap (Placeholder, Actual)
            select src.CurrencyId, tgt.CompatCurrencyId
            from @Currency src
            join Currency tgt on src.CurrencyCode = tgt.CurrencyCode
            where Operation = 'I'
        end

        update tgt
        set
            AverageRate = src.AverageRate,
            EndOfDayRate = src.EndOfDayRate,
            ModifiedDate = isnull(src.ModifiedDate, GETUTCDATE()),
            FromCurrencyId = isnull(fromId.Actual, src.FromCurrencyId),
            ToCurrencyId = isnull(toId.Actual, src.ToCurrencyId),
            CurrencyRateDate = src.CurrencyRateDate
        from @CurrencyRate src
        left outer join @identitymap fromId on src.FromCurrencyId = fromId.Placeholder
        left outer join @identitymap toId on src.ToCurrencyId = toId.Placeholder
        join CurrencyRate tgt on src.CurrencyRateId = tgt.CurrencyRateId
        where src.Operation = 'U'

        insert into CurrencyRate (AverageRate, EndOfDayRate, ModifiedDate, FromCurrencyId, ToCurrencyId, CurrencyRateDate)
        select
            src.AverageRate,
            src.EndOfDayRate, 
            isnull(src.ModifiedDate, GETUTCDATE()),
            isnull(fromId.Actual, src.FromCurrencyId), 
            isnull(toId.Actual, src.ToCurrencyId), 
            src.CurrencyRateDate
        from @CurrencyRate src
        left outer join @identitymap fromId on src.FromCurrencyId = fromId.Placeholder
        left outer join @identitymap toId on src.ToCurrencyId = toId.Placeholder
        where src.Operation = 'I'

        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Altering [dbo].[ecf_mktg_Expression]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Expression]
    @ExpressionId int
AS
BEGIN
	
	if(@ExpressionId = 0)
		set @ExpressionId = null

	SELECT E.* from [Expression] E
	WHERE
		E.ExpressionId = COALESCE(@ExpressionId,E.ExpressionId)

END
GO
PRINT N'Altering [dbo].[ecf_mktg_Expression_Category]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Expression_Category]
    @Category nvarchar(50)
AS
BEGIN
	
	SELECT E.* from [Expression] E
	WHERE
		E.Category = @Category

END
GO
PRINT N'Altering [dbo].[ecf_mktg_Expression_Segment]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Expression_Segment]
    @SegmentId int
AS
BEGIN
	
	SELECT E.* from [Expression] E
	INNER JOIN SegmentCondition S ON E.ExpressionId = S.ExpressionId
	WHERE
		S.SegmentId = @SegmentId
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_AdjustInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_AdjustInventory]
    @changes [dbo].[udttInventory] READONLY
AS
BEGIN
    if exists (
        select 1 from @changes src 
        where not exists (select 1 from [dbo].[InventoryService] dst where dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]))
    begin
        raiserror('unmatched key found in update set', 16, 1)
    end
    else
    begin
        update dst
        set      
            [PurchaseAvailableQuantity] = dst.[PurchaseAvailableQuantity] + src.[PurchaseAvailableQuantity],
            [PreorderAvailableQuantity] = dst.[PreorderAvailableQuantity] + src.[PreorderAvailableQuantity],
            [BackorderAvailableQuantity] = dst.[BackorderAvailableQuantity] + src.[BackorderAvailableQuantity],
            [PurchaseRequestedQuantity] = dst.[PurchaseRequestedQuantity] + src.[PurchaseRequestedQuantity],
            [PreorderRequestedQuantity] = dst.[PreorderRequestedQuantity] + src.[PreorderRequestedQuantity],
            [BackorderRequestedQuantity] = dst.[BackorderRequestedQuantity] + src.[BackorderRequestedQuantity]
        from [dbo].[InventoryService] dst
        join (
            select 
                [CatalogEntryCode], [WarehouseCode],
                SUM([PurchaseAvailableQuantity]) as [PurchaseAvailableQuantity],
                SUM([PreorderAvailableQuantity]) as [PreorderAvailableQuantity],
                SUM([BackorderAvailableQuantity]) as [BackorderAvailableQuantity],
                SUM([PurchaseRequestedQuantity]) as [PurchaseRequestedQuantity],
                SUM([PreorderRequestedQuantity]) as [PreorderRequestedQuantity],
                SUM([BackorderRequestedQuantity]) as [BackorderRequestedQuantity]
            from @changes
            group by [CatalogEntryCode], [WarehouseCode]) src 
          on dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]
    end
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_DeleteInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_DeleteInventory]
    @partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    delete mi
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @partialKeys keys 
        where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
          and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_GetInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_GetInventory]
    @CatalogKeys udttCatalogKey readonly
AS
BEGIN
    select
        i.[CatalogEntryCode], 
        i.[WarehouseCode], 
        i.[IsTracked], 
        i.[PurchaseAvailableQuantity], 
        i.[PreorderAvailableQuantity], 
        i.[BackorderAvailableQuantity], 
        i.[PurchaseRequestedQuantity], 
        i.[PreorderRequestedQuantity], 
        i.[BackorderRequestedQuantity], 
        i.[PurchaseAvailableUtc],
        i.[PreorderAvailableUtc],
        i.[BackorderAvailableUtc],
        i.[AdditionalQuantity],
        i.[ReorderMinQuantity]
    from [dbo].[InventoryService] i
    inner join @CatalogKeys k
    on i.[CatalogEntryCode] = k.CatalogEntryCode
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_InsertInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_InsertInventory]
    @inventory [dbo].[udttInventory] READONLY
AS
BEGIN
    insert into [dbo].[InventoryService]
    (          
        [CatalogEntryCode],
        [WarehouseCode],
        [IsTracked],
        [PurchaseAvailableQuantity],
        [PreorderAvailableQuantity],
        [BackorderAvailableQuantity],
        [PurchaseRequestedQuantity],
        [PreorderRequestedQuantity],
        [BackorderRequestedQuantity],
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    )
    select
        src.[CatalogEntryCode],
        src.[WarehouseCode],
        src.[IsTracked],
        src.[PurchaseAvailableQuantity],
        src.[PreorderAvailableQuantity],
        src.[BackorderAvailableQuantity],
        src.[PurchaseRequestedQuantity],
        src.[PreorderRequestedQuantity],
        src.[BackorderRequestedQuantity],
        src.[PurchaseAvailableUtc],
        src.[PreorderAvailableUtc],
        src.[BackorderAvailableUtc],
        src.[AdditionalQuantity],
        src.[ReorderMinQuantity]
    from @inventory src
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_ListInventory]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_ListInventory]
AS
BEGIN
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService]
    order by [CatalogEntryCode], [WarehouseCode]
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_QueryInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_QueryInventory]
    @entryKeys [dbo].[udttInventoryCode] READONLY,
	@warehouseKeys [dbo].[udttInventoryCode] READONLY,
	@partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @entryKeys keys1 
        where mi.[CatalogEntryCode] = keys1.[Code])
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @warehouseKeys keys2 
        where mi.[WarehouseCode] = keys2.[Code])
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @partialKeys keys3 
        where mi.[CatalogEntryCode] = keys3.[CatalogEntryCode]
          and mi.[WarehouseCode] = keys3.[WarehouseCode])
    order by [CatalogEntryCode], [WarehouseCode]


END
GO
PRINT N'Creating [dbo].[ecf_Inventory_QueryInventoryPaged]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_QueryInventoryPaged]
    @offset int,
    @count int,
    @partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    declare @results table (
        [CatalogEntryCode] nvarchar(100),
        [WarehouseCode] nvarchar(50),
        [IsTracked] bit,
        [PurchaseAvailableQuantity] decimal(38, 9),
        [PreorderAvailableQuantity] decimal(38, 9),
        [BackorderAvailableQuantity] decimal(38, 9),
        [PurchaseRequestedQuantity] decimal(38, 9),
        [PreorderRequestedQuantity] decimal(38, 9),
        [BackorderRequestedQuantity] decimal(38, 9),
        [PurchaseAvailableUtc] datetime2,
        [PreorderAvailableUtc] datetime2,
        [BackorderAvailableUtc] datetime2,
        [AdditionalQuantity] decimal(38, 9),
        [ReorderMinQuantity] decimal(38, 9),
        [RowNumber] int,
        [TotalCount] int
    )

    insert into @results (
        [CatalogEntryCode],
        [WarehouseCode],
        [IsTracked],
        [PurchaseAvailableQuantity],
        [PreorderAvailableQuantity],
        [BackorderAvailableQuantity],
        [PurchaseRequestedQuantity],
        [PreorderRequestedQuantity],
        [BackorderRequestedQuantity],
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [TotalCount]
    )
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [RowNumber] + [ReverseRowNumber] - 1 as [TotalCount]
    from (
        select 
            ROW_NUMBER() over (order by [CatalogEntryCode], [WarehouseCode]) as [RowNumber],
            ROW_NUMBER() over (order by [CatalogEntryCode] desc, [WarehouseCode] desc) as [ReverseRowNumber],
            [CatalogEntryCode], 
            [WarehouseCode], 
            [IsTracked], 
            [PurchaseAvailableQuantity], 
            [PreorderAvailableQuantity], 
            [BackorderAvailableQuantity], 
            [PurchaseRequestedQuantity], 
            [PreorderRequestedQuantity], 
            [BackorderRequestedQuantity], 
            [PurchaseAvailableUtc],
            [PreorderAvailableUtc],
            [BackorderAvailableUtc],
            [AdditionalQuantity],
            [ReorderMinQuantity]
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
              and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
    ) paged
    where @offset < [RowNumber] and [RowNumber] <= (@offset + @count)

    if not exists (select 1 from @results)
    begin
        select COUNT(*) as TotalCount
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
              and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
    end
    else
    begin
        select top 1 [TotalCount] from @results
    end
       
    select 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from @results
    order by [RowNumber]
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_SaveInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_SaveInventory]
    @inventory [dbo].[udttInventory] READONLY
AS
BEGIN
    merge into [dbo].[InventoryService] dst
    using @inventory src
    on (dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode])
    when matched then
        update set      
            [IsTracked] = src.[IsTracked],
            [PurchaseAvailableQuantity] = src.[PurchaseAvailableQuantity],
            [PreorderAvailableQuantity] = src.[PreorderAvailableQuantity],
            [BackorderAvailableQuantity] = src.[BackorderAvailableQuantity],
            [PurchaseRequestedQuantity] = src.[PurchaseRequestedQuantity],
            [PreorderRequestedQuantity] = src.[PreorderRequestedQuantity],
            [BackorderRequestedQuantity] = src.[BackorderRequestedQuantity],
            [PurchaseAvailableUtc] = src.[PurchaseAvailableUtc],
            [PreorderAvailableUtc] = src.[PreorderAvailableUtc],
            [BackorderAvailableUtc] = src.[BackorderAvailableUtc],
            [AdditionalQuantity] = src.[AdditionalQuantity],
            [ReorderMinQuantity] = src.[ReorderMinQuantity]
    when not matched then 
        insert (
            [CatalogEntryCode],
            [WarehouseCode],
            [IsTracked],
            [PurchaseAvailableQuantity],
            [PreorderAvailableQuantity],
            [BackorderAvailableQuantity],
            [PurchaseRequestedQuantity],
            [PreorderRequestedQuantity],
            [BackorderRequestedQuantity],
            [PurchaseAvailableUtc],
            [PreorderAvailableUtc],
            [BackorderAvailableUtc],
            [AdditionalQuantity],
            [ReorderMinQuantity]
        ) values (
            src.[CatalogEntryCode],
            src.[WarehouseCode],
            src.[IsTracked],
            src.[PurchaseAvailableQuantity],
            src.[PreorderAvailableQuantity],
            src.[BackorderAvailableQuantity],
            src.[PurchaseRequestedQuantity],
            src.[PreorderRequestedQuantity],
            src.[BackorderRequestedQuantity],
            src.[PurchaseAvailableUtc],
            src.[PreorderAvailableUtc],
            src.[BackorderAvailableUtc],
            src.[AdditionalQuantity],
            src.[ReorderMinQuantity]
        );
END
GO
PRINT N'Creating [dbo].[ecf_Inventory_UpdateInventory]...';


GO
CREATE PROCEDURE [dbo].[ecf_Inventory_UpdateInventory]
    @inventory [dbo].[udttInventory] READONLY
AS
BEGIN
    if exists (
        select 1 from @inventory 
        group by [CatalogEntryCode], [WarehouseCode] 
        having COUNT(*) > 1)
    begin
        raiserror('duplicate key found in update set', 16, 1)
    end
    else if exists (
        select 1 from @inventory src 
        where not exists (select 1 from [dbo].[InventoryService] dst where dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]))
    begin
        raiserror('unmatched key found in update set', 16, 1)
    end
    else
    begin
        update dst
        set      
            [IsTracked] = src.[IsTracked],
            [PurchaseAvailableQuantity] = src.[PurchaseAvailableQuantity],
            [PreorderAvailableQuantity] = src.[PreorderAvailableQuantity],
            [BackorderAvailableQuantity] = src.[BackorderAvailableQuantity],
            [PurchaseRequestedQuantity] = src.[PurchaseRequestedQuantity],
            [PreorderRequestedQuantity] = src.[PreorderRequestedQuantity],
            [BackorderRequestedQuantity] = src.[BackorderRequestedQuantity],
            [PurchaseAvailableUtc] = src.[PurchaseAvailableUtc],
            [PreorderAvailableUtc] = src.[PreorderAvailableUtc],
            [BackorderAvailableUtc] = src.[BackorderAvailableUtc],
            [AdditionalQuantity] = src.[AdditionalQuantity],
            [ReorderMinQuantity] = src.[ReorderMinQuantity]
        from [dbo].[InventoryService] dst
        join @inventory src on dst.[CatalogEntryCode] = src.[CatalogEntryCode] and dst.[WarehouseCode] = src.[WarehouseCode]
    end
END
GO
PRINT N'Altering [dbo].[ecf_GetTaxes]...';


GO
ALTER PROCEDURE ecf_GetTaxes
	@SiteId uniqueidentifier,
	@TaxCategory nvarchar(50),
	@LanguageCode nvarchar(50),
	@CountryCode nvarchar(50),
	@StateProvinceCode nvarchar(50) = null,
	@ZipPostalCode nvarchar(50) = null,
	@District nvarchar(50) = null,
	@County nvarchar(50) = null,
	@City nvarchar(50) = null
AS
	SELECT V.Percentage, T.TaxType, T.Name, (select L.DisplayName from TaxLanguage L where L.TaxId = V.TaxId and LanguageCode = @LanguageCode) DisplayName from TaxValue V 
		inner join Tax T ON T.TaxId = V.TaxId
		inner join JurisdictionGroup JG ON JG.JurisdictionGroupId = V.JurisdictionGroupId
		inner join JurisdictionRelation JR ON JG.JurisdictionGroupId = JR.JurisdictionGroupId
		inner join Jurisdiction J ON JR.JurisdictionId = J.JurisdictionId
	WHERE 
		V.AffectiveDate < getutcdate() AND 
		V.TaxCategory = @TaxCategory AND
		(COALESCE(V.SiteId, @SiteId) = @SiteId or SiteId is null) AND
		J.CountryCode = @CountryCode AND 
		JG.JurisdictionType = 1 /*tax*/ AND
		(COALESCE(@StateProvinceCode, J.StateProvinceCode) = J.StateProvinceCode OR J.StateProvinceCode is null) AND
		((@ZipPostalCode between J.ZipPostalCodeStart and J.ZipPostalCodeEnd or @ZipPostalCode is null) OR J.ZipPostalCodeStart is null) AND
		(COALESCE(@District, J.District) = J.District OR J.District is null) AND
		(COALESCE(@County, J.County) = J.County OR J.County is null) AND
		(COALESCE(@City, J.City) = J.City OR J.City is null)
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction]
	@JurisdictionType int = null
AS
BEGIN
	select * from [Jurisdiction] 
		where (COALESCE(@JurisdictionType, [JurisdictionType]) = [JurisdictionType] OR [JurisdictionType] is null)

	select * from [JurisdictionGroup] 
		where (COALESCE(@JurisdictionType, [JurisdictionType]) = [JurisdictionType] OR [JurisdictionType] is null)

	select JR.* from [JurisdictionRelation] JR
		inner join [Jurisdiction] J on JR.[JurisdictionId]=J.[JurisdictionId]
		inner join [JurisdictionGroup] JG on JR.[JurisdictionGroupId]=JG.[JurisdictionGroupId]
		where (COALESCE(@JurisdictionType, J.[JurisdictionType]) = J.[JurisdictionType] OR J.[JurisdictionType] is null) and
			(COALESCE(@JurisdictionType, JG.[JurisdictionType]) = JG.[JurisdictionType] OR JG.[JurisdictionType] is null)
END
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction_JurisdictionCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction_JurisdictionCode]
	@JurisdictionCode nvarchar(50),
	@ReturnAllGroups bit = 0
AS
BEGIN
	select * from [Jurisdiction] 
		where [Code] = @JurisdictionCode

	IF @ReturnAllGroups=1 BEGIN -- return all jurisdiction groups of the found jurisdiction type
		select * from [JurisdictionGroup] 
			where [JurisdictionType] IN (select [JurisdictionType] from [Jurisdiction] 
											where [Code] = @JurisdictionCode)
	END ELSE BEGIN
		select JG.* from [JurisdictionGroup] JG
			inner join [JurisdictionRelation] JR on JR.[JurisdictionGroupId] = JG.[JurisdictionGroupId]
			inner join [Jurisdiction] J on JR.[JurisdictionId] = J.[JurisdictionId]
			where J.[Code] = @JurisdictionCode
	END

	select JR.* from [JurisdictionRelation] JR
		inner join [Jurisdiction] J on JR.[JurisdictionId]=J.[JurisdictionId]
		where J.[Code] = @JurisdictionCode
END
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction_JurisdictionId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction_JurisdictionId]
	@JurisdictionId int,
	@ReturnAllGroups bit = 0
AS
BEGIN
	select * from [Jurisdiction] 
		where [JurisdictionId] = @JurisdictionId

	IF @ReturnAllGroups=1 BEGIN -- return all jurisdiction groups of the found jurisdiction type
		select * from [JurisdictionGroup] 
			where [JurisdictionType] IN (select [JurisdictionType] from [Jurisdiction] 
											where [JurisdictionId] = @JurisdictionId)
	END ELSE BEGIN
		select JG.* from [JurisdictionGroup] JG
			inner join [JurisdictionRelation] JR on JR.[JurisdictionGroupId] = JG.[JurisdictionGroupId]
			where JR.[JurisdictionId] = @JurisdictionId
	END

	select JR.* from [JurisdictionRelation] JR
		inner join [Jurisdiction] J on JR.[JurisdictionId]=J.[JurisdictionId]
		where JR.[JurisdictionId] = @JurisdictionId
END
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction_JurisdictionGroupCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction_JurisdictionGroupCode]
	@JurisdictionGroupCode nvarchar(50)
AS
BEGIN
	select * from [JurisdictionGroup] 
		where [Code] = @JurisdictionGroupCode

	select JR.* from [JurisdictionRelation] JR
		inner join [JurisdictionGroup] J on JR.[JurisdictionGroupId]=J.[JurisdictionGroupId]
		where J.[Code] = @JurisdictionGroupCode
END
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction_JurisdictionGroupId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction_JurisdictionGroupId]
	@JurisdictionGroupId int
AS
BEGIN
	select * from [JurisdictionGroup] 
		where [JurisdictionGroupId] = @JurisdictionGroupId

	select JR.* from [JurisdictionRelation] JR
		inner join [JurisdictionGroup] J on JR.[JurisdictionGroupId]=J.[JurisdictionGroupId]
		where JR.[JurisdictionGroupId] = @JurisdictionGroupId
END
GO
PRINT N'Altering [dbo].[ecf_Jurisdiction_JurisdictionGroups]...';


GO
ALTER PROCEDURE [dbo].[ecf_Jurisdiction_JurisdictionGroups]
	@JurisdictionType int = null
AS
BEGIN
	select * from [JurisdictionGroup] JG
		where (COALESCE(@JurisdictionType, JG.[JurisdictionType]) = JG.[JurisdictionType] OR JG.[JurisdictionType] is null)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogRelation_NodeDelete]...';


GO
ALTER procedure [dbo].[ecf_CatalogRelation_NodeDelete]
    @CatalogEntries dbo.udttEntityList readonly,
    @CatalogNodes dbo.udttEntityList readonly
as
begin
    select * from CatalogNodeRelation cnr where 0=1
    
    select *
    from CatalogEntryRelation
    where ParentEntryId in (select EntityId from @CatalogEntries)
       or ChildEntryId in (select EntityId from @CatalogEntries)
       
    select CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary
    from NodeEntryRelation
    where CatalogEntryId in (select EntityId from @CatalogEntries)
       or CatalogNodeId in (select EntityId from @CatalogNodes)
end
GO
PRINT N'Altering [dbo].[ecf_NodeEntryRelations]...';


GO
ALTER PROCEDURE [dbo].[ecf_NodeEntryRelations]
	@ContentList udttContentList readonly
AS
BEGIN
	Select NodeEntryRelation.CatalogId, CatalogEntryId, CatalogNodeId, SortOrder, IsPrimary
	FROM NodeEntryRelation
	INNER JOIN @ContentList as idTable on idTable.ContentId = NodeEntryRelation.CatalogEntryId
END
GO
PRINT N'Altering [dbo].[ecf_OrderGroup_Insert]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderGroup_Insert]
(
	@OrderGroupId int OUT,
	@InstanceId uniqueidentifier,
	@AffiliateId uniqueidentifier,
	@Name nvarchar(64) = NULL,
	@CustomerId uniqueidentifier,
	@CustomerName nvarchar(64) = NULL,
	@AddressId nvarchar(50) = NULL,
	@ShippingTotal DECIMAL (38, 9),
	@HandlingTotal DECIMAL (38, 9),
	@TaxTotal DECIMAL (38, 9),
	@SubTotal DECIMAL (38, 9),
	@Total DECIMAL (38, 9),
	@BillingCurrency nvarchar(64) = NULL,
	@Status nvarchar(64) = NULL,
	@ProviderId nvarchar(255) = NULL,
	@SiteId nvarchar(255) = NULL,
	@OwnerOrg nvarchar(255) = NULL,
	@Owner nvarchar(255) = NULL,
	@MarketId nvarchar(8)
)
AS
BEGIN

	SET NOCOUNT OFF
	DECLARE @Err int

	if(@OrderGroupId is null)
	begin
		INSERT
		INTO [OrderGroup]
		(
			[InstanceId],
			[AffiliateId],
			[Name],
			[CustomerId],
			[CustomerName],
			[AddressId],
			[ShippingTotal],
			[HandlingTotal],
			[TaxTotal],
			[SubTotal],
			[Total],
			[BillingCurrency],
			[Status],
			[ProviderId],
			[SiteId],
			[OwnerOrg],
			[Owner],
			[MarketId]
		)
		VALUES
		(
			@InstanceId,
			@AffiliateId,
			@Name,
			@CustomerId,
			@CustomerName,
			@AddressId,
			@ShippingTotal,
			@HandlingTotal,
			@TaxTotal,
			@SubTotal,
			@Total,
			@BillingCurrency,
			@Status,
			@ProviderId,
			@SiteId,
			@OwnerOrg,
			@Owner,
			@MarketId
		)
		SELECT @OrderGroupId = SCOPE_IDENTITY()
	end

	SET @Err = @@Error

	RETURN @Err
END
GO
PRINT N'Altering [dbo].[ecf_OrderGroup_InsertForShoppingCart]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderGroup_InsertForShoppingCart]
(
	@OrderGroupId int OUT,
	@InstanceId UNIQUEIDENTIFIER,
	@AffiliateId UNIQUEIDENTIFIER,
	@Name nvarchar(64) = NULL,
	@CustomerId UNIQUEIDENTIFIER,
	@CustomerName nvarchar(64) = NULL,
	@AddressId nvarchar(50) = NULL,
	@ShippingTotal DECIMAL (38, 9),
	@HandlingTotal DECIMAL (38, 9),
	@TaxTotal DECIMAL (38, 9),
	@SubTotal DECIMAL (38, 9),
	@Total DECIMAL (38, 9),
	@BillingCurrency nvarchar(64) = NULL,
	@Status nvarchar(64) = NULL,
	@ProviderId nvarchar(255) = NULL,
	@SiteId nvarchar(255) = NULL,
	@OwnerOrg nvarchar(255) = NULL,
	@Owner nvarchar(255) = NULL,
	@MarketId nvarchar(8)
)
AS
BEGIN

	SET NOCOUNT OFF
	DECLARE @Err int
	set transaction isolation level serializable
	begin transaction
		IF NOT EXISTS (SELECT 1 
			from [OrderGroup_ShoppingCart] with (updlock)
			join [OrderGroup] with (updlock) on OrderGroupId = ObjectId 
			where [CustomerId] = @CustomerId 
				and Name = @Name COLLATE DATABASE_DEFAULT 
				and MarketId = @MarketId COLLATE DATABASE_DEFAULT ) 
				and @OrderGroupId is null
			begin
				INSERT
				INTO [OrderGroup]
				(
					[InstanceId],
					[AffiliateId],
					[Name],
					[CustomerId],
					[CustomerName],
					[AddressId],
					[ShippingTotal],
					[HandlingTotal],
					[TaxTotal],
					[SubTotal],
					[Total],
					[BillingCurrency],
					[Status],
					[ProviderId],
					[SiteId],
					[OwnerOrg],
					[Owner],
					[MarketId]
				)
				VALUES
				(
					@InstanceId,
					@AffiliateId,
					@Name,
					@CustomerId,
					@CustomerName,
					@AddressId,
					@ShippingTotal,
					@HandlingTotal,
					@TaxTotal,
					@SubTotal,
					@Total,
					@BillingCurrency,
					@Status,
					@ProviderId,
					@SiteId,
					@OwnerOrg,
					@Owner,
					@MarketId
				)
				SELECT @OrderGroupId = SCOPE_IDENTITY()
			end
	commit
	SET @Err = @@Error

	RETURN @Err
END
GO
PRINT N'Altering [dbo].[ecf_OrderGroup_Update]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderGroup_Update]
(
	@OrderGroupId int OUT,
	@InstanceId uniqueidentifier,
	@AffiliateId uniqueidentifier,
	@Name nvarchar(64) = NULL,
	@CustomerId uniqueidentifier,
	@CustomerName nvarchar(64) = NULL,
	@AddressId nvarchar(50) = NULL,
	@ShippingTotal DECIMAL (38, 9),
	@HandlingTotal DECIMAL (38, 9),
	@TaxTotal DECIMAL (38, 9),
	@SubTotal DECIMAL (38, 9),
	@Total DECIMAL (38, 9),
	@BillingCurrency nvarchar(64) = NULL,
	@Status nvarchar(64) = NULL,
	@ProviderId nvarchar(255) = NULL,
	@SiteId nvarchar(255) = NULL,
	@OwnerOrg nvarchar(255) = NULL,
	@Owner nvarchar(255) = NULL,
	@MarketId nvarchar(8)
)
AS
BEGIN

	SET NOCOUNT OFF
	DECLARE @Err int

		UPDATE [OrderGroup]
		SET
			[InstanceId] = @InstanceId,
			[AffiliateId] = @AffiliateId,
			[Name] = @Name,
			[CustomerId] = @CustomerId,
			[CustomerName] = @CustomerName,
			[AddressId] = @AddressId,
			[ShippingTotal] = @ShippingTotal,
			[HandlingTotal] = @HandlingTotal,
			[TaxTotal] = @TaxTotal,
			[SubTotal] = @SubTotal,
			[Total] = @Total,
			[BillingCurrency] = @BillingCurrency,
			[Status] = @Status,
			[ProviderId] = @ProviderId,
			[SiteId] = @SiteId,
			[OwnerOrg] = @OwnerOrg,
			[Owner] = @Owner,
			[MarketId] = @MarketId
		WHERE
			[OrderGroupId] = @OrderGroupId

	SET @Err = @@Error

	RETURN @Err
END
GO
PRINT N'Altering [dbo].[ecf_reporting_Shipping]...';


GO
ALTER PROCEDURE [dbo].[ecf_reporting_Shipping] 
	@MarketId nvarchar(8),
	@CurrencyCode NVARCHAR(8),
	@interval VARCHAR(20),
	@startdate DATETIME, -- parameter expected in UTC
	@enddate DATETIME, -- parameter expected in UTC
	@offset_st INT,
	@offset_dt INT
AS

BEGIN

	SELECT	x.Period,  
			ISNULL(y.ShippingMethodDisplayName, 'NONE') AS ShippingMethodDisplayName,
			ISNULL(y.NumberofOrders, 0) AS NumberOfOrders,
			ISNULL(y.ShippingTotal, 0) AS TotalShipping,
			ISNULL(y.ShippingDiscount, 0) AS ShippingDiscount,
			ISNULL(y.ShippingCost, 0) AS ShippingCost
			
	FROM 
	(
		SELECT DISTINCT 
			(CASE WHEN @interval = 'Day'
				THEN CONVERT(VARCHAR(10), D.DateFull, 101)
			WHEN @interval = 'Month'
			THEN (DATENAME(MM, D.DateFull) + ', ' + CAST(YEAR(D.DateFull) AS VARCHAR(20))) 
			ElSE CAST(YEAR(D.DateFull) AS VARCHAR(20))  
			End) AS Period 
		FROM ReportingDates D LEFT OUTER JOIN OrderFormEx FEX ON D.DateFull = FEX.Created
		WHERE 
			-- convert back from UTC using offset to generate a list of WEBSERVER datetimes
			D.DateFull BETWEEN 
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@startdate, @offset_st, @offset_dt) as float)) as datetime) AND
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@enddate, @offset_st, @offset_dt) as float)) as datetime)
	) AS x

	LEFT JOIN

	(
		SELECT DISTINCT (CASE WHEN @interval = 'Day'
							THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
							WHEN @interval = 'Month'
							THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' 
								+ CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
							ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
							End) AS Period, 
				COUNT(S.ShipmentId) AS NumberofOrders, 
				SUM(S.ShipmentTotal) AS ShippingTotal,
				SUM(S.ShippingDiscountAmount) AS ShippingDiscount,
				SUM(S.ShipmentTotal - S.ShippingDiscountAmount) AS ShippingCost,
				SM.DisplayName AS ShippingMethodDisplayName
		FROM Shipment AS S INNER JOIN
		ShippingMethod AS SM ON S.ShippingMethodId = SM.ShippingMethodId INNER JOIN
			OrderForm AS F ON S.OrderFormId = F.OrderFormId INNER JOIN
			OrderFormEx AS FEX ON FEX.ObjectId = F.OrderFormId INNER JOIN
			OrderGroup AS OG ON OG.OrderGroupId = F.OrderGroupId
		WHERE (FEX.Created BETWEEN @startdate AND @enddate)
		AND OG.BillingCurrency = @CurrencyCode 
		AND (LEN(@MarketId) = 0 OR OG.MarketId = @MarketId)
		AND S.Status <> 'Cancelled'
		GROUP BY (Case WHEN @interval = 'Day'
					THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
					WHEN @interval = 'Month'
					THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  )
					ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
				END), SM.DisplayName
	) AS y

	ON x.Period = y.Period
	ORDER BY CONVERT(datetime, x.Period, 101)

END
GO
PRINT N'Altering [dbo].[ecf_Search_PaymentPlan_Customer]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PaymentPlan_Customer]
    @CustomerId uniqueidentifier
AS
BEGIN
	declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)    
    select OrderGroupId 
    from [OrderGroup_PaymentPlan] PO 
    join OrderGroup OG on PO.ObjectId = OG.OrderGroupId
    where ([CustomerId] = @CustomerId)
        
    exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
	exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_PaymentPlan_CustomerAndName]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PaymentPlan_CustomerAndName]
    @CustomerId uniqueidentifier,
	@Name nvarchar(64)
AS
BEGIN
	declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)    
    select OrderGroupId 
    from [OrderGroup_PaymentPlan] PO 
    join OrderGroup OG on PO.ObjectId = OG.OrderGroupId 
    where ([CustomerId] = @CustomerId) and [Name] = @Name
    
    exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
	exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_PurchaseOrder_Customer]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PurchaseOrder_Customer]
    @CustomerId uniqueidentifier
AS
BEGIN
    declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)
	select [OrderGroupId]
	from [OrderGroup_PurchaseOrder] PO
	join OrderGroup OG on PO.ObjectId = OG.OrderGroupId
	where ([CustomerId] = @CustomerId)
	
	exec dbo.ecf_Search_OrderGroup @results
	
	-- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_PurchaseOrder_CustomerAndName]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PurchaseOrder_CustomerAndName]
    @CustomerId uniqueidentifier,
	@Name nvarchar(64)
AS
BEGIN
    declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)
	select [OrderGroupId] 
	from [OrderGroup_PurchaseOrder] PO 
	join OrderGroup OG on PO.ObjectId = OG.OrderGroupId 
	where ([CustomerId] = @CustomerId) and [Name] = @Name
	
	exec dbo.ecf_Search_OrderGroup @results
	
	-- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition	

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_ShoppingCart_Customer]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_ShoppingCart_Customer]
	@CustomerId uniqueidentifier
AS
BEGIN
    declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)
	select [OrderGroupId]
	from [OrderGroup_ShoppingCart] PO 
	join OrderGroup OG on PO.ObjectId = OG.OrderGroupId 
	where ([CustomerId] = @CustomerId)
	
	exec dbo.ecf_Search_OrderGroup @results
	
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId IN (SELECT [OrderGroupId] FROM @results)))
	begin
	    -- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)
		CREATE TABLE #OrderSearchResults (OrderGroupId int)
		insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition
        
		DROP TABLE #OrderSearchResults
	end
END
GO
PRINT N'Altering [dbo].[ecf_Search_ShoppingCart_CustomerAndName]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_ShoppingCart_CustomerAndName]
    @CustomerId uniqueidentifier,
	@Name nvarchar(64) = null
AS
BEGIN
    declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)
	select [OrderGroupId]
	from [OrderGroup_ShoppingCart] PO
	join OrderGroup OG on PO.ObjectId = OG.OrderGroupId
	where ([CustomerId] = @CustomerId) and [Name] = @Name

    exec dbo.ecf_Search_OrderGroup @results

	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId IN (SELECT [OrderGroupId] FROM @results)))
	begin
	    -- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)
		CREATE TABLE #OrderSearchResults (OrderGroupId int)
		insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

		DROP TABLE #OrderSearchResults
	end
END
GO
PRINT N'Altering [dbo].[ecf_ShippingMethod_Language]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingMethod_Language]
	@LanguageId nvarchar(10) = null,
	@ReturnInactive bit = 0
AS
BEGIN
	declare @_shippingMethodIds as table (ShippingMethodId uniqueidentifier)
	insert into @_shippingMethodIds
	select ShippingMethodId 
		from ShippingMethod 
		where COALESCE(@LanguageId, LanguageId) = LanguageId 
		and (([IsActive] = 1) or @ReturnInactive = 1) 

	select * from [ShippingOption]
	select SOP.* from [ShippingOptionParameter] SOP 
	inner join [ShippingOption] SO on SOP.[ShippingOptionId]=SO.[ShippingOptionId]
	select distinct SM.* from [ShippingMethod] SM 
	inner join [Warehouse] W on SM.Name <> 'In Store Pickup' or W.IsPickupLocation = 1
		where COALESCE(@LanguageId, LanguageId) = LanguageId and ((SM.[IsActive] = 1) or @ReturnInactive = 1)
		order by SM.Ordering
	select * from [ShippingMethodParameter] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingMethodCase] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingCountry] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingRegion] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
	select * from [ShippingPaymentRestriction] 
		where 
			(ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds) )
				and
			[RestrictShippingMethods] = 0
	select * from [Package]
	select SP.* from [ShippingPackage] SP 
	inner join [Package] P on SP.[PackageId]=P.[PackageId]
	select * from [MarketShippingMethods] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
END
GO
PRINT N'Altering [dbo].[ecf_ShippingMethod_Market]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingMethod_Market]
    @MarketId nvarchar(10) = null,
    @ReturnInactive bit = 0
AS
BEGIN
    declare @_shippingMethodIds as table (ShippingMethodId uniqueidentifier)
    insert into @_shippingMethodIds
    select SM.ShippingMethodId
        from [ShippingMethod] SM
        inner join [MarketShippingMethods] MSM
          on SM.ShippingMethodId = MSM.ShippingMethodId
        inner join [Warehouse] W
          on (SM.Name <> 'In Store Pickup' or W.IsPickupLocation = 1)
        where COALESCE(@MarketId, MSM.MarketId) = MSM.MarketId
          and ((SM.[IsActive] = 1) or (@ReturnInactive = 1))

    select * from [ShippingOption]
    
    select SOP.* from [ShippingOptionParameter] SOP 
    inner join [ShippingOption] SO on SOP.[ShippingOptionId]=SO.[ShippingOptionId]
        
    select distinct SM.* from [ShippingMethod] SM where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds) order by SM.Ordering
    select * from [ShippingMethodParameter] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingMethodCase] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingCountry] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    select * from [ShippingRegion] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
    
    select * from [ShippingPaymentRestriction]
        where 
            ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
            and
            [RestrictShippingMethods] = 0
    select * from [Package]

    select SP.* from [ShippingPackage] SP 
    inner join [Package] P on SP.[PackageId]=P.[PackageId]
	select * from [MarketShippingMethods] where ShippingMethodId in (select ShippingMethodId from @_shippingMethodIds)
END
GO
PRINT N'Altering [dbo].[ecf_ShippingMethod_ShippingMethodId]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingMethod_ShippingMethodId]
	@ShippingMethodId uniqueidentifier,
	@ReturnInactive bit = 0
AS
BEGIN
	select SO.* from [ShippingOption] SO
		inner join [ShippingMethod] SM on SO.[ShippingOptionId]=SM.[ShippingOptionId]
	where SM.[ShippingMethodId] = @ShippingMethodId

	select SOP.* from [ShippingOptionParameter] SOP 
		inner join [ShippingMethod] SM on SOP.[ShippingOptionId]=SM.[ShippingOptionId]
	where SM.[ShippingMethodId] = @ShippingMethodId

	select SM.* from [ShippingMethod] SM
		where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SMP.* from [ShippingMethodParameter] SMP
		inner join [ShippingMethod] SM on SMP.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SMC.* from [ShippingMethodCase] SMC
		inner join [ShippingMethod] SM on SMC.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SC.* from [ShippingCountry] SC
		inner join [ShippingMethod] SM on SC.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SR.* from [ShippingRegion] SR
		inner join [ShippingMethod] SM on SR.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SPR.* from [ShippingPaymentRestriction] SPR
		inner join [ShippingMethod] SM on SPR.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId and SPR.[RestrictShippingMethods] = 0

	select P.* from [Package] P
		inner join [ShippingPackage] SP on SP.[PackageId]=P.[PackageId]
		inner join [ShippingMethod] SM on SP.[ShippingOptionId]=SM.[ShippingOptionId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SP.* from [ShippingPackage] SP
		inner join [ShippingMethod] SM on SP.[ShippingOptionId]=SM.[ShippingOptionId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId

	select SMS.* from [MarketShippingMethods] SMS
		inner join [ShippingMethod] SM on SMS.[ShippingMethodId]=SM.[ShippingMethodId]
			where ((SM.[IsActive] = 1) or @ReturnInactive = 1) and SM.[ShippingMethodId] = @ShippingMethodId
END
GO
PRINT N'Altering [dbo].[ecf_ShippingOption_ShippingOptionId]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingOption_ShippingOptionId]
	@ShippingOptionId uniqueidentifier
AS
BEGIN
	select * from [ShippingOption] 
		where [ShippingOptionId] = @ShippingOptionId
	select SOP.* from [ShippingOptionParameter] SOP 
	inner join [ShippingOption] SO on SO.[ShippingOptionId]=SOP.[ShippingOptionId]
		where SO.[ShippingOptionId] = @ShippingOptionId
	select * from [Package] P
		inner join [ShippingPackage] SP on P.[PackageId]=SP.[PackageId]
			where SP.[ShippingOptionId] = @ShippingOptionId
	select * from [ShippingPackage] where [ShippingOptionId] = @ShippingOptionId
END
GO
PRINT N'Altering [dbo].[ecf_ShippingPackage]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingPackage]
AS
	select * from [Package] P
GO
PRINT N'Altering [dbo].[ecf_ShippingPackage_Name]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingPackage_Name]
	@Name nvarchar(100)
AS
	select * from [Package] P 
		where P.[Name] = @Name
GO
PRINT N'Altering [dbo].[ecf_ShippingPackage_PackageId]...';


GO
ALTER PROCEDURE [dbo].[ecf_ShippingPackage_PackageId]
	@PackageId int
AS
	select * from [Package] P 
		where P.[PackageId] = @PackageId
GO
PRINT N'Altering [dbo].[ecf_PaymentMethod_Language]...';


GO
ALTER PROCEDURE [dbo].[ecf_PaymentMethod_Language]
	@LanguageId nvarchar(128),
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [PaymentMethod] 
	where COALESCE(@LanguageId, [LanguageId]) = [LanguageId] and 
		(([IsActive] = 1) or @ReturnInactive = 1) order by [Ordering]

	select PMP.* from [PaymentMethodParameter] PMP 
	inner join [PaymentMethod] PM on PMP.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1)

	select SPR.* from [ShippingPaymentRestriction] SPR  
	inner join [PaymentMethod] PM on SPR.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1) and 
		SPR.[RestrictShippingMethods]=0
			
	select MPM.* from [MarketPaymentMethods] MPM  
	inner join [PaymentMethod] PM on MPM.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_PaymentMethod_Market]...';


GO
ALTER PROCEDURE [dbo].[ecf_PaymentMethod_Market]
	@MarketId nvarchar(8),
	@LanguageId nvarchar(128),
	@ReturnInactive bit = 0
AS
BEGIN
	select PM.* from [PaymentMethod] PM
	inner join [MarketPaymentMethods] PMM on PMM.[PaymentMethodId] = PM.[PaymentMethodId]
		where COALESCE(@MarketId, PMM.[MarketId]) = PMM.[MarketId] and
		COALESCE(@LanguageId, PM.[LanguageId]) = PM.[LanguageId] and
		((PM.[IsActive] = 1) or @ReturnInactive = 1)

	select PMP.* from [PaymentMethodParameter] PMP
	inner join [PaymentMethod] PM on PMP.[PaymentMethodId] = PM.[PaymentMethodId] 
	inner join [MarketPaymentMethods] PMM on PMM.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@MarketId, PMM.[MarketId]) = PMM.[MarketId] and 
		COALESCE(@LanguageId, PM.[LanguageId]) = PM.[LanguageId] and
		((PM.[IsActive] = 1) or @ReturnInactive = 1)

	select SPR.* from [ShippingPaymentRestriction] SPR  
	inner join [PaymentMethod] PM on SPR.[PaymentMethodId] = PM.[PaymentMethodId] 
	inner join [MarketPaymentMethods] PMM on PMM.[PaymentMethodId] = PM.[PaymentMethodId]
		where COALESCE(@MarketId, PMM.[MarketId]) = PMM.[MarketId] and
		COALESCE(@LanguageId, PM.[LanguageId]) = PM.[LanguageId] and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1) and
		SPR.[RestrictShippingMethods]=0

	select MPM.* from [MarketPaymentMethods] MPM  
	inner join [PaymentMethod] PM on MPM.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		MPM.[MarketId] = @MarketId and
		((PM.[IsActive] = 1) or @ReturnInactive = 1)

END
GO
PRINT N'Altering [dbo].[ecf_PaymentMethod_PaymentMethodId]...';


GO
ALTER PROCEDURE [dbo].[ecf_PaymentMethod_PaymentMethodId]
	@PaymentMethodId uniqueidentifier,
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [PaymentMethod] 
		where [PaymentMethodId] = @PaymentMethodId and 
			(([IsActive] = 1) or @ReturnInactive = 1)

	if @@rowcount > 0 begin
		select * from [PaymentMethodParameter] 
			where [PaymentMethodId] = @PaymentMethodId

		select * from [ShippingPaymentRestriction] 
			where [PaymentMethodId] = @PaymentMethodId and [RestrictShippingMethods] = 1
	end
	else begin
		-- select nothing
		select * from [PaymentMethodParameter] where 1=0
		select * from [ShippingPaymentRestriction] where 1=0
	end
		select MPM.* from [MarketPaymentMethods] MPM  
		inner join [PaymentMethod] PM on MPM.[PaymentMethodId] = PM.[PaymentMethodId] 
		where ((PM.[IsActive] = 1) or @ReturnInactive = 1) and 
		MPM.[PaymentMethodId] = @PaymentMethodId
END
GO
PRINT N'Altering [dbo].[ecf_PaymentMethod_SystemKeyword]...';


GO
ALTER PROCEDURE [dbo].[ecf_PaymentMethod_SystemKeyword]
	@SystemKeyword nvarchar(30),
	@LanguageId nvarchar(128),
	@MarketId nvarchar(8),
	@ReturnInactive bit = 0
AS
BEGIN
	select * from [PaymentMethod] 
	where COALESCE(@LanguageId, [LanguageId]) = [LanguageId] and 
		(([IsActive] = 1) or @ReturnInactive = 1) and 
		COALESCE (@SystemKeyword, [SystemKeyword]) = [SystemKeyword]
		order by [Ordering]

	select PMP.* from [PaymentMethodParameter] PMP 
	inner join [PaymentMethod] PM on PMP.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		(PM.[SystemKeyword] = @SystemKeyword) and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1)

	select SPR.* from [ShippingPaymentRestriction] SPR  
	inner join [PaymentMethod] PM on SPR.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		(PM.[SystemKeyword] = @SystemKeyword) and 
		((PM.[IsActive] = 1) or @ReturnInactive = 1) and 
		SPR.[RestrictShippingMethods]=1
	
	select MPM.* from [MarketPaymentMethods] MPM  
	inner join [PaymentMethod] PM on MPM.[PaymentMethodId] = PM.[PaymentMethodId] 
		where COALESCE(@LanguageId, PM.[LanguageId]) = [LanguageId] and 
		COALESCE (@SystemKeyword, [SystemKeyword]) = [SystemKeyword] and
		COALESCE (@MarketId, [MarketId]) = [MarketId] and
		((PM.[IsActive] = 1) or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_mktg_Policy]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Policy]
    @PolicyId int
AS
BEGIN

	if(@PolicyId = 0)
		set @PolicyId = null
	
	SELECT P.* from [Policy] P
	WHERE
		P.PolicyId = COALESCE(@PolicyId,P.PolicyId)

	SELECT GP.* from [GroupPolicy] GP
	INNER JOIN [Policy] P ON P.PolicyId = GP.PolicyId
	WHERE
		GP.PolicyId = COALESCE(@PolicyId,GP.PolicyId)

END
GO
PRINT N'Altering [dbo].[ecf_PriceDetail_Get]...';


GO
ALTER procedure [dbo].[ecf_PriceDetail_Get]
    @priceValueId bigint
as
begin
    select
        pd.PriceValueId,
        pd.Created,
        pd.Modified,
        pd.CatalogEntryCode,
        pd.MarketId,
        pd.CurrencyCode,
        pd.PriceTypeId,
        pd.PriceCode,
        pd.ValidFrom,
        pd.ValidUntil,
        pd.MinQuantity,
        pd.UnitPrice
    from PriceDetail pd
    where pd.PriceValueId = @priceValueId
end
GO
PRINT N'Creating [dbo].[ecf_PriceDetail_ReplacePrices]...';


GO
create procedure [dbo].[ecf_PriceDetail_ReplacePrices]
    @CatalogKeys udttCatalogKey readonly,
    @PriceValues udttCatalogEntryPrice readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction
    
        delete from PriceDetail
        where exists (select 1 from @CatalogKeys ck where ck.CatalogEntryCode = PriceDetail.CatalogEntryCode)
     
        insert into PriceDetail (Created, Modified, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice)
        select GETUTCDATE(), GETUTCDATE(), CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice
        from @PriceValues
                
        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Creating [dbo].[ecf_PriceDetail_Save]...';


GO
create procedure [dbo].[ecf_PriceDetail_Save]
    @priceValues udttPriceDetail readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        declare @results table (PriceValueId bigint)
        declare @affectedEntries table (CatalogEntryCode nvarchar(100))

        insert into @affectedEntries (CatalogEntryCode)
        select distinct CatalogEntryCode
        from dbo.PriceDetail
        where PriceValueId in (select PriceValueId from @priceValues where CatalogEntryCode is null)

        delete from dbo.PriceDetail
        where PriceValueId in (select PriceValueId from @priceValues where CatalogEntryCode is null)
                
        insert into @results (PriceValueId)
        select dst.PriceValueId
        from dbo.PriceDetail dst
        join @priceValues src on dst.PriceValueId = src.PriceValueId
        where src.PriceValueId > 0

        ;with update_effects as (
            select 
                dst.CatalogEntryCode as CatalogEntryCodeBefore,
                src.CatalogEntryCode as CatalogEntryCodeAfter
            from dbo.PriceDetail dst
            join @priceValues src on dst.PriceValueId = src.PriceValueId
        )
        insert into @affectedEntries (CatalogEntryCode)
        select CatalogEntryCodeBefore from update_effects
        union
        select CatalogEntryCodeAfter from update_effects

        update dst
        set
            Modified = GETUTCDATE(),
            CatalogEntryCode = src.CatalogEntryCode,
            MarketId = src.MarketId,
            CurrencyCode = src.CurrencyCode,
            PriceTypeId = src.PriceTypeId,
            PriceCode = src.PriceCode,
            ValidFrom = src.ValidFrom,
            ValidUntil = src.ValidUntil,
            MinQuantity = src.MinQuantity,
            UnitPrice = src.UnitPrice
        from dbo.PriceDetail dst
        join @priceValues src on dst.PriceValueId = src.PriceValueId
        where src.PriceValueId > 0

        declare @catalogEntryCode nvarchar(100)
        declare @marketId nvarchar(8)
        declare @currencyCode nvarchar(8)
        declare @priceTypeId int
        declare @priceCode nvarchar(256)
        declare @validFrom datetime
        declare @validUntil datetime
        declare @minQuantity decimal(38,9)
        declare @unitPrice DECIMAL (38, 9)
        declare inserted_prices cursor local for
            select CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice
            from @priceValues
            where PriceValueId <= 0
        open inserted_prices
        while 1=1
        begin
            fetch next from inserted_prices into @catalogEntryCode, @marketId, @currencyCode, @priceTypeId, @priceCode, @validFrom, @validUntil, @minQuantity, @unitPrice
            if @@FETCH_STATUS != 0 break

            insert into dbo.PriceDetail (Created, Modified, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice)
            values (GETUTCDATE(), GETUTCDATE(), @catalogEntryCode, @marketId, @currencyCode, @priceTypeId, @priceCode, @validFrom, @validUntil, @minQuantity, @unitPrice)

            insert into @results (PriceValueId) 
            values (SCOPE_IDENTITY())

            insert into @affectedEntries (CatalogEntryCode)
            values (@catalogEntryCode)
        end
        close inserted_prices

        select 
            PriceValueId,
            Created,
            Modified,
            CatalogEntryCode,
            MarketId,
            CurrencyCode,
            PriceTypeId,
            PriceCode,
            ValidFrom,
            ValidUntil,
            MinQuantity,
            UnitPrice
        from PriceDetail
        where PriceValueId in (select PriceValueId from @results)

        select
            pd.PriceValueId,
            pd.Created,
            pd.Modified,
            ae.CatalogEntryCode,
            pd.MarketId,
            pd.CurrencyCode,
            pd.PriceTypeId,
            pd.PriceCode,
            pd.ValidFrom,
            pd.ValidUntil,
            pd.MinQuantity,
            pd.UnitPrice
        from (select distinct CatalogEntryCode from @affectedEntries) ae
        left outer join PriceDetail pd on ae.CatalogEntryCode = pd.CatalogEntryCode

        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Creating [dbo].[ecf_Pricing_GetCatalogEntryPrices]...';


GO
create procedure dbo.ecf_Pricing_GetCatalogEntryPrices
    @CatalogKeys udttCatalogKey readonly
as
begin
    select pg.CatalogEntryCode, pg.MarketId, pg.CurrencyCode, pg.PriceTypeId, pg.PriceCode, pv.ValidFrom, pv.ValidUntil, pv.MinQuantity, pv.UnitPrice
    from @CatalogKeys ck
    join PriceGroup pg on ck.CatalogEntryCode = pg.CatalogEntryCode
    join PriceValue pv on pg.PriceGroupId = pv.PriceGroupId
end
GO
PRINT N'Creating [dbo].[ecf_Pricing_GetPrices]...';


GO

create procedure dbo.ecf_Pricing_GetPrices
    @MarketId nvarchar(8),
    @ValidOn datetime,
    @CatalogKeysAndQuantities udttCatalogKeyAndQuantity readonly,
    @CurrencyCodes udttCurrencyCode readonly,
    @CustomerPricing udttCustomerPricing readonly,
    @ReturnCustomerPricing bit = 0,
    @ReturnQuantities bit = 0
as
begin
    declare @filterCurrencies bit = case when exists (select 1 from @CurrencyCodes) then 1 else 0 end
    declare @filterCustomerPricing bit = case when exists (select 1 from @CustomerPricing) then 1 else 0 end

    select
        pg.CatalogEntryCode,
        pg.MarketId,
        pg.CurrencyCode,
        case when @ReturnCustomerPricing = 1 then pg.PriceTypeId else null end as PriceTypeId,
        case when @ReturnCustomerPricing = 1 then pg.PriceCode else null end as PriceCode,
        pv.ValidFrom,
        pv.ValidUntil,
        pv.MinQuantity,
        min(pv.UnitPrice) as UnitPrice
    from @CatalogKeysAndQuantities ckaq
    join PriceGroup pg on ckaq.CatalogEntryCode = pg.CatalogEntryCode
    join PriceValue pv on pg.PriceGroupId = pv.PriceGroupId
    where
		(@MarketId = '' or pg.MarketId = @MarketId)
        and (@filterCurrencies = 0 or pg.CurrencyCode in (select CurrencyCode from @CurrencyCodes))
        and (@filterCustomerPricing = 0 or exists (select 1 from @CustomerPricing cp where cp.PriceTypeId = pg.PriceTypeId and cp.PriceCode = pg.PriceCode))
        and pv.ValidFrom <= @ValidOn
        and (pv.ValidUntil is null or @ValidOn < pv.ValidUntil)
        and (@ReturnQuantities = 1 or (pv.MinQuantity <= ckaq.Quantity and ckaq.Quantity < ISNULL(pv.MaxQuantity, ckaq.Quantity+1)))
    group by pg.CatalogEntryCode, pg.MarketId, pg.CurrencyCode,
        case when @ReturnCustomerPricing = 1 then pg.PriceTypeId else null end,
        case when @ReturnCustomerPricing = 1 then pg.PriceCode else null end,
        pv.ValidFrom, pv.ValidUntil, pv.MinQuantity
end
GO
PRINT N'Creating [dbo].[ecf_Pricing_SetCatalogEntryPrices]...';


GO
create procedure dbo.ecf_Pricing_SetCatalogEntryPrices
    @CatalogKeys udttCatalogKey readonly,
    @PriceValues udttCatalogEntryPrice readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        delete pv
        from @CatalogKeys ck
        join dbo.PriceGroup pg on ck.CatalogEntryCode = pg.CatalogEntryCode
        join dbo.PriceValue pv on pg.PriceGroupId = pv.PriceGroupId

        merge into dbo.PriceGroup tgt
        using (select distinct CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode from @PriceValues) src
        on (    tgt.CatalogEntryCode = src.CatalogEntryCode
            and tgt.MarketId = src.MarketId
            and tgt.CurrencyCode = src.CurrencyCode
            and tgt.PriceTypeId = src.PriceTypeId
            and tgt.PriceCode = src.PriceCode)
        when matched then update set Modified = GETUTCDATE()
        when not matched then insert (Created, Modified, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode)
            values (GETUTCDATE(), GETUTCDATE(), src.CatalogEntryCode, src.MarketId, src.CurrencyCode, src.PriceTypeId, src.PriceCode);

        insert into dbo.PriceValue (PriceGroupId, ValidFrom, ValidUntil, MinQuantity, MaxQuantity, UnitPrice)
        select pg.PriceGroupId, src.ValidFrom, src.ValidUntil, src.MinQuantity, src.MaxQuantity, src.UnitPrice
        from @PriceValues src
        left outer join PriceGroup pg
            on  src.CatalogEntryCode = pg.CatalogEntryCode
            and src.MarketId = pg.MarketId
            and src.CurrencyCode = pg.CurrencyCode
            and src.PriceTypeId = pg.PriceTypeId
            and src.PriceCode = pg.PriceCode

        delete tgt
        from dbo.PriceGroup tgt
        join @CatalogKeys ck on tgt.CatalogEntryCode = ck.CatalogEntryCode
        left join dbo.PriceValue pv on pv.PriceGroupId = tgt.PriceGroupId
        where pv.PriceGroupId is null

        if @initialTranCount = 0 commit transaction
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Altering [dbo].[ecf_mktg_CancelExpiredPromoReservations]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_CancelExpiredPromoReservations]
    @Expires int
AS
BEGIN
	if(@Expires <= 0)
		return

	DECLARE @EXP DATETIME
	DECLARE @NOW DATETIME

	set @NOW = GetUTCDate()

	/*sabtract number of minutes from now time*/
	set @EXP = DATEADD(minute, 0-@Expires, @now)

	UPDATE [PromotionUsage]
	SET Status = 0
	FROM [PromotionUsage] U INNER JOIN Promotion P ON U.PromotionId = P.PromotionId
	WHERE
		U.Status = 1 and /*reserved*/
		U.LastUpdated < @EXP
END
GO
PRINT N'Altering [dbo].[ecf_mktg_Promotion]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Promotion]
    @PromotionId int
AS
BEGIN

	if(@PromotionId = 0)
		set @PromotionId = null
	
	SELECT P.* from [Promotion] P
	WHERE
		P.PromotionId = COALESCE(@PromotionId,P.PromotionId)
	ORDER BY
		P.Priority  DESC, P.CouponCode DESC, P.PromotionGroup

	SELECT PC.* from [PromotionCondition] PC
	INNER JOIN [Promotion] P ON P.PromotionId = PC.PromotionId
	WHERE
		PC.PromotionId = COALESCE(@PromotionId,PC.PromotionId)

	SELECT PG.* from [PromotionLanguage] PG
	INNER JOIN [Promotion] P ON P.PromotionId = PG.PromotionId
	WHERE
		PG.PromotionId = COALESCE(@PromotionId,PG.PromotionId)

	SELECT PP.* from [PromotionPolicy] PP
	INNER JOIN [Promotion] P ON P.PromotionId = PP.PromotionId
	WHERE
		PP.PromotionId = COALESCE(@PromotionId,PP.PromotionId)

END
GO
PRINT N'Altering [dbo].[ecf_mktg_PromotionUsage]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_PromotionUsage]
    @PromotionId int,
	@CustomerId uniqueidentifier = null,
	@OrderGroupId int = null
AS
BEGIN

	if(@PromotionId = 0)
		set @PromotionId = null

	if(@OrderGroupId = 0)
		set @OrderGroupId = null
	
	SELECT U.* from [PromotionUsage] U
	INNER JOIN Promotion P ON U.PromotionId = P.PromotionId
	WHERE
		U.PromotionId = COALESCE(@PromotionId,U.PromotionId) and
		U.CustomerId = COALESCE(@CustomerId,U.CustomerId) and
		U.OrderGroupId = COALESCE(@OrderGroupId,U.OrderGroupId)
END
GO
PRINT N'Altering [dbo].[ecf_Order_ReturnReasonsDictionairy]...';


GO
ALTER PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairy]
	@ReturnInactive bit = 0
 AS
 BEGIN
	SELECT * FROM dbo.ReturnReasonDictionary RRD
	where (([Visible] = 1) or @ReturnInactive = 1)
	order by RRD.[Ordering], RRD.[ReturnReasonText]
END
GO
PRINT N'Altering [dbo].[ecf_Order_ReturnReasonsDictionairyId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairyId]
	@ReturnReasonId int
 AS
 BEGIN
	SELECT [ReturnReasonId]
		  ,[ReturnReasonText]
		  ,[Ordering]
		  ,[Visible]
		FROM dbo.ReturnReasonDictionary
		where ReturnReasonId = @ReturnReasonId
END
GO
PRINT N'Altering [dbo].[ecf_Order_ReturnReasonsDictionairyName]...';


GO
ALTER PROCEDURE [dbo].[ecf_Order_ReturnReasonsDictionairyName]
	@ReturnReasonName nvarchar(50)
 AS
 BEGIN
	SELECT [ReturnReasonId]
		  ,[ReturnReasonText]
		FROM dbo.ReturnReasonDictionary
		where ReturnReasonText = @ReturnReasonName
END
GO
PRINT N'Altering [dbo].[ecf_RolePermission]...';


GO
ALTER PROCEDURE [dbo].[ecf_RolePermission]
	@Roles nvarchar(max)
AS
BEGIN
	SET NOCOUNT ON;
	select * from RolePermission where RoleName in (select Item from ecf_splitlist(@Roles))
END
GO
PRINT N'Altering [dbo].[mc_RolePermissionInsert]...';


GO
ALTER PROCEDURE [dbo].[mc_RolePermissionInsert]
@RoleName AS NVarChar(4000),
@Permission AS NVarChar(4000),
@RolePermissionId AS Int = NULL OUTPUT
AS
BEGIN
SET NOCOUNT ON;

INSERT INTO [RolePermission]
(
[RoleName],
[Permission])
VALUES(
@RoleName,
@Permission)
SELECT @RolePermissionId = SCOPE_IDENTITY();

END
GO
PRINT N'Altering [dbo].[mc_RolePermissionSelect]...';


GO
ALTER PROCEDURE [dbo].[mc_RolePermissionSelect]
@RolePermissionId AS Int
AS
BEGIN
SET NOCOUNT ON;

SELECT [t01].[RolePermissionId] AS [RolePermissionId], [t01].[RoleName] AS [RoleName], [t01].[Permission] AS [Permission]
FROM [RolePermission] AS [t01]
WHERE ([t01].[RolePermissionId]=@RolePermissionId)

END
GO
PRINT N'Altering [dbo].[mc_RolePermissionUpdate]...';


GO
ALTER PROCEDURE [dbo].[mc_RolePermissionUpdate]
@RoleName AS NVarChar(4000),
@Permission AS NVarChar(4000),
@RolePermissionId AS Int
AS
BEGIN
SET NOCOUNT ON;

UPDATE [RolePermission] SET
[RoleName] = @RoleName,
[Permission] = @Permission WHERE
[RolePermissionId] = @RolePermissionId

END
GO
PRINT N'Altering [dbo].[ecf_mktg_Segment]...';


GO
ALTER PROCEDURE [dbo].[ecf_mktg_Segment]
    @SegmentId int
AS
BEGIN

	if(@SegmentId = 0)
		set @SegmentId = null
	
	SELECT P.* from [Segment] P
	WHERE
		P.SegmentId = COALESCE(@SegmentId,P.SegmentId)

	SELECT SM.* from [SegmentMember] SM
	INNER JOIN [Segment] S ON S.SegmentId = SM.SegmentId
	WHERE
		SM.SegmentId = COALESCE(@SegmentId,SM.SegmentId)

	SELECT SC.* from [SegmentCondition] SC
	INNER JOIN [Segment] S ON S.SegmentId = SC.SegmentId
	WHERE
		SC.SegmentId = COALESCE(@SegmentId,SC.SegmentId)
END
GO
PRINT N'Altering [dbo].[ecf_Tax]...';


GO
ALTER PROCEDURE [dbo].[ecf_Tax]
	@TaxType int = null
AS
BEGIN
	select T.* from [Tax] T 
		where (COALESCE(@TaxType, T.[TaxType]) = T.[TaxType] OR T.[TaxType] is null)

	select TL.* from [TaxLanguage] TL
		inner join [Tax] T on TL.[TaxId]=T.[TaxId]
		where (COALESCE(@TaxType, T.[TaxType]) = T.[TaxType] OR T.[TaxType] is null)

	select TV.* from [TaxValue] TV
		inner join [Tax] T on TV.[TaxId]=T.[TaxId]
		where (COALESCE(@TaxType, T.[TaxType]) = T.[TaxType] OR T.[TaxType] is null)
END
GO
PRINT N'Altering [dbo].[ecf_Tax_TaxId]...';


GO
SET ANSI_NULLS ON;

SET QUOTED_IDENTIFIER OFF;


GO
ALTER PROCEDURE [dbo].[ecf_Tax_TaxId]
	@TaxId int	
AS
BEGIN
	select T.* from [Tax] T 
		where T.[TaxId] = @TaxId

	select TL.* from [TaxLanguage] TL
		inner join [Tax] T on T.[TaxId] = TL.[TaxId]
			where TL.[TaxId] = @TaxId

	select TV.* from [TaxValue] TV
		inner join [Tax] T on T.[TaxId] = TV.[TaxId]
			where TV.[TaxId] = @TaxId
END
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Altering [dbo].[ecf_Tax_TaxName]...';


GO
ALTER PROCEDURE [dbo].[ecf_Tax_TaxName]
	@Name nvarchar(50)
AS
BEGIN
	select T.* from [Tax] T 
		where T.[Name] = @Name 

	select TL.* from [TaxLanguage] TL
		inner join [Tax] T on T.[TaxId] = TL.[TaxId]
			where T.[Name] = @Name

	select TV.* from [TaxValue] TV
		inner join [Tax] T on T.[TaxId] = TV.[TaxId]
			where T.[Name] = @Name
END
GO
PRINT N'Altering [dbo].[ecf_TaxCategory]...';


GO
ALTER PROCEDURE [dbo].[ecf_TaxCategory]
AS
BEGIN
	
	SELECT T.* from [TaxCategory] T
	ORDER BY T.[Name]
END
GO
PRINT N'Altering [dbo].[ecf_TaxCategory_Name]...';


GO
ALTER PROCEDURE [dbo].[ecf_TaxCategory_Name]
	@Name nvarchar(50)
AS
BEGIN
	
	SELECT T.* from [TaxCategory] T
	WHERE
		T.[Name] = @Name
END
GO
PRINT N'Altering [dbo].[ecf_TaxCategory_TaxCategoryId]...';


GO
ALTER PROCEDURE [dbo].[ecf_TaxCategory_TaxCategoryId]
	@TaxCategoryId int
AS
BEGIN
	
	SELECT T.* from [TaxCategory] T
	WHERE
		T.[TaxCategoryId] = @TaxCategoryId
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_DeleteWarehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_DeleteWarehouse]
    @Code NVARCHAR(50)
AS
BEGIN    
    delete from [dbo].[Warehouse]
    where [Code] = @Code
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_GetWarehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_GetWarehouse]
    @Code nvarchar(50)
AS
BEGIN
    select
        [WarehouseId],
        [Name],
        [CreatorId],
        [Created],
        [ModifierId],
        [Modified],
        [IsActive],
        [IsPrimary],
        [SortOrder],
        [Code],
        [IsFulfillmentCenter],
        [IsPickupLocation],
        [IsDeliveryLocation],
        [FirstName],
        [LastName],
        [Organization],
        [Line1],
        [Line2],
        [City],
        [State],
        [CountryCode],
        [CountryName],
        [PostalCode],
        [RegionCode],
        [RegionName],
        [DaytimePhoneNumber],
        [EveningPhoneNumber],
        [FaxNumber],
        [Email]
    from [dbo].[Warehouse]
    where [Code] = @Code
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_InsertWarehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_InsertWarehouse]
    @Name NVARCHAR(255),
    @CreatorId NVARCHAR(100),
    @Created DATETIME,
    @ModifierId NVARCHAR(100),
    @Modified DATETIME,
    @IsActive BIT,
    @IsPrimary BIT,
    @SortOrder INT,
    @Code NVARCHAR(50),
    @IsFulfillmentCenter BIT,
    @IsPickupLocation BIT,
    @IsDeliveryLocation BIT,
    @FirstName NVARCHAR(64),
    @LastName NVARCHAR(64),
    @Organization NVARCHAR(64),
    @Line1 NVARCHAR(80),
    @Line2 NVARCHAR(80),
    @City NVARCHAR(64),
    @State NVARCHAR(64),
    @CountryCode NVARCHAR(50),
    @CountryName NVARCHAR(50),
    @PostalCode NVARCHAR(20),
    @RegionCode NVARCHAR(50),
    @RegionName NVARCHAR(64),
    @DaytimePhoneNumber NVARCHAR(32),
    @EveningPhoneNumber NVARCHAR(32),
    @FaxNumber NVARCHAR(32),
    @Email NVARCHAR(64)
AS
BEGIN    
    insert into [dbo].[Warehouse] (
        [Name],
        [CreatorId],
        [Created],
        [ModifierId],
        [Modified],
        [IsActive],
        [IsPrimary],
        [SortOrder],
        [Code],
        [IsFulfillmentCenter],
        [IsPickupLocation],
        [IsDeliveryLocation],
        [FirstName],
        [LastName],
        [Organization],
        [Line1],
        [Line2],
        [City],
        [State],
        [CountryCode],
        [CountryName],
        [PostalCode],
        [RegionCode],
        [RegionName],
        [DaytimePhoneNumber],
        [EveningPhoneNumber],
        [FaxNumber],
        [Email]
    ) values (
        @Name,
        @CreatorId,
        @Created,
        @ModifierId,
        @Modified,
        @IsActive,
        @IsPrimary,
        @SortOrder,
        @Code,
        @IsFulfillmentCenter,
        @IsPickupLocation,
        @IsDeliveryLocation,
        @FirstName,
        @LastName,
        @Organization,
        @Line1,
        @Line2,
        @City,
        @State,
        @CountryCode,
        @CountryName,
        @PostalCode,
        @RegionCode,
        @RegionName,
        @DaytimePhoneNumber,
        @EveningPhoneNumber,
        @FaxNumber,
        @Email
    )
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_ListWarehouses]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_ListWarehouses]
AS
BEGIN
    select
        [WarehouseId],
        [Name],
        [CreatorId],
        [Created],
        [ModifierId],
        [Modified],
        [IsActive],
        [IsPrimary],
        [SortOrder],
        [Code],
        [IsFulfillmentCenter],
        [IsPickupLocation],
        [IsDeliveryLocation],
        [FirstName],
        [LastName],
        [Organization],
        [Line1],
        [Line2],
        [City],
        [State],
        [CountryCode],
        [CountryName],
        [PostalCode],
        [RegionCode],
        [RegionName],
        [DaytimePhoneNumber],
        [EveningPhoneNumber],
        [FaxNumber],
        [Email]
    from [dbo].[Warehouse]
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_UpdateWarehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_UpdateWarehouse]
    @Name NVARCHAR(255),
    @CreatorId NVARCHAR(100),
    @Created DATETIME,
    @ModifierId NVARCHAR(100),
    @Modified DATETIME,
    @IsActive BIT,
    @IsPrimary BIT,
    @SortOrder INT,
    @Code NVARCHAR(50),
    @IsFulfillmentCenter BIT,
    @IsPickupLocation BIT,
    @IsDeliveryLocation BIT,
    @FirstName NVARCHAR(64),
    @LastName NVARCHAR(64),
    @Organization NVARCHAR(64),
    @Line1 NVARCHAR(80),
    @Line2 NVARCHAR(80),
    @City NVARCHAR(64),
    @State NVARCHAR(64),
    @CountryCode NVARCHAR(50),
    @CountryName NVARCHAR(50),
    @PostalCode NVARCHAR(20),
    @RegionCode NVARCHAR(50),
    @RegionName NVARCHAR(64),
    @DaytimePhoneNumber NVARCHAR(32),
    @EveningPhoneNumber NVARCHAR(32),
    @FaxNumber NVARCHAR(32),
    @Email NVARCHAR(64)
AS
BEGIN    
    update dbo.Warehouse
    set 
        [Name] = @Name,
        [CreatorId] = @CreatorId,
        [Created] = @Created,
        [ModifierId] = @ModifierId,
        [Modified] = @Modified,
        [IsActive] = @IsActive,
        [IsPrimary] = @IsPrimary,
        [SortOrder] = @SortOrder,
        [Code] = @Code,
        [IsFulfillmentCenter] = @IsFulfillmentCenter,
        [IsPickupLocation] = @IsPickupLocation,
        [IsDeliveryLocation] = @IsDeliveryLocation,
        [FirstName] = @FirstName,
        [LastName] = @LastName,
        [Organization] = @Organization,
        [Line1] = @Line1,
        [Line2] = @Line2,
        [City] = @City,
        [State] = @State,
        [CountryCode] = @CountryCode,
        [CountryName] = @CountryName,
        [PostalCode] = @PostalCode,
        [RegionCode] = @RegionCode,
        [RegionName] = @RegionName,
        [DaytimePhoneNumber] = @DaytimePhoneNumber,
        [EveningPhoneNumber] = @EveningPhoneNumber,
        [FaxNumber] = @FaxNumber,
        [Email] = @Email
    where [Code] = @Code    
END
GO
PRINT N'Altering [dbo].[ecf_Warehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Warehouse]
AS
BEGIN
	select * from [Warehouse] 
		order by [Name]
END
GO
PRINT N'Altering [dbo].[ecf_Warehouse_Delete]...';


GO
ALTER PROCEDURE dbo.ecf_Warehouse_Delete
	@WarehouseId INT
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE FROM dbo.Warehouse
    WHERE WarehouseId = @WarehouseId
    
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
PRINT N'Altering [dbo].[ecf_Warehouse_GetByCode]...';


GO
ALTER PROCEDURE dbo.ecf_Warehouse_GetByCode
	@Code NVARCHAR(50)
AS
BEGIN
	SELECT * FROM Warehouse
	WHERE Code = @Code
END
GO
PRINT N'Altering [dbo].[ecf_Warehouse_GetById]...';


GO
ALTER PROCEDURE dbo.ecf_Warehouse_GetById
	@WarehouseId INT
AS
BEGIN
	SELECT * FROM Warehouse
	WHERE WarehouseId = @WarehouseId
END
GO
PRINT N'Altering [dbo].[ecf_Warehouse_List]...';


GO
ALTER PROCEDURE dbo.ecf_Warehouse_List
AS
BEGIN
	SELECT * FROM Warehouse
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
PRINT N'Altering [dbo].[ecf_Warehouse_WarehouseId]...';


GO
ALTER PROCEDURE [dbo].[ecf_Warehouse_WarehouseId]
	@WarehouseId int
AS
BEGIN
	select * from [Warehouse] 
		where [WarehouseId] = @WarehouseId
END
GO
PRINT N'Altering [dbo].[ecf_WarehouseInventory_GetAllInventories]...';


GO
ALTER PROCEDURE dbo.ecf_WarehouseInventory_GetAllInventories
AS
BEGIN
	SELECT WI.WarehouseCode,
		WI.CatalogEntryCode,
		WI.InStockQuantity,
		WI.ReservedQuantity,
		WI.ReorderMinQuantity,
		WI.PreorderQuantity,
		WI.BackorderQuantity,
		WI.AllowPreorder,
		WI.AllowBackorder,
		WI.InventoryStatus,
		WI.PreorderAvailabilityDate,
		WI.BackorderAvailabilityDate
	FROM [WarehouseInventory] AS WI
	JOIN [Warehouse] AS W ON WI.WarehouseCode = W.Code
	ORDER BY W.SortOrder
	
END
GO
PRINT N'Creating [dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories]...';


GO
CREATE PROCEDURE dbo.ecf_WarehouseInventory_GetCatalogEntryInventories
	@CatalogKeys udttCatalogKey READONLY
AS
BEGIN
	SELECT WI.WarehouseCode,
		WI.CatalogEntryCode,
		WI.InStockQuantity,
		WI.ReservedQuantity,
		WI.ReorderMinQuantity,
		WI.PreorderQuantity,
		WI.BackorderQuantity,
		WI.AllowPreorder,
		WI.AllowBackorder,
		WI.InventoryStatus,
		WI.PreorderAvailabilityDate,
		WI.BackorderAvailabilityDate
	FROM @CatalogKeys AS ck
	JOIN [WarehouseInventory] AS WI ON ck.CatalogEntryCode = WI.CatalogEntryCode
	JOIN [Warehouse] AS W ON WI.WarehouseCode = W.Code
	ORDER BY W.SortOrder
END
GO
PRINT N'Creating [dbo].[ecf_WarehouseInventory_GetInventories]...';


GO
CREATE PROCEDURE [dbo].[ecf_WarehouseInventory_GetInventories]
	@CatalogKeys udttCatalogKey READONLY,
	@WarehouseCodes udttWarehouseCode READONLY
AS
BEGIN

    DECLARE
		@filterCatalogKeys BIT = CASE WHEN EXISTS (SELECT 1 FROM @CatalogKeys) THEN 1 ELSE 0 END,
		@filterWarehouseCodes BIT = CASE WHEN EXISTS (SELECT 1 FROM @WarehouseCodes) THEN 1 ELSE 0 END

	SELECT 
		WI.WarehouseCode,
		WI.CatalogEntryCode,
		WI.InStockQuantity,
		WI.ReservedQuantity,
		WI.ReorderMinQuantity,
		WI.PreorderQuantity,
		WI.BackorderQuantity,
		WI.AllowPreorder,
		WI.AllowBackorder,
		WI.InventoryStatus,
		WI.PreorderAvailabilityDate,
		WI.BackorderAvailabilityDate
	FROM [WarehouseInventory] AS WI
	JOIN [Warehouse] AS W ON WI.WarehouseCode = W.Code
        LEFT JOIN @WarehouseCodes as WC ON WI.WarehouseCode = WC.WarehouseCode
		LEFT JOIN @CatalogKeys as CK ON WI.CatalogEntryCode = CK.CatalogEntryCode
	WHERE (@filterWarehouseCodes = 0 OR WC.WarehouseCode is not NULL)
	AND (@filterCatalogKeys = 0 OR CK.CatalogEntryCode is not NULL)
	ORDER BY W.SortOrder, WI.CatalogEntryCode
END
GO
PRINT N'Creating [dbo].[ecf_WarehouseInventory_GetInventory]...';


GO
CREATE PROCEDURE dbo.ecf_WarehouseInventory_GetInventory
	@CatalogKeys udttCatalogKey READONLY,
	@WarehouseCode NVARCHAR(50)
AS
BEGIN
	SELECT WI.WarehouseCode,
		WI.CatalogEntryCode,
		WI.InStockQuantity,
		WI.ReservedQuantity,
		WI.ReorderMinQuantity,
		WI.PreorderQuantity,
		WI.BackorderQuantity,
		WI.AllowPreorder,
		WI.AllowBackorder,
		WI.InventoryStatus,
		WI.PreorderAvailabilityDate,
		WI.BackorderAvailabilityDate
	FROM @CatalogKeys AS ck
	JOIN [WarehouseInventory] AS WI ON ck.CatalogEntryCode = WI.CatalogEntryCode
	JOIN [Warehouse] AS W ON WI.WarehouseCode = W.Code
	WHERE WI.WarehouseCode = @WarehouseCode
	ORDER BY W.SortOrder
END
GO
PRINT N'Altering [dbo].[ecf_WarehouseInventory_GetWarehouseInventories]...';


GO
ALTER PROCEDURE dbo.ecf_WarehouseInventory_GetWarehouseInventories
	@WarehouseCode NVARCHAR(50)
AS
BEGIN
	SELECT WI.WarehouseCode,
		WI.CatalogEntryCode,
		WI.InStockQuantity,
		WI.ReservedQuantity,
		WI.ReorderMinQuantity,
		WI.PreorderQuantity,
		WI.BackorderQuantity,
		WI.AllowPreorder,
		WI.AllowBackorder,
		WI.InventoryStatus,
		WI.PreorderAvailabilityDate,
		WI.BackorderAvailabilityDate
	FROM [WarehouseInventory] AS WI
	JOIN [Warehouse] AS W ON WI.WarehouseCode = W.Code
	WHERE WI.WarehouseCode = @WarehouseCode
	ORDER BY W.SortOrder
	
END
GO
PRINT N'Altering [dbo].[ecf_WarehouseInventory_DeleteAllInventory]...';


GO
ALTER PROCEDURE dbo.ecf_WarehouseInventory_DeleteAllInventory
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE FROM WarehouseInventory
    
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
PRINT N'Creating [dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories]...';


GO
CREATE PROCEDURE dbo.ecf_WarehouseInventory_DeleteCatalogEntryInventories
	@CatalogKeys udttCatalogKey READONLY
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE WI
    FROM @CatalogKeys AS ck
    JOIN dbo.WarehouseInventory WI ON ck.CatalogEntryCode = WI.CatalogEntryCode
    
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
PRINT N'Creating [dbo].[ecf_WarehouseInventory_DeleteInventories]...';


GO
CREATE PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteInventories]
	@CatalogKeys udttCatalogKey READONLY,
	@WarehouseCodes udttWarehouseCode READONLY
AS
BEGIN
    DECLARE
		@filterCatalogKeys BIT = CASE WHEN EXISTS (SELECT 1 FROM @CatalogKeys) THEN 1 ELSE 0 END,
		@filterWarehouseCodes BIT = CASE WHEN EXISTS (SELECT 1 FROM @WarehouseCodes) THEN 1 ELSE 0 END

	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE WI
	FROM [WarehouseInventory] AS WI
	JOIN @CatalogKeys ck ON @filterCatalogKeys = 0 OR (WI.CatalogEntryCode = ck.CatalogEntryCode)
	JOIN @WarehouseCodes wCode ON @filterWarehouseCodes = 0 OR WI.WarehouseCode = wCode.WarehouseCode
    
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
PRINT N'Creating [dbo].[ecf_WarehouseInventory_DeleteInventory]...';


GO
CREATE PROCEDURE dbo.ecf_WarehouseInventory_DeleteInventory
	@CatalogKeys udttCatalogKey READONLY,
	@WarehouseCode NVARCHAR(50)
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE WI
    FROM @CatalogKeys AS ck
    JOIN dbo.WarehouseInventory WI ON ck.CatalogEntryCode = WI.CatalogEntryCode
    WHERE WI.WarehouseCode = @WarehouseCode
    
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
PRINT N'Altering [dbo].[ecf_WarehouseInventory_DeleteWarehouseInventories]...';


GO
ALTER PROCEDURE dbo.ecf_WarehouseInventory_DeleteWarehouseInventories
	@WarehouseCode NVARCHAR(50)
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE FROM dbo.WarehouseInventory
    WHERE WarehouseCode = @WarehouseCode
    
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
PRINT N'Creating [dbo].[ecf_WarehouseInventory_SaveInventories]...';


GO
CREATE PROCEDURE dbo.ecf_WarehouseInventory_SaveInventories
	@Inventories udttWarehouseInventory READONLY
AS
BEGIN
	BEGIN TRY
    DECLARE @initialTranCount INT = @@TRANCOUNT
    IF @initialTranCount = 0 BEGIN TRANSACTION
    
    DELETE WI
	FROM WarehouseInventory AS WI
	JOIN @Inventories arg ON 
		    arg.CatalogEntryCode = WI.CatalogEntryCode 
		AND arg.WarehouseCode = WI.WarehouseCode

	INSERT INTO dbo.WarehouseInventory 
	(WarehouseCode, CatalogEntryCode, InStockQuantity, ReservedQuantity, 
	 ReorderMinQuantity, PreorderQuantity, BackorderQuantity, AllowPreorder, 
	 AllowBackorder, InventoryStatus, PreorderAvailabilityDate, BackorderAvailabilityDate)
	SELECT arg.WarehouseCode, arg.CatalogEntryCode, arg.InStockQuantity, arg.ReservedQuantity, 
	 arg.ReorderMinQuantity, arg.PreorderQuantity, arg.BackorderQuantity, arg.AllowPreorder, 
	 arg.AllowBackorder, arg.InventoryStatus, arg.PreorderAvailabilityDate, arg.BackorderAvailabilityDate
	FROM @Inventories AS arg
    
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
PRINT N'Altering [dbo].[ecf_CatalogEntrySearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntrySearch]
(
	@SearchSetId				uniqueidentifier,
	@Language 					nvarchar(50),
	@Catalogs 					nvarchar(max),
	@CatalogNodes 				nvarchar(max),
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
	@KeywordPhrase				nvarchar(max),
	@OrderBy 					nvarchar(max),
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

BEGIN
	SET NOCOUNT ON
	
	DECLARE @FilterVariables_tmp 		nvarchar(max)
	DECLARE @query_tmp 		nvarchar(max)
	DECLARE @FilterQuery_tmp 		nvarchar(max)
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
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN NodeEntryRelation NodeEntryRelation ON CatalogEntry.CatalogEntryId = NodeEntryRelation.CatalogEntryId '
	end
	
	-- If nodes specified, no need to filter by catalog since that is done in node filter
	if(Len(@CatalogNodes) = 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN @Catalogs_temp catalogs ON CatalogEntry.CatalogId = catalogs.CatalogId '
	end

	-- If language specified, then filter by language	
	if (Len(@Language) != 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' INNER JOIN CatalogLanguage l ON l.CatalogId = CatalogEntry.CatalogId AND l.LanguageCode = N'''+@Language+'''' 
	end	

	-- CREATE "WHERE" NEEDED
	set @FilterQuery_tmp = @FilterQuery_tmp + N' WHERE 1=1'  --BUGBUG

	IF(@KeywordPhraseLength>0)
		SET @FilterQuery_tmp = @FilterQuery_tmp + N' AND CatalogEntry.Name LIKE N''%' + @KeywordPhrase + '%'' ';	

	if(Len(@CatalogNodes) != 0)
	begin
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND'
		-- Different filter if more than one category is specified
		if ((select count(Item) from ecf_splitlist(@CatalogNodes)) > 1)
		begin 
			set @FilterQuery_tmp = @FilterQuery_tmp + N' CatalogEntry.CatalogEntryId in (select NodeEntryRelation.CatalogEntryId from NodeEntryRelation NodeEntryRelation where '
		end
		set @FilterQuery_tmp = @FilterQuery_tmp + N' NodeEntryRelation.CatalogNodeId IN (select CatalogNode.CatalogNodeId from CatalogNode CatalogNode'
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
	
	--add meta class name filter
	DECLARE @MetaClassNameFilter NVARCHAR(MAX)
	SET @MetaClassNameFilter = ''
	IF (LEN(@Classes) > 0)
	BEGIN
		SET @MetaClassNameFilter = ' AND MC.Name IN (select Item from ecf_splitlist(''' +@Classes + '''))'
	END

	--if @MetaSQLClause is not empty, we filter by _ExcludedCatalogEntryMarkets field and also meta class name if it is not empty.
	IF(@MetaSQLClauseLength>0)
	BEGIN
		SET @FromQuery_tmp = @FromQuery_tmp + @MetaSQLClause
	END
	--if not, we filter by meta class name if it is not empty.
	ELSE IF (LEN(@Classes) > 0)
	BEGIN
		SET @FromQuery_tmp = @FromQuery_tmp + N' 
				INNER JOIN
				(
					select distinct CP.ObjectId 
					from CatalogContentProperty CP
					inner join MetaClass MC ON MC.MetaClassId = CP.MetaClassId
					Where CP.ObjectTypeId = 0 --entry only
						' + @MetaClassNameFilter +' 
				) FilteredEntries ON FilteredEntries.ObjectId = [CatalogEntry].CatalogEntryId
		 '
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

	-- print(@FullQuery)
	SET NOCOUNT OFF
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
PRINT N'Altering [dbo].[ecf_CatalogNodeSearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNodeSearch]
(
	@SearchSetId			uniqueidentifier,
	@Catalogs 				nvarchar(max),
	@CatalogNodes 			nvarchar(max),
	@SQLClause 				nvarchar(max),
	@MetaSQLClause 			nvarchar(max),
	@OrderBy 				nvarchar(max),
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
	set @FilterQuery_tmp =  N' WHERE ((1=1'
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
PRINT N'Altering [dbo].[ecf_OrderSearch]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderSearch]
(
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @query_tmp nvarchar(max)
	DECLARE @FilterQuery_tmp nvarchar(max)
	DECLARE @TableName_tmp sysname
	DECLARE @SelectMetaQuery_tmp nvarchar(max)
	DECLARE @FromQuery_tmp nvarchar(max)
	DECLARE @FullQuery nvarchar(max)

	-- 1. Cycle through all the available product meta classes
	print 'Iterating through meta classes'
	DECLARE MetaClassCursor CURSOR READ_ONLY
	FOR SELECT TableName FROM MetaClass 
		WHERE Namespace like @Namespace + '%' AND ([Name] in (select Item from ecf_splitlist(@Classes)) or @Classes = '')
		and IsSystem = 0

	OPEN MetaClassCursor
	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	WHILE (@@fetch_status = 0)
	BEGIN 
		print 'Metaclass Table: ' + @TableName_tmp
		set @Query_tmp = 'select 100 as ''Rank'', META.ObjectId as ''Key'', * from ' + @TableName_tmp + ' META'
		
		-- Add meta Where clause
		if(LEN(@MetaSQLClause)>0)
			set @query_tmp = @query_tmp + ' WHERE ' + @MetaSQLClause

		if(@SelectMetaQuery_tmp is null)
			set @SelectMetaQuery_tmp = @Query_tmp;
		else
			set @SelectMetaQuery_tmp = @SelectMetaQuery_tmp + N' UNION ALL ' + @Query_tmp;

	FETCH NEXT FROM MetaClassCursor INTO @TableName_tmp
	END
	CLOSE MetaClassCursor
	DEALLOCATE MetaClassCursor

	-- Create from command
	SET @FromQuery_tmp = N'FROM [OrderGroup] OrderGroup' + N' INNER JOIN (select distinct U.[Key], U.Rank from (' + @SelectMetaQuery_tmp + N') U) META ON OrderGroup.[OrderGroupId] = META.[Key] '

	set @FilterQuery_tmp = N' WHERE 1=1'
	-- add sql clause statement here, if specified
	if(Len(@SQLClause) != 0)
		set @FilterQuery_tmp = @FilterQuery_tmp + N' AND (' + @SqlClause + ')'

    if(Len(@OrderBy) = 0)
    begin
		set @OrderBy = '[OrderGroup].OrderGroupId DESC'
    end
	set @FullQuery = N'SELECT count([OrderGroup].OrderGroupId) OVER() TotalRecords, [OrderGroup].OrderGroupId, Rank, ROW_NUMBER() OVER(ORDER BY ' + @OrderBy + N') RowNumber ' + @FromQuery_tmp + @FilterQuery_tmp

	-- use temp table variable
	set @FullQuery = N'with OrderedResults as (' + @FullQuery +') INSERT INTO @Page_temp (TotalRecords, OrderGroupId) SELECT top(' + cast(@NumRecords as nvarchar(50)) + ') TotalRecords, OrderGroupId FROM OrderedResults WHERE RowNumber > ' + cast(@StartingRec as nvarchar(50)) + ';'
	set @FullQuery = 'declare @Page_temp table (TotalRecords int, OrderGroupId int);' + @FullQuery + ';select @RecordCount = TotalRecords from @Page_temp;SELECT OrderGroupId from @Page_temp;'
	--print @FullQuery
	exec sp_executesql @FullQuery, N'@RecordCount int output', @RecordCount = @RecordCount OUTPUT

	SET NOCOUNT OFF
END
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
PRINT N'Altering [dbo].[ecf_CatalogEntry_CatalogName]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_CatalogName]
	@CatalogName nvarchar(150),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN [Catalog] C ON N.CatalogId = C.CatalogId
	WHERE
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]
	@CatalogName nvarchar(150),
	@CatalogNodeCode nvarchar(100),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
	INNER JOIN CatalogNode CN ON R.CatalogNodeId = CN.CatalogNodeId
	INNER JOIN [Catalog] C ON R.CatalogId = C.CatalogId
	WHERE
		CN.Code = @CatalogNodeCode AND
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]
	@CatalogName nvarchar(150),
	@CatalogNodeId int,
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
	INNER JOIN [Catalog] C ON R.CatalogId = C.CatalogId
	WHERE
		R.CatalogNodeId = @CatalogNodeId AND
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNode_CatalogParentNodeCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogNode_CatalogParentNodeCode]
	@CatalogName nvarchar(150),
	@ParentNodeCode nvarchar(100),
	@ReturnInactive bit = 0
AS
BEGIN
	declare @CatalogId int
	declare @ParentNodeId int

	select @CatalogId = CatalogId from [Catalog] where [Name] = @CatalogName
	select @ParentNodeId = CatalogNodeId from [CatalogNode] where Code = @ParentNodeCode

	EXECUTE [ecf_CatalogNode_CatalogParentNode] @CatalogId,@ParentNodeId,@ReturnInactive
END
GO
PRINT N'Altering [dbo].[ecfVersion_ListByWorkIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_ListByWorkIds]
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
PRINT N'Altering [dbo].[ecf_CatalogEntry_AssociatedByCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_AssociatedByCode]
	@CatalogEntryCode nvarchar(100),
	@AssociationName nvarchar(150) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogEntryAssociation A ON A.CatalogEntryId = N.CatalogEntryId
	INNER JOIN CatalogAssociation CA ON CA.CatalogAssociationId = A.CatalogAssociationId
	INNER JOIN CatalogEntry NE ON NE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		NE.Code = @CatalogEntryCode AND COALESCE(@AssociationName, CA.AssociationName) = CA.AssociationName AND 
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY CA.SortOrder, A.SortOrder

	if(@AssociationName = '')
		set @AssociationName = null
	
	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_List]...';


GO
 ALTER PROCEDURE [dbo].[ecf_CatalogEntry_List]
    @CatalogEntries dbo.udttEntityList READONLY,
	@ResponseGroup INT = NULL
AS
BEGIN
	SELECT n.*
	FROM CatalogEntry n
	JOIN @CatalogEntries r ON n.CatalogEntryId = r.EntityId
	ORDER BY r.SortOrder
	
	SELECT s.*
	FROM CatalogItemSeo s
	JOIN @CatalogEntries r ON s.CatalogEntryId = r.EntityId

	IF @ResponseGroup IS NULL
	BEGIN
		SELECT er.CatalogId, er.CatalogEntryId, er.CatalogNodeId, er.SortOrder, er.IsPrimary
		FROM NodeEntryRelation er
		JOIN @CatalogEntries r ON er.CatalogEntryId = r.EntityId
	END
	
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT EntityId from @CatalogEntries

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_Name]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_Name]
	@Name nvarchar(100) = '',
	@ClassTypeId nvarchar(50) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN

	if(@ClassTypeId = '')
		set @ClassTypeId = null

	if(@Name = '')
		set @Name = null

	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	WHERE
	N.[Name] like @Name AND COALESCE(@ClassTypeId, N.ClassTypeId) = N.ClassTypeId AND
	((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON N.CatalogEntryId = C.ContentId
	

	SELECT DISTINCT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON S.CatalogEntryId = C.ContentId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntry_UriLanguage]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntry_UriLanguage]
	@Uri nvarchar(255),
	@LanguageCode nvarchar(50),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogItemSeo S ON N.CatalogEntryId = S.CatalogEntryId
	WHERE
		S.Uri = @Uri AND (S.LanguageCode = @LanguageCode OR @LanguageCode is NULL) AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT TOP(1) N.* from [CatalogEntry] N 
	INNER JOIN CatalogItemSeo S ON N.CatalogEntryId = S.CatalogEntryId
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogEntryByCode]...';


GO
ALTER PROCEDURE [dbo].[ecf_CatalogEntryByCode]
	@CatalogEntryCode nvarchar(100),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	WHERE
		N.Code = @CatalogEntryCode AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END
GO
PRINT N'Altering [dbo].[ecf_CatalogNode_GetAllChildEntries]...';


GO
ALTER procedure ecf_CatalogNode_GetAllChildEntries
    @catalogNodeIds udttCatalogNodeList readonly
as
begin
	declare @hierarchy table (CatalogNodeId int)
	insert @hierarchy exec ecf_CatalogNode_GetAllChildNodes @catalogNodeIds

    select distinct ce.CatalogEntryId, ce.Code
    from CatalogEntry ce
    join NodeEntryRelation ner on ce.CatalogEntryId = ner.CatalogEntryId
    where ner.CatalogNodeId in (select CatalogNodeId from @hierarchy)
end
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
PRINT N'Altering [dbo].[ecf_GetMostRecentOrder]...';


GO
ALTER PROCEDURE [dbo].[ecf_GetMostRecentOrder]
(
	@CustomerId uniqueidentifier
)
AS
BEGIN
    declare @results udttOrderGroupId
    
    insert into @results (OrderGroupId)
	select top 1 [OrderGroupId]
	from [OrderGroup_PurchaseOrder] PO
	join OrderGroup OG on PO.ObjectId = OG.OrderGroupId
	where ([CustomerId] = @CustomerId)
	ORDER BY ObjectId DESC

	exec dbo.ecf_Search_OrderGroup @results

	-- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults(OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults)'
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_ShoppingCart]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_ShoppingCart]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
    
    exec dbo.ecf_Search_OrderGroup @results
    
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId IN (SELECT [OrderGroupId] FROM @results)))
	begin
	    -- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)
		CREATE TABLE #OrderSearchResults (OrderGroupId int)
		insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
		if(Len(@OrderBy) = 0)
		begin
			set @OrderBy = 'OrderGroupId DESC'
		end
		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

		DROP TABLE #OrderSearchResults
	end
END
GO
PRINT N'Altering [dbo].[ecf_Search_PaymentPlan]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PaymentPlan]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
	
	exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Search_PurchaseOrder]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_PurchaseOrder]
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
	
	exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_SaveWarehouse]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_SaveWarehouse]
    @Name NVARCHAR(255),
    @CreatorId NVARCHAR(100),
    @Created DATETIME,
    @ModifierId NVARCHAR(100),
    @Modified DATETIME,
    @IsActive BIT,
    @IsPrimary BIT,
    @SortOrder INT,
    @Code NVARCHAR(50),
    @IsFulfillmentCenter BIT,
    @IsPickupLocation BIT,
    @IsDeliveryLocation BIT,
    @FirstName NVARCHAR(64),
    @LastName NVARCHAR(64),
    @Organization NVARCHAR(64),
    @Line1 NVARCHAR(80),
    @Line2 NVARCHAR(80),
    @City NVARCHAR(64),
    @State NVARCHAR(64),
    @CountryCode NVARCHAR(50),
    @CountryName NVARCHAR(50),
    @PostalCode NVARCHAR(20),
    @RegionCode NVARCHAR(50),
    @RegionName NVARCHAR(64),
    @DaytimePhoneNumber NVARCHAR(32),
    @EveningPhoneNumber NVARCHAR(32),
    @FaxNumber NVARCHAR(32),
    @Email NVARCHAR(64)
AS
BEGIN
    if exists (select 1 from [dbo].[Warehouse] where [Code] = @Code)
    begin
        exec [dbo].[ecf_Inventory_UpdateWarehouse]
            @Name,
            @CreatorId,
            @Created,
            @ModifierId,
            @Modified,
            @IsActive,
            @IsPrimary,
            @SortOrder,
            @Code,
            @IsFulfillmentCenter,
            @IsPickupLocation,
            @IsDeliveryLocation,
            @FirstName,
            @LastName,
            @Organization,
            @Line1,
            @Line2,
            @City,
            @State,
            @CountryCode,
            @CountryName,
            @PostalCode,
            @RegionCode,
            @RegionName,
            @DaytimePhoneNumber,
            @EveningPhoneNumber,
            @FaxNumber,
            @Email
    end
    else
    begin
        exec [dbo].[ecf_Inventory_InsertWarehouse]
            @Name,
            @CreatorId,
            @Created,
            @ModifierId,
            @Modified,
            @IsActive,
            @IsPrimary,
            @SortOrder,
            @Code,
            @IsFulfillmentCenter,
            @IsPickupLocation,
            @IsDeliveryLocation,
            @FirstName,
            @LastName,
            @Organization,
            @Line1,
            @Line2,
            @City,
            @State,
            @CountryCode,
            @CountryName,
            @PostalCode,
            @RegionCode,
            @RegionName,
            @DaytimePhoneNumber,
            @EveningPhoneNumber,
            @FaxNumber,
            @Email
    end
END
GO

-- Detach ApplicationId metafields from metaclasses
DELETE FROM [dbo].[MetaClassMetaFieldRelation] WHERE MetaFieldId IN
(SELECT MetaFieldId FROM [dbo].[MetaField] WHERE Name = 'ApplicationId' AND SystemMetaClassId != 0 AND Namespace LIKE '%System%')

-- Delete ApplicationId metafields
DELETE FROM [dbo].[MetaField] WHERE Name = 'ApplicationId' AND SystemMetaClassId != 0 AND Namespace LIKE '%System%'

GO

PRINT N'Refreshing [dbo].[ecf_ApplicationLog_DeletedEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ApplicationLog_DeletedEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_ApplicationLog_LogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ApplicationLog_LogId]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Load]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Load]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_LoadBatch]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_LoadBatch]';


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
PRINT N'Refreshing [dbo].[ecfVersion_SyncCatalogData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncCatalogData]';


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
SET ANSI_NULLS, QUOTED_IDENTIFIER OFF;


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_sys_GetMetaKey]';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Refreshing [dbo].[CatalogContent_GetDefaultIndividualPublishStatus]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContent_GetDefaultIndividualPublishStatus]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[ecf_AllCatalogEntry_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_AllCatalogEntry_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogAssociation_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogAssociation_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_ListSimple]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_ListSimple]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_SearchInsertList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_SearchInsertList]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntryItemSeo_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntryItemSeo_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_ChildEntryCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_ChildEntryCount]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetChildrenEntries]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetChildrenEntries]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidEntry_Find]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidEntry_Find]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidEntry_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidEntry_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_PropertyDefinitionIsUsed]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PropertyDefinitionIsUsed]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByObjectId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByObjectId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByObjectIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByObjectIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_DeleteByWorkId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_DeleteByWorkId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListMatchingSegments]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListMatchingSegments]';


GO
PRINT N'Refreshing [dbo].[mdpsp_GetChildBySegment]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mdpsp_GetChildBySegment]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_List]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_List]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_SiteId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_SiteId]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogNode]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogNode]';


GO
PRINT N'Refreshing [dbo].[CatalogNode_FindParentId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogNode_FindParentId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_ChildNodeCount]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_ChildNodeCount]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNode_GetAllChildNodes]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNode_GetAllChildNodes]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogNodesList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogNodesList]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidNode_Find]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidNode_Find]';


GO
PRINT N'Refreshing [dbo].[ecf_GuidNode_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_GuidNode_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_Currency_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Currency_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_Currency_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Currency_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_Currency_GetAll]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Currency_GetAll]';


GO
PRINT N'Refreshing [dbo].[ecf_Currency_Update]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Currency_Update]';


GO
PRINT N'Refreshing [dbo].[ecf_ShippingMethod_GetCases]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ShippingMethod_GetCases]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Components]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Components]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Full]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Full]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Variation]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Variation]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_OrderGroup]';


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
PRINT N'Refreshing [dbo].[ecf_OrderGroup_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderGroup_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_SaleReport]...';


GO
SET QUOTED_IDENTIFIER ON;

SET ANSI_NULLS OFF;


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_SaleReport]';


GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Refreshing [dbo].[ecf_Search_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_OrderGroup]';


GO
PRINT N'Refreshing [dbo].[mc_RolePermissionDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mc_RolePermissionDelete]';


GO
PRINT N'Refreshing [dbo].[CatalogContentProperty_Save]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[CatalogContentProperty_Save]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_UpdateMasterLanguage]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_UpdateMasterLanguage]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_Associated]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_Associated]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_CatalogNodeId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_CatalogNodeId]';


GO
PRINT N'Refreshing [dbo].[ecf_CatalogEntry_ParentEntryId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_CatalogEntry_ParentEntryId]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncEntryData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncEntryData]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_CatalogEntry]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_CatalogEntry]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncNodeData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncNodeData]';


GO
 
-- removes sprocs related to removed subsystem versions
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetApplicationSchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetApplicationSchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetBusinessFoundationSchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetBusinessFoundationSchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetCatalogSchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetCatalogSchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetMarketingSchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetMarketingSchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetOrderSchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetOrderSchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[GetSecuritySchemaVersionNumber]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[GetSecuritySchemaVersionNumber]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[mc_mcmd_MetaModelVersionIdSelect]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[mc_mcmd_MetaModelVersionIdSelect]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[mc_mcmd_MetaModelVersionIdUpdate]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[mc_mcmd_MetaModelVersionIdUpdate]
GO

--drop tables related to removed subsystem versions
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'mcmd_MetaModelVersionId')
	DROP TABLE [dbo].[mcmd_MetaModelVersionId]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_ApplicationSystem')
	DROP TABLE [dbo].[SchemaVersion_ApplicationSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_BusinessFoundation')
	DROP TABLE [dbo].[SchemaVersion_BusinessFoundation]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_CatalogSystem')
	DROP TABLE [dbo].[SchemaVersion_CatalogSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_MarketingSystem')
	DROP TABLE [dbo].[SchemaVersion_MarketingSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_MetaDataSystem')
	DROP TABLE [dbo].[SchemaVersion_MetaDataSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_OrderSystem')
	DROP TABLE [dbo].[SchemaVersion_OrderSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_PricingSystem')
	DROP TABLE [dbo].[SchemaVersion_PricingSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_ReportingSystem')
	DROP TABLE [dbo].[SchemaVersion_ReportingSystem]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion_SecuritySystem')
	DROP TABLE [dbo].[SchemaVersion_SecuritySystem]
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(8, 0, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 

