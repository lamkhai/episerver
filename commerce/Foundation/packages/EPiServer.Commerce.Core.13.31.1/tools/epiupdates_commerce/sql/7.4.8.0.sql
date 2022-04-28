--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

GO

-- create Epi_FreeQuantity meta field
DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'LineItemEx')
SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Decimal')

IF @metaClassId IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT 1 FROM [dbo].[MetaField] WHERE [Name] = N'Epi_FreeQuantity')
	BEGIN		  
		EXEC mdpsp_sys_AddMetaField 'Mediachase.Commerce.Orders.LineItem',
			'Epi_FreeQuantity',
			'FreeQuantity Property',
			'The property is specified only for LineItem class. It contains the amount of free quantity.',
			@metaDataTypeId,
			8,
			1,
			0,
			0,
			0,
			@Retval = @metaFieldId OUTPUT
	
		EXEC mdpsp_sys_AddMetaFieldToMetaClass @metaClassId, @metaFieldId, 0
	END
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_OrderGroup_InsertForShoppingCart]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_OrderGroup_InsertForShoppingCart] 
GO

CREATE PROCEDURE [dbo].[ecf_OrderGroup_InsertForShoppingCart]
(
    @OrderGroupId int OUT,
    @InstanceId UNIQUEIDENTIFIER,
    @ApplicationId UNIQUEIDENTIFIER,
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
                and ApplicationId = @ApplicationId 
                and MarketId = @MarketId COLLATE DATABASE_DEFAULT ) 
                and @OrderGroupId is null
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
    commit
    SET @Err = @@Error

    RETURN @Err
END
 
GO

ALTER TABLE [dbo].[PromotionInformation] ADD [IsRedeemed] BIT NOT NULL DEFAULT(1)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[PromotionInformationList] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[PromotionInformationSave] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationGetRedemptions]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[PromotionInformationGetRedemptions] 
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') 
DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(
	[PromotionInformationId] INT NULL,
	[OrderFormId] INT NOT NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL,
	[VisitorGroup] UNIQUEIDENTIFIER NULL,
	[CustomerId] UNIQUEIDENTIFIER NOT NULL,
	[OrderLevelSavedAmount] DECIMAL(18, 3) NULL,
	[IsRedeemed] BIT NOT NULL DEFAULT(1)
)
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformationShipment') 
DROP TYPE [dbo].[udttPromotionInformationShipment]
GO

CREATE TYPE [dbo].[udttPromotionInformationShipment] AS TABLE(
	[PromotionInformationId] INT NULL,
	[ShippingMethodId] UNIQUEIDENTIFIER NOT NULL,
	[OrderAddressName] NVARCHAR(64) NULL,
	[ShippingMethodName] NVARCHAR(100) NOT NULL,
	[SavedAmount] DECIMAL(18, 3) NOT NULL
)

GO

ALTER TABLE [dbo].[PromotionInformationShipment] ALTER COLUMN [OrderAddressName] NVARCHAR(64) NULL
GO

CREATE PROCEDURE [dbo].[PromotionInformationList]
	@OrderFormId INT
AS
BEGIN
	DECLARE @PromotionInformation [udttPromotionInformation];
	
	INSERT INTO @PromotionInformation
			(PromotionInformationId,
			 OrderFormId,
			 PromotionGuid,
			 Description,
			 RewardType,
			 DiscountType,
			 CouponCode,
			 AdditionalInformation,
			 VisitorGroup,
			 CustomerId,
			 OrderLevelSavedAmount,
			 IsRedeemed)
	SELECT 
		   PromotionInformationId,
		   OrderFormId,
		   PromotionGuid,
		   Description,
		   RewardType,
		   DiscountType,
		   CouponCode,
		   AdditionalInformation,
		   VisitorGroup,
		   CustomerId,
		   OrderLevelSavedAmount,
		   IsRedeemed
	FROM dbo.PromotionInformation
	WHERE OrderFormId = @OrderFormId
	
	SELECT * FROM @PromotionInformation

	SELECT 
		i.PromotionInformationId,
		e.EntryCode,
		e.SavedAmount
	FROM PromotionInformationEntry e
	INNER JOIN @PromotionInformation i ON e.PromotionInformationId = i.PromotionInformationId

	SELECT 
		i.PromotionInformationId,
		s.ShippingMethodId,
		s.OrderAddressName,
		s.ShippingMethodName,
		s.SavedAmount
	FROM PromotionInformationShipment s
	INNER JOIN @PromotionInformation i ON s.PromotionInformationId = i.PromotionInformationId
