--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 4    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

-- BEGIN update key structure on PromotionInformation table and referencing tables PromotionInformationEntry, PromotionInformationShipment
ALTER TABLE [PromotionInformationEntry] DROP CONSTRAINT [FK_PromotionInformationEntry_PromotionInformationGuid]
GO

ALTER TABLE [PromotionInformationShipment] DROP CONSTRAINT [FK_PromotionInformationShipment_PromotionInformationGuid]
GO

ALTER TABLE [PromotionInformation] DROP CONSTRAINT [PK_PromotionInformationGuid]
GO

IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'PromotionInformationId' AND Object_ID = Object_ID(N'PromotionInformation'))
	ALTER TABLE [PromotionInformation] ADD [PromotionInformationId] INT IDENTITY(1,1) NOT NULL
GO

ALTER TABLE [PromotionInformation]
ADD CONSTRAINT [PK_PromotionInformationId] PRIMARY KEY NONCLUSTERED ([PromotionInformationId])
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name='IDX_PromotionInformation_PromotionInformationGuid' AND object_id = OBJECT_ID('PromotionInformation'))
	BEGIN
	DROP INDEX [IDX_PromotionInformation_PromotionInformationGuid] ON [dbo].[PromotionInformation];
	END
GO

ALTER TABLE [PromotionInformationEntry] ADD [PromotionInformationId] INT
GO

-- migration [PromotionInformationEntry] table
UPDATE e
SET e.[PromotionInformationId] = p.[PromotionInformationId]
FROM [PromotionInformationEntry] e
INNER JOIN [PromotionInformation] p ON e.[PromotionInformationGuid] = p.[PromotionInformationGuid]
GO

ALTER TABLE [PromotionInformationEntry]
ALTER COLUMN [PromotionInformationId] INT NOT NULL
GO

DROP INDEX [IDX_PromotionInformationEntry] ON [PromotionInformationEntry]
GO

ALTER TABLE [PromotionInformationEntry] DROP COLUMN [PromotionInformationGuid]
GO

ALTER TABLE [PromotionInformationEntry]
ADD CONSTRAINT [FK_PromotionInformationEntry_PromotionInformationId] FOREIGN KEY ([PromotionInformationId])
REFERENCES [dbo].[PromotionInformation] ([PromotionInformationId]) ON DELETE CASCADE
GO

CREATE CLUSTERED INDEX [IDX_PromotionInformationEntry] ON [PromotionInformationEntry]
(
	[PromotionInformationId] 
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

ALTER TABLE [PromotionInformationShipment] ADD [PromotionInformationId] INT
GO

-- migration [PromotionInformationShipment] table
UPDATE s
SET s.[PromotionInformationId] = p.[PromotionInformationId]
FROM PromotionInformationShipment s
INNER JOIN [PromotionInformation] p ON s.[PromotionInformationGuid] = p.[PromotionInformationGuid]
GO

ALTER TABLE PromotionInformationShipment
ALTER COLUMN [PromotionInformationId] INT NOT NULL
GO

DROP INDEX [IDX_PromotionInformationShipment] ON [PromotionInformationShipment]
GO

ALTER TABLE [PromotionInformationShipment] DROP COLUMN [PromotionInformationGuid]
GO

ALTER TABLE [PromotionInformationShipment]
ADD CONSTRAINT [FK_PromotionInformationShipment_PromotionInformationId] FOREIGN KEY ([PromotionInformationId])
REFERENCES [dbo].[PromotionInformation] ([PromotionInformationId]) ON DELETE CASCADE
GO

CREATE CLUSTERED INDEX [IDX_PromotionInformationShipment] ON [PromotionInformationShipment]
(
	[PromotionInformationId] 
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

ALTER TABLE [PromotionInformation] DROP COLUMN [PromotionInformationGuid]
GO

-- END update key structure on PromotionInformation table and referencing tables PromotionInformationEntry, PromotionInformationShipment

-- Correct index name
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name='IDX_PromotionInformation_PromotionGuid_CustomermId' AND object_id = OBJECT_ID('PromotionInformation'))
BEGIN
	EXEC sp_rename N'[dbo].PromotionInformation.IDX_PromotionInformation_PromotionGuid_CustomermId', N'IDX_PromotionInformation_PromotionGuid_CustomerId', N'INDEX'; 
END
GO

-- drop sprocs referencing udtts that need to be updated
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave];
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList];
GO

