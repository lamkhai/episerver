--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 2, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave] 
GO

ALTER TABLE dbo.PromotionInformation ADD CouponCode NVARCHAR(100) NULL
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO
CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(		
	[PromotionInformationId][int] NULL,
	[ContentLink] NVARCHAR(100) NOT NULL,
	[PromotionLink] NVARCHAR(100) NOT NULL,
	[OrderFormId] INT NOT NULL,
	[SavedAmount]  DECIMAL(18,3) NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL
)

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList] 
GO

CREATE PROCEDURE [dbo].[PromotionInformationList]
	@OrderFormId int
AS
BEGIN
	SELECT
		   PromotionInformation.PromotionInformationId as PromotionInformationId,
		   PromotionInformation.ContentLink AS ContentLink,
		   PromotionInformation.PromotionLink AS PromotionLink,
		   PromotionInformation.SavedAmount AS SavedAmount,
		   PromotionInformation.Description AS Description,
		   PromotionInformation.RewardType AS RewardType,
		   PromotionInformation.DiscountType AS DiscountType,
		   PromotionInformation.CouponCode AS CouponCode,
		   PromotionInformation.AdditionalInformation AS AdditionalInformation
	FROM dbo.PromotionInformation
	WHERE PromotionInformation.OrderFormId = @OrderFormId
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave] 
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@OrderFormId INT,
	@PromotionInformation dbo.udttPromotionInformation READONLY
AS
BEGIN

    DELETE FROM dbo.PromotionInformation WHERE OrderFormId = @OrderFormId;

    INSERT INTO dbo.PromotionInformation(OrderFormId, ContentLink, PromotionLink, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation)
    SELECT @OrderFormId, ContentLink, PromotionLink, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation
    FROM @PromotionInformation

END

GO

-- Add Epi_ActiveCoupons
DECLARE @metaClassId int, @metaDataTypeId int, @metaFieldId int
SET @metaClassId = (SELECT TOP 1 MetaClassId from MetaClass WHERE Name = 'OrderFormEx')
SET @metaDataTypeId = (SELECT TOP 1 DataTypeId from MetaDataType WHERE Name = 'ShortString')

IF @metaClassId IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT 1 FROM [dbo].[MetaField] WHERE [Name] = N'Epi_CouponCodes')
	BEGIN		  
		EXEC mdpsp_sys_AddMetaField 'Mediachase.Commerce.Orders.System',
			'Epi_CouponCodes',
			'Coupon Codes',
			'Coupon codes added to the order.',
			@metaDataTypeId,
			512,
			1,
			0,
			0,
			0,
			@Retval = @metaFieldId OUTPUT
	
		EXEC mdpsp_sys_AddMetaFieldToMetaClass @metaClassId,
			@metaFieldId,
			0
	END
END
GO
-- end of add Epi_ActiveCoupons

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 2, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