END
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@PromotionInformation dbo.udttPromotionInformation READONLY,
	@PromotionInformationEntry dbo.udttPromotionInformationEntry READONLY,
	@PromotionInformationShipment dbo.udttPromotionInformationShipment READONLY
AS
BEGIN
	DELETE i FROM PromotionInformation i
	INNER JOIN @PromotionInformation p ON i.OrderFormId = p.OrderFormId

	DECLARE @IdMap TABLE (TempId INT, Id INT)

	-- Use merge that never matches to do the insert and get the map between temporary and inserted
	MERGE INTO PromotionInformation
	USING @PromotionInformation AS input
	ON 1 = 0
	WHEN NOT MATCHED THEN
		INSERT (OrderFormId, PromotionGuid, RewardType, [Description], DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId, OrderLevelSavedAmount, IsRedeemed)
		VALUES (input.OrderFormId, input.PromotionGuid, input.RewardType, input.[Description], input.DiscountType, input.CouponCode, input.AdditionalInformation, input.VisitorGroup, input.CustomerId, input.OrderLevelSavedAmount, input.IsRedeemed)
	OUTPUT input.PromotionInformationId, inserted.PromotionInformationId
	INTO @IdMap;

	-- Create updated versions of input tables with inserted identities from PromotionInformation table
	-- Separate operation to avoid deadlock under high concurrency on the following inserts
	DECLARE @PromotionInformationEntryUpdated dbo.udttPromotionInformationEntry
	INSERT INTO @PromotionInformationEntryUpdated (PromotionInformationId, EntryCode, SavedAmount)
	SELECT m.Id, e.EntryCode, e.SavedAmount
	FROM @PromotionInformationEntry e
	INNER JOIN @IdMap m ON m.TempId = e.PromotionInformationId

	DECLARE @PromotionInformationShipmentUpdated dbo.udttPromotionInformationShipment
	INSERT INTO @PromotionInformationShipmentUpdated (PromotionInformationId, ShippingMethodId, OrderAddressName, ShippingMethodName, SavedAmount)
	SELECT m.Id, s.ShippingMethodId, s.OrderAddressName, s.ShippingMethodName, s.SavedAmount
	FROM @PromotionInformationShipment s
	INNER JOIN @IdMap m ON m.TempId = s.PromotionInformationId

	INSERT INTO PromotionInformationEntry (PromotionInformationId, EntryCode, SavedAmount)
	SELECT e.PromotionInformationId, e.EntryCode, e.SavedAmount
	FROM @PromotionInformationEntryUpdated e

	INSERT INTO PromotionInformationShipment (PromotionInformationId, ShippingMethodId, OrderAddressName, ShippingMethodName, SavedAmount)
	SELECT s.PromotionInformationId, s.ShippingMethodId, s.OrderAddressName, s.ShippingMethodName, s.SavedAmount
	FROM @PromotionInformationShipmentUpdated s
END
GO

CREATE PROCEDURE [dbo].[PromotionInformationGetRedemptions]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@ExcludeOrderFormId INT = NULL
AS
BEGIN

	IF @CustomerId IS NULL
		BEGIN

	    SELECT PromotionInformation.PromotionGuid, COUNT(*) AS TotalRedemptions, 0 AS CustomerRedemptions 
		FROM PromotionInformation 
		WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids) AND IsRedeemed = 1
		GROUP BY PromotionInformation.PromotionGuid;

		END
	ELSE
		BEGIN

		    CREATE TABLE #Totals(PromotionGuid UNIQUEIDENTIFIER, TotalRedemptions INT);

			INSERT INTO #Totals 
			SELECT PromotionInformation.PromotionGuid, COUNT(*) AS TotalRedemptions
			FROM PromotionInformation WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids) AND (PromotionInformation.OrderFormId != @ExcludeOrderFormId OR @ExcludeOrderFormId IS NULL) AND IsRedeemed = 1
			GROUP BY PromotionInformation.PromotionGuid;

			SELECT PromotionLevel.PromotionGuid AS PromotionGuid, TotalRedemptions = PromotionLevel.TotalRedemptions, COUNT(CustomerId) AS CustomerRedemptions
			FROM dbo.PromotionInformation AS CustomerLevel 
			RIGHT JOIN #Totals AS PromotionLevel	
			ON CustomerLevel.PromotionGuid = PromotionLevel.PromotionGuid AND CustomerLevel.CustomerId = @CustomerId AND CustomerLevel.OrderFormId != @ExcludeOrderFormId
			GROUP BY PromotionLevel.PromotionGuid, PromotionLevel.TotalRedemptions;

			DROP TABLE #Totals;

		END
END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
