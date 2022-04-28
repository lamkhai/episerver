--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 9, @minor int = 0, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

PRINT N'Altering [dbo].[LineItem]...';


GO
ALTER TABLE [dbo].[LineItem]
    ADD [Epi_SalesTax]      DECIMAL (38, 9) NULL,
        [Epi_TaxCategoryId] INT             NULL;


GO

PRINT N'Creating Epi_SalesTax meta field for LineItem...';


GO
IF NOT EXISTS(SELECT * FROM [dbo].[MetaField] 
        WHERE [Name] = N'Epi_SalesTax')
	AND EXISTS(SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItem')
BEGIN
	DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
	SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItem')
	SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Money')
	
	INSERT INTO [dbo].[MetaField]
           ([Name]
           ,[Namespace]
           ,[SystemMetaClassId]
           ,[FriendlyName]
           ,[Description]
           ,[DataTypeId]
           ,[Length]
           ,[AllowNulls]
           ,[MultiLanguageValue]
           ,[AllowSearch]
           ,[IsEncrypted]
           ,[IsKeyField])
	VALUES
           (
		   'Epi_SalesTax'
           ,'Mediachase.Commerce.Orders.System.LineItem'
           ,@metaClassId
           ,'Sales tax'
           ,'The property is specified only for LineItem class. It is for storing the sales tax of line item.'
           ,@metaDataTypeId
           ,8
           ,1
           ,0
           ,0
           ,0
           ,0)
	
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_SalesTax')
	
	-- add relation between LineItem and Epi_SalesTax
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	VALUES (@metaClassId, @metaFieldId)
			   
	-- add relation between Epi_SalesTax and LineItem's children
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	SELECT MC.MetaClassId, MF.MetaFieldId FROM MetaField MF, MetaClass MC
	WHERE MF.[SystemMetaClassId] = @metaClassId AND MF.MetaFieldId = @metaFieldId AND MC.ParentClassId = @metaClassId
 
END
GO

PRINT N'Creating Epi_TaxCategoryId meta field for LineItem...';


GO
IF NOT EXISTS(SELECT * FROM [dbo].[MetaField] 
        WHERE [Name] = N'Epi_TaxCategoryId')
	AND EXISTS(SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItem')
BEGIN
	DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
	SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItem')
	SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Int')
	
	INSERT INTO [dbo].[MetaField]
           ([Name]
           ,[Namespace]
           ,[SystemMetaClassId]
           ,[FriendlyName]
           ,[Description]
           ,[DataTypeId]
           ,[Length]
           ,[AllowNulls]
           ,[MultiLanguageValue]
           ,[AllowSearch]
           ,[IsEncrypted]
           ,[IsKeyField])
	VALUES
           (
		   'Epi_TaxCategoryId'
           ,'Mediachase.Commerce.Orders.System.LineItem'
           ,@metaClassId
           ,'Tax category id'
           ,'The property is specified only for LineItem class. It is for storing the tax category id of line item.'
           ,@metaDataTypeId
           ,4
           ,1
           ,0
           ,0
           ,0
           ,0)
	
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_TaxCategoryId')
	
	-- add relation between LineItem and Epi_TaxCategoryId
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	VALUES (@metaClassId, @metaFieldId)
			   
	-- add relation between Epi_TaxCategoryId and LineItem's children
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	SELECT MC.MetaClassId, MF.MetaFieldId FROM MetaField MF, MetaClass MC
	WHERE MF.[SystemMetaClassId] = @metaClassId AND MF.MetaFieldId = @metaFieldId AND MC.ParentClassId = @metaClassId
 
END
GO

PRINT N'Altering [dbo].[Market]...';


GO
ALTER TABLE [dbo].[Market]
    ADD [PricesIncludeTax] BIT DEFAULT 0 NOT NULL;


GO
PRINT N'Altering [dbo].[OrderGroup]...';


GO
ALTER TABLE [dbo].[OrderGroup]
    ADD [Epi_MarketName]       NVARCHAR (50) DEFAULT ('Default Market') NOT NULL,
        [Epi_PricesIncludeTax] BIT           DEFAULT 0 NOT NULL;


GO

PRINT N'Creating Epi_MarketName meta field for OrderGroup...';


GO
IF NOT EXISTS(SELECT * FROM [dbo].[MetaField] 
        WHERE [Name] = N'Epi_MarketName')
	AND EXISTS(SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'OrderGroup')
BEGIN
	DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
	SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'OrderGroup')
	SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'NVarChar')
	
	-- create Epi_MarketName meta field
	INSERT INTO [dbo].[MetaField]
           ([Name]
           ,[Namespace]
           ,[SystemMetaClassId]
           ,[FriendlyName]
           ,[Description]
           ,[DataTypeId]
           ,[Length]
           ,[AllowNulls]
           ,[MultiLanguageValue]
           ,[AllowSearch]
           ,[IsEncrypted]
           ,[IsKeyField])
	VALUES
           (
		   'Epi_MarketName'
           ,'Mediachase.Commerce.Orders.System.OrderGroup'
           ,@metaClassId
           ,'Epi_MarketName'
           ,'The market name.'
           ,@metaDataTypeId
           ,50
           ,1
           ,0
           ,0
           ,0
           ,0)
		   
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_MarketName')
		   
	-- add relation between OrderGroup and Epi_MarketName
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	VALUES (@metaClassId, @metaFieldId)

	-- add relation between Epi_MarketName and OrderGroup's children
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	SELECT MC.MetaClassId, MF.MetaFieldId FROM MetaField MF, MetaClass MC
	WHERE MF.[SystemMetaClassId] = @metaClassId AND MF.MetaFieldId = @metaFieldId AND MC.ParentClassId = @metaClassId

	END
