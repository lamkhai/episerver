--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 1, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[ecfVersion_Update]...';


GO
DROP PROCEDURE [dbo].[ecfVersion_Update];


GO
PRINT N'Dropping [dbo].[ecfVersionCatalog_Save]...';


GO
DROP PROCEDURE [dbo].[ecfVersionCatalog_Save];


GO
PRINT N'Dropping [dbo].[udttVersionCatalog]...';


GO
DROP TYPE [dbo].[udttVersionCatalog];


GO
PRINT N'Creating [dbo].[udttVersionCatalog]...';


GO
CREATE TYPE [dbo].[udttVersionCatalog] AS TABLE (
    [WorkId]          INT             NOT NULL,
    [DefaultCurrency] NVARCHAR (150)  NULL,
    [WeightBase]      NVARCHAR (128)  NULL,
    [LengthBase]      NVARCHAR (128)  NULL,
    [DefaultLanguage] NVARCHAR (50)   NULL,
    [Languages]       NVARCHAR (4000) NULL,
    [IsPrimary]       BIT             NULL,
    [Owner]           NVARCHAR (255)  NULL);


GO
PRINT N'Altering [dbo].[ecfVersionCatalog]...';


GO
ALTER TABLE [dbo].[ecfVersionCatalog] ALTER COLUMN [Languages] NVARCHAR (4000) NULL;


GO
PRINT N'Creating [dbo].[LineItemReportData]...';


GO
CREATE TABLE [dbo].[LineItemReportData] (
    [Id]                  INT             IDENTITY (1, 1) NOT NULL,
    [LineItemId]          INT             NOT NULL,
    [OrderGroupId]        INT             NOT NULL,
    [LineItemCode]        NVARCHAR (255)  NOT NULL,
    [DisplayName]         NVARCHAR (255)  NULL,
    [PlacedPrice]         DECIMAL (38, 9) NOT NULL,
    [Quantity]            DECIMAL (38, 9) NOT NULL,
    [EntryDiscountAmount] DECIMAL (38, 9) NOT NULL,
    [OrderDiscountAmount] DECIMAL (38, 9) NOT NULL,
    [ExtendedPrice]       DECIMAL (38, 9) NOT NULL,
    [SalesTax]            DECIMAL (38, 9) NOT NULL,
    [OrderCreatedDate]    DATETIME        NOT NULL,
    CONSTRAINT [PK_LineItemReportData] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [dbo].[LineItemReportData].[IX_LineItemReportData_OrderCreatedDate]...';


GO
CREATE NONCLUSTERED INDEX [IX_LineItemReportData_OrderCreatedDate]
    ON [dbo].[LineItemReportData]([OrderCreatedDate] ASC);


GO
PRINT N'Creating [dbo].[LineItemReportData].[IX_LineItemReportData_OrderGroupId]...';


GO
CREATE NONCLUSTERED INDEX [IX_LineItemReportData_OrderGroupId]
    ON [dbo].[LineItemReportData]([OrderGroupId] ASC);


GO
PRINT N'Creating [dbo].[OrderReportData]...';


GO
CREATE TABLE [dbo].[OrderReportData] (
    [Id]                  INT              IDENTITY (1, 1) NOT NULL,
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
    [Total]               DECIMAL (38, 9)  NOT NULL,
    CONSTRAINT [PK_OrderReportData] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [dbo].[OrderReportData].[IX_OrderData_OrderGroupId]...';


GO
CREATE NONCLUSTERED INDEX [IX_OrderData_OrderGroupId]
    ON [dbo].[OrderReportData]([OrderGroupId] ASC);


GO
PRINT N'Creating [dbo].[OrderReportData].[IX_OrderReportData_OrderCreatedDate]...';


GO
CREATE NONCLUSTERED INDEX [IX_OrderReportData_OrderCreatedDate]
    ON [dbo].[OrderReportData]([OrderCreatedDate] ASC);


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
		DECLARE @WorkIds TABLE (WorkId INT, DefaultLanguage NVARCHAR(20), Languages NVARCHAR(4000))
		INSERT INTO @WorkIds(WorkId, DefaultLanguage, Languages)
		SELECT v.WorkId, v.DefaultLanguage, v.Languages
		FROM @VersionCatalogs v

		DECLARE @NumberVersions INT, @CatalogId INT, @MasterLanguageName NVARCHAR(20), @Languages NVARCHAR(4000)
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
PRINT N'Creating [dbo].[ecf_LineItemReportData_Get]...';


GO
CREATE PROCEDURE [dbo].[ecf_LineItemReportData_Get]
	@FromDate DateTime,
	@ToDate DateTime
AS
BEGIN	
	SELECT L.LineItemId, L.LineItemCode, L.DisplayName, L.PlacedPrice, L.Quantity, L.ExtendedPrice,
		L.EntryDiscountAmount, L.SalesTax, O.Currency, L.OrderGroupId, O.OrderCreatedDate, O.OrderNumber, 
		O.CustomerId, O.CustomerName, O.MarketId
	FROM LineItemReportData L
	INNER JOIN OrderReportData O ON L.OrderGroupId = O.OrderGroupId
	WHERE L.OrderCreatedDate BETWEEN @FromDate AND @ToDate
END
GO
PRINT N'Creating [dbo].[ecf_LineItemReportData_Truncate]...';


GO
CREATE PROCEDURE [dbo].[ecf_LineItemReportData_Truncate]	
AS
BEGIN
    -- Truncate LineItemReportData table before insert new data.
	TRUNCATE TABLE LineItemReportData
END
GO
PRINT N'Creating [dbo].[ecf_OrderReportData_AggregateByDay]...';


GO
CREATE PROCEDURE [dbo].[ecf_OrderReportData_AggregateByDay]
	@TimeZoneOffset DECIMAL(38, 9) = 0
AS
BEGIN
	SELECT 
		CONVERT(DATE, DATEADD(minute, @TimeZoneOffset, OrderCreatedDate)) AS OrderCreatedDate,
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
	GROUP BY CONVERT(DATE, DATEADD(minute, @TimeZoneOffset, OrderCreatedDate)), MarketId, Currency
	ORDER BY OrderCreatedDate, MarketId, Currency
END
GO
PRINT N'Creating [dbo].[ecf_OrderReportData_Truncate]...';


GO
CREATE PROCEDURE [dbo].[ecf_OrderReportData_Truncate]	
AS
BEGIN
    -- Truncate OrderReportData table before insert new data.
	TRUNCATE TABLE OrderReportData
END
GO
PRINT N'Refreshing [dbo].[ecfVersionCatalog_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersionCatalog_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_ListByWorkIds]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_ListByWorkIds]';


GO
PRINT N'Refreshing [dbo].[ecfVersion_SyncCatalogData]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecfVersion_SyncCatalogData]';


GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 1, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