-- recreate udttPromotionInformation 
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation];
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
	[CustomerId] UNIQUEIDENTIFIER NOT NULL
)
GO

-- recreate udttPromotionInformationEntry
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformationEntry') DROP TYPE [dbo].[udttPromotionInformationEntry];
GO

CREATE TYPE [dbo].[udttPromotionInformationEntry] AS TABLE(
	[PromotionInformationId] INT NULL,
	[EntryCode] NVARCHAR(100) NOT NULL,
	[SavedAmount] DECIMAL(18, 3) NOT NULL
)
GO

-- recreate udttPromotionInformationShipment
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformationShipment') DROP TYPE [dbo].[udttPromotionInformationShipment];
GO

CREATE TYPE [dbo].[udttPromotionInformationShipment] AS TABLE(
	[PromotionInformationId] INT NULL,
	[ShippingMethodId] UNIQUEIDENTIFIER NOT NULL,
	[OrderAddressName] NVARCHAR(64) NOT NULL,
	[ShippingMethodName] NVARCHAR(100) NOT NULL,
	[SavedAmount] DECIMAL(18, 3) NOT NULL
)
GO

-- recreate sprocs
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
		INSERT (OrderFormId, PromotionGuid, RewardType, [Description], DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId)
		VALUES (input.OrderFormId, input.PromotionGuid, input.RewardType, input.[Description], input.DiscountType, input.CouponCode, input.AdditionalInformation, input.VisitorGroup, input.CustomerId)
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
			 DiscountType,
			 CouponCode,
			 AdditionalInformation,
			 VisitorGroup,
			 CustomerId)
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
		   CustomerId
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

-- Alter MigratePromotionInformation in case Database need to be migrated from version before 7.3.1
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[MigratePromotionInformation]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
BEGIN	
	EXEC( N'ALTER PROCEDURE [dbo].[MigratePromotionInformation]
		@PromotionMap [dbo].[udttContentGuidContentLinkMap] READONLY
	AS
	BEGIN
		DECLARE @guidIdMap TABLE (Id INT IDENTITY(1,1), PromotionInformationId INT)
		INSERT INTO dbo.PromotionInformation(
			CustomerId, OrderFormId,
			RewardType, Description,
			DiscountType, CouponCode, AdditionalInformation,
			VisitorGroup,
			PromotionGuid)
		OUTPUT inserted.PromotionInformationId INTO @guidIdMap(PromotionInformationId)
		SELECT
			t.CustomerId, t.OrderFormId,
			t.RewardType, t.Description,
			t.DiscountType, t.CouponCode, t.AdditionalInformation,
			t.VisitorGroup,
			ISNULL(m.ContentGuid, NEWID())
		FROM PromotionInformation_temp t
		LEFT JOIN @PromotionMap m on m.ContentLink = t.PromotionLink
		ORDER BY PromotionInformationGuid
		
		DECLARE @Order INT
		DECLARE @EntryCodes NVARCHAR(max)
		DECLARE @SavedAmount DECIMAL(18, 3)
		DECLARE @PromotionInformationId INT
		
		DECLARE db_cursor CURSOR FOR
		SELECT ROW_NUMBER() OVER(ORDER BY PromotionInformationGuid), EntryCodes, SavedAmount FROM PromotionInformation_temp
		
		OPEN db_cursor
		FETCH NEXT FROM db_cursor INTO @Order, @EntryCodes, @SavedAmount
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @EntryCodes = REPLACE(REPLACE(REPLACE(@EntryCodes,''['',''''),'']'',''''),''"'','''')
			SET @PromotionInformationId = (SELECT PromotionInformationId
			FROM @guidIdMap
			WHERE Id = @Order)

			INSERT INTO PromotionInformationEntry (PromotionInformationId, EntryCode, SavedAmount)
			SELECT @PromotionInformationId, Item, 
					CASE WHEN (ROW_NUMBER() OVER(ORDER BY Item)) = 1 THEN @SavedAmount ELSE 0 END
			FROM ecf_splitlist(@EntryCodes)

			FETCH NEXT FROM db_cursor INTO @Order, @EntryCodes, @SavedAmount
		END
		
		CLOSE db_cursor
		DEALLOCATE db_cursor
	END')
END
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 4, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion