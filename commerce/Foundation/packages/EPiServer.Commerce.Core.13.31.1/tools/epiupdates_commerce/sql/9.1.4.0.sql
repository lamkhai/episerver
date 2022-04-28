--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[PromotionInformation].[IDX_PromotionInformation_PromotionGuid_CustomerId]...';


GO
DROP INDEX [IDX_PromotionInformation_PromotionGuid_CustomerId]
    ON [dbo].[PromotionInformation];


GO
PRINT N'Dropping [dbo].[IX_CatalogEntryAssociation]...';


GO
ALTER TABLE [dbo].[CatalogEntryAssociation] DROP CONSTRAINT [IX_CatalogEntryAssociation];


GO
PRINT N'Creating [dbo].[udttLineItemReportData]...';


GO
CREATE TYPE [dbo].[udttLineItemReportData] AS TABLE (
    [LineItemId]          INT             NOT NULL,
    [LineItemCode]        NVARCHAR (255)  NOT NULL,
    [DisplayName]         NVARCHAR (255)  NULL,
    [PlacedPrice]         DECIMAL (38, 9) NOT NULL,
    [Quantity]            DECIMAL (38, 9) NOT NULL,
    [EntryDiscountAmount] DECIMAL (38, 9) NOT NULL,
    [OrderDiscountAmount] DECIMAL (38, 9) NOT NULL,
    [ExtendedPrice]       DECIMAL (38, 9) NOT NULL,
    [SalesTax]            DECIMAL (38, 9) NOT NULL,
    [OrderGroupId]        INT             NOT NULL,
    [OrderCreatedDate]    DATETIME        NOT NULL);


GO
PRINT N'Creating [dbo].[udttOrderReportData]...';


GO
CREATE TYPE [dbo].[udttOrderReportData] AS TABLE (
    [OrderGroupId]        INT              NOT NULL,
    [OrderNumber]         NVARCHAR (512)   NOT NULL,
    [Currency]            NVARCHAR (8)     NOT NULL,
    [CustomerId]          UNIQUEIDENTIFIER NOT NULL,
    [CustomerName]        NVARCHAR (64)    NULL,
    [Status]              NVARCHAR (64)    NOT NULL,
    [OrderCreatedDate]    DATETIME         NOT NULL,
    [MarketId]            NVARCHAR (8)     NOT NULL,
    [TotalQuantity]       DECIMAL (38, 9)  NOT NULL,
    [TotalDiscountAmount] DECIMAL (38, 9)  NOT NULL,
    [ShippingTotal]       DECIMAL (38, 9)  NOT NULL,
    [HandlingTotal]       DECIMAL (38, 9)  NOT NULL,
    [TaxTotal]            DECIMAL (38, 9)  NOT NULL,
    [SubTotal]            DECIMAL (38, 9)  NOT NULL,
    [Total]               DECIMAL (38, 9)  NOT NULL);


GO
PRINT N'Creating [dbo].[PromotionInformation].[IDX_PromotionInformation_PromotionGuid_CustomerId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_PromotionInformation_PromotionGuid_CustomerId]
    ON [dbo].[PromotionInformation]([PromotionGuid] ASC) WHERE IsRedeemed = 1;


GO
PRINT N'Creating [dbo].[CatalogEntryAssociation].[IX_CatalogEntryAssociation_CatalogEntryId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CatalogEntryAssociation_CatalogEntryId]
    ON [dbo].[CatalogEntryAssociation]([CatalogEntryId] ASC);


GO
PRINT N'Creating [dbo].[PromotionInformation].[IDX_PromotionInformation_CustomerId_PromotionGuid]...';


GO
CREATE NONCLUSTERED INDEX [IDX_PromotionInformation_CustomerId_PromotionGuid]
    ON [dbo].[PromotionInformation]([CustomerId] ASC, [PromotionGuid] ASC);


GO
PRINT N'Altering [dbo].[mdpsp_GetChildBySegment]...';


GO