GO

PRINT N'Creating Epi_PricesIncludeTax meta field for OrderGroup...';


GO
IF NOT EXISTS(SELECT * FROM [dbo].[MetaField] 
        WHERE [Name] = N'Epi_PricesIncludeTax')
	AND EXISTS(SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'OrderGroup')
BEGIN
	DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
	SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'OrderGroup')
	SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Bit')
	
	-- create Epi_PricesIncludeTax meta field
	INSERT INTO [dbo].[MetaField]
           ([Name]
           ,[Namespace]
           ,[SystemMetaClassId]
           ,[FriendlyName]
           ,[Description]
           ,[DataTypeId]
           ,[Length]
           ,[AllowNulls]
           ,[MultiLanguageValue]
           ,[AllowSearch]
           ,[IsEncrypted]
           ,[IsKeyField])
	VALUES
           (
		   'Epi_PricesIncludeTax'
           ,'Mediachase.Commerce.Orders.System.OrderGroup'
           ,@metaClassId
           ,'Epi_PricesIncludeTax'
           ,'The property indicates whether the prices using in order include tax already or not.'
           ,@metaDataTypeId
           ,1
           ,1
           ,0
           ,0
           ,0
           ,0)
		   
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_PricesIncludeTax')
		   
	-- add relation between OrderGroup and Epi_PricesIncludeTax
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	VALUES (@metaClassId, @metaFieldId)

	-- add relation between Epi_PricesIncludeTax and OrderGroup's children
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	SELECT MC.MetaClassId, MF.MetaFieldId FROM MetaField MF, MetaClass MC
	WHERE MF.[SystemMetaClassId] = @metaClassId AND MF.MetaFieldId = @metaFieldId AND MC.ParentClassId = @metaClassId
END
GO

PRINT N'Altering [dbo].[Shipment]...';


GO
ALTER TABLE [dbo].[Shipment]
    ADD [Epi_ShippingCost] DECIMAL (38, 9) NULL;

GO

PRINT N'Creating Epi_ShippingCost meta field for Shipment...';


GO
IF NOT EXISTS(SELECT * FROM [dbo].[MetaField] 
        WHERE [Name] = N'Epi_ShippingCost')
	AND EXISTS(SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'Shipment')
BEGIN
	DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
	SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'Shipment')
	SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Money')
	
	INSERT INTO [dbo].[MetaField]
           ([Name]
           ,[Namespace]
           ,[SystemMetaClassId]
           ,[FriendlyName]
           ,[Description]
           ,[DataTypeId]
           ,[Length]
           ,[AllowNulls]
           ,[MultiLanguageValue]
           ,[AllowSearch]
           ,[IsEncrypted]
           ,[IsKeyField])
	VALUES
           (
		   'Epi_ShippingCost'
           ,'Mediachase.Commerce.Orders.System.Shipment'
           ,@metaClassId
           ,'Shipping cost'
           ,'The property is specified only for shipment class. It is for storing the shipping cost of shipment.'
           ,@metaDataTypeId
           ,8
           ,1
           ,0
           ,0
           ,0
           ,0)
	
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_ShippingCost')
	
	-- add relation between Shipment and Epi_ShippingCost
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	VALUES (@metaClassId, @metaFieldId)
			   
	-- add relation between Epi_ShippingCost and Shipment's children
	 
	INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
	SELECT MC.MetaClassId, MF.MetaFieldId FROM MetaField MF, MetaClass MC
	WHERE MF.[SystemMetaClassId] = @metaClassId AND MF.MetaFieldId = @metaFieldId AND MC.ParentClassId = @metaClassId
 
