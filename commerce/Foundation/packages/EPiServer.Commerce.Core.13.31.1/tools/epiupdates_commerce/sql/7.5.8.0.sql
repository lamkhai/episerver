--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 5, @patch int = 8    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

ALTER TABLE dbo.PromotionInformation ADD [Name] NVARCHAR(4000) NULL
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionInformationSave] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionInformationList] 
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation')
	DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(
	[PromotionInformationId] INT NULL,
	[OrderFormId] INT NOT NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Name]  NVARCHAR(4000) NULL,
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
		INSERT (OrderFormId, PromotionGuid, RewardType, [Name], [Description], DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId, OrderLevelSavedAmount, IsRedeemed)
		VALUES (input.OrderFormId, input.PromotionGuid, input.RewardType, input.[Name], input.[Description], input.DiscountType, input.CouponCode, input.AdditionalInformation, input.VisitorGroup, input.CustomerId, input.OrderLevelSavedAmount, input.IsRedeemed)
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecfVersionCatalog_Save]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[ecfVersionCatalog_Save]
GO

-- begin creating ecfVersionCatalog_Save sproc
CREATE PROCEDURE [dbo].[ecfVersionCatalog_Save]
	@VersionCatalogs dbo.[udttVersionCatalog] readonly,
	@PublishAction bit
AS
BEGIN
	DECLARE @WorkIds table (WorkId int, DefaultLanguage nvarchar(20))

	MERGE dbo.ecfVersionCatalog AS TARGET
	USING @VersionCatalogs AS SOURCE
	ON (TARGET.WorkId = SOURCE.WorkId)
	WHEN MATCHED THEN 
		UPDATE SET DefaultCurrency = SOURCE.DefaultCurrency,
				   WeightBase = SOURCE.WeightBase,
				   LengthBase = SOURCE.LengthBase,
				   DefaultLanguage = SOURCE.DefaultLanguage,
				   Languages = SOURCE.Languages,
				   IsPrimary = SOURCE.IsPrimary,
				   [Owner] = SOURCE.[Owner]
	WHEN NOT MATCHED THEN
		INSERT (WorkId, DefaultCurrency, WeightBase, LengthBase, DefaultLanguage, Languages, IsPrimary, [Owner])
		VALUES (SOURCE.WorkId, SOURCE.DefaultCurrency, SOURCE.WeightBase, SOURCE.LengthBase, SOURCE.DefaultLanguage, SOURCE.Languages, SOURCE.IsPrimary, SOURCE.[Owner])
	OUTPUT inserted.WorkId, inserted.DefaultLanguage INTO @WorkIds;

	IF @PublishAction = 1
	BEGIN
		DECLARE @Catalogs udttObjectWorkId

		INSERT INTO @Catalogs
			(ObjectId, ObjectTypeId, LanguageName, WorkId)
			SELECT c.ObjectId, c.ObjectTypeId, w.DefaultLanguage, c.WorkId
			FROM ecfVersion c INNER JOIN @WorkIds w ON c.WorkId = w.WorkId
			WHERE c.ObjectTypeId = 2
		-- Note that @Catalogs.LanguageName is @WorkIds.DefaultLanguage
		
		DECLARE @CatalogId int, @MasterLanguageName nvarchar(20), @Languages nvarchar(512)
		DECLARE @ObjectIdsTemp TABLE(ObjectId INT)
		DECLARE catalogCursor CURSOR FOR SELECT DISTINCT ObjectId FROM @Catalogs
		
		OPEN catalogCursor  
		FETCH NEXT FROM catalogCursor INTO @CatalogId
		
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			SELECT @MasterLanguageName = v.DefaultLanguage, @Languages = v.Languages
			FROM @VersionCatalogs v
			INNER JOIN @Catalogs c ON c.WorkId = v.WorkId
			WHERE c.ObjectId = @CatalogId
						
			-- when publishing a Catalog, we need to update all drafts to have the same DefaultLanguage as the published one.
			UPDATE d SET 
				d.DefaultLanguage = @MasterLanguageName
			FROM ecfVersionCatalog d
			INNER JOIN ecfVersion v ON d.WorkId = v.WorkId
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
			
			-- and also update MasterLanguageName and CurrentLanguageRemovedFlag of contents that's related to Catalog
			-- catalogs
			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			WHERE v.ObjectTypeId = 2 AND v.ObjectId = @CatalogId
						
			--nodes
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT n.CatalogNodeId
				FROM CatalogNode n
				WHERE n.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 1
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			--entries
			DELETE FROM @ObjectIdsTemp
			INSERT INTO @ObjectIdsTemp
				SELECT e.CatalogEntryId
				FROM CatalogEntry e
				WHERE e.CatalogId = @CatalogId

			UPDATE v SET 
				CurrentLanguageRemoved = CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END,
				MasterLanguageName = @MasterLanguageName
			FROM ecfVersion v
			INNER JOIN @ObjectIdsTemp t ON t.ObjectId = v.ObjectId
			WHERE v.ObjectTypeId = 0
				  AND (CurrentLanguageRemoved <> CASE WHEN CHARINDEX(v.LanguageName + ';', @Languages + ';') > 0 THEN 0 ELSE 1 END
					   OR MasterLanguageName <> @MasterLanguageName)
			
			
			FETCH NEXT FROM catalogCursor INTO @CatalogId
		END
		
		CLOSE catalogCursor  
		DEALLOCATE catalogCursor;  
	END
END
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 5, 8, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
