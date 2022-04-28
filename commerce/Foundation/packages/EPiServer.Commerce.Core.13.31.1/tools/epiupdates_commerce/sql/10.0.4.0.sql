--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 


GO
PRINT N'Dropping [dbo].[ecf_ReportingSalesData_Sync]...';


GO
DROP PROCEDURE [dbo].[ecf_ReportingSalesData_Sync];


GO
PRINT N'Dropping [dbo].[udttLineItemReportData]...';


GO
DROP TYPE [dbo].[udttLineItemReportData];


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
    [OrderCreated]        DATETIME        NOT NULL,
    PRIMARY KEY CLUSTERED ([LineItemId] ASC));


GO
PRINT N'Starting removing constraint of [dbo].[LineItemReportData]...';

GO
ALTER TABLE [dbo].[LineItemReportData] DROP CONSTRAINT [PK_LineItemReportData]


GO
PRINT N'Dropping [dbo].[LineItemReportData].[IX_LineItemReportData_OrderGroupId]...';


GO
DROP INDEX [IX_LineItemReportData_OrderGroupId]
    ON [dbo].[LineItemReportData];


GO
PRINT N'Creating [dbo].[LineItemReportData].[IX_LineItemReportData_OrderGroupId]...';


GO
CREATE CLUSTERED INDEX [IX_LineItemReportData_OrderGroupId] 
	ON [dbo].[LineItemReportData]([OrderGroupId] ASC);


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_ModifiedBy_Modified]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_ModifiedBy_Modified]
    ON [dbo].[ecfVersion]([ModifiedBy] ASC, [Modified] DESC);


GO
PRINT N'Creating [dbo].[ecfVersion].[IDX_ecfVersion_Status_Modified]...';


GO
CREATE NONCLUSTERED INDEX [IDX_ecfVersion_Status_Modified]
    ON [dbo].[ecfVersion]([Status] ASC, [Modified] DESC);


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
	;WITH ExistingLineItems ([LineItemId], [OrderGroupId], [LineItemCode], [DisplayName], [PlacedPrice], [Quantity],
			[EntryDiscountAmount], [OrderDiscountAmount], [ExtendedPrice], [SalesTax], [OrderCreated])
			AS
			(
			SELECT [LineItemId], [OrderGroupId], [LineItemCode], [DisplayName], [PlacedPrice], [Quantity],
			[EntryDiscountAmount], [OrderDiscountAmount], [ExtendedPrice], [SalesTax], [OrderCreated]
			FROM [dbo].[LineItemReportData]
			WHERE OrderGroupId = @OrderGroupId
			)

    MERGE INTO ExistingLineItems AS T
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
	WHEN NOT MATCHED BY SOURCE
	THEN DELETE;

	RETURN 0
END
GO
PRINT N'Refreshing [dbo].[ecf_LineItemReportData_Get]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItemReportData_Get]';


GO
PRINT N'Refreshing [dbo].[ecf_OrderReportData_Purge]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderReportData_Purge]';


GO
PRINT N'Refreshing [dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_ReportingSalesData_DeleteByOrderGroupId]';


GO
PRINT N'Creating Decimal for MetaFieldType...';


GO
IF NOT EXISTS(SELECT * FROM mcmd_MetaFieldType WHERE [Name] = 'Decimal')
BEGIN
	INSERT INTO [dbo].[mcmd_MetaFieldType] ([Name], [FriendlyName], [McDataType], [XSViews], [XSAttributes], [Owner], [AccessLevel]) VALUES (N'Decimal', N'{GlobalMetaInfo:Decimal}', 18, NULL, NULL, N'System', 1)
END


GO 

 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