END
GO

PRINT N'Altering [dbo].[ecf_LineItem_Insert]...';


GO
ALTER PROCEDURE [dbo].[ecf_LineItem_Insert]
(
	@LineItemId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@Catalog nvarchar(255),
	@CatalogNode nvarchar(255),
	@ParentCatalogEntryId nvarchar(255),
	@CatalogEntryId nvarchar(255),
	@Quantity DECIMAL (38, 9),
	@PlacedPrice DECIMAL(38, 9),
	@ListPrice DECIMAL(38, 9),
	@LineItemDiscountAmount DECIMAL(38, 9),
	@OrderLevelDiscountAmount DECIMAL(38, 9),
	@ShippingAddressId nvarchar(64),
	@ShippingMethodName nvarchar(128) = NULL,
	@ShippingMethodId uniqueidentifier,
	@ExtendedPrice DECIMAL(38, 9),
	@Epi_SalesTax DECIMAL(38, 9),
	@Description nvarchar(255) = NULL,
	@Status nvarchar(64) = NULL,
	@DisplayName nvarchar(128) = NULL,
	@AllowBackordersAndPreorders bit,
	@InStockQuantity DECIMAL(38, 9),
	@PreorderQuantity DECIMAL(38, 9),
	@BackorderQuantity DECIMAL(38, 9),
	@InventoryStatus int,
	@LineItemOrdering datetime,
	@ConfigurationId nvarchar(255) = NULL,
	@MinQuantity DECIMAL(38, 9),
	@MaxQuantity DECIMAL(38, 9),
	@ProviderId nvarchar(255) = NULL,
	@ReturnReason nvarchar(255)= NULL,
	@OrigLineItemId int = NULL,
	@ReturnQuantity DECIMAL(38, 9),
	@WarehouseCode nvarchar(50) = NULL,
    @IsInventoryAllocated bit = NULL,
	@Epi_TaxCategoryId int = NULL
)
AS
	SET NOCOUNT ON

	INSERT INTO [LineItem]
	(
		[OrderFormId],
		[OrderGroupId],
		[Catalog],
		[CatalogNode],
		[ParentCatalogEntryId],
		[CatalogEntryId],
		[Quantity],
		[PlacedPrice],
		[ListPrice],
		[LineItemDiscountAmount],
		[OrderLevelDiscountAmount],
		[ShippingAddressId],
		[ShippingMethodName],
		[ShippingMethodId],
		[ExtendedPrice],
		[Epi_SalesTax],
		[Description],
		[Status],
		[DisplayName],
		[AllowBackordersAndPreorders],
		[InStockQuantity],
		[PreorderQuantity],
		[BackorderQuantity],
		[InventoryStatus],
		[LineItemOrdering],
		[ConfigurationId],
		[MinQuantity],
		[MaxQuantity],
		[ProviderId],
		[ReturnReason],
		[OrigLineItemId],
		[ReturnQuantity],
		[WarehouseCode],
        [IsInventoryAllocated],
		[Epi_TaxCategoryId]
	)
	VALUES
	(
		@OrderFormId,
		@OrderGroupId,
		@Catalog,
		@CatalogNode,
		@ParentCatalogEntryId,
		@CatalogEntryId,
		@Quantity,
		@PlacedPrice,
		@ListPrice,
		@LineItemDiscountAmount,
		@OrderLevelDiscountAmount,
		@ShippingAddressId,
		@ShippingMethodName,
		@ShippingMethodId,
		@ExtendedPrice,
		@Epi_SalesTax,
		@Description,
		@Status,
		@DisplayName,
		@AllowBackordersAndPreorders,
		@InStockQuantity,
		@PreorderQuantity,
		@BackorderQuantity,
		@InventoryStatus,
		@LineItemOrdering,
		@ConfigurationId,
		@MinQuantity,
		@MaxQuantity,
		@ProviderId,
		@ReturnReason,
		@OrigLineItemId,
		@ReturnQuantity,
		@WarehouseCode,
        @IsInventoryAllocated,
		@Epi_TaxCategoryId
	)

	SELECT @LineItemId = SCOPE_IDENTITY()

	RETURN @@Error
