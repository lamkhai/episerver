--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 7    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER TABLE [dbo].[OrderFormPayment] ALTER COLUMN [BillingAddressId] NVARCHAR(64) NULL
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormPayment_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_OrderFormPayment_Update] 
GO

CREATE PROCEDURE [dbo].[ecf_OrderFormPayment_Update]
(
	@PaymentId int,
	@OrderFormId int,
	@OrderGroupId int,
	@BillingAddressId nvarchar(64) = NULL,
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderFormPayment_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_OrderFormPayment_Insert] 
GO

CREATE PROCEDURE [dbo].[ecf_OrderFormPayment_Insert]
(
	@PaymentId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@BillingAddressId nvarchar(64) = NULL,
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

ALTER TABLE [dbo].[OrderForm] ALTER COLUMN [BillingAddressId] NVARCHAR(64) NULL
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderForm_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_OrderForm_Insert] 
GO

CREATE PROCEDURE [dbo].[ecf_OrderForm_Insert]
(
	@OrderFormId int = NULL OUTPUT,
	@OrderGroupId int,
	@Name nvarchar(64) = NULL,
	@BillingAddressId nvarchar(64) = NULL,
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderForm_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_OrderForm_Update] 
GO

CREATE PROCEDURE [dbo].[ecf_OrderForm_Update]
(
	@OrderFormId int,
	@OrderGroupId int,
	@Name nvarchar(64) = NULL,
	@BillingAddressId nvarchar(64) = NULL,
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
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 7, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
