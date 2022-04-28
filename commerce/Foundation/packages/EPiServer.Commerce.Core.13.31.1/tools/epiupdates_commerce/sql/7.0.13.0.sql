--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 0, @patch int = 13    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- create ecf_CatalogRelation SP 
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_CatalogRelation]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_CatalogRelation]
GO
CREATE PROCEDURE [dbo].[ecf_CatalogRelation]
	@ApplicationId UNIQUEIDENTIFIER,
	@CatalogId INT,
	@CatalogNodeId INT,
	@CatalogEntryId INT,
	@GroupName NVARCHAR(100),
	@ResponseGroup INT
AS
BEGIN
	DECLARE @CatalogNode AS INT
	DECLARE @CatalogEntry AS INT
	DECLARE @NodeEntry AS INT

	SET @CatalogNode = 1
	SET @CatalogEntry = 2
	SET @NodeEntry = 4

	IF(@ResponseGroup & @CatalogNode = @CatalogNode)
		SELECT CNR.* FROM CatalogNodeRelation CNR
		INNER JOIN CatalogNode CN ON CN.CatalogNodeId = CNR.ParentNodeId AND (CN.CatalogId = @CatalogId OR @CatalogId = 0)
		WHERE CN.ApplicationId = @ApplicationId AND (@CatalogNodeId = 0 OR CNR.ParentNodeId = @CatalogNodeId)
		ORDER BY CNR.SortOrder
	ELSE
		SELECT TOP 0 * FROM CatalogNodeRelation

	IF(@ResponseGroup & @CatalogEntry = @CatalogEntry)
	BEGIN
		IF (@CatalogNodeId = 0)
		BEGIN
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE CE.ApplicationId = @ApplicationId AND (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				WHERE CE.ApplicationId = @ApplicationId AND
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
		ELSE --We must filter by CatalogNodeId when getting CatalogEntryRelation if the @CatalogNodeId is different from zero, so that we don't get redundant data.
		BEGIN		
			IF (@CatalogEntryId = 0)
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE CE.ApplicationId = @ApplicationId AND (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
			ELSE
				SELECT CER.* FROM CatalogEntryRelation CER
				INNER JOIN CatalogEntry CE ON CE.CatalogEntryId = CER.ParentEntryId AND (CE.CatalogId = @CatalogId OR @CatalogId = 0)
				INNER JOIN NodeEntryRelation NER ON CE.CatalogEntryId=NER.CatalogEntryId AND NER.CatalogNodeId=@CatalogNodeId
				WHERE CE.ApplicationId = @ApplicationId AND
					 (CER.ParentEntryId = @CatalogEntryId) AND
					 (CER.GroupName = @GroupName OR LEN(@GroupName) = 0)
				ORDER BY CER.SortOrder
		END
	END
	ELSE
		SELECT TOP 0 * FROM CatalogEntryRelation

	IF(@ResponseGroup & @NodeEntry = @NodeEntry)
	BEGIN
		DECLARE @execStmt NVARCHAR(1000)
		SET @execStmt = 'SELECT NER.CatalogId, NER.CatalogEntryId, NER.CatalogNodeId, NER.SortOrder FROM NodeEntryRelation NER
						 INNER JOIN [Catalog] C ON C.CatalogId = NER.CatalogId
						 WHERE C.ApplicationId = @ApplicationId '
		
		IF @CatalogId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogId = @CatalogId) '
		IF @CatalogNodeId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogNodeId = @CatalogNodeId) '
		IF @CatalogEntryId!=0
			SET @execStmt = @execStmt + ' AND (NER.CatalogEntryId = @CatalogEntryId) '

		SET @execStmt = @execStmt + ' ORDER BY NER.SortOrder'
		
		DECLARE @pars NVARCHAR(500)
		SET @pars = '@ApplicationId uniqueidentifier, @CatalogId int, @CatalogNodeId int, @CatalogEntryId int'
		EXEC sp_executesql @execStmt, @pars,
			@ApplicationId=@ApplicationId, @CatalogId=@CatalogId, @CatalogNodeId=@CatalogNodeId, @CatalogEntryId=@CatalogEntryId
	END
	ELSE
		SELECT TOP 0 CatalogId, CatalogEntryId, CatalogNodeId, SortOrder FROM NodeEntryRelation
END
GO
-- end of creating ecf_CatalogRelation SP

-- create ecf_GetCodeByCatalogEntryId SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCodeByCatalogEntryId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCodeByCatalogEntryId]
GO

CREATE PROCEDURE [dbo].[ecf_GetCodeByCatalogEntryId]
	@ApplicationId UNIQUEIDENTIFIER,
	@CatalogEntryId INT
AS
BEGIN
	SELECT TOP 1 Code from [CatalogEntry]
	WHERE ApplicationId = @ApplicationId AND
		  CatalogEntryId = @CatalogEntryId
END
GO
-- end of creating ecf_GetCodeByCatalogEntryId SP

-- create ecf_GetCodeByCatalogNodeId SP
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GetCodeByCatalogNodeId]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_GetCodeByCatalogNodeId]
GO

CREATE PROCEDURE [dbo].[ecf_GetCodeByCatalogNodeId]
	@ApplicationId UNIQUEIDENTIFIER,
	@CatalogNodeId INT
AS
BEGIN
	SELECT TOP 1 Code from [CatalogNode]
	WHERE ApplicationId = @ApplicationId AND
		  CatalogNodeId = @CatalogNodeId
END
GO
-- end of creating ecf_GetCodeByCatalogNodeId SP

 
-- modify stored procedure ecf_Shipment_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Shipment_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_Shipment_Insert]
GO
CREATE PROCEDURE [dbo].[ecf_Shipment_Insert]
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
-- end modify stored procedure ecf_Shipment_Insert
-- modify stored procedure ecf_Shipment_Update
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_Shipment_Update]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_Shipment_Update]
GO
CREATE PROCEDURE [dbo].[ecf_Shipment_Update]
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
-- end modify stored procedure ecf_Shipment_Update 

-- modify ShippingAddressId length
ALTER TABLE [LineItem] ALTER COLUMN [ShippingAddressId] NVARCHAR (64) NOT NULL
GO
-- end modify ShippingAddressId length

-- modify stored procedure ecf_LineItem_Insert
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_LineItem_Insert]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecf_LineItem_Insert]
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
	@ShippingAddressId nvarchar(64),
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
-- end modify stored procedure ecf_LineItem_Insert

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 0, 13, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
