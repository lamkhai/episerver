--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 30    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Dropping [dbo].[mc_OrderGroupNotesUpdate]...';


GO
DROP PROCEDURE [dbo].[mc_OrderGroupNotesUpdate];


GO
PRINT N'Dropping [dbo].[udttOrderGroupNote]...';


GO
DROP TYPE [dbo].[udttOrderGroupNote];


GO
PRINT N'Creating [dbo].[udttOrderGroupNote]...';


GO
CREATE TYPE [dbo].[udttOrderGroupNote] AS TABLE (
    [OrderNoteId]  INT              NULL,
    [OrderGroupId] INT              NOT NULL,
    [CustomerId]   UNIQUEIDENTIFIER NOT NULL,
    [Title]        NVARCHAR (255)   NULL,
    [Type]         NVARCHAR (50)    NULL,
    [Detail]       NTEXT            NULL,
    [Created]      DATETIME         NOT NULL,
    [LineItemId]   INT              NULL,
    [IsModified]   BIT              NOT NULL,
    [Channel]      NVARCHAR (50)    NULL,
    [EventType]    NVARCHAR (50)    NULL);


GO
PRINT N'Altering [dbo].[OrderGroupNote]...';


GO
ALTER TABLE [dbo].[OrderGroupNote]
    ADD [Channel]   NVARCHAR (50) NULL,
        [EventType] NVARCHAR (50) NULL;


GO
PRINT N'Altering [dbo].[ecf_Load_OrderGroup]...';


GO
ALTER PROCEDURE [dbo].[ecf_Load_OrderGroup]
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
DECLARE @ids udttOrderGroupId
INSERT INTO @ids VALUES(@OrderGroupId)
EXEC dbo.ecf_Search_Payment @ids

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
		G.Type,
		G.Channel,
		G.EventType
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
PRINT N'Altering [dbo].[ecf_Search_OrderGroup]...';


GO
ALTER PROCEDURE [dbo].[ecf_Search_OrderGroup]
    @results udttOrderGroupId readonly
AS
BEGIN

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
EXEC dbo.ecf_Search_Payment @results

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
		G.Type,
		G.Channel,
		G.EventType
	FROM [OrderGroupNote] G 
	INNER JOIN @results R ON G.OrderGroupId = R.OrderGroupId

EXEC dbo.PromotionInformationLoad @results

-- assign random local variable to set @@rowcount attribute to 1
declare @temp as int
set @temp = 1

END
GO
PRINT N'Creating [dbo].[mc_OrderGroupNotesUpdate]...';


GO
CREATE PROCEDURE [dbo].[mc_OrderGroupNotesUpdate]
@OrderGroupId int,
@OrderGroupNotes udttOrderGroupNote readonly
AS
BEGIN
SET NOCOUNT ON;

;WITH CTE AS
(SELECT * FROM dbo.OrderGroupNote 
WHERE OrderGroupId = @OrderGroupId)

MERGE CTE AS T
USING @OrderGroupNotes AS S
ON T.OrderNoteId = S.OrderNoteId

WHEN NOT MATCHED BY TARGET
	THEN INSERT (
		[OrderGroupId],
		[CustomerId],
		[Title],
		[Type],
		[Detail],
		[Created],
		[LineItemId],
		[Channel],
		[EventType])
	VALUES(S.OrderGroupId,
		S.CustomerId,
		S.Title,
		S.Type,
		S.Detail,
		S.Created,
		S.LineItemId,
		S.Channel,
		S.EventType)
WHEN NOT MATCHED BY SOURCE
	THEN DELETE
WHEN MATCHED AND (S.IsModified = 1) THEN 
UPDATE SET
	[OrderGroupId] = S.OrderGroupId,
	[CustomerId] = S.CustomerId,
	[Title] = S.Title,
	[Type] = S.Type,
	[Detail] = S.Detail,
	[Created] = S.Created,
	[LineItemId] = S.LineItemId,
	[Channel] = S.Channel,
	[EventType] = S.EventType;
END
GO
PRINT N'Altering [dbo].[CatalogContentProperty_Load]...';


GO
ALTER PROCEDURE [dbo].[CatalogContentProperty_Load]
	@ObjectId int,
	@ObjectTypeId int,
	@MetaClassId int,
	@Language nvarchar(50)
