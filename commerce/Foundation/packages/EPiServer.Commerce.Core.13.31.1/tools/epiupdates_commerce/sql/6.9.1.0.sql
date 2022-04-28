--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 9, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

--#122525 rename ShippingTax to EPi_ShippingTax metafield to not have possible colissions with
--customers' metafield.
--if already existed one keep data according the data type.


IF NOT EXISTS(SELECT * FROM sys.columns  
				WHERE [name] = N'EPi_ShippingTax' AND [object_id] = OBJECT_ID(N'Shipment'))
EXEC sp_RENAME 'Shipment.ShippingTax' , 'Epi_ShippingTax', 'COLUMN'
GO

ALTER PROCEDURE [dbo].[ecf_Shipment_Insert]
(
	@ShipmentId int = NULL OUTPUT,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(50) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal money,
	@ShippingDiscountAmount money,
	@ShippingMethodName nvarchar(128) = NULL,
	@Epi_ShippingTax money,
	@Status nvarchar(64) = NULL,
	@LineItemIds nvarchar(max) = NULL,
	@WarehouseCode nvarchar(50) = NULL,
	@PickListId int = NULL,
	@SubTotal money,
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

ALTER PROCEDURE [dbo].[ecf_Shipment_Update]
(
	@ShipmentId int,
	@OrderFormId int,
	@OrderGroupId int,
	@ShippingMethodId uniqueidentifier,
	@ShippingAddressId nvarchar(50) = NULL,
	@ShipmentTrackingNumber nvarchar(128) = NULL,
	@ShipmentTotal money,
	@ShippingDiscountAmount money,
	@ShippingMethodName nvarchar(128) = NULL,
	@Epi_ShippingTax money,
	@Status nvarchar(64) = NULL,
	@LineItemIds nvarchar(max) = NULL,
	@WarehouseCode nvarchar(50) = NULL,
	@PickListId int = NULL,
	@SubTotal money,
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
------metaclass Shipment
DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'Shipment')
SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'Money')

IF @metaClassId IS NOT NULL
BEGIN
--insert with name prefixed 'Epi_' in case doesn't exists already or doesn't exist the old one without prefix
--and the Shipment metaclass is available
IF NOT EXISTS(SELECT 1 FROM [dbo].[MetaField] 
				WHERE ([Name] = N'Epi_ShippingTax')
			  AND EXISTS(SELECT 1  from MetaClass 
							WHERE MetaClass.MetaClassId = MetaField.SystemMetaClassId
						 AND MetaClass.MetaClassId = @metaClassId))
BEGIN		  
	SET @metaFieldId = (SELECT TOP 1 MetaFieldId FROM [dbo].[MetaField] 
				WHERE ([Name] = N'ShippingTax')
			  AND EXISTS(SELECT 1  from MetaClass 
							WHERE MetaClass.MetaClassId = MetaField.SystemMetaClassId
						 AND MetaClass.MetaClassId = @metaClassId))
	IF (@metaFieldId IS NOT NULL)
	
	    BEGIN
		UPDATE [dbo].[MetaField] SET [Name] = 'Epi_ShippingTax'
		WHERE [MetaFieldId] = @metaFieldId
		END
    
	ELSE
		BEGIN
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
				   'Epi_ShippingTax'
				   ,'Mediachase.Commerce.Orders.System.Shipment'
				   ,@metaClassId
				   ,'Shipping tax'
				   ,'The shipping tax'
				   ,@metaDataTypeId
				   ,8
				   ,1
				   ,0
				   ,0
				   ,0
				   ,0)
	
			SET @metaFieldId = (SELECT TOP 1 MetaFieldId from MetaField WHERE Name = 'Epi_ShippingTax')
			-- add relation between Shipment and ShippingTax
			INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
			VALUES (@metaClassId, @metaFieldId)
			
			-- add relation between Shipment and ShippingTaxEx
			DECLARE @shipmentExMetaClassId int
			SET @shipmentExMetaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'ShipmentEx')
			INSERT INTO [dbo].[MetaClassMetaFieldRelation] ([MetaClassId], [MetaFieldId])
			VALUES (@shipmentExMetaClassId, @metaFieldId)
		END
	
END
END	
GO


--if already exists a custom metafield shippingtax
IF EXISTS(SELECT * FROM sys.columns  
		WHERE [name] = N'ShippingTax' AND [object_id] = OBJECT_ID(N'ShipmentEx'))
	
	--Metaclass ShipmentEx
	BEGIN
		DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int, @EpiShippingTaxMetaFieldId int, @sqlstatement nvarchar(4000)
		SET @metaFieldId = (SELECT TOP 1  MetaFieldId from MetaField WHERE Name = 'ShippingTax')
		SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'ShipmentEx')
	    SET @EpiShippingTaxMetaFieldId =  (SELECT TOP 1  MetaFieldId from MetaField WHERE Name = 'EPi_ShippingTax')
		
		
		--if numeric
		IF EXISTS( select 1 from INFORMATION_SCHEMA.COLUMNS IC 
								WHERE TABLE_NAME = 'ShipmentEx' and COLUMN_NAME = 'ShippingTax'
							 AND IC.DATA_TYPE IN( 'int','numeric','bigint','money', 'smallint','smallmoney','tinyint','float','decimal','real'))
			BEGIN
	
				set @sqlstatement = 'UPDATE Shipment SET  [Epi_ShippingTax] = [ShippingTax]
										FROM [dbo].[ShipmentEx]
									 INNER JOIN [dbo].[Shipment] ON [ObjectId] = [ShipmentId]'
				EXECUTE sp_executesql @sqlstatement
			END
		ELSE
			BEGIN
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
			SELECT 'EPi_ShippingTax_old',
						[Namespace]
					   ,[SystemMetaClassId]
					   ,[FriendlyName]
					   ,[Description]
					   ,[DataTypeId]
					   ,[Length]
					   ,1
					   ,[MultiLanguageValue]
					   ,[AllowSearch]
					   ,[IsEncrypted]
					   ,[IsKeyField]
			FROM MetaField
			WHERE Name = 'ShippingTax'
					
			DECLARE @MetaFieldOld int
			SET @MetaFieldOld = (SELECT TOP 1 [MetaFieldId] FROM MetaField WHERE Name = 'EPi_ShippingTax_Old')
			
		 
			EXECUTE [dbo].[mdpsp_sys_AddMetaFieldToMetaClass] @MetaClassId = @metaClassId,
															  @MetaFieldId = @MetaFieldOld,
															  @Weight = 0
			
			IF EXISTS(SELECT * FROM sys.columns  
				WHERE [name] = N'EPi_ShippingTax_Old' AND [object_id] = OBJECT_ID(N'ShipmentEx'))
			BEGIN			
			set @sqlstatement = 'UPDATE [dbo].[ShipmentEx] SET
								[EPi_ShippingTax_Old] = [ShippingTax],
								[ShippingTax] = NULL
								WHERE [ShippingTax] IS NOT NULL'
					
			EXECUTE sp_executesql @sqlstatement
			END
		END

    EXECUTE [dbo].[mdpsp_sys_CreateMetaClassProcedure] @MetaClassId = @metaClassId
    EXECUTE mdpsp_sys_DeleteMetaFieldFromMetaClass @MetaClassId = @metaClassId ,@metaFieldId = @metaFieldId
	END

GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 9, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