ALTER PROCEDURE [dbo].[mdpsp_GetChildBySegment]
	@parentNodeId int,
	@catalogId int = 0,
	@UriSegment nvarchar(255)
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

	SELECT
		S.CatalogNodeId as ChildId,
		S.LanguageCode,
		1 as ContentType
	FROM CatalogItemSeo S WITH (NOLOCK)
		INNER JOIN CatalogNode N WITH (NOLOCK) ON N.CatalogNodeId = S.CatalogNodeId
		LEFT OUTER JOIN CatalogNodeRelation NR ON NR.ChildNodeId = S.CatalogNodeId
	WHERE
		UriSegment = @UriSegment AND N.IsActive = 1 AND
		((N.ParentNodeId = @parentNodeId AND (N.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(NR.ParentNodeId = @parentNodeId AND (NR.CatalogId = @catalogId OR @catalogId = 0)))

	UNION ALL

	SELECT
		S.CatalogEntryId as ChildId,
		S.LanguageCode,
		0 as ContentType
	FROM CatalogItemSeo S  WITH (NOLOCK)
		INNER JOIN CatalogEntry E ON E.CatalogEntryId = S.CatalogEntryId
		LEFT OUTER JOIN NodeEntryRelation ER ON ER.CatalogEntryId = S.CatalogEntryId
	WHERE
		UriSegment = @UriSegment AND E.IsActive = 1 AND
		((ER.CatalogNodeId = @parentNodeId AND (ER.CatalogId = @catalogId OR @catalogId = 0))
		OR
		(@parentNodeId = 0 AND (ER.CatalogNodeId IS NULL or ER.IsPrimary = 0) AND (E.CatalogId = @catalogId OR @catalogId = 0)))
END
GO
PRINT N'Creating [dbo].[ecf_OrderReportData_Purge]...';


GO
CREATE PROCEDURE [dbo].[ecf_OrderReportData_Purge]	
    @FromDate DATETIME,
	@ToDate   DATETIME
AS
BEGIN
	-- Purge LineItemReportData table before insert new data.
	DELETE FROM LineItemReportData
	WHERE OrderCreatedDate BETWEEN @FromDate AND @ToDate

    -- Purge OrderReportData table before insert new data.
	DELETE FROM OrderReportData
	WHERE OrderCreatedDate BETWEEN @FromDate AND @ToDate
END
GO
PRINT N'Creating [dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]...';


GO
CREATE PROCEDURE [dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]
	@OrderGroupId int
AS
	DELETE OrderReportData
	WHERE OrderGroupId = @OrderGroupId

	DELETE LineItemReportData
	WHERE OrderGroupId = @OrderGroupId
RETURN 0
GO
PRINT N'Creating [dbo].[ecf_ReportingSalesData_Sync]...';


GO
CREATE PROCEDURE [dbo].[ecf_ReportingSalesData_Sync]
	@OrderGroupId INT,
	@OrderData [dbo].[udttOrderReportData] READONLY,
	@LineItemData [dbo].[udttLineItemReportData] READONLY
AS
BEGIN
	--Update or Insert for OrderReportData table
	MERGE INTO [dbo].[OrderReportData] AS T
	USING @OrderData AS S
	ON T.[OrderGroupId] = S.[OrderGroupId]
	WHEN MATCHED THEN
		UPDATE SET
			[OrderNumber] = S.[OrderNumber],
			[Currency] = S.[Currency],
			[CustomerId] = S.[CustomerId],
			[CustomerName] = S.[CustomerName],
			[Status] = S.[Status],
			[OrderCreatedDate] = S.[OrderCreatedDate],
			[MarketId] = S.[MarketId],
			[TotalQuantity] = S.[TotalQuantity],
			[TotalDiscountAmount] = S.[TotalDiscountAmount],
			[ShippingTotal] = S.[ShippingTotal],
			[HandlingTotal] =  S.[HandlingTotal],
			[TaxTotal] = S.[TaxTotal],
			[SubTotal] = S.[SubTotal],
			[Total] = S.[Total]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT([OrderGroupId], [OrderNumber], [Currency], [CustomerId], [CustomerName],
			[Status], [OrderCreatedDate], [MarketId], [TotalQuantity], [TotalDiscountAmount],
			[ShippingTotal], [HandlingTotal], [TaxTotal], [SubTotal], [Total])
		VALUES(S.[OrderGroupId], S.[OrderNumber], S.[Currency], S.[CustomerId], S.[CustomerName],
			S.[Status], S.[OrderCreatedDate], S.[MarketId], S.[TotalQuantity], S.[TotalDiscountAmount],
			S.[ShippingTotal], S.[HandlingTotal], S.[TaxTotal], S.[SubTotal], S.[Total]);

	--Update, Insert or Delete for LineItemReportData table
	MERGE INTO [dbo].[LineItemReportData] AS T
	USING @LineItemData AS S
	ON T.[LineItemId] = S.[LineItemId]
	WHEN MATCHED THEN
		UPDATE SET
			[LineItemCode] = S.[LineItemCode],
			[DisplayName] = S.[DisplayName],
			[PlacedPrice] = S.[PlacedPrice],
			[Quantity] = S.[Quantity],
			[EntryDiscountAmount] = S.[EntryDiscountAmount],
			[OrderDiscountAmount] = S.[OrderDiscountAmount],
			[ExtendedPrice] = S.[ExtendedPrice],
			[SalesTax] = S.[SalesTax]
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT([LineItemId], [OrderGroupId], [LineItemCode], [DisplayName], [PlacedPrice], [Quantity],
			[EntryDiscountAmount], [OrderDiscountAmount], [ExtendedPrice], [SalesTax], [OrderCreatedDate])
		VALUES( S.[LineItemId], S.[OrderGroupId], S.[LineItemCode], S.[DisplayName], S.[PlacedPrice], S.[Quantity],
			S.[EntryDiscountAmount], S.[OrderDiscountAmount], S.[ExtendedPrice], S.[SalesTax], S.[OrderCreatedDate])
	WHEN NOT MATCHED BY SOURCE AND T.OrderGroupId = @OrderGroupId
	THEN DELETE;

	RETURN 0
END
GO
PRINT N'Altering [dbo].[ecfVersionAsset_InsertForMasterLanguage]...';


GO
ALTER PROCEDURE [dbo].[ecfVersionAsset_InsertForMasterLanguage]
	@CatalogId INT
AS
BEGIN
	DELETE a
	FROM ecfVersionAsset a
		INNER JOIN ecfVersion v on a.WorkId = v.WorkId
	WHERE v.LanguageName <> v.MasterLanguageName AND v.CatalogId = @CatalogId

	MERGE ecfVersionAsset AS TARGET
	USING
	(SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN CatalogItemAsset a ON (v.ObjectId = a.CatalogEntryId AND v.ObjectTypeId = 0)
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT AND v.CatalogId = @CatalogId
		AND (v.Status = 4 OR v.IsCommonDraft = 1)) AS SOURCE (WorkId, AssetType, AssetKey, GroupName, SortOrder)
	ON 
	TARGET.WorkId = SOURCE.WorkId
		AND TARGET.AssetType = SOURCE.AssetType
		AND TARGET.AssetKey = SOURCE.AssetKey
	WHEN MATCHED THEN
		UPDATE SET GroupName = SOURCE.GroupName, SortOrder = SOURCE.SortOrder
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (WorkId, AssetType, AssetKey, GroupName, SortOrder) VALUES (WorkId, AssetType, AssetKey, GroupName, SortOrder);

	MERGE ecfVersionAsset AS TARGET
	USING
	(SELECT v.WorkId, a.AssetType, a.AssetKey, a.GroupName, a.SortOrder
	FROM ecfVersion v
		INNER JOIN CatalogItemAsset a ON (v.ObjectId = a.CatalogNodeId AND v.ObjectTypeId = 1)
	WHERE v.LanguageName = v.MasterLanguageName COLLATE DATABASE_DEFAULT AND v.CatalogId = @CatalogId
		AND (v.Status = 4 OR v.IsCommonDraft = 1)) AS SOURCE (WorkId, AssetType, AssetKey, GroupName, SortOrder)
	ON 
	TARGET.WorkId = SOURCE.WorkId
		AND TARGET.AssetType = SOURCE.AssetType
		AND TARGET.AssetKey = SOURCE.AssetKey
	WHEN MATCHED THEN
		UPDATE SET GroupName = SOURCE.GroupName, SortOrder = SOURCE.SortOrder
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (WorkId, AssetType, AssetKey, GroupName, SortOrder) VALUES (WorkId, AssetType, AssetKey, GroupName, SortOrder);
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