AS
BEGIN
	DECLARE @catalogId INT
	DECLARE @FallbackLanguage nvarchar(50)

	SET @catalogId = CASE WHEN @ObjectTypeId = 0 THEN
							(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
							WHEN @ObjectTypeId = 1 THEN							
							(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
						END
	SELECT @FallbackLanguage = DefaultLanguage FROM dbo.[Catalog] WHERE CatalogId = @catalogId

	-- load from fallback language only if @Language is not existing language of catalog.
	-- in other work, fallback language is used for invalid @Language value only.
	IF @Language NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
		SET @Language = @FallbackLanguage
    
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 --Fields will be encrypted only when DB does not support Azure
		BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							CASE WHEN (F.IsEncrypted = 1 AND dbo.mdpfn_sys_IsLongStringMetaField(F.DataTypeId) = 1 )
							THEN dbo.mdpfn_sys_EncryptDecryptString(P.LongString, 0) 
							ELSE P.LongString END AS LongString, 
							P.[Guid]  
		FROM dbo.CatalogContentProperty P
		INNER JOIN MetaField F ON P.MetaFieldId = F.MetaFieldId
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((F.MultiLanguageValue = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((F.MultiLanguageValue = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))

		EXEC mdpsp_sys_CloseSymmetricKey
		END
	ELSE
		BEGIN
		SELECT P.ObjectId, P.ObjectTypeId, P.MetaFieldId, P.MetaClassId, P.MetaFieldName, P.LanguageName,
							P.Boolean, P.Number, P.FloatNumber, P.[Money], P.[Decimal], P.[Date], P.[Binary], P.[String], 
							P.LongString, 
							P.[Guid]
		FROM dbo.CatalogContentProperty P
		WHERE ObjectId = @ObjectId AND
				ObjectTypeId = @ObjectTypeId AND
				MetaClassId = @MetaClassId AND
				((P.CultureSpecific = 1 AND LanguageName = @Language COLLATE DATABASE_DEFAULT) OR ((P.CultureSpecific = 0 AND LanguageName = @FallbackLanguage COLLATE DATABASE_DEFAULT)))
		END

	-- Select CatalogContentEx data
	EXEC CatalogContentEx_Load @ObjectId, @ObjectTypeId
END
GO
PRINT N'Altering [dbo].[ecf_Inventory_QueryInventory]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_QueryInventory]
    @entryKeys [dbo].[udttInventoryCode] READONLY,
	@warehouseKeys [dbo].[udttInventoryCode] READONLY,
	@partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @entryKeys keys1 
        where mi.[CatalogEntryCode] = keys1.[Code])
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @warehouseKeys keys2 
        where mi.[WarehouseCode] = keys2.[Code])
    union
	select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from [dbo].[InventoryService] mi
    where exists (
        select 1 
        from @partialKeys keys3 
        where mi.[CatalogEntryCode] = keys3.[CatalogEntryCode]
          and mi.[WarehouseCode] = keys3.[WarehouseCode])
    order by [CatalogEntryCode], [WarehouseCode]


END
GO
PRINT N'Altering [dbo].[ecf_Inventory_QueryInventoryPaged]...';


GO
ALTER PROCEDURE [dbo].[ecf_Inventory_QueryInventoryPaged]
    @offset int,
    @count int,
    @partialKeys [dbo].[udttInventory] READONLY
AS
BEGIN
    declare @results table (
        [CatalogEntryCode] nvarchar(100),
        [WarehouseCode] nvarchar(50),
        [IsTracked] bit,
        [PurchaseAvailableQuantity] decimal(38, 9),
        [PreorderAvailableQuantity] decimal(38, 9),
        [BackorderAvailableQuantity] decimal(38, 9),
        [PurchaseRequestedQuantity] decimal(38, 9),
        [PreorderRequestedQuantity] decimal(38, 9),
        [BackorderRequestedQuantity] decimal(38, 9),
        [PurchaseAvailableUtc] datetime2,
        [PreorderAvailableUtc] datetime2,
        [BackorderAvailableUtc] datetime2,
        [AdditionalQuantity] decimal(38, 9),
        [ReorderMinQuantity] decimal(38, 9),
        [RowNumber] int,
        [TotalCount] int
    )

    insert into @results (
        [CatalogEntryCode],
        [WarehouseCode],
        [IsTracked],
        [PurchaseAvailableQuantity],
        [PreorderAvailableQuantity],
        [BackorderAvailableQuantity],
        [PurchaseRequestedQuantity],
        [PreorderRequestedQuantity],
        [BackorderRequestedQuantity],
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [TotalCount]
    )
    select
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity],
        [RowNumber],
        [RowNumber] + [ReverseRowNumber] - 1 as [TotalCount]
    from (
        select 
            ROW_NUMBER() over (order by [CatalogEntryCode], [WarehouseCode]) as [RowNumber],
            ROW_NUMBER() over (order by [CatalogEntryCode] desc, [WarehouseCode] desc) as [ReverseRowNumber],
            [CatalogEntryCode], 
            [WarehouseCode], 
            [IsTracked], 
            [PurchaseAvailableQuantity], 
            [PreorderAvailableQuantity], 
            [BackorderAvailableQuantity], 
            [PurchaseRequestedQuantity], 
            [PreorderRequestedQuantity], 
            [BackorderRequestedQuantity], 
            [PurchaseAvailableUtc],
            [PreorderAvailableUtc],
            [BackorderAvailableUtc],
            [AdditionalQuantity],
            [ReorderMinQuantity]
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
              and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
    ) paged
    where @offset < [RowNumber] and [RowNumber] <= (@offset + @count)

    if not exists (select 1 from @results)
    begin
        select COUNT(*) as TotalCount
        from [dbo].[InventoryService] mi
        where exists (
            select 1 
            from @partialKeys keys 
            where mi.[CatalogEntryCode] = isnull(keys.[CatalogEntryCode], mi.[CatalogEntryCode])
              and mi.[WarehouseCode] = isnull(keys.[WarehouseCode], mi.[WarehouseCode]))
    end
    else
    begin
        select top 1 [TotalCount] from @results
    end
       
    select 
        [CatalogEntryCode], 
        [WarehouseCode], 
        [IsTracked], 
        [PurchaseAvailableQuantity], 
        [PreorderAvailableQuantity], 
        [BackorderAvailableQuantity], 
        [PurchaseRequestedQuantity], 
        [PreorderRequestedQuantity], 
        [BackorderRequestedQuantity], 
        [PurchaseAvailableUtc],
        [PreorderAvailableUtc],
        [BackorderAvailableUtc],
        [AdditionalQuantity],
        [ReorderMinQuantity]
    from @results
    order by [RowNumber]
END
GO
PRINT N'Refreshing [dbo].[mc_OrderGroupNoteDelete]...';


GO
EXECUTE sp_refreshsqlmodule N'[dbo].[mc_OrderGroupNoteDelete]';


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
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 30, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
