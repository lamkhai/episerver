--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 7, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Load_PurchaseOrder_OrderGroupId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Load_PurchaseOrder_OrderGroupId] 

GO 

CREATE PROCEDURE [dbo].[ecf_Load_PurchaseOrder_OrderGroupId]
    @OrderGroupId int
AS
BEGIN
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId = @OrderGroupId))
		BEGIN
		exec [dbo].[ecf_Load_OrderGroup] @OrderGroupId

		-- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)

		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] = ' + CAST(@OrderGroupId AS VARCHAR)
		exec mdpsp_avto_OrderGroup_PurchaseOrder_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition
	END
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Load_ShoppingCart_OrderGroupId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Load_ShoppingCart_OrderGroupId] 

GO 

CREATE PROCEDURE [dbo].[ecf_Load_ShoppingCart_OrderGroupId]
    @OrderGroupId int
AS
BEGIN
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId = @OrderGroupId))
	BEGIN
		exec [dbo].[ecf_Load_OrderGroup] @OrderGroupId
	
		-- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)

		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] = ' + CAST(@OrderGroupId AS VARCHAR)
		exec mdpsp_avto_OrderGroup_ShoppingCart_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition
	END
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Load_PaymentPlan_OrderGroupId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Load_PaymentPlan_OrderGroupId] 

GO 

CREATE PROCEDURE [dbo].[ecf_Load_PaymentPlan_OrderGroupId]
    @OrderGroupId int
