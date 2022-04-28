--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Dropping [dbo].[LineItemReportData].[IX_LineItemReportData_OrderCreatedDate]...';


GO
DROP INDEX [IX_LineItemReportData_OrderCreatedDate]
    ON [dbo].[LineItemReportData];


GO
PRINT N'Dropping [dbo].[OrderReportData].[IX_OrderReportData_OrderCreatedDate]...';


GO
DROP INDEX [IX_OrderReportData_OrderCreatedDate]
    ON [dbo].[OrderReportData];


GO
PRINT N'Dropping [dbo].[DF__ecf_mktg-__Modif__3716A457]...';


GO
ALTER TABLE [dbo].[Campaign] DROP CONSTRAINT [DF__ecf_mktg-__Modif__3716A457];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-CampaignSegment_ecf_mktg-Campaign]...';


GO
ALTER TABLE [dbo].[CampaignSegment] DROP CONSTRAINT [FK_ecf_mktg-CampaignSegment_ecf_mktg-Campaign];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-Promotion_ecf_mktg-Campaign]...';


GO
ALTER TABLE [dbo].[Promotion] DROP CONSTRAINT [FK_ecf_mktg-Promotion_ecf_mktg-Campaign];


GO
PRINT N'Dropping [dbo].[FK_MarketCampaigns_Campaign]...';


GO
ALTER TABLE [dbo].[MarketCampaigns] DROP CONSTRAINT [FK_MarketCampaigns_Campaign];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-Policy_ecf_mktg-Expression]...';


GO
ALTER TABLE [dbo].[Policy] DROP CONSTRAINT [FK_ecf_mktg-Policy_ecf_mktg-Expression];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-PromotionCondition_ecf_mktg-Expression]...';


GO
ALTER TABLE [dbo].[PromotionCondition] DROP CONSTRAINT [FK_ecf_mktg-PromotionCondition_ecf_mktg-Expression];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-SegmentCondition_ecf_mktg-Expression]...';


GO
ALTER TABLE [dbo].[SegmentCondition] DROP CONSTRAINT [FK_ecf_mktg-SegmentCondition_ecf_mktg-Expression];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-GroupPolicy_ecf_mktg-Policy]...';


GO
ALTER TABLE [dbo].[GroupPolicy] DROP CONSTRAINT [FK_ecf_mktg-GroupPolicy_ecf_mktg-Policy];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-PromotionPolicy_ecf_mktg-Policy]...';


GO
ALTER TABLE [dbo].[PromotionPolicy] DROP CONSTRAINT [FK_ecf_mktg-PromotionPolicy_ecf_mktg-Policy];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-PromotionCondition_ecf_mktg-Promotion]...';


GO
ALTER TABLE [dbo].[PromotionCondition] DROP CONSTRAINT [FK_ecf_mktg-PromotionCondition_ecf_mktg-Promotion];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-PromotionLanguage_ecf_mktg-Promotion]...';


GO
ALTER TABLE [dbo].[PromotionLanguage] DROP CONSTRAINT [FK_ecf_mktg-PromotionLanguage_ecf_mktg-Promotion];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-PromotionPolicy_ecf_mktg-Promotion]...';


GO
ALTER TABLE [dbo].[PromotionPolicy] DROP CONSTRAINT [FK_ecf_mktg-PromotionPolicy_ecf_mktg-Promotion];


GO
PRINT N'Dropping [dbo].[FK_PromotionUsage_Promotion]...';


GO
ALTER TABLE [dbo].[PromotionUsage] DROP CONSTRAINT [FK_PromotionUsage_Promotion];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-CampaignSegment_ecf_mktg-Segment]...';


GO
ALTER TABLE [dbo].[CampaignSegment] DROP CONSTRAINT [FK_ecf_mktg-CampaignSegment_ecf_mktg-Segment];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-SegmentCondition_ecf_mktg-Segment]...';


GO
ALTER TABLE [dbo].[SegmentCondition] DROP CONSTRAINT [FK_ecf_mktg-SegmentCondition_ecf_mktg-Segment];


GO
PRINT N'Dropping [dbo].[FK_ecf_mktg-SegmentMember_ecf_mktg-Segment]...';


GO
ALTER TABLE [dbo].[SegmentMember] DROP CONSTRAINT [FK_ecf_mktg-SegmentMember_ecf_mktg-Segment];


GO
PRINT N'Dropping [dbo].[FK_MarketCampaigns_Market]...';


GO
ALTER TABLE [dbo].[MarketCampaigns] DROP CONSTRAINT [FK_MarketCampaigns_Market];


GO
PRINT N'Dropping [dbo].[FK_WarehouseInventory_Warehouse]...';


GO
ALTER TABLE [dbo].[WarehouseInventory] DROP CONSTRAINT [FK_WarehouseInventory_Warehouse];


GO
PRINT N'Dropping [dbo].[ecf_ReportingSalesData_Sync]...';


GO
DROP PROCEDURE [dbo].[ecf_ReportingSalesData_Sync];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntry_Asset]...';


