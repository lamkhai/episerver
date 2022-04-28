--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
	BEGIN 
	declare @major int = 7, @minor int = 0, @patch int = 2
	IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
		select 0,'Already correct database version' 
	ELSE 
		select 1, 'Upgrading database' 
	END 
ELSE 
	select -1, 'Not an EPiServer Commerce database' 
GO
--endvalidatingquery 

-- create ecf_LineItem_Insert sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_LineItem_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_LineItem_Insert]
GO
CREATE PROCEDURE [dbo].[ecf_LineItem_Insert]
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
	@ShippingAddressId nvarchar(50),
	@ShippingMethodName nvarchar(128) = NULL,
	@ShippingMethodId uniqueidentifier,
	@ExtendedPrice DECIMAL(38, 9),
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
    @IsInventoryAllocated bit = NULL
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
        [IsInventoryAllocated]
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
        @IsInventoryAllocated
	)

	SELECT @LineItemId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end of creating ecf_LineItem_Insert sp


-- create ecf_LineItem_Update sp
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[ecf_LineItem_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_LineItem_Update]
GO
CREATE PROCEDURE [dbo].[ecf_LineItem_Update]
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
    @IsInventoryAllocated bit = NULL
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
        [IsInventoryAllocated] = @IsInventoryAllocated
	WHERE 
		[LineItemId] = @LineItemId

	IF @@ERROR > 0
	BEGIN
		RAISERROR('Concurrency Error',16,1)
	END

	RETURN @@Error
GO
-- end of creating ecf_LineItem_Update sp


