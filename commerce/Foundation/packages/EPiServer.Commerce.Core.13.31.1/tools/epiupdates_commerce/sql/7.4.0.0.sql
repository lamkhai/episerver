--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 4, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO 

ALTER TABLE [dbo].[PromotionInformation] ALTER COLUMN [EntryCodes] NVARCHAR(MAX) NULL
GO

ALTER TABLE [dbo].[PromotionInformation] ADD [ShipmentIds] VARCHAR(500) NULL
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
DROP PROCEDURE [dbo].[PromotionInformationSave]
GO


-- recreate udttPromotionInformation
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(		
	[PromotionInformationId] INT NULL,
	[OrderFormId] INT NOT NULL,
	[EntryCodes] NVARCHAR(MAX) NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
	[ShipmentIds] VARCHAR(500) NULL,
	[SavedAmount]  DECIMAL(18,3) NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL,
	[VisitorGroup] UNIQUEIDENTIFIER NULL,
	[CustomerId] UNIQUEIDENTIFIER NOT NULL
)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave];
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@PromotionInformation dbo.udttPromotionInformation READONLY
AS
BEGIN

    DELETE FROM dbo.PromotionInformation WHERE OrderFormId IN (SELECT OrderFormId FROM @PromotionInformation);

    INSERT INTO dbo.PromotionInformation(OrderFormId, EntryCodes, ShipmentIds, PromotionGuid, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId)
    SELECT OrderFormId, EntryCodes, ShipmentIds, PromotionGuid, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId
    FROM @PromotionInformation

END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList]
GO

CREATE PROCEDURE [dbo].[PromotionInformationList]
	@OrderFormId INT
AS
BEGIN
	SELECT
		   PromotionInformationId,
		   EntryCodes,
		   ShipmentIds,
		   PromotionGuid,
		   SavedAmount,
		   Description,
		   RewardType,
		   DiscountType,
		   CouponCode,
		   AdditionalInformation,
		   VisitorGroup,
		   CustomerId
	FROM dbo.PromotionInformation
	WHERE OrderFormId = @OrderFormId;
END
GO


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 4, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
