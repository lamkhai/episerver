--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 2
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery  
GO 

ALTER TABLE [PromotionInformation] DROP CONSTRAINT [PK_PromotionInformationId]
GO

-- Adding PromotionInformationGuid and setting it as primary key
ALTER TABLE [PromotionInformation] ADD [PromotionInformationGuid] UNIQUEIDENTIFIER NULL
GO

UPDATE [PromotionInformation] SET [PromotionInformationGuid] = NEWID()
GO

ALTER TABLE [PromotionInformation] ALTER COLUMN [PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL
GO

ALTER TABLE [PromotionInformation]
ADD CONSTRAINT [PK_PromotionInformationGuid] PRIMARY KEY NONCLUSTERED ([PromotionInformationGuid])
GO
-- End adding PromotionInformationGuid and setting it as primary key

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'PromotionInformationEntry')
BEGIN
	CREATE TABLE [dbo].[PromotionInformationEntry](
		[PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL,
		[EntryCode] NVARCHAR(100) NOT NULL,
		[SavedAmount] DECIMAL(18, 3) NOT NULL,	
	CONSTRAINT [FK_PromotionInformationEntry_PromotionInformationGuid] FOREIGN KEY([PromotionInformationGuid])
		REFERENCES [dbo].[PromotionInformation] ([PromotionInformationGuid])
		ON DELETE CASCADE
	)	

	CREATE CLUSTERED INDEX [IDX_PromotionInformationEntry] ON [dbo].[PromotionInformationEntry]
	(
		[PromotionInformationGuid] 
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
END
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'PromotionInformationShipment')
BEGIN
	CREATE TABLE [dbo].[PromotionInformationShipment](
		[PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL,
		[ShippingMethodId] UNIQUEIDENTIFIER NOT NULL,
		[OrderAddressName] NVARCHAR(64) NOT NULL,
		[ShippingMethodName] NVARCHAR(100) NOT NULL,
		[SavedAmount] DECIMAL(18, 3) NOT NULL,	
	CONSTRAINT [FK_PromotionInformationShipment_PromotionInformationGuid] FOREIGN KEY([PromotionInformationGuid])
		REFERENCES [dbo].[PromotionInformation] ([PromotionInformationGuid])
		ON DELETE CASCADE
	)
	
	CREATE CLUSTERED INDEX [IDX_PromotionInformationShipment] ON [dbo].[PromotionInformationShipment]
	(
		[PromotionInformationGuid] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
	
END
GO

CREATE TYPE [dbo].[udttPromotionInformationEntry] AS TABLE(
	[PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL,
	[EntryCode] NVARCHAR(100) NOT NULL,
	[SavedAmount] DECIMAL(18, 3) NOT NULL
)
GO

CREATE TYPE [dbo].[udttPromotionInformationShipment] AS TABLE(
	[PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL,
	[ShippingMethodId] UNIQUEIDENTIFIER NOT NULL,
	[OrderAddressName] NVARCHAR(64) NOT NULL,
	[ShippingMethodName] NVARCHAR(100) NOT NULL,
	[SavedAmount] DECIMAL(18, 3) NOT NULL
)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave];
GO

-- recreate udttPromotionInformation
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(
	[PromotionInformationGuid] UNIQUEIDENTIFIER NOT NULL,
	[OrderFormId] INT NOT NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL,
	[VisitorGroup] UNIQUEIDENTIFIER NULL,
	[CustomerId] UNIQUEIDENTIFIER NOT NULL
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

    INSERT INTO PromotionInformation(OrderFormId, PromotionGuid, [PromotionInformationGuid], RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId)
    SELECT OrderFormId, PromotionGuid, [PromotionInformationGuid], RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId
    FROM @PromotionInformation

	INSERT INTO PromotionInformationEntry ([PromotionInformationGuid], [EntryCode], [SavedAmount])
	SELECT e.PromotionInformationGuid, e.EntryCode, e.SavedAmount
	FROM @PromotionInformationEntry e

	INSERT INTO PromotionInformationShipment ([PromotionInformationGuid], [ShippingMethodId], [OrderAddressName], [ShippingMethodName], [SavedAmount])
	SELECT s.PromotionInformationGuid, s.ShippingMethodId, s.OrderAddressName, s.ShippingMethodName, s.SavedAmount
	FROM @PromotionInformationShipment s
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList]
GO

CREATE PROCEDURE [dbo].[PromotionInformationList]
	@OrderFormId INT
AS
BEGIN
	DECLARE @PromotionInformation [udttPromotionInformation];
	
	INSERT INTO @PromotionInformation
			(PromotionInformationGuid,
			 OrderFormId,
			 PromotionGuid,
			 Description,
			 RewardType,
			 DiscountType,
			 CouponCode,
			 AdditionalInformation,
			 VisitorGroup,
			 CustomerId)
	SELECT 
		   PromotionInformationGuid,
		   OrderFormId,
		   PromotionGuid,
		   Description,
		   RewardType,
		   DiscountType,
		   CouponCode,
		   AdditionalInformation,
		   VisitorGroup,
		   CustomerId
	FROM dbo.PromotionInformation
	WHERE OrderFormId = @OrderFormId

	SELECT * FROM @PromotionInformation

	SELECT 
		e.PromotionInformationGuid,
		e.EntryCode,
		e.SavedAmount
	FROM PromotionInformationEntry e
	INNER JOIN @PromotionInformation i ON e.PromotionInformationGuid = i.PromotionInformationGuid

	SELECT 
		s.PromotionInformationGuid,
		s.ShippingMethodId,
		s.OrderAddressName,
		s.ShippingMethodName,
		s.SavedAmount
	FROM PromotionInformationShipment s
	INNER JOIN @PromotionInformation i ON s.PromotionInformationGuid = i.PromotionInformationGuid
END
GO

-- Alter MigratePromotionInformation in case Database need to be migrated from versi before 7.3.1
IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PromotionInformation_Temp')
BEGIN
	ALTER TABLE [PromotionInformation_Temp] ADD [PromotionInformationGuid] UNIQUEIDENTIFIER NULL
END
GO

IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PromotionInformation_Temp')
BEGIN
	UPDATE [PromotionInformation_Temp] SET [PromotionInformationGuid] = NEWID()
END
GO
		
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[MigratePromotionInformation]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
BEGIN	
	EXECUTE sp_executesql N'ALTER PROCEDURE [dbo].[MigratePromotionInformation]
		@PromotionMap [dbo].[udttContentGuidContentLinkMap] READONLY
	AS
	BEGIN		
		INSERT INTO dbo.PromotionInformation(
			CustomerId, OrderFormId, 
			PromotionInformationGuid, RewardType, Description, 
			DiscountType, CouponCode, AdditionalInformation, 
			VisitorGroup, 
			PromotionGuid)
		SELECT 
			t.CustomerId, t.OrderFormId, 						
			t.PromotionInformationGuid, t.RewardType, t.Description, 
			t.DiscountType, t.CouponCode, t.AdditionalInformation, 
			t.VisitorGroup,		
			ISNULL(m.ContentGuid, NEWID())
		FROM PromotionInformation_temp t
		LEFT JOIN @PromotionMap m on m.ContentLink = t.PromotionLink
		
		DECLARE @PromotionInformationGuid UNIQUEIDENTIFIER
		DECLARE @EntryCodes NVARCHAR(max)
		DECLARE @SavedAmount DECIMAL(18, 3)

		DECLARE db_cursor CURSOR FOR  
		SELECT PromotionInformationGuid, EntryCodes, SavedAmount FROM PromotionInformation_temp

		OPEN db_cursor   
		FETCH NEXT FROM db_cursor INTO @PromotionInformationGuid, @EntryCodes, @SavedAmount
		
		WHILE @@FETCH_STATUS = 0   
		BEGIN  
			SET @EntryCodes = REPLACE(REPLACE(REPLACE(@EntryCodes,''['',''''),'']'',''''),''"'','''')
			
			INSERT INTO PromotionInformationEntry (PromotionInformationGuid, EntryCode, SavedAmount)
			SELECT @PromotionInformationGuid, Item, 
					CASE WHEN (ROW_NUMBER() OVER(ORDER BY Item)) = 1 THEN @SavedAmount ELSE 0 END 
			FROM ecf_splitlist(@EntryCodes)

			FETCH NEXT FROM db_cursor INTO @PromotionInformationGuid, @EntryCodes, @SavedAmount
		END   

		CLOSE db_cursor   
		DEALLOCATE db_cursor
	END'
END
GO

--Note: Should drop these colums after recreate udttPromotionInformation, PromotionInformationSave
ALTER TABLE [dbo].[PromotionInformation] DROP COLUMN [EntryCodes]
GO

ALTER TABLE [dbo].[PromotionInformation] DROP COLUMN [ShipmentIds]
GO

ALTER TABLE [dbo].[PromotionInformation] DROP COLUMN [SavedAmount]
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 2, GETUTCDATE()) 
GO 

--endUpdatingDatabaseVersion 