-- begin create SP [ecf_LineItemDiscount_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_LineItemDiscount_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_LineItemDiscount_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_LineItemDiscount_Insert]
(
	@LineItemDiscountId int = NULL OUTPUT,
	@LineItemId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON

	INSERT INTO [LineItemDiscount]
	(
		[LineItemId],
		[DiscountId],
		[OrderGroupId],
		[DiscountAmount],
		[DiscountCode],
		[DiscountName],
		[DisplayMessage],
		[DiscountValue]
	)
	VALUES
	(
		@LineItemId,
		@DiscountId,
		@OrderGroupId,
		@DiscountAmount,
		@DiscountCode,
		@DiscountName,
		@DisplayMessage,
		@DiscountValue
	)

	SELECT @LineItemDiscountId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end of creating sp ecf_LineItemDiscount_Insert

-- begin create SP [ecf_LineItemDiscount_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_LineItemDiscount_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_LineItemDiscount_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_LineItemDiscount_Update]
(
	@LineItemDiscountId int,
	@LineItemId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON
	
	UPDATE [LineItemDiscount]
	SET
		[LineItemId] = @LineItemId,
		[DiscountId] = @DiscountId,
		[OrderGroupId] = @OrderGroupId,
		[DiscountAmount] = @DiscountAmount,
		[DiscountCode] = @DiscountCode,
		[DiscountName] = @DiscountName,
		[DisplayMessage] = @DisplayMessage,
		[DiscountValue] = @DiscountValue
	WHERE 
		[LineItemDiscountId] = @LineItemDiscountId

	RETURN @@Error
GO
-- end of creating sp ecf_LineItemDiscount_Update

-- begin create SP [ecf_OrderForm_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderForm_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderForm_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderForm_Insert]
(
	@OrderFormId int = NULL OUTPUT,
	@OrderGroupId int,
	@Name nvarchar(64) = NULL,
	@BillingAddressId nvarchar(50) = NULL,
	@DiscountAmount DECIMAL(38, 9),
	@SubTotal DECIMAL(38, 9),
	@ShippingTotal DECIMAL(38, 9),
	@HandlingTotal DECIMAL (38, 9),
	@TaxTotal DECIMAL (38, 9),
	@Total DECIMAL (38, 9),
	@Status nvarchar(64) = NULL,
	@ProviderId nvarchar(255) = NULL,
	@ReturnComment nvarchar(1024) = NULL,
	@ReturnType nvarchar(50) = NULL,
	@ReturnAuthCode nvarchar(255) = NULL,
	@OrigOrderFormId int = NULL,
	@ExchangeOrderGroupId int  = NULL,
	@AuthorizedPaymentTotal DECIMAL (38, 9),
	@CapturedPaymentTotal DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON

	INSERT INTO [OrderForm]
	(
		[OrderGroupId],
		[Name],
		[BillingAddressId],
		[DiscountAmount],
		[SubTotal],
		[ShippingTotal],
		[HandlingTotal],
		[TaxTotal],
		[Total],
		[Status],
		[ProviderId],
		[ReturnComment],
		[ReturnType],
		[ReturnAuthCode],
		[OrigOrderFormId],
		[ExchangeOrderGroupId],
		[AuthorizedPaymentTotal],
		[CapturedPaymentTotal]
		
	)
	VALUES
	(
		@OrderGroupId,
		@Name,
		@BillingAddressId,
		@DiscountAmount,
		@SubTotal,
		@ShippingTotal,
		@HandlingTotal,
		@TaxTotal,
		@Total,
		@Status,
		@ProviderId,
		@ReturnComment,
		@ReturnType,
		@ReturnAuthCode,
		@OrigOrderFormId,
		@ExchangeOrderGroupId,
		@AuthorizedPaymentTotal,
		@CapturedPaymentTotal
	)

	SELECT @OrderFormId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end ecf_OrderForm_Insert

-- begin create SP [ecf_OrderForm_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderForm_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderForm_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderForm_Update]
(
	@OrderFormId int,
	@OrderGroupId int,
	@Name nvarchar(64) = NULL,
	@BillingAddressId nvarchar(50) = NULL,
	@DiscountAmount DECIMAL (38, 9),
	@SubTotal DECIMAL (38, 9),
	@ShippingTotal DECIMAL (38, 9),
	@HandlingTotal DECIMAL (38, 9),
	@TaxTotal DECIMAL (38, 9),
	@Total DECIMAL (38, 9),
	@Status nvarchar(64) = NULL,
	@ProviderId nvarchar(255) = NULL,
	@ReturnComment nvarchar(1024) = NULL,
	@ReturnType nvarchar(50) = NULL,
	@ReturnAuthCode nvarchar(255) = NULL,
	@OrigOrderFormId int = NULL,
	@ExchangeOrderGroupId int = NULL,
	@AuthorizedPaymentTotal DECIMAL (38, 9),
	@CapturedPaymentTotal DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON
	
	UPDATE [OrderForm]
	SET
		[OrderGroupId] = @OrderGroupId,
		[Name] = @Name,
		[BillingAddressId] = @BillingAddressId,
		[DiscountAmount] = @DiscountAmount,
		[SubTotal] = @SubTotal,
		[ShippingTotal] = @ShippingTotal,
		[HandlingTotal] = @HandlingTotal,
		[TaxTotal] = @TaxTotal,
		[Total] = @Total,
		[Status] = @Status,
		[ProviderId] = @ProviderId,
		[ReturnComment] = @ReturnComment,
		[ReturnType] = @ReturnType,
		[ReturnAuthCode] = @ReturnAuthCode,
		[OrigOrderFormId] = @OrigOrderFormId,
		[ExchangeOrderGroupId] = @ExchangeOrderGroupId,
		[AuthorizedPaymentTotal] = @AuthorizedPaymentTotal,
		[CapturedPaymentTotal] = @CapturedPaymentTotal
	WHERE 
		[OrderFormId] = @OrderFormId

	RETURN @@Error
GO
-- end ecf_OrderForm_Update

-- begin create SP [ecf_OrderFormDiscount_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormDiscount_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderFormDiscount_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderFormDiscount_Insert]
(
	@OrderFormDiscountId int = NULL OUTPUT,
	@OrderFormId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON

	INSERT INTO [OrderFormDiscount]
	(
		[OrderFormId],
		[DiscountId],
		[OrderGroupId],
		[DiscountAmount],
		[DiscountCode],
		[DiscountName],
		[DisplayMessage],
		[DiscountValue]
	)
	VALUES
	(
		@OrderFormId,
		@DiscountId,
		@OrderGroupId,
		@DiscountAmount,
		@DiscountCode,
		@DiscountName,
		@DisplayMessage,
		@DiscountValue
	)

	SELECT @OrderFormDiscountId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end ecf_OrderFormDiscount_Insert

-- begin create SP [ecf_OrderFormDiscount_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormDiscount_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderFormDiscount_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderFormDiscount_Update]
(
	@OrderFormDiscountId int,
	@OrderFormId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON
	
	UPDATE [OrderFormDiscount]
	SET
		[OrderFormId] = @OrderFormId,
		[DiscountId] = @DiscountId,
		[OrderGroupId] = @OrderGroupId,
		[DiscountAmount] = @DiscountAmount,
		[DiscountCode] = @DiscountCode,
		[DiscountName] = @DiscountName,
		[DisplayMessage] = @DisplayMessage,
		[DiscountValue] = @DiscountValue
	WHERE 
		[OrderFormDiscountId] = @OrderFormDiscountId

	RETURN @@Error
GO
-- end ecf_OrderFormDiscount_Update

-- begin create SP [ecf_OrderFormPayment_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormPayment_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderFormPayment_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderFormPayment_Insert]
(
	@PaymentId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@BillingAddressId nvarchar(50) = NULL,
	@PaymentMethodId uniqueidentifier,
	@PaymentMethodName nvarchar(128) = NULL,
	@CustomerName nvarchar(64) = NULL,
	@Amount DECIMAL (38, 9),
	@PaymentType int,
	@ValidationCode nvarchar(64) = NULL,
	@AuthorizationCode nvarchar(255) = NULL,
	@TransactionType nvarchar(255) = NULL,
	@TransactionID nvarchar(255) = NULL,
	@ProviderTransactionID nvarchar(255) = NULL,
	@Status nvarchar(64) = NULL,
	@ImplementationClass nvarchar(255)
)
AS
	SET NOCOUNT ON

	INSERT INTO [OrderFormPayment]
	(
		[OrderFormId],
		[OrderGroupId],
		[BillingAddressId],
		[PaymentMethodId],
		[PaymentMethodName],
		[CustomerName],
		[Amount],
		[PaymentType],
		[ValidationCode],
		[AuthorizationCode],
		[TransactionType],
		[TransactionID],
		[Status],
		[ImplementationClass],
		[ProviderTransactionID]
	)
	VALUES
	(
		@OrderFormId,
		@OrderGroupId,
		@BillingAddressId,
		@PaymentMethodId,
		@PaymentMethodName,
		@CustomerName,
		@Amount,
		@PaymentType,
		@ValidationCode,
		@AuthorizationCode,
		@TransactionType,
		@TransactionID,
		@Status,
		@ImplementationClass,
		@ProviderTransactionID
	)

	SELECT @PaymentId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end ecf_OrderFormPayment_Insert

-- begin create SP [ecf_OrderFormPayment_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormPayment_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderFormPayment_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderFormPayment_Update]
(
	@PaymentId int,
	@OrderFormId int,
	@OrderGroupId int,
	@BillingAddressId nvarchar(50) = NULL,
	@PaymentMethodId uniqueidentifier,
	@PaymentMethodName nvarchar(128) = NULL,
	@CustomerName nvarchar(64) = NULL,
	@Amount DECIMAL (38, 9),
	@PaymentType int,
	@ValidationCode nvarchar(64) = NULL,
	@AuthorizationCode nvarchar(255) = NULL,
	@TransactionType nvarchar(255) = NULL,
	@TransactionID nvarchar(255) = NULL,
	@ProviderTransactionID nvarchar(255) = NULL,
	@Status nvarchar(64) = NULL,
	@ImplementationClass nvarchar(255)
)
AS
	SET NOCOUNT ON
	
	UPDATE [OrderFormPayment]
	SET
		[OrderFormId] = @OrderFormId,
		[OrderGroupId] = @OrderGroupId,
		[BillingAddressId] = @BillingAddressId,
		[PaymentMethodId] = @PaymentMethodId,
		[PaymentMethodName] = @PaymentMethodName,
		[CustomerName] = @CustomerName,
		[Amount] = @Amount,
		[PaymentType] = @PaymentType,
		[ValidationCode] = @ValidationCode,
		[AuthorizationCode] = @AuthorizationCode,
		[TransactionType] = @TransactionType,
		[TransactionID] = @TransactionID,
		[ProviderTransactionID] = @ProviderTransactionID,
		[Status] = @Status,
		[ImplementationClass] = @ImplementationClass
	WHERE 
		[PaymentId] = @PaymentId

	RETURN @@Error
GO
-- end ecf_OrderFormPayment_Update

-- begin create SP [ecf_OrderGroup_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderGroup_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderGroup_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderGroup_Insert]
(
	@OrderGroupId int OUT,
	@InstanceId uniqueidentifier,
	@ApplicationId uniqueidentifier,
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
			[ApplicationId],
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
			@ApplicationId,
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
-- end ecf_OrderGroup_Insert

-- begin create SP [ecf_OrderGroup_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderGroup_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderGroup_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_OrderGroup_Update]
(
	@OrderGroupId int OUT,
	@InstanceId uniqueidentifier,
	@ApplicationId uniqueidentifier,
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
			[ApplicationId] = @ApplicationId,
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
-- end ecf_OrderGroup_Update

-- begin create SP [ecf_PriceDetail_List]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_PriceDetail_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_PriceDetail_List] 
GO
create procedure [dbo].[ecf_PriceDetail_List]
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
            select ce.CatalogEntryId, ce.ApplicationId, ce.Code
            from specified_entries se
            join CatalogEntry ce on se.CatalogEntryId = ce.CatalogEntryId
            union all
            select ce.CatalogEntryId, ce.ApplicationId, ce.Code
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
            pd.ApplicationId,
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
        where exists (select 1 from returned_entries re where pd.ApplicationId = re.ApplicationId and pd.CatalogEntryCode = re.Code)
        and (@MarketId = '' or pd.MarketId = @MarketId)
        and (@filterCurrencies = 0 or pd.CurrencyCode in (select CurrencyCode from @CurrencyCodes))
        and (@filterCustomerPricing = 0 or exists (select 1 from @CustomerPricing cp where cp.PriceTypeId = pd.PriceTypeId and cp.PriceCode = pd.PriceCode))
        order by CatalogEntryCode, ApplicationId
    end
    else
    begin
        declare @ordered_results table (
            ordering int not null,
            PriceValueId bigint not null,
            Created datetime not null,
            Modified datetime not null,
            ApplicationId uniqueidentifier not null,
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
            select ce.CatalogEntryId, ce.ApplicationId, ce.Code
            from specified_entries se
            join CatalogEntry ce on se.CatalogEntryId = ce.CatalogEntryId
            union all
            select ce.CatalogEntryId, ce.ApplicationId, ce.Code
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
            ApplicationId,
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
            ROW_NUMBER() over (ORDER BY pd.CatalogEntryCode, pd.ApplicationId, pd.PriceCode, pd.MarketId, pd.CurrencyCode) - 1, -- arguments are zero-based.
            pd.PriceValueId,
            pd.Created,
            pd.Modified,
            pd.ApplicationId,
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
        where exists (select 1 from returned_entries re where pd.ApplicationId = re.ApplicationId and pd.CatalogEntryCode = re.Code)
        and (@MarketId = '' or pd.MarketId = @MarketId)
        and (@filterCurrencies = 0 or pd.CurrencyCode in (select CurrencyCode from @CurrencyCodes))
        and (@filterCustomerPricing = 0 or exists (select 1 from @CustomerPricing cp where cp.PriceTypeId = pd.PriceTypeId and cp.PriceCode = pd.PriceCode))
        select @totalCount = count(*) from @ordered_results

        select
            PriceValueId,
            Created,
            Modified,
            ApplicationId,
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
-- end ecf_PriceDetail_List

-- begin create SP [ecf_PriceDetail_Save]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_PriceDetail_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_PriceDetail_Save] 
GO
-- create [udttPriceDetail] type
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPriceDetail') DROP TYPE [dbo].[udttPriceDetail]
GO
CREATE TYPE [dbo].[udttPriceDetail] AS TABLE (
    [PriceValueId]     BIGINT           NOT NULL,
    [ApplicationId]    UNIQUEIDENTIFIER NULL,
    [CatalogEntryCode] NVARCHAR (100)   NULL,
    [MarketId]         NVARCHAR (8)     NULL,
    [CurrencyCode]     NVARCHAR (8)     NULL,
    [PriceTypeId]      INT              NULL,
    [PriceCode]        NVARCHAR (256)   NULL,
    [ValidFrom]        DATETIME         NULL,
    [ValidUntil]       DATETIME         NULL,
    [MinQuantity]      DECIMAL (38, 9)  NULL,
    [UnitPrice]        DECIMAL (38, 9)  NULL);
GO
-- end of creating udttPriceDetail type

create procedure [dbo].[ecf_PriceDetail_Save]
    @priceValues udttPriceDetail readonly
as
begin
    begin try
        declare @initialTranCount int = @@TRANCOUNT
        if @initialTranCount = 0 begin transaction

        declare @results table (PriceValueId bigint)
        declare @affectedEntries table (ApplicationId uniqueidentifier, CatalogEntryCode nvarchar(100))

        insert into @affectedEntries (ApplicationId, CatalogEntryCode)
        select distinct ApplicationId, CatalogEntryCode
        from dbo.PriceDetail
        where PriceValueId in (select PriceValueId from @priceValues where ApplicationId is null)

        delete from dbo.PriceDetail
        where PriceValueId in (select PriceValueId from @priceValues where ApplicationId is null)
                
        insert into @results (PriceValueId)
        select dst.PriceValueId
        from dbo.PriceDetail dst
        join @priceValues src on dst.PriceValueId = src.PriceValueId
        where src.PriceValueId > 0

        ;with update_effects as (
            select 
                dst.ApplicationId as ApplicationIdBefore, 
                dst.CatalogEntryCode as CatalogEntryCodeBefore,
                src.ApplicationId as ApplicationIdAfter,
                src.CatalogEntryCode as CatalogEntryCodeAfter
            from dbo.PriceDetail dst
            join @priceValues src on dst.PriceValueId = src.PriceValueId
        )
        insert into @affectedEntries (ApplicationId, CatalogEntryCode)
        select ApplicationIdBefore, CatalogEntryCodeBefore from update_effects
        union
        select ApplicationIdAfter, CatalogEntryCodeAfter from update_effects

        update dst
        set
            Modified = GETUTCDATE(),
            ApplicationId = src.ApplicationId, 
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

        declare @applicationId uniqueidentifier
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
            select ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice
            from @priceValues
            where PriceValueId <= 0
        open inserted_prices
        while 1=1
        begin
            fetch next from inserted_prices into @applicationId, @catalogEntryCode, @marketId, @currencyCode, @priceTypeId, @priceCode, @validFrom, @validUntil, @minQuantity, @unitPrice
            if @@FETCH_STATUS != 0 break

            insert into dbo.PriceDetail (Created, Modified, ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice)
            values (GETUTCDATE(), GETUTCDATE(), @applicationId, @catalogEntryCode, @marketId, @currencyCode, @priceTypeId, @priceCode, @validFrom, @validUntil, @minQuantity, @unitPrice)

            insert into @results (PriceValueId) 
            values (SCOPE_IDENTITY())

            insert into @affectedEntries (ApplicationId, CatalogEntryCode)
            values (@applicationId, @catalogEntryCode)
        end
        close inserted_prices

        select 
            PriceValueId,
            Created,
            Modified,
            ApplicationId,
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
            ae.ApplicationId,
            ae.CatalogEntryCode,
            pd.MarketId,
            pd.CurrencyCode,
            pd.PriceTypeId,
            pd.PriceCode,
            pd.ValidFrom,
            pd.ValidUntil,
            pd.MinQuantity,
            pd.UnitPrice
        from (select distinct ApplicationId, CatalogEntryCode from @affectedEntries) ae
        left outer join PriceDetail pd on ae.ApplicationId = pd.ApplicationId and ae.CatalogEntryCode = pd.CatalogEntryCode

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
-- end ecf_PriceDetail_Save

-- begin create SP [ecf_Shipment_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Shipment_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Shipment_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_Shipment_Insert]
(
	@ShipmentId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(50) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal DECIMAL (38, 9),
	@ShippingDiscountAmount DECIMAL (38, 9),
	@ShippingMethodName nvarchar(128) = NULL,
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
-- end ecf_Shipment_Insert

-- begin create SP [ecf_Shipment_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Shipment_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Shipment_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_Shipment_Update]
(
	@ShipmentId int,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(50) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal DECIMAL (38, 9),
	@ShippingDiscountAmount DECIMAL (38, 9),
	@ShippingMethodName nvarchar(128) = NULL,
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
-- end ecf_Shipment_Update

-- begin create SP [ecf_ShipmentDiscount_Insert]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_ShipmentDiscount_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_ShipmentDiscount_Insert] 
GO
CREATE PROCEDURE [dbo].[ecf_ShipmentDiscount_Insert]
(
	@ShipmentDiscountId int = NULL OUTPUT,
	@ShipmentId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON

	INSERT INTO [ShipmentDiscount]
	(
		[ShipmentId],
		[DiscountId],
		[OrderGroupId],
		[DiscountAmount],
		[DiscountCode],
		[DiscountName],
		[DisplayMessage],
		[DiscountValue]
	)
	VALUES
	(
		@ShipmentId,
		@DiscountId,
		@OrderGroupId,
		@DiscountAmount,
		@DiscountCode,
		@DiscountName,
		@DisplayMessage,
		@DiscountValue
	)

	SELECT @ShipmentDiscountId = SCOPE_IDENTITY()

	RETURN @@Error
GO
-- end ecf_ShipmentDiscount_Insert

-- begin create SP [ecf_ShipmentDiscount_Update]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_ShipmentDiscount_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_ShipmentDiscount_Update] 
GO
CREATE PROCEDURE [dbo].[ecf_ShipmentDiscount_Update]
(
	@ShipmentDiscountId int,
	@ShipmentId int,
	@DiscountId int,
	@OrderGroupId int,
	@DiscountAmount DECIMAL (38, 9),
	@DiscountCode nvarchar(50) = NULL,
	@DiscountName nvarchar(50) = NULL,
	@DisplayMessage nvarchar(100) = NULL,
	@DiscountValue DECIMAL (38, 9)
)
AS
	SET NOCOUNT ON
	
	UPDATE [ShipmentDiscount]
	SET
		[ShipmentId] = @ShipmentId,
		[DiscountId] = @DiscountId,
		[OrderGroupId] = @OrderGroupId,
		[DiscountAmount] = @DiscountAmount,
		[DiscountCode] = @DiscountCode,
		[DiscountName] = @DiscountName,
		[DisplayMessage] = @DisplayMessage,
		[DiscountValue] = @DiscountValue
	WHERE 
		[ShipmentDiscountId] = @ShipmentDiscountId

	RETURN @@Error
GO
-- end ecf_ShipmentDiscount_Update

-- begin create SP [ecf_ShippingMethod_GetCases]
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_ShippingMethod_GetCases]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_ShippingMethod_GetCases] 
GO
CREATE PROCEDURE [dbo].[ecf_ShippingMethod_GetCases]
	@ShippingMethodId uniqueidentifier,
	@CountryCode nvarchar(50) = null,
	@Total DECIMAL (38, 9) = null,
	@StateProvinceCode nvarchar(50) = null,
	@ZipPostalCode nvarchar(50) = null,
	@District nvarchar(50) = null,
	@County nvarchar(50) = null,
	@City nvarchar(50) = null
AS
BEGIN
/* First set all empty string variables except ShippingMethodId to NULL */
IF (LTRIM(RTRIM(@CountryCode)) = '')
  SET @CountryCode = NULL

IF (LTRIM(RTRIM(@StateProvinceCode)) = '')
  SET @StateProvinceCode = NULL

IF (LTRIM(RTRIM(@ZipPostalCode)) = '')
  SET @ZipPostalCode = NULL

IF (LTRIM(RTRIM(@District)) = '')
  SET @District = NULL

IF (LTRIM(RTRIM(@County)) = '')
  SET @County = NULL

IF (LTRIM(RTRIM(@City )) = '')
  SET @City = NULL

/* If Jurisdiction values in database are null or an empty string, they will return the same results */
	SELECT C.Charge, C.Total, C.StartDate, C.EndDate, C.JurisdictionGroupId from ShippingMethodCase C 
		inner join JurisdictionGroup JG ON JG.JurisdictionGroupId = C.JurisdictionGroupId
		inner join JurisdictionRelation JR ON JG.JurisdictionGroupId = JR.JurisdictionGroupId
		inner join Jurisdiction J ON JR.JurisdictionId = J.JurisdictionId
	WHERE 
		(C.StartDate < getutcdate() OR C.StartDate is null) AND 
		(C.EndDate > getutcdate() OR C.EndDate is null) AND 
		C.ShippingMethodId = @ShippingMethodId AND
		(@Total >= C.Total OR @Total is null) AND
		(J.CountryCode = @CountryCode OR (@CountryCode is null and J.CountryCode = 'WORLD')) AND 
		JG.JurisdictionType = 2 /*shipping*/ AND
		(COALESCE(@StateProvinceCode, J.StateProvinceCode) = J.StateProvinceCode OR J.StateProvinceCode is null OR RTRIM(LTRIM(J.StateProvinceCode)) = '') AND
		((REPLACE(@ZipPostalCode,' ','') between REPLACE(J.ZipPostalCodeStart,' ','') and REPLACE(J.ZipPostalCodeEnd,' ','') or @ZipPostalCode is null) OR J.ZipPostalCodeStart is null OR RTRIM(LTRIM(J.ZipPostalCodeStart)) = '') AND
		(COALESCE(@District, J.District) = J.District OR J.District is null OR RTRIM(LTRIM(J.District)) = '') AND
		(COALESCE(@County, J.County) = J.County OR J.County is null OR RTRIM(LTRIM(J.County)) = '') AND
		(COALESCE(@City, J.City) = J.City OR J.City is null OR RTRIM(LTRIM(J.City)) = '')
END
GO
-- end ecf_ShippingMethod_GetCases

-- create [udttCatalogEntryPrice] type
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_PriceDetail_ReplacePrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_PriceDetail_ReplacePrices] 
GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Pricing_SetCatalogEntryPrices]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Pricing_SetCatalogEntryPrices] 
GO
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttCatalogEntryPrice') DROP TYPE [dbo].[udttCatalogEntryPrice]
GO
CREATE TYPE [dbo].[udttCatalogEntryPrice] AS TABLE (
    [ApplicationId]    UNIQUEIDENTIFIER NOT NULL,
    [CatalogEntryCode] NVARCHAR (100)   NOT NULL,
    [MarketId]         NVARCHAR (8)     NOT NULL,
    [CurrencyCode]     NVARCHAR (8)     NOT NULL,
    [PriceTypeId]      INT              NOT NULL,
    [PriceCode]        NVARCHAR (256)   NOT NULL,
    [ValidFrom]        DATETIME         NOT NULL,
    [ValidUntil]       DATETIME         NULL,
    [MinQuantity]      DECIMAL (38, 9)  NOT NULL,
    [MaxQuantity]      DECIMAL (38, 9)  NULL,
    [UnitPrice]        DECIMAL (38, 9)  NOT NULL);
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
        where exists (select 1 from @CatalogKeys ck where ck.ApplicationId = PriceDetail.ApplicationId and ck.CatalogEntryCode = PriceDetail.CatalogEntryCode)
     
        insert into PriceDetail (Created, Modified, ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice)
        select GETUTCDATE(), GETUTCDATE(), ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode, ValidFrom, ValidUntil, MinQuantity, UnitPrice
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
        join dbo.PriceGroup pg on ck.ApplicationId = pg.ApplicationId and ck.CatalogEntryCode = pg.CatalogEntryCode
        join dbo.PriceValue pv on pg.PriceGroupId = pv.PriceGroupId

        merge into dbo.PriceGroup tgt
        using (select distinct ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode from @PriceValues) src
        on (    tgt.ApplicationId = src.ApplicationId
            and tgt.CatalogEntryCode = src.CatalogEntryCode
            and tgt.MarketId = src.MarketId
            and tgt.CurrencyCode = src.CurrencyCode
            and tgt.PriceTypeId = src.PriceTypeId
            and tgt.PriceCode = src.PriceCode)
        when matched then update set Modified = GETUTCDATE()
        when not matched then insert (Created, Modified, ApplicationId, CatalogEntryCode, MarketId, CurrencyCode, PriceTypeId, PriceCode)
            values (GETUTCDATE(), GETUTCDATE(), src.ApplicationId, src.CatalogEntryCode, src.MarketId, src.CurrencyCode, src.PriceTypeId, src.PriceCode);

        insert into dbo.PriceValue (PriceGroupId, ValidFrom, ValidUntil, MinQuantity, MaxQuantity, UnitPrice)
        select pg.PriceGroupId, src.ValidFrom, src.ValidUntil, src.MinQuantity, src.MaxQuantity, src.UnitPrice
        from @PriceValues src
        left outer join PriceGroup pg
            on  src.ApplicationId = pg.ApplicationId
            and src.CatalogEntryCode = pg.CatalogEntryCode
            and src.MarketId = pg.MarketId
            and src.CurrencyCode = pg.CurrencyCode
            and src.PriceTypeId = pg.PriceTypeId
            and src.PriceCode = pg.PriceCode

        delete tgt
        from dbo.PriceGroup tgt
        join @CatalogKeys ck on tgt.ApplicationId = ck.ApplicationId and tgt.CatalogEntryCode = ck.CatalogEntryCode
        where not exists (select 1 from dbo.PriceValue pv where pv.PriceGroupId = tgt.PriceGroupId)

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
-- end of creating udttCatalogEntryPrice type

-- begin alter table CatalogEntryRelation
ALTER TABLE CatalogEntryRelation ALTER COLUMN [Quantity]       decimal (38, 9) NULL;
GO
-- end of alter table CatalogEntryRelation

-- begin alter table LineItem
ALTER TABLE LineItem ALTER COLUMN [Quantity]                    decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [PlacedPrice]					decimal (38, 9)			   NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [ListPrice]					decimal (38, 9)			   NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [LineItemDiscountAmount]		decimal (38, 9)			   NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [OrderLevelDiscountAmount]	decimal (38, 9)			   NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [ExtendedPrice]				decimal (38, 9)			   NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [InStockQuantity]             decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [PreorderQuantity]            decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [BackorderQuantity]           decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [MinQuantity]                 decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ALTER COLUMN [MaxQuantity]                 decimal (38, 9)            NOT NULL;
GO

DECLARE @defaultConstraint nvarchar(100)
SELECT @defaultConstraint = name FROM sys.objects WHERE type_desc = 'DEFAULT_CONSTRAINT' AND name like '%DF__LineItem__RETURN%'
EXEC('ALTER TABLE LineItem DROP ' + @defaultConstraint)
ALTER TABLE LineItem ALTER COLUMN [ReturnQuantity]              decimal (38, 9)            NOT NULL;
GO
ALTER TABLE LineItem ADD DEFAULT ((0)) FOR [ReturnQuantity];
GO
-- end of alter table LineItem

-- begin alter table LineItemDiscount
ALTER TABLE LineItemDiscount ALTER COLUMN [DiscountAmount]     decimal (38, 9)          NOT NULL;
GO
ALTER TABLE LineItemDiscount ALTER COLUMN [DiscountValue]      decimal (38, 9)          NOT NULL;
-- end of alter table LineItemDiscount

-- begin alter table OrderForm
ALTER TABLE OrderForm ALTER COLUMN [DiscountAmount]         decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [SubTotal]               decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [ShippingTotal]          decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [HandlingTotal]          decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [TaxTotal]               decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [Total]                  decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [AuthorizedPaymentTotal] decimal (38, 9)           NOT NULL;
GO
ALTER TABLE OrderForm ALTER COLUMN [CapturedPaymentTotal]   decimal (38, 9)           NOT NULL;
GO
-- end of alter table OrderForm

-- begin alter table OrderFormDiscount
ALTER TABLE OrderFormDiscount ALTER COLUMN [DiscountAmount]      decimal (38, 9)          NOT NULL;
GO
ALTER TABLE OrderFormDiscount ALTER COLUMN [DiscountValue]       decimal (38, 9)          NOT NULL;
GO
-- end of alter table OrderFormDiscount

-- begin alter table OrderFormPayment
ALTER TABLE OrderFormPayment ALTER COLUMN [Amount]              decimal (38, 9)            NOT NULL;
GO
-- end of alter table OrderFormPayment

-- begin alter table OrderGroup
ALTER TABLE OrderGroup ALTER COLUMN [ShippingTotal]   decimal (38, 9)            NOT NULL;
GO
ALTER TABLE OrderGroup ALTER COLUMN [HandlingTotal]   decimal (38, 9)            NOT NULL;
GO
ALTER TABLE OrderGroup ALTER COLUMN [TaxTotal]        decimal (38, 9)            NOT NULL;
GO
ALTER TABLE OrderGroup ALTER COLUMN [SubTotal]        decimal (38, 9)            NOT NULL;
GO
ALTER TABLE OrderGroup ALTER COLUMN [Total]           decimal (38, 9)            NOT NULL;
GO
-- end of alter table OrderGroup

-- begin alter table PriceDetail
ALTER TABLE PriceDetail ALTER COLUMN [UnitPrice]        decimal (38, 9)            NOT NULL;
GO
-- end of alter table PriceDetail

-- begin alter table PriceValue
ALTER TABLE PriceValue ALTER COLUMN [UnitPrice]    decimal (38, 9)           NOT NULL;
GO
-- end of alter table PriceValue

-- begin alter table Promotion
ALTER TABLE Promotion ALTER COLUMN [OfferAmount]              decimal (38, 9)            NOT NULL;
GO
-- end of alter table Promotion

-- begin alter table SalePrice
ALTER TABLE SalePrice ALTER COLUMN [MinQuantity]   decimal (38, 9)          NOT NULL;
GO
ALTER TABLE SalePrice ALTER COLUMN [UnitPrice]   decimal (38, 9)          NOT NULL;
GO
-- end of alter table SalePrice

-- begin alter table Shipment
ALTER TABLE Shipment ALTER COLUMN [ShipmentTotal]          decimal (38, 9)            NOT NULL;
GO
ALTER TABLE Shipment ALTER COLUMN [ShippingDiscountAmount] decimal (38, 9)            NOT NULL;
GO
ALTER TABLE Shipment ALTER COLUMN [Epi_ShippingTax]        decimal (38, 9)            NULL;
GO
ALTER TABLE Shipment ALTER COLUMN [SubTotal]               decimal (38, 9)            NOT NULL;
GO
-- end of alter table Shipment

-- begin alter table ShipmentDiscount
ALTER TABLE ShipmentDiscount ALTER COLUMN [DiscountAmount]     decimal (38, 9)          NOT NULL;
GO
ALTER TABLE ShipmentDiscount ALTER COLUMN [DiscountValue]       decimal (38, 9)          NOT NULL;
GO
-- end of alter table ShipmentDiscount

-- begin alter table ShippingMethod
ALTER TABLE ShippingMethod ALTER COLUMN [BasePrice]        decimal (38, 9)            NOT NULL;
GO
-- end of alter table ShippingMethod

-- begin alter table ShippingMethodCase
ALTER TABLE ShippingMethodCase ALTER COLUMN [Charge]               decimal (38, 9)            NOT NULL;
GO
-- end of alter table ShippingMethodCase

-- begin alter table Variation
ALTER TABLE Variation ALTER COLUMN [ListPrice]      decimal (38, 9)            NULL;
GO
ALTER TABLE Variation ALTER COLUMN [MinQuantity]    decimal (38, 9)            NULL;
GO
ALTER TABLE Variation ALTER COLUMN [MaxQuantity]    decimal (38, 9)            NULL;
GO
-- end of alter table Variation


--beginUpdatingDatabaseVersion 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 2, GETUTCDATE())  
GO 
--endUpdatingDatabaseVersion 