GO
PRINT N'Altering [dbo].[ecf_LineItem_Update]...';


GO
ALTER PROCEDURE [dbo].[ecf_LineItem_Update]
(
	@LineItemId int,
	@OrderFormId int,
	@OrderGroupId int,
	@Catalog nvarchar(255),
	@CatalogNode nvarchar(255),
	@ParentCatalogEntryId nvarchar(255),
	@CatalogEntryId nvarchar(255),
	@Quantity DECIMAL(38, 9),
	@PlacedPrice DECIMAL(38, 9),
	@ListPrice DECIMAL(38, 9),
	@LineItemDiscountAmount DECIMAL(38, 9),
	@OrderLevelDiscountAmount DECIMAL(38, 9),
	@ShippingAddressId nvarchar(255),
	@ShippingMethodName nvarchar(128) = NULL,
	@ShippingMethodId uniqueidentifier,
	@ExtendedPrice DECIMAL(38, 9),
	@Epi_SalesTax DECIMAL(38, 9),
	@Description nvarchar(255) = NULL,
	@Status nvarchar(64) = NULL,
	@DisplayName nvarchar(128) = NULL,
	@AllowBackordersAndPreorders bit,
	@InStockQuantity DECIMAL(38, 9),
	@PreorderQuantity DECIMAL(38, 9),
	@BackorderQuantity DECIMAL(38, 9),
	@InventoryStatus int,
	@LineItemOrdering datetime,
	@ConfigurationId nvarchar(255) = NULL,
	@MinQuantity DECIMAL(38, 9),
	@MaxQuantity DECIMAL(38, 9),
	@ProviderId nvarchar(255) = NULL,
	@ReturnReason nvarchar(255)= NULL,
	@OrigLineItemId int = NULL,
	@ReturnQuantity DECIMAL(38, 9),
	@WarehouseCode nvarchar(50) = NULL,
    @IsInventoryAllocated bit = NULL,
	@Epi_TaxCategoryId int = NULL
)
AS
	SET NOCOUNT ON
	
	UPDATE [LineItem]
	SET
		[OrderFormId] = @OrderFormId,
		[OrderGroupId] = @OrderGroupId,
		[Catalog] = @Catalog,
		[CatalogNode] = @CatalogNode,
		[ParentCatalogEntryId] = @ParentCatalogEntryId,
		[CatalogEntryId] = @CatalogEntryId,
		[Quantity] = @Quantity,
		[PlacedPrice] = @PlacedPrice,
		[ListPrice] = @ListPrice,
		[LineItemDiscountAmount] = @LineItemDiscountAmount,
		[OrderLevelDiscountAmount] = @OrderLevelDiscountAmount,
		[ShippingAddressId] = @ShippingAddressId,
		[ShippingMethodName] = @ShippingMethodName,
		[ShippingMethodId] = @ShippingMethodId,
		[ExtendedPrice] = @ExtendedPrice,
		[Epi_SalesTax] = @Epi_SalesTax,
		[Description] = @Description,
		[Status] = @Status,
		[DisplayName] = @DisplayName,
		[AllowBackordersAndPreorders] = @AllowBackordersAndPreorders,
		[InStockQuantity] = @InStockQuantity,
		[PreorderQuantity] = @PreorderQuantity,
		[BackorderQuantity] = @BackorderQuantity,
		[InventoryStatus] = @InventoryStatus,
		[LineItemOrdering] = @LineItemOrdering,
		[ConfigurationId] = @ConfigurationId,
		[MinQuantity] = @MinQuantity,
		[MaxQuantity] = @MaxQuantity,
		[ProviderId] = @ProviderId,
		[ReturnReason] = @ReturnReason,
		[OrigLineItemId] = @OrigLineItemId,
		[ReturnQuantity] = @ReturnQuantity,
		[WarehouseCode] = @WarehouseCode,
        [IsInventoryAllocated] = @IsInventoryAllocated,
		[Epi_TaxCategoryId] = @Epi_TaxCategoryId
	WHERE 
		[LineItemId] = @LineItemId

	IF @@ERROR > 0
	BEGIN
		RAISERROR('Concurrency Error',16,1)
	END

	RETURN @@Error
GO
PRINT N'Altering [dbo].[ecf_Market_Create]...';


GO

