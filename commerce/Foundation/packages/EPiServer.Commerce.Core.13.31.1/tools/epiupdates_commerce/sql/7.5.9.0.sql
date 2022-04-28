--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 9    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionInformationList] 
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
			 Name,
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
		   Name,
		   DiscountType,
		   CouponCode,
		   AdditionalInformation,
		   VisitorGroup,
		   CustomerId,
		   OrderLevelSavedAmount,
		   IsRedeemed
	FROM dbo.PromotionInformation
	WHERE OrderFormId = @OrderFormId
	
	SELECT 'PromotionInformation' TableName, p.* FROM @PromotionInformation p

	SELECT 'PromotionInformationEntry' TableName,
		i.PromotionInformationId,
		e.EntryCode,
		e.SavedAmount
	FROM PromotionInformationEntry e
	INNER JOIN @PromotionInformation i ON e.PromotionInformationId = i.PromotionInformationId

	SELECT 'PromotionInformationShipment' TableName,
		i.PromotionInformationId,
		s.ShippingMethodId,
		s.OrderAddressName,
		s.ShippingMethodName,
		s.SavedAmount
	FROM PromotionInformationShipment s
	INNER JOIN @PromotionInformation i ON s.PromotionInformationId = i.PromotionInformationId
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationLoad]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionInformationLoad] 
GO

CREATE PROCEDURE [dbo].[PromotionInformationLoad]
    @OrderGroupIds udttOrderGroupId readonly
AS
BEGIN
	DECLARE @PromotionInformation [udttPromotionInformation];
	
	INSERT INTO @PromotionInformation
			(PromotionInformationId,
			 OrderFormId,
			 PromotionGuid,
			 Description,
			 RewardType,
			 Name,
			 DiscountType,
			 CouponCode,
			 AdditionalInformation,
			 VisitorGroup,
			 CustomerId,
			 OrderLevelSavedAmount,
			 IsRedeemed)
	SELECT 
		   PromotionInformationId,
		   p.OrderFormId,
		   PromotionGuid,
		   Description,
		   RewardType,
		   p.Name,
		   DiscountType,
		   CouponCode,
		   AdditionalInformation,
		   VisitorGroup,
		   CustomerId,
		   OrderLevelSavedAmount,
		   IsRedeemed
	FROM dbo.PromotionInformation p
	INNER JOIN dbo.OrderForm f ON p.OrderFormId = f.OrderFormId
	INNER JOIN @OrderGroupIds r on f.OrderGroupId = r.OrderGroupId
	
	SELECT 'PromotionInformation' TableName, p.* FROM @PromotionInformation p

	SELECT 'PromotionInformationEntry' TableName,
		i.PromotionInformationId,
		e.EntryCode,
		e.SavedAmount
	FROM PromotionInformationEntry e
	INNER JOIN @PromotionInformation i ON e.PromotionInformationId = i.PromotionInformationId

	SELECT 'PromotionInformationShipment' TableName,
		i.PromotionInformationId,
		s.ShippingMethodId,
		s.OrderAddressName,
		s.ShippingMethodName,
		s.SavedAmount
	FROM PromotionInformationShipment s
	INNER JOIN @PromotionInformation i ON s.PromotionInformationId = i.PromotionInformationId
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_OrderGroup]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_Search_OrderGroup] 
GO

CREATE PROCEDURE [dbo].[ecf_Search_OrderGroup]
    @results udttOrderGroupId readonly
AS
BEGIN

DECLARE @search_condition nvarchar(max)

-- Return GroupIds.
SELECT [OrderGroupId] FROM @results


-- Prevent any queries if order group doesn't exist
IF NOT EXISTS(SELECT * from OrderGroup G INNER JOIN @results R ON G.OrderGroupId = R.OrderGroupId)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderForm' TableName, OE.*, O.*
	FROM [OrderFormEx] OE 
		INNER JOIN OrderForm O ON O.OrderFormId = OE.ObjectId 
		INNER JOIN @results R ON O.OrderGroupId = R.OrderGroupId 

