--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 6    
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
PRINT N'Dropping [dbo].[PromotionInformationSave]...';


GO
DROP PROCEDURE [dbo].[PromotionInformationSave];


GO
PRINT N'Dropping [dbo].[udttPromotionInformation]...';


GO
DROP TYPE [dbo].[udttPromotionInformation];


GO
PRINT N'Creating [dbo].[udttPromotionInformation]...';


GO
CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE (
    [PromotionInformationId] INT              NULL,
    [OrderFormId]            INT              NOT NULL,
    [PromotionGuid]          UNIQUEIDENTIFIER NOT NULL,
    [RewardType]             VARCHAR (50)     NOT NULL,
    [Name]                   NVARCHAR (4000)  NULL,
    [Description]            NVARCHAR (4000)  NULL,
    [DiscountType]           VARCHAR (50)     NOT NULL,
    [CouponCode]             NVARCHAR (100)   NULL,
    [AdditionalInformation]  NVARCHAR (MAX)   NULL,
    [VisitorGroup]           UNIQUEIDENTIFIER NULL,
    [CustomerId]             UNIQUEIDENTIFIER NOT NULL,
    [OrderLevelSavedAmount]  DECIMAL (18, 3)  NULL,
    [IsRedeemed]             BIT              DEFAULT (1) NOT NULL,
    [IsReturnOrderForm]      BIT              DEFAULT (0) NOT NULL);


GO
PRINT N'Altering [dbo].[PromotionInformation]...';


GO
ALTER TABLE [dbo].[PromotionInformation]
    ADD [IsReturnOrderForm] BIT DEFAULT (0) NOT NULL;


GO
PRINT N'Creating [dbo].[PromotionInformation].[IDX_PromotionInformation_PromotionGuid_CustomerId]...';


GO
CREATE NONCLUSTERED INDEX [IDX_PromotionInformation_PromotionGuid_CustomerId]
    ON [dbo].[PromotionInformation]([PromotionGuid] ASC) WHERE IsRedeemed = 1 AND IsReturnOrderForm = 0;


GO
PRINT N'Altering [dbo].[PromotionInformationGetRedemptions]...';


GO
ALTER PROCEDURE [dbo].[PromotionInformationGetRedemptions]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@ExcludeOrderFormId INT = NULL
AS
BEGIN

	IF @CustomerId IS NULL
		BEGIN
			SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions, 0 AS CustomerRedemptions 
			FROM PromotionInformation p
			INNER JOIN @PromotionGuids g on p.PromotionGuid = g.ContentGuid
			WHERE IsRedeemed = 1 AND IsReturnOrderForm = 0
			GROUP BY p.PromotionGuid;
		END
	ELSE
		BEGIN
			WITH CTE (PromotionGuid, TotalRedemptions)
				AS
				(SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions
				FROM PromotionInformation p
				INNER JOIN @PromotionGuids g on p.PromotionGuid = g.ContentGuid
				AND (p.OrderFormId != @ExcludeOrderFormId OR @ExcludeOrderFormId IS NULL) 
				AND IsRedeemed = 1 AND IsReturnOrderForm = 0
				GROUP BY p.PromotionGuid)

			SELECT PromotionLevel.PromotionGuid AS PromotionGuid, TotalRedemptions = PromotionLevel.TotalRedemptions, COUNT(CustomerId) AS CustomerRedemptions
			FROM dbo.PromotionInformation AS CustomerLevel 
			RIGHT JOIN CTE AS PromotionLevel 
			ON CustomerLevel.PromotionGuid = PromotionLevel.PromotionGuid AND CustomerLevel.CustomerId = @CustomerId
			AND IsRedeemed = 1 AND IsReturnOrderForm = 0
			AND CustomerLevel.OrderFormId != @ExcludeOrderFormId
			GROUP BY PromotionLevel.PromotionGuid, PromotionLevel.TotalRedemptions;

		END
END
GO
PRINT N'Creating [dbo].[PromotionInformationSave]...';


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
		INSERT (OrderFormId, PromotionGuid, RewardType, [Name], [Description], DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId, OrderLevelSavedAmount, IsRedeemed, IsReturnOrderForm)
		VALUES (input.OrderFormId, input.PromotionGuid, input.RewardType, input.[Name], input.[Description], input.DiscountType, input.CouponCode, input.AdditionalInformation, input.VisitorGroup, input.CustomerId, input.OrderLevelSavedAmount, input.IsRedeemed, input.IsReturnOrderForm)
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
UPDATE P
SET IsReturnOrderForm = 1
FROM dbo.PromotionInformation P
INNER JOIN dbo.OrderForm O ON p.OrderFormId = o.OrderFormId
WHERE o.OrigOrderFormId IS NOT NULL

GO
PRINT N'Refreshing [dbo].[PromotionInformationDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[PromotionInformationDelete]';


GO
PRINT N'Refreshing [dbo].[PromotionInformationGetOrders]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[PromotionInformationGetOrders]';


GO
PRINT N'Refreshing [dbo].[PromotionInformationList]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[PromotionInformationList]';


GO
PRINT N'Refreshing [dbo].[PromotionInformationLoad]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[PromotionInformationLoad]';


GO
PRINT N'Refreshing [dbo].[ecf_Load_OrderGroup]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[ecf_Load_OrderGroup]';


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
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 6, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