ALTER procedure dbo.ecf_Market_Create
    @MarketId nvarchar(8),
    @IsEnabled bit,
	@PricesIncludeTax bit, 
    @MarketName nvarchar(50),
    @MarketDescription nvarchar(4000),
    @DefaultCurrencyCode nvarchar(8),
    @DefaultLanguageCode nvarchar(84),
    @CurrencyCodes udttCurrencyCode readonly,
    @LanguageCodes udttLanguageCode readonly,
    @CountryCodes udttCountryCode readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        if not exists (select 1 from @CurrencyCodes where CurrencyCode = @DefaultCurrencyCode) raiserror('Default currency must be included in the currency list.', 10, 0)
        if not exists (select 1 from @LanguageCodes where LanguageCode = @DefaultLanguageCode) raiserror('Default language must be included in the language list.', 10, 0)            

        insert into dbo.Market (MarketId, Created, Modified, IsEnabled, MarketName, MarketDescription, DefaultCurrencyCode, DefaultLanguageCode, PricesIncludeTax)
        values (@MarketId, GETUTCDATE(), GETUTCDATE(), @IsEnabled, @MarketName, @MarketDescription, @DefaultCurrencyCode, @DefaultLanguageCode, @PricesIncludeTax)
        
        insert into dbo.MarketCurrencies (MarketId, CurrencyCode)
        select distinct @MarketId, CurrencyCode
        from @CurrencyCodes
        
        insert into dbo.MarketLanguages (MarketId, LanguageCode)
        select distinct @MarketId, LanguageCode
        from @LanguageCodes
        
        insert into dbo.MarketCountries (MarketId, CountryCode)
        select distinct @MarketId, CountryCode
        from @CountryCodes

        if @initialTranCount = 0 commit transaction ecf_Market_Create
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
GO
PRINT N'Altering [dbo].[ecf_Market_Get]...';


GO


ALTER procedure dbo.ecf_Market_Get
    @MarketId nvarchar(8)
as
begin
    select
        m.MarketId,
        m.Created,
        m.Modified,
        m.IsEnabled,
		m.MarketName,
        m.MarketDescription,
        m.DefaultCurrencyCode,
        m.DefaultLanguageCode,
		m.PricesIncludeTax
    from dbo.Market m
    where m.MarketId = @MarketId
    
    select MarketId, CurrencyCode
    from dbo.MarketCurrencies
    where MarketId = @MarketId
    
    select MarketId, LanguageCode
    from dbo.MarketLanguages
    where MarketId = @MarketId

    select MarketId, CountryCode
    from dbo.MarketCountries
    where MarketId = @MarketId
end
GO
PRINT N'Altering [dbo].[ecf_Market_GetAll]...';


GO

ALTER procedure dbo.ecf_Market_GetAll
as
begin
    select MarketId, Created, Modified, IsEnabled, MarketName, MarketDescription, DefaultCurrencyCode, DefaultLanguageCode, PricesIncludeTax
    from dbo.Market
    
    select MarketId, CurrencyCode
    from dbo.MarketCurrencies
    
    select MarketId, LanguageCode
    from dbo.MarketLanguages

    select MarketId, CountryCode
    from dbo.MarketCountries
end
GO
PRINT N'Altering [dbo].[ecf_Market_Update]...';


GO