if(@@ROWCOUNT = 0)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderGroupAddress' TableName, OE.*, O.*
	FROM [OrderGroupAddressEx] OE 
		INNER JOIN OrderGroupAddress O ON O.OrderGroupAddressId = OE.ObjectId  
		INNER JOIN @results R ON O.OrderGroupId = R.OrderGroupId 

-- Return Shipment Collection
SELECT 'Shipment' TableName, SE.*, S.*
	FROM [ShipmentEx] SE 
		INNER JOIN Shipment S ON S.ShipmentId = SE.ObjectId 
		INNER JOIN @results R ON S.OrderGroupId = R.OrderGroupId 

-- Return Line Item Collection
SELECT 'LineItem' TableName, LE.*, L.*
	FROM [LineItemEx] LE 
		INNER JOIN LineItem L ON L.LineItemId = LE.ObjectId 
		INNER JOIN @results R ON L.OrderGroupId = R.OrderGroupId 

-- Return Order Form Payment Collection

CREATE TABLE #OrderSearchResults (OrderGroupId int)
insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
SET @search_condition = N'''INNER JOIN OrderFormPayment O ON O.PaymentId = T.ObjectId INNER JOIN #OrderSearchResults R ON O.OrderGroupId = R.OrderGroupId '''

DECLARE @metaclassid int
DECLARE @parentclassid int
DECLARE @parentmetaclassid int
DECLARE @rowNum int
DECLARE @maxrows int
DECLARE @tablename nvarchar(120)
DECLARE @name nvarchar(120)
DECLARE @procedurefull nvarchar(max)

SET @parentmetaclassid = (SELECT MetaClassId from [MetaClass] WHERE Name = N'orderformpayment' and TableName = N'orderformpayment')

SELECT top 1 @metaclassid = MetaClassId, @tablename = TableName, @parentclassid = ParentClassId, @name = Name from [MetaClass]
	SELECT @maxRows = count(*) from [MetaClass]
	SET @rowNum = 0
	WHILE @rowNum < @maxRows
	BEGIN
		SET @rowNum = @rowNum + 1
		IF (@parentclassid = @parentmetaclassid)
		BEGIN
			SET @procedurefull = N'mdpsp_avto_' + @tablename + N'_Search NULL, ' + N'''''''' + @tablename + N''''''+  ' TableName, [O].*'' ,'  + @search_condition
			EXEC (@procedurefull)
		END
		SELECT top 1 @metaclassid = MetaClassId, @tablename = TableName, @parentclassid = ParentClassId, @name = Name from [MetaClass] where MetaClassId > @metaclassid
	END