AS
BEGIN
	IF(EXISTS(SELECT OrderGroupId from OrderGroup where OrderGroupId = @OrderGroupId))
	BEGIN
		exec [dbo].[ecf_Load_OrderGroup] @OrderGroupId

		-- Return Purchase Order Details
		DECLARE @search_condition nvarchar(max)

		SET @search_condition = N'INNER JOIN OrderGroup OG ON OG.OrderGroupId = T.ObjectId WHERE [T].[ObjectId] = ' + CAST(@OrderGroupId AS VARCHAR)
		exec mdpsp_avto_OrderGroup_PaymentPlan_Search NULL, '''OrderGroup'' TableName, [OG].*', @search_condition
	END
END

GO

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

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END

GO


--optimize loading entries by using catalog entry response group
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry]
    @CatalogEntryId int,
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN

	DECLARE @CatalogEntryFull INT
	DECLARE @Associations INT
	DECLARE @Assets INT
	DECLARE @Variations INT

	SET @CatalogEntryFull = 4
	SET @Associations = 8
	SET @Assets = 32
	SET @Variations = 128

	IF (@ReturnInactive = 0)
	BEGIN
		IF  NOT EXISTS(SELECT CatalogEntryId FROM [CatalogEntry] N WHERE N.CatalogEntryId = @CatalogEntryId AND N.IsActive = 1)
			RETURN
	END

	SELECT N.* from [CatalogEntry] N
	WHERE
		N.CatalogEntryId = @CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	WHERE
		S.CatalogEntryId = @CatalogEntryId 

	IF ((@ResponseGroup & @Variations = @Variations)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT v.*
		FROM Variation v
		WHERE v.CatalogEntryId = @CatalogEntryId
	
		SELECT m.*
		FROM Merchant m
		INNER JOIN Variation v ON m.MerchantId = v.MerchantId
		WHERE v.CatalogEntryId = @CatalogEntryId
    END

	IF ((@ResponseGroup & @Associations = @Associations)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT a.*
		FROM CatalogAssociation a
		WHERE a.CatalogEntryId = @CatalogEntryId
	END

	IF ((@ResponseGroup & @Assets = @Assets)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT a.*
		FROM CatalogItemAsset a
		WHERE a.CatalogEntryId = @CatalogEntryId
		AND a.CatalogNodeId = 0 -- get Entry only, not Node
	END
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_Components]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_Components] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_Components]
	@CatalogEntryIds udttContentList readonly,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryFull INT
	DECLARE @Associations INT
	DECLARE @Assets INT
	DECLARE @Variations INT

	SET @CatalogEntryFull = 4
	SET @Associations = 8
	SET @Assets = 32
	SET @Variations = 128

	IF ((@ResponseGroup & @Variations = @Variations)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT v.*
		FROM Variation v
		INNER JOIN @CatalogEntryIds N ON N.ContentId = v.CatalogEntryId
	
		SELECT m.*
		FROM Merchant m
		INNER JOIN Variation v ON m.MerchantId = v.MerchantId
		INNER JOIN @CatalogEntryIds N ON N.ContentId = v.CatalogEntryId
    END

	IF ((@ResponseGroup & @Associations = @Associations)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT a.*
		FROM CatalogAssociation a
		INNER JOIN @CatalogEntryIds N ON N.ContentId = a.CatalogEntryId

	END

	IF ((@ResponseGroup & @Assets = @Assets)
		OR (@ResponseGroup & @CatalogEntryFull = @CatalogEntryFull))
	BEGIN
		SELECT a.*
		FROM CatalogItemAsset a
		INNER JOIN @CatalogEntryIds N ON N.ContentId = a.CatalogEntryId
	END

END

GO
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_Associated]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_Associated] 

GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntry_Associated]
    @CatalogEntryId int,
	@AssociationName nvarchar(150) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	if(@AssociationName = '')
		set @AssociationName = null

	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogEntryAssociation A ON A.CatalogEntryId = N.CatalogEntryId
	INNER JOIN CatalogAssociation CA ON CA.CatalogAssociationId = A.CatalogAssociationId
	WHERE
		CA.CatalogEntryId = @CatalogEntryId AND COALESCE(@AssociationName, CA.AssociationName) = CA.AssociationName AND 
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY CA.SortOrder, A.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C on N.CatalogEntryId = C.ContentId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C on S.CatalogEntryId = C.ContentId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_AssociatedByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_AssociatedByCode] 

GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntry_AssociatedByCode]
	@ApplicationId uniqueidentifier,
	@CatalogEntryCode nvarchar(100),
	@AssociationName nvarchar(150) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogEntryAssociation A ON A.CatalogEntryId = N.CatalogEntryId
	INNER JOIN CatalogAssociation CA ON CA.CatalogAssociationId = A.CatalogAssociationId
	INNER JOIN CatalogEntry NE ON NE.CatalogEntryId = CA.CatalogEntryId
	WHERE
		NE.ApplicationId = @ApplicationId AND
		NE.Code = @CatalogEntryCode AND COALESCE(@AssociationName, CA.AssociationName) = CA.AssociationName AND 
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY CA.SortOrder, A.SortOrder

	if(@AssociationName = '')
		set @AssociationName = null
	
	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_CatalogId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_CatalogId] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_CatalogId]
    @CatalogId int,
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	WHERE
		N.CatalogId = @CatalogId AND
		NOT EXISTS(SELECT * FROM NodeEntryRelation R WHERE R.CatalogId = @CatalogId and N.CatalogEntryId = R.CatalogEntryId) AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_CatalogName]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_CatalogName] 

GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntry_CatalogName]
	@ApplicationId uniqueidentifier,
	@CatalogName nvarchar(150),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN [Catalog] C ON N.CatalogId = C.CatalogId
	WHERE
		N.ApplicationId = @ApplicationId AND
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode] 

GO
CREATE PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeCode]
	@ApplicationId uniqueidentifier,
	@CatalogName nvarchar(150),
	@CatalogNodeCode nvarchar(100),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
	INNER JOIN CatalogNode CN ON R.CatalogNodeId = CN.CatalogNodeId
	INNER JOIN [Catalog] C ON R.CatalogId = C.CatalogId
	WHERE
		N.ApplicationId = @ApplicationId AND
		CN.Code = @CatalogNodeCode AND
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNameCatalogNodeId]
	@ApplicationId uniqueidentifier,
	@CatalogName nvarchar(150),
	@CatalogNodeId int,
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
	INNER JOIN [Catalog] C ON R.CatalogId = C.CatalogId
	WHERE
		N.ApplicationId = @ApplicationId AND
		R.CatalogNodeId = @CatalogNodeId AND
		C.[Name] = @CatalogName AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_CatalogNodeId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNodeId] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_CatalogNodeId]
	@CatalogId int,
    @CatalogNodeId int,
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN NodeEntryRelation R ON R.CatalogEntryId = N.CatalogEntryId
	WHERE
		R.CatalogNodeId = @CatalogNodeId AND
		R.CatalogId = @CatalogId AND
		((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C on N.CatalogEntryId = C.ContentId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C on S.CatalogEntryId = C.ContentId
	
	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_Name]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_Name] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_Name]
	@ApplicationId uniqueidentifier,
	@Name nvarchar(100) = '',
	@ClassTypeId nvarchar(50) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN

	if(@ClassTypeId = '')
		set @ClassTypeId = null

	if(@Name = '')
		set @Name = null

	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	WHERE
	N.ApplicationId = @ApplicationId AND
	N.[Name] like @Name AND COALESCE(@ClassTypeId, N.ClassTypeId) = N.ClassTypeId AND
	((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON N.CatalogEntryId = C.ContentId
	

	SELECT DISTINCT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON S.CatalogEntryId = C.ContentId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_ParentEntryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_ParentEntryId] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_ParentEntryId]
    @ParentEntryId int,
	@ClassTypeId nvarchar(50) = '',
	@RelationTypeId nvarchar(50) = '',
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN

	if(@ClassTypeId = '')
		set @ClassTypeId = null

	if(@RelationTypeId = '')
		set @RelationTypeId = null

	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogEntryRelation R ON R.ChildEntryId = N.CatalogEntryId
	WHERE
	R.ParentEntryId = @ParentEntryId AND COALESCE(@ClassTypeId, N.ClassTypeId) = N.ClassTypeId AND COALESCE(@RelationTypeId, R.RelationTypeId) = R.RelationTypeId AND
	((N.IsActive = 1) or @ReturnInactive = 1)
	ORDER BY R.SortOrder

	SELECT N.*, R.Quantity, R.RelationTypeId, R.GroupName, R.SortOrder from [CatalogEntry] N
	INNER JOIN CatalogEntryRelation R ON R.ChildEntryId = N.CatalogEntryId
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId
	WHERE R.ParentEntryId = @ParentEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_UriLanguage]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_UriLanguage] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntry_UriLanguage]
	@ApplicationId uniqueidentifier,
	@Uri nvarchar(255),
	@LanguageCode nvarchar(50),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	INNER JOIN CatalogItemSeo S ON N.CatalogEntryId = S.CatalogEntryId
	WHERE
		N.ApplicationId = @ApplicationId AND
		N.ApplicationId = S.ApplicationId  AND
		S.Uri = @Uri AND (S.LanguageCode = @LanguageCode OR @LanguageCode is NULL) AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT TOP(1) N.* from [CatalogEntry] N 
	INNER JOIN CatalogItemSeo S ON N.CatalogEntryId = S.CatalogEntryId
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntryByCode]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntryByCode] 

GO

CREATE PROCEDURE [dbo].[ecf_CatalogEntryByCode]
	@ApplicationId uniqueidentifier,
	@CatalogEntryCode nvarchar(100),
	@ReturnInactive bit = 0,
	@ResponseGroup INT = NULL
AS
BEGIN
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT N.CatalogEntryId from [CatalogEntry] N
	WHERE
		N.ApplicationId = @ApplicationId AND
		N.Code = @CatalogEntryCode AND
		((N.IsActive = 1) or @ReturnInactive = 1)

	SELECT N.* from [CatalogEntry] N
	INNER JOIN @CatalogEntryIds C ON C.ContentId = N.CatalogEntryId

	SELECT S.* from CatalogItemSeo S
	INNER JOIN @CatalogEntryIds C ON C.ContentId = S.CatalogEntryId

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

--Optimization: Add response group parameter in order to indicate tables which will be loaded
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogEntry_List]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_CatalogEntry_List] 
GO

CREATE PROCEDURE dbo.ecf_CatalogEntry_List
    @CatalogEntries dbo.udttEntityList READONLY,
	@ResponseGroup INT = NULL
AS
BEGIN
	SELECT n.*
	FROM CatalogEntry n
	JOIN @CatalogEntries r ON n.CatalogEntryId = r.EntityId
	ORDER BY r.SortOrder
	
	SELECT s.*
	FROM CatalogItemSeo s
	JOIN @CatalogEntries r ON s.CatalogEntryId = r.EntityId

	IF @ResponseGroup IS NULL
	BEGIN
		SELECT er.CatalogId, er.CatalogEntryId, er.CatalogNodeId, er.SortOrder
		FROM NodeEntryRelation er
		JOIN @CatalogEntries r ON er.CatalogEntryId = r.EntityId
	END
	
	DECLARE @CatalogEntryIds udttContentList
	INSERT INTO @CatalogEntryIds
	SELECT EntityId from @CatalogEntries

	exec ecf_CatalogEntry_Components @CatalogEntryIds, @ResponseGroup
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Search_CatalogEntry]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_Search_CatalogEntry] 
GO

create procedure dbo.ecf_Search_CatalogEntry
	@ApplicationId uniqueidentifier,
	@SearchSetId uniqueidentifier,
	@ResponseGroup INT = NULL
as
begin
    declare @entries dbo.udttEntityList
    insert into @entries (EntityId, SortOrder)
    select r.CatalogEntryId, r.SortOrder
    from CatalogEntrySearchResults r
    where r.SearchSetId = @SearchSetId
    
	exec dbo.ecf_CatalogEntry_List @entries, @ResponseGroup

	delete CatalogEntrySearchResults
	where SearchSetId = @SearchSetId
end


GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 7, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