ALTER procedure dbo.ecf_Market_Update
    @MarketId nvarchar(8),
    @IsEnabled bit,
	@PricesIncludeTax bit,
    @MarketName nvarchar(50),
    @MarketDescription nvarchar(4000),
    @DefaultCurrencyCode nvarchar(8),
    @DefaultLanguageCode nvarchar(84),
    @CurrencyCodes udttCurrencyCode readonly,
    @LanguageCodes udttLanguageCode readonly,
    @CountryCodes udttCountryCode readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        if not exists (select 1 from @CurrencyCodes where CurrencyCode = @DefaultCurrencyCode) raiserror('Default currency must be included in the currency list.', 10, 0)
        if not exists (select 1 from @LanguageCodes where LanguageCode = @DefaultLanguageCode) raiserror('Default language must be included in the language list.', 10, 0)            

        update dbo.Market
        set Modified = GETUTCDATE(), IsEnabled = @IsEnabled, MarketName = @MarketName, MarketDescription = @MarketDescription, DefaultCurrencyCode = @DefaultCurrencyCode, DefaultLanguageCode = @DefaultLanguageCode, PricesIncludeTax = @PricesIncludeTax
        where MarketId = @MarketId
        
        delete mc
        from dbo.MarketCurrencies mc
        where mc.MarketId = @MarketId
          and not exists (select 1 from @CurrencyCodes cc where mc.CurrencyCode = cc.CurrencyCode)
        
        insert into dbo.MarketCurrencies (MarketId, CurrencyCode)
        select @MarketId, CurrencyCode
        from @CurrencyCodes cc
        where not exists (select 1 from dbo.MarketCurrencies mc where mc.MarketId = @MarketId and mc.CurrencyCode = cc.CurrencyCode)
        
        delete ml
        from dbo.MarketLanguages ml
        where ml.MarketId = @MarketId
          and not exists (select 1 from @LanguageCodes cc where ml.LanguageCode = cc.LanguageCode)
        
        insert into dbo.MarketLanguages (MarketId, LanguageCode)
        select @MarketId, LanguageCode
        from @LanguageCodes lc
        where not exists (select 1 from dbo.MarketLanguages ml where ml.MarketId = @MarketId and ml.LanguageCode = lc.LanguageCode)

        delete mc
        from dbo.MarketCountries mc
        where mc.MarketId = @MarketId
          and not exists (select 1 from @CountryCodes cc where mc.CountryCode = cc.CountryCode)

        insert into dbo.MarketCountries (MarketId, CountryCode)
        select @MarketId, CountryCode
        from @CountryCodes cc
        where not exists (select 1 from dbo.MarketCountries mc where mc.MarketId = @MarketId and mc.CountryCode = cc.CountryCode)

        if @initialTranCount = 0 commit transaction ecf_Market_Update
    end try
    begin catch
        declare @msg nvarchar(4000), @severity int, @state int
        select @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE()
        if @initialTranCount = 0 rollback transaction
        raiserror(@msg, @severity, @state)
    end catch
end
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
	@MarketId nvarchar(8),
	@Epi_MarketName nvarchar(50),
	@Epi_PricesIncludeTax bit = 0
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
			[MarketId],
			[Epi_MarketName],
			[Epi_PricesIncludeTax]
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
			@MarketId,
			@Epi_MarketName,
			@Epi_PricesIncludeTax
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
	@MarketId nvarchar(8),
	@Epi_MarketName nvarchar(50),
	@Epi_PricesIncludeTax bit = 0
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
					[MarketId],
					[Epi_MarketName],
					[Epi_PricesIncludeTax]
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
					@MarketId,
					@Epi_MarketName,
					@Epi_PricesIncludeTax
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
	@MarketId nvarchar(8),
	@Epi_MarketName nvarchar(50),
	@Epi_PricesIncludeTax bit = 0
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
			[MarketId] = @MarketId,
			[Epi_MarketName] = @Epi_MarketName,
			[Epi_PricesIncludeTax] = @Epi_PricesIncludeTax
		WHERE
			[OrderGroupId] = @OrderGroupId

	SET @Err = @@Error

	RETURN @Err
END
GO
PRINT N'Altering [dbo].[ecf_Shipment_Insert]...';


GO
ALTER PROCEDURE [dbo].[ecf_Shipment_Insert]
(
	@ShipmentId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(64) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal DECIMAL (38, 9),
	@ShippingDiscountAmount DECIMAL (38, 9),
	@ShippingMethodName nvarchar(128) = NULL,
	@Epi_ShippingCost DECIMAL (38, 9),
	@Epi_ShippingTax DECIMAL (38, 9),
	@Status nvarchar(64) = NULL,
	@LineItemIds nvarchar(max) = NULL,
	@WarehouseCode nvarchar(50) = NULL,
	@PickListId int = NULL,
	@SubTotal DECIMAL (38, 9),
	@OperationKeys nvarchar(max) = NULL
)
AS
	SET NOCOUNT ON

	INSERT INTO [Shipment]
	(
		[OrderFormId],
		[OrderGroupId],
		[ShippingMethodId],
		[ShippingAddressId],
		[ShipmentTrackingNumber],
		[ShipmentTotal],
		[ShippingDiscountAmount],
		[ShippingMethodName],
		[Epi_ShippingCost],
		[Epi_ShippingTax],
		[Status],
		[LineItemIds],
		[WarehouseCode],
		[PickListId],
		[SubTotal],
		[OperationKeys]
	)
	VALUES
	(
		@OrderFormId,
		@OrderGroupId,
		@ShippingMethodId,
		@ShippingAddressId,
		@ShipmentTrackingNumber,
		@ShipmentTotal,
		@ShippingDiscountAmount,
		@ShippingMethodName,
		@Epi_ShippingCost,
		@Epi_ShippingTax,
		@Status,
		@LineItemIds,
		@WarehouseCode,
		@PickListId,
		@SubTotal,
		@OperationKeys
	)

	SELECT @ShipmentId = SCOPE_IDENTITY()

	RETURN @@Error