GO
DROP PROCEDURE [dbo].[ecf_CatalogEntry_Asset];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntry_Association]...';


GO
DROP PROCEDURE [dbo].[ecf_CatalogEntry_Association];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntry_Full]...';


GO
DROP PROCEDURE [dbo].[ecf_CatalogEntry_Full];


GO
PRINT N'Dropping [dbo].[ecf_CatalogEntry_Variation]...';


GO
DROP PROCEDURE [dbo].[ecf_CatalogEntry_Variation];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Campaign]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Campaign];


GO
PRINT N'Dropping [dbo].[ecf_mktg_CampaignMarket]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_CampaignMarket];


GO
PRINT N'Dropping [dbo].[ecf_mktg_CancelExpiredPromoReservations]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_CancelExpiredPromoReservations];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Expression]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Expression];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Expression_Category]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Expression_Category];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Expression_Segment]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Expression_Segment];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Policy]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Policy];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Promotion]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Promotion];


GO
PRINT N'Dropping [dbo].[ecf_mktg_PromotionByDate]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_PromotionByDate];


GO
PRINT N'Dropping [dbo].[ecf_mktg_PromotionUsage]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_PromotionUsage];


GO
PRINT N'Dropping [dbo].[ecf_mktg_PromotionUsageStatistics]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_PromotionUsageStatistics];


GO
PRINT N'Dropping [dbo].[ecf_mktg_Segment]...';


GO
DROP PROCEDURE [dbo].[ecf_mktg_Segment];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteAllInventory]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteAllInventory];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteCatalogEntryInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteInventory]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteInventory];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_DeleteWarehouseInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_DeleteWarehouseInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetAllInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetAllInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetCatalogEntryInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetInventory]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetInventory];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_GetWarehouseInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_GetWarehouseInventories];


GO
PRINT N'Dropping [dbo].[ecf_WarehouseInventory_SaveInventories]...';


GO
DROP PROCEDURE [dbo].[ecf_WarehouseInventory_SaveInventories];


GO
PRINT N'Dropping [dbo].[Campaign]...';


GO
DROP TABLE [dbo].[Campaign];


GO
PRINT N'Dropping [dbo].[CampaignSegment]...';


GO
DROP TABLE [dbo].[CampaignSegment];


GO
PRINT N'Dropping [dbo].[Expression]...';


GO
DROP TABLE [dbo].[Expression];


GO
PRINT N'Dropping [dbo].[GroupPolicy]...';


GO
DROP TABLE [dbo].[GroupPolicy];


GO
PRINT N'Dropping [dbo].[MarketCampaigns]...';


GO
DROP TABLE [dbo].[MarketCampaigns];


GO
PRINT N'Dropping [dbo].[Policy]...';


GO
DROP TABLE [dbo].[Policy];


GO
PRINT N'Dropping [dbo].[Promotion]...';


GO
DROP TABLE [dbo].[Promotion];


GO
PRINT N'Dropping [dbo].[PromotionCondition]...';


GO
DROP TABLE [dbo].[PromotionCondition];


GO
PRINT N'Dropping [dbo].[PromotionLanguage]...';


GO
DROP TABLE [dbo].[PromotionLanguage];


GO
PRINT N'Dropping [dbo].[PromotionPolicy]...';


GO
DROP TABLE [dbo].[PromotionPolicy];


GO
PRINT N'Dropping [dbo].[PromotionUsage]...';


GO
DROP TABLE [dbo].[PromotionUsage];


GO
PRINT N'Dropping [dbo].[Segment]...';


GO
DROP TABLE [dbo].[Segment];


GO
PRINT N'Dropping [dbo].[SegmentCondition]...';


GO
DROP TABLE [dbo].[SegmentCondition];


GO
PRINT N'Dropping [dbo].[SegmentMember]...';


GO
DROP TABLE [dbo].[SegmentMember];


GO
PRINT N'Dropping [dbo].[WarehouseInventory]...';


GO
DROP TABLE [dbo].[WarehouseInventory];


GO
PRINT N'Dropping [dbo].[udttLineItemReportData]...';


GO
DROP TYPE [dbo].[udttLineItemReportData];


GO
PRINT N'Dropping [dbo].[udttOrderReportData]...';


GO
DROP TYPE [dbo].[udttOrderReportData];

GO
PRINT N'Dropping [dbo].[udttWarehouseInventory]...';


GO
DROP TYPE [dbo].[udttWarehouseInventory];


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
    [OrderCreated]        DATETIME        NOT NULL);


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
    [OrderCreated]        DATETIME         NOT NULL,
    [MarketId]            NVARCHAR (8)     NOT NULL,
    [TotalQuantity]       DECIMAL (38, 9)  NOT NULL,
    [TotalDiscountAmount] DECIMAL (38, 9)  NOT NULL,
    [ShippingTotal]       DECIMAL (38, 9)  NOT NULL,
    [HandlingTotal]       DECIMAL (38, 9)  NOT NULL,
    [TaxTotal]            DECIMAL (38, 9)  NOT NULL,
    [SubTotal]            DECIMAL (38, 9)  NOT NULL,
    [Total]               DECIMAL (38, 9)  NOT NULL);