DROP TABLE #OrderSearchResults
-- Return Order Form Discount Collection
SELECT 'OrderFormDiscount' TableName, D.* 
	FROM [OrderFormDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 

-- Return Line Item Discount Collection
SELECT 'LineItemDiscount' TableName, D.* 
	FROM [LineItemDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 

-- Return Shipment Discount Collection
SELECT 'ShipmentDiscount' TableName, D.* 
	FROM [ShipmentDiscount] D 
		INNER JOIN @results R ON D.OrderGroupId = R.OrderGroupId 
		
-- Return OrderGroupNote Collection
SELECT 'OrderGroupNote' TableName, 
		G.OrderNoteId, 
		G.CustomerId, 
		G.Created, 
		G.OrderGroupId, 
		G.Detail,
		G.LineItemId,
		G.Title,
		G.Type 
	FROM [OrderGroupNote] G INNER JOIN @results R ON G.OrderGroupId = R.OrderGroupId

EXEC dbo.PromotionInformationLoad @results

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Load_OrderGroup]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[ecf_Load_OrderGroup] 
GO

CREATE PROCEDURE [dbo].[ecf_Load_OrderGroup]
    @OrderGroupId int
AS
BEGIN

DECLARE @search_condition nvarchar(max)

-- Return GroupIds.
SELECT @OrderGroupId AS [OrderGroupId]

-- Prevent any queries if order group doesn't exist
IF NOT EXISTS(SELECT OrderGroupId from OrderGroup G WHERE G.OrderGroupId = @OrderGroupId)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderForm' TableName, OE.*, O.*
	FROM [OrderFormEx] OE 
		INNER JOIN OrderForm O ON O.OrderFormId = OE.ObjectId 
		WHERE O.OrderGroupId = @OrderGroupId

if(@@ROWCOUNT = 0)
	RETURN;

-- Return Order Form Collection
SELECT 'OrderGroupAddress' TableName, OE.*, O.*
	FROM [OrderGroupAddressEx] OE 
		INNER JOIN OrderGroupAddress O ON O.OrderGroupAddressId = OE.ObjectId  
		WHERE O.OrderGroupId = @OrderGroupId

-- Return Shipment Collection
SELECT 'Shipment' TableName, SE.*, S.*
	FROM [ShipmentEx] SE 
		INNER JOIN Shipment S ON S.ShipmentId = SE.ObjectId 
		WHERE S.OrderGroupId = @OrderGroupId

-- Return Line Item Collection
SELECT 'LineItem' TableName, LE.*, L.*
	FROM [LineItemEx] LE 
		INNER JOIN LineItem L ON L.LineItemId = LE.ObjectId 
		WHERE L.OrderGroupId = @OrderGroupId

-- Return Order Form Payment Collection

SET @search_condition = N'''INNER JOIN OrderFormPayment O ON O.PaymentId = T.ObjectId WHERE O.OrderGroupId = ' + CAST(@OrderGroupId AS NVARCHAR) + ''''

DECLARE @metaclassid int
DECLARE @parentclassid int
DECLARE @parentmetaclassid int
DECLARE @rowNum int
DECLARE @maxrows int
DECLARE @tablename nvarchar(120)
DECLARE @name nvarchar(120)
DECLARE @procedurefull nvarchar(max)

SET @parentmetaclassid = (SELECT MetaClassId from [MetaClass] WHERE Name = N'orderformpayment' and TableName = N'orderformpayment')

SELECT top 1 @metaclassid = MetaClassId, @tablename = TableName, @parentclassid = ParentClassId, @name = Name from [MetaClass]
	SELECT @maxRows = count(*) from [MetaClass]
	SET @rowNum = 0
	WHILE @rowNum < @maxRows
	BEGIN
		SET @rowNum = @rowNum + 1
		IF (@parentclassid = @parentmetaclassid)
		BEGIN
			SET @procedurefull = N'mdpsp_avto_' + @tablename + N'_Search NULL, ' + N'''''''' + @tablename + N''''''+  ' TableName, [O].*'' ,'  + @search_condition
			EXEC (@procedurefull)
		END
		SELECT top 1 @metaclassid = MetaClassId, @tablename = TableName, @parentclassid = ParentClassId, @name = Name from [MetaClass] where MetaClassId > @metaclassid
	END

-- Return Order Form Discount Collection
SELECT 'OrderFormDiscount' TableName, D.* 
	FROM [OrderFormDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId

-- Return Line Item Discount Collection
SELECT 'LineItemDiscount' TableName, D.* 
	FROM [LineItemDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId

-- Return Shipment Discount Collection
SELECT 'ShipmentDiscount' TableName, D.* 
	FROM [ShipmentDiscount] D 
		WHERE D.OrderGroupId = @OrderGroupId
		
-- Return OrderGroupNote Collection
SELECT 'OrderGroupNote' TableName, 
		G.OrderNoteId, 
		G.CustomerId, 
		G.Created, 
		G.OrderGroupId, 
		G.Detail,
		G.LineItemId,
		G.Title,
		G.Type 
	FROM [OrderGroupNote] G
		WHERE G.OrderGroupId = @OrderGroupId

DECLARE @OrderGroupIds as udttOrderGroupId
INSERT INTO @OrderGroupIds(OrderGroupId) VALUES(@OrderGroupId)

EXEC dbo.PromotionInformationLoad @OrderGroupIds

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END
GO
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 9, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