GO
PRINT N'Altering [dbo].[ecf_Shipment_Update]...';


GO
ALTER PROCEDURE [dbo].[ecf_Shipment_Update]
(
	@ShipmentId int,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(64) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal DECIMAL (38, 9),
	@ShippingDiscountAmount DECIMAL (38, 9),
	@ShippingMethodName nvarchar(128) = NULL,
	@Epi_ShippingCost DECIMAL (38, 9),
	@Epi_ShippingTax DECIMAL (38, 9),
	@Status nvarchar(64) = NULL,
	@LineItemIds nvarchar(max) = NULL,
	@WarehouseCode nvarchar(50) = NULL,
	@PickListId int = NULL,
	@SubTotal DECIMAL (38, 9),
	@OperationKeys nvarchar(max) = NULL
)
AS
	SET NOCOUNT ON
	
	UPDATE [Shipment]
	SET
		[OrderFormId] = @OrderFormId,
		[OrderGroupId] = @OrderGroupId,
		[ShippingMethodId] = @ShippingMethodId,
		[ShippingAddressId] = @ShippingAddressId,
		[ShipmentTrackingNumber] = @ShipmentTrackingNumber,
		[ShipmentTotal] = @ShipmentTotal,
		[ShippingDiscountAmount] = @ShippingDiscountAmount,
		[ShippingMethodName] = @ShippingMethodName,
		[Epi_ShippingCost] = @Epi_ShippingCost,
		[Epi_ShippingTax] = @Epi_ShippingTax,
		[Status] = @Status,
		[LineItemIds] = @LineItemIds,
		[WarehouseCode] = @WarehouseCode,
		[PickListId] = @PickListId,
		[SubTotal] = @SubTotal,
		[OperationKeys] = @OperationKeys
	WHERE 
		[ShipmentId] = @ShipmentId

	RETURN @@Error
GO
PRINT N'Altering [dbo].[ecf_Catalog]...';


GO
ALTER PROCEDURE [dbo].[ecf_Catalog]
	@CatalogId int = null,
	@ReturnInactive bit = 0
AS
BEGIN
	
	SELECT DISTINCT C.* from [Catalog] C
		LEFT OUTER JOIN SiteCatalog SC ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)

	SELECT DISTINCT L.* from [CatalogLanguage] L
		LEFT OUTER JOIN [Catalog] C ON C.CatalogId = L.CatalogId
		LEFT OUTER JOIN SiteCatalog SC ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)

	SELECT DISTINCT SC.* from SiteCatalog SC
		INNER JOIN [Catalog] C ON SC.CatalogId = C.CatalogId
	WHERE
		(
			(C.CatalogId = COALESCE(@CatalogId,C.CatalogId) or (@CatalogId is null and C.CatalogId is null))
		) and 
		(C.IsActive = 1 or @ReturnInactive = 1)
END
GO
PRINT N'Altering [dbo].[ecf_CatalogRelation_NodeDelete]...';


GO
ALTER procedure [dbo].[ecf_CatalogRelation_NodeDelete]
    @CatalogEntries dbo.udttEntityList readonly,
    @CatalogNodes dbo.udttEntityList readonly
as
begin
    select *
	from CatalogNodeRelation
	where ParentNodeId in (select EntityId from @CatalogNodes)
	   or ChildNodeId in (select EntityId from @CatalogNodes)
    
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

PRINT N'Altering [dbo].[CatalogItemChange_Insert]...';


GO
ALTER PROCEDURE [dbo].[CatalogItemChange_Insert]
@EntryIds [udttIdTable]  READONLY
AS
BEGIN
	MERGE INTO CatalogItemChange AS TARGET  
	USING (SELECT
		C.ID, CE.CatalogId
	FROM @EntryIds C
	INNER JOIN CatalogEntry CE ON C.ID = CE.CatalogEntryId)
		   AS SOURCE (CatalogEntryId, CatalogId)  
	ON 
		TARGET.CatalogEntryId = SOURCE.CatalogEntryId 
		AND TARGET.CatalogId = SOURCE.CatalogId
		AND TARGET.IsBeingIndexed = 0

	WHEN NOT MATCHED BY TARGET THEN  
		INSERT (CatalogEntryId, CatalogId, IsBeingIndexed) VALUES (CatalogEntryId, CatalogId, 0);