GO
PRINT N'Altering [dbo].[LineItemReportData]...';

EXEC sp_RENAME '[LineItemReportData].[OrderCreatedDate]' , 'OrderCreated', 'COLUMN'

GO

PRINT N'Altering [dbo].[OrderReportData]...';

EXEC sp_RENAME '[OrderReportData].[OrderCreatedDate]' , 'OrderCreated', 'COLUMN'
GO

PRINT N'Creating index [dbo].[LineItemReportData].[IX_LineItemReportData_OrderCreated]...';
GO
CREATE NONCLUSTERED INDEX [IX_LineItemReportData_OrderCreated]
	ON [dbo].[LineItemReportData]([OrderCreated] ASC);
GO

PRINT N'Creating index [dbo].[OrderReportData].[IX_OrderReportData_OrderCreated]...';
GO
CREATE NONCLUSTERED INDEX [IX_OrderReportData_OrderCreated]
	ON [dbo].[OrderReportData]([OrderCreated] ASC);
GO

GO
PRINT N'Altering [dbo].[ecf_LineItemReportData_Get]...';


GO
ALTER PROCEDURE [dbo].[ecf_LineItemReportData_Get]
	@FromDate DateTime,
	@ToDate DateTime
AS
BEGIN	
	SELECT L.LineItemId, L.LineItemCode, L.DisplayName, L.PlacedPrice, L.Quantity, L.ExtendedPrice,
		L.EntryDiscountAmount, L.SalesTax, O.Currency, L.OrderGroupId, O.OrderCreated, O.OrderNumber, 
		O.CustomerId, O.CustomerName, O.MarketId
	FROM LineItemReportData L
	INNER JOIN OrderReportData O ON L.OrderGroupId = O.OrderGroupId
	WHERE L.OrderCreated BETWEEN @FromDate AND @ToDate
END
GO
PRINT N'Altering [dbo].[ecf_OrderReportData_Purge]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderReportData_Purge]	
    @FromDate DATETIME,
	@ToDate   DATETIME
AS
BEGIN
	-- Purge LineItemReportData table before insert new data.
	DELETE FROM LineItemReportData
	WHERE OrderCreated BETWEEN @FromDate AND @ToDate

    -- Purge OrderReportData table before insert new data.
	DELETE FROM OrderReportData
	WHERE OrderCreated BETWEEN @FromDate AND @ToDate
END
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
			[OrderCreated] = S.[OrderCreated],
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
			[Status], [OrderCreated], [MarketId], [TotalQuantity], [TotalDiscountAmount],
			[ShippingTotal], [HandlingTotal], [TaxTotal], [SubTotal], [Total])
		VALUES(S.[OrderGroupId], S.[OrderNumber], S.[Currency], S.[CustomerId], S.[CustomerName],
			S.[Status], S.[OrderCreated], S.[MarketId], S.[TotalQuantity], S.[TotalDiscountAmount],
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
			[EntryDiscountAmount], [OrderDiscountAmount], [ExtendedPrice], [SalesTax], [OrderCreated])
		VALUES( S.[LineItemId], S.[OrderGroupId], S.[LineItemCode], S.[DisplayName], S.[PlacedPrice], S.[Quantity],
			S.[EntryDiscountAmount], S.[OrderDiscountAmount], S.[ExtendedPrice], S.[SalesTax], S.[OrderCreated])
	WHEN NOT MATCHED BY SOURCE AND T.OrderGroupId = @OrderGroupId
	THEN DELETE;

	RETURN 0
END
GO
PRINT N'Altering [dbo].[ecf_OrderReportData_AggregateByDay]...';


GO
ALTER PROCEDURE [dbo].[ecf_OrderReportData_AggregateByDay]
	@TimeZoneOffset DECIMAL(38, 9) = 0
AS
BEGIN
	SELECT 
		CONVERT(DATE, DATEADD(minute, @TimeZoneOffset, OrderCreated)) AS OrderCreated,
		MarketId,
		Currency,
		COUNT(OrderGroupId) AS NumOfOrders,
		SUM(TotalQuantity) AS NumOfItems,
		SUM(TaxTotal) AS TaxTotal,
		SUM(ShippingTotal) as ShippingTotal,
		SUM(HandlingTotal) as HandlingTotal,
		SUM(TotalDiscountAmount) AS DiscountsTotal,
		SUM(SubTotal) AS SubTotal,
		SUM(Total) AS Total
	FROM OrderReportData
	GROUP BY CONVERT(DATE, DATEADD(minute, @TimeZoneOffset, OrderCreated)), MarketId, Currency
	ORDER BY OrderCreated, MarketId, Currency
END
GO
PRINT N'Refreshing [dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
