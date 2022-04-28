--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 9, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = object_id('dbo.OrderGroup') AND NAME ='IX_OrderGroup_ApplicationId')
    DROP INDEX IX_OrderGroup_ApplicationId ON dbo.OrderGroup;
GO

CREATE NONCLUSTERED INDEX [IX_OrderGroup_ApplicationId] ON [dbo].[OrderGroup] 
(
	[ApplicationId]
)
INCLUDE ([OrderGroupId])
GO

-- Update ecf_Search_OrderGroup SP to return OrderGroupNote collection
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_OrderGroup]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Search_OrderGroup] 
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

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END

GO
-- End of updating ecf_Search_OrderGroup

-- Update ecf_Load_OrderGroup SP to return OrderGroupNote collection
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Load_OrderGroup]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Load_OrderGroup] 
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

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END
GO
-- End of updating ecf_Load_OrderGroup

-- Update ecf_Search_PurchaseOrder to include ORDER BY
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_PurchaseOrder]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Search_PurchaseOrder] 
GO 

CREATE PROCEDURE [dbo].[ecf_Search_PurchaseOrder]
    @ApplicationId				uniqueidentifier,
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @ApplicationId, 
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
	
	exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END

GO
-- End of updating ecf_Search_PurchaseOrder

-- Update ecf_Search_ShoppingCart to include ORDER BY
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_ShoppingCart]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Search_ShoppingCart] 
GO 

CREATE PROCEDURE [dbo].[ecf_Search_ShoppingCart]
    @ApplicationId				uniqueidentifier,
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @ApplicationId, 
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
    
    exec dbo.ecf_Search_OrderGroup @results
    
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId IN (SELECT [OrderGroupId] FROM @results)))
	begin
	    -- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)
		CREATE TABLE #OrderSearchResults (OrderGroupId int)
		insert into #OrderSearchResults (OrderGroupId) select OrderGroupId from @results
		if(Len(@OrderBy) = 0)
		begin
			set @OrderBy = 'OrderGroupId DESC'
		end
		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

		DROP TABLE #OrderSearchResults
	end
END

GO
-- End of updating ecf_Search_ShoppingCart

-- Update ecf_Search_PaymentPlan to include ORDER BY
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_PaymentPlan]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Search_PaymentPlan] 
GO 

CREATE PROCEDURE [dbo].[ecf_Search_PaymentPlan]
    @ApplicationId				uniqueidentifier,
	@SQLClause 					nvarchar(max),
	@MetaSQLClause 				nvarchar(max),
    @OrderBy 					nvarchar(max),
	@Namespace					nvarchar(1024) = N'',
	@Classes					nvarchar(max) = N'',
    @StartingRec 				int,
	@NumRecords   				int,
	@RecordCount                int OUTPUT
AS
BEGIN
    declare @results udttOrderGroupId
    insert into @results (OrderGroupId)    
    exec dbo.ecf_OrderSearch
        @ApplicationId, 
        @SQLClause, 
        @MetaSQLClause, 
        @OrderBy, 
        @Namespace, 
        @Classes, 
        @StartingRec, 
        @NumRecords, 
        @RecordCount output
	
	exec [dbo].[ecf_Search_OrderGroup] @results

    -- Return Purchase Order Details
	DECLARE @search_condition nvarchar(max)
	CREATE TABLE #OrderSearchResults (OrderGroupId int)
	insert into #OrderSearchResults select OrderGroupId from @results
	if(Len(@OrderBy) = 0)
	begin
		set @OrderBy = 'OrderGroupId DESC'
	end
	SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] IN (SELECT [OrderGroupId] FROM #OrderSearchResults) ORDER BY ' + @OrderBy
	exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition

	DROP TABLE #OrderSearchResults
END

GO
-- End of updating ecf_Search_PaymentPlan

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 9, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