END
GO
PRINT N'Altering [dbo].[ecfVersion_SyncCatalogData]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_SyncCatalogData]
	@ContentDraft dbo.udttVersion READONLY,
	@SelectOutput BIT = 0
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, ObjectId int, LanguageName nvarchar(20), MasterLanguageName nvarchar(20))

	-- Insert/Update draft table
	MERGE INTO dbo.ecfVersion AS target
	USING (SELECT d.ObjectId, d.ObjectTypeId, d.CatalogId, d.LanguageName, d.[MasterLanguageName], 1, d.[Status],
				  c.StartDate, c.Name, '', d.CreatedBy, d.Created, d.ModifiedBy, d.Modified,
				  c.EndDate, d.SeoUriSegment
			FROM @ContentDraft d
			INNER JOIN dbo.Catalog c on d.ObjectId = c.CatalogId)
	AS SOURCE(ObjectId, ObjectTypeId, CatalogId, LanguageName, [MasterLanguageName], IsCommonDraft, [Status], 
			  StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified,
			  StopPublish, SeoUriSegment)
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
			target.StopPublish = SOURCE.StopPublish,
			target.SeoUriSegment = SOURCE.SeoUriSegment
	WHEN NOT MATCHED THEN
		INSERT (ObjectId, ObjectTypeId, CatalogId, LanguageName, MasterLanguageName, IsCommonDraft, [Status], 
				StartPublish, Name, Code, CreatedBy, Created, ModifiedBy, Modified, StopPublish, SeoUriSegment)
		VALUES (SOURCE.ObjectId, SOURCE.ObjectTypeId, SOURCE.CatalogId, SOURCE.LanguageName, SOURCE.MasterLanguageName, SOURCE.IsCommonDraft, SOURCE.[Status], 
				SOURCE.StartPublish, SOURCE.Name, SOURCE.Code, SOURCE.CreatedBy, SOURCE.Created, SOURCE.ModifiedBy, SOURCE.Modified, SOURCE.StopPublish, SOURCE.SeoUriSegment)
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
PRINT N'Altering [dbo].[ecfVersion_UpdateSeoByObjectIds]...';


GO
ALTER PROCEDURE [dbo].[ecfVersion_UpdateSeoByObjectIds]
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
	
	--update entry versions
	UPDATE v 
	SET v.SeoUri = s.Uri,
	    v.SeoUriSegment = s.UriSegment
	FROM ecfVersion v
	INNER JOIN @WorkIds w on v.WorkId = w.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogEntryId = v.ObjectId AND v.ObjectTypeId = 0)
	WHERE s.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT
	
	--update node versions
	UPDATE v 
	SET v.SeoUri = s.Uri,
	    v.SeoUriSegment = s.UriSegment
	FROM ecfVersion v
	INNER JOIN @WorkIds w on v.WorkId = w.WorkId
	INNER JOIN CatalogItemSeo s ON (s.CatalogNodeId = v.ObjectId AND v.ObjectTypeId = 1)
	WHERE s.LanguageCode = v.LanguageName COLLATE DATABASE_DEFAULT
END
GO

PRINT N'Refreshing [dbo].[ecf_LineItem_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_LineItem_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_OrderGroup]';


GO
PRINT N'Refreshing [dbo].[ecf_OrderForm_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_OrderForm_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_ProductBestSellers]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_ProductBestSellers]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_SaleReport]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_SaleReport]';


GO
PRINT N'Refreshing [dbo].[ecf_Search_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Search_OrderGroup]';


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
PRINT N'Refreshing [dbo].[ecf_Market_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Market_Delete]';


GO
PRINT N'Refreshing [dbo].[ecf_reporting_Shipping]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_reporting_Shipping]';


GO
PRINT N'Refreshing [dbo].[ecf_PickList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_PickList]';


GO
PRINT N'Refreshing [dbo].[ecf_Shipment_Delete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Shipment_Delete]';


GO
 
--start migrating existing OrderGroup
UPDATE og
SET og.Epi_MarketName = m.MarketName
FROM OrderGroup og
INNER JOIN Market m ON og.MarketId = m.MarketId COLLATE DATABASE_DEFAULT

GO
--end migrating existing OrderGroup


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(9, 0, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
