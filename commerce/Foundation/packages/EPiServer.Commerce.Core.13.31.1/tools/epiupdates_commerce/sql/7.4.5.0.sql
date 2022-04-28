--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 5    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER TABLE [dbo].[PromotionInformation] ADD [OrderLevelSavedAmount] DECIMAL(18, 3) NULL

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList] 

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave] 

GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]

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
	[OrderLevelSavedAmount] DECIMAL(18, 3) NULL
)

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
			 OrderLevelSavedAmount)
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
		   OrderLevelSavedAmount
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
		INSERT (OrderFormId, PromotionGuid, RewardType, [Description], DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId, OrderLevelSavedAmount)
		VALUES (input.OrderFormId, input.PromotionGuid, input.RewardType, input.[Description], input.DiscountType, input.CouponCode, input.AdditionalInformation, input.VisitorGroup, input.CustomerId, input.OrderLevelSavedAmount)
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[CatalogContentProperty_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[CatalogContentProperty_Save] 

GO

CREATE PROCEDURE [dbo].[CatalogContentProperty_Save]
	@ContentProperty dbo.udttCatalogContentProperty readonly,
	@ObjectId int,
	@ObjectTypeId int,
	@LanguageName NVARCHAR(20),
	@ContentExData dbo.udttCatalogContentEx readonly,
	@SyncVersion bit = 1
AS
BEGIN
	DECLARE @catalogId INT
	SET @catalogId =
		CASE
			WHEN @ObjectTypeId = 0 THEN
				(SELECT CatalogId FROM CatalogEntry WHERE CatalogEntryId = @ObjectId)
			WHEN @ObjectTypeId = 1 THEN
				(SELECT CatalogId FROM CatalogNode WHERE CatalogNodeId = @ObjectId)
		END
	IF @LanguageName NOT IN (SELECT LanguageCode FROM dbo.CatalogLanguage WHERE CatalogId = @catalogId)
	BEGIN
		SET @LanguageName = (SELECT DefaultLanguage FROM dbo.Catalog WHERE CatalogId = @catalogId)
	END

	IF ((SELECT COUNT(*) FROM @ContentProperty) = 0)
	BEGIN 
		DELETE [CatalogContentProperty] WHERE ObjectId = @ObjectId AND ObjectTypeId = @ObjectTypeId

		IF (@SyncVersion = 1)
		BEGIN
			EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
		END

		RETURN
	END
	--delete properties where is null in input table
	DELETE A
	FROM [dbo].[CatalogContentProperty] A
	INNER JOIN @ContentProperty I
	ON	A.ObjectId = I.ObjectId AND 
		A.ObjectTypeId = I.ObjectTypeId AND
		A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT AND
		A.MetaFieldId = I.MetaFieldId
	WHERE I.[IsNull] = 1
	
	--update encrypted field: support only LongString field
	DECLARE @propertyData dbo.udttCatalogContentProperty
	
	IF dbo.mdpfn_sys_IsAzureCompatible() = 0 -- Fields will be encrypted only when only when DB does not support Azure
	BEGIN
		EXEC mdpsp_sys_OpenSymmetricKey

		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String],
			LongString,
			[Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], 
			CASE WHEN IsEncrypted = 1 THEN dbo.mdpfn_sys_EncryptDecryptString(LongString, 1) ELSE LongString END AS LongString, 
			[Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

		EXEC mdpsp_sys_CloseSymmetricKey
	END
	ELSE
	BEGIN
		INSERT INTO @propertyData (
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
		SELECT
			ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, @LanguageName, Boolean, Number, 
			FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid]
		FROM @ContentProperty
		WHERE [IsNull] = 0

	END

	-- update/insert items which are not in input
	MERGE	[dbo].[CatalogContentProperty] with (HOLDLOCK, ROWLOCK) as A
	USING	@propertyData as I
	ON		A.ObjectId = I.ObjectId AND 
			A.ObjectTypeId = I.ObjectTypeId AND 
			A.MetaFieldId = I.MetaFieldId AND
			A.LanguageName = I.LanguageName COLLATE DATABASE_DEFAULT
	WHEN	MATCHED 
		-- update the CatalogContentProperty for existing row
		THEN UPDATE SET
			A.Boolean = I.Boolean, 
			A.Number = I.Number, 
			A.FloatNumber = I.FloatNumber, 
			A.[Money] = I.[Money], 
			A.[Decimal] = I.[Decimal],
			A.[Date] = I.[Date], 
			A.[Binary] = I.[Binary], 
			A.[String] = I.[String], 
			A.LongString = I.LongString, 
			A.[Guid] = I.[Guid]

	WHEN	NOT MATCHED BY TARGET 
		-- insert new record if the record does not exist in CatalogContentProperty table
		THEN 
			INSERT (
				ObjectId, ObjectTypeId, MetaFieldId, MetaClassId, MetaFieldName, LanguageName, Boolean, Number, 
				FloatNumber, [Money], [Decimal], [Date], [Binary], [String], LongString, [Guid])
			VALUES (
				I.ObjectId, I.ObjectTypeId, I.MetaFieldId, I.MetaClassId, I.MetaFieldName, I.LanguageName, I.Boolean, I.Number, 
				I.FloatNumber, I.[Money], I.[Decimal], I.[Date], I.[Binary], I.[String], I.LongString, I.[Guid])
	;

	--Update ecfVersionProperty
	IF (@SyncVersion = 1)
	BEGIN
		EXEC [ecfVersionProperty_SyncPublishedVersion] @ContentProperty, @ObjectId, @ObjectTypeId, @LanguageName
	END

	-- Update CatalogContentEx table
	EXEC CatalogContentEx_Save @ContentExData
END
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 5, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 