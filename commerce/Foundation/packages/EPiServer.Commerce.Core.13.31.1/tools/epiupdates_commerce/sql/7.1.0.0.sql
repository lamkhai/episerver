--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 1, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

-- Drop 3 previously created procedures having typo in name.
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionsInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionsInformationSave] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionsInformationDelete]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionsInformationDelete] 
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionsInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionsInformationList] 
GO

--Drop the saving SP so that we can drop the udtt.
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave] 
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
	[AdditionalInformation] NVARCHAR(MAX) NULL
)

GO

sp_rename 'dbo.PromotionInformation.ContentReference', 'ContentLink', 'COLUMN';
GO

ALTER TABLE dbo.PromotionInformation ADD OrderFormId INT NOT NULL DEFAULT(0)
GO

ALTER TABLE dbo.PromotionInformation ALTER COLUMN Description NVARCHAR(4000) NULL
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE [Name] LIKE 'DF__Promotion__IsAct%' AND TYPE = N'D')
BEGIN
	DECLARE @cons nvarchar(50)
	SELECT @cons = [Name] FROM sys.objects WHERE [Name] LIKE 'DF__Promotion__IsAct%' AND TYPE = N'D'

	EXEC ('ALTER TABLE [dbo].[PromotionInformation] DROP CONSTRAINT ' + @cons)
END
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE [Name] = N'IsActive' AND Object_ID = Object_ID(N'PromotionInformation')) 
BEGIN 
	ALTER TABLE dbo.PromotionInformation DROP COLUMN IsActive
END
GO

ALTER TABLE dbo.PromotionInformation ADD PromotionLink NVARCHAR(100) NOT NULL DEFAULT('EmptyContentReference')
GO
ALTER TABLE dbo.PromotionInformation ADD RewardType VARCHAR(50) NOT NULL DEFAULT('None')
GO
ALTER TABLE dbo.PromotionInformation ADD DiscountType VARCHAR(50) NOT NULL DEFAULT('None')
GO
ALTER TABLE dbo.PromotionInformation ADD AdditionalInformation NVARCHAR(MAX) NULL
GO

UPDATE dbo.PromotionInformation 
SET dbo.PromotionInformation.OrderFormId = O.OrderFormId
FROM dbo.PromotionInformation PI 
INNER JOIN dbo.OrderForm O
ON PI.OrderGroupId = O.OrderGroupId

GO

ALTER TABLE dbo.PromotionInformation
ADD CONSTRAINT FK_PromotionInformation_OrderFormId FOREIGN KEY([OrderFormId])
	REFERENCES [dbo].[OrderForm] ([OrderFormId]) 
	ON UPDATE CASCADE 
	ON DELETE CASCADE
GO

ALTER TABLE dbo.PromotionInformation DROP CONSTRAINT FK_PromotionInformation_OrderGroup
GO

CREATE CLUSTERED INDEX IDX_PromotionInformation_OrderGroupId ON [dbo].[PromotionInformation]
(
	[OrderFormId]
) WITH ( DROP_EXISTING = ON )
GO

EXEC sp_rename N'[dbo].[PromotionInformation].[IDX_PromotionInformation_OrderGroupId]', N'IDX_PromotionInformation_OrderFormId', N'INDEX';
GO

ALTER TABLE dbo.PromotionInformation DROP COLUMN OrderGroupId
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@OrderFormId int,
	@PromotionInformation dbo.udttPromotionInformation readonly
AS
BEGIN
	MERGE dbo.PromotionInformation as existingpromos
	USING @PromotionInformation as promos
	ON promos.PromotionInformationId = existingpromos.PromotionInformationId
	WHEN MATCHED THEN 
		UPDATE SET existingpromos.PromotionLink = promos.PromotionLink,
		existingpromos.SavedAmount = promos.SavedAmount,
		existingpromos.RewardType = promos.RewardType,
		existingpromos.Description = promos.Description, 
		existingpromos.DiscountType = promos.DiscountType, 
		existingpromos.ContentLink = promos.ContentLink,
		existingpromos.AdditionalInformation = promos.AdditionalInformation
	WHEN NOT MATCHED THEN 
		INSERT (OrderFormId, ContentLink, PromotionLink, SavedAmount, RewardType, Description, DiscountType, AdditionalInformation)
		VALUES(@OrderFormId, promos.ContentLink, promos.PromotionLink, promos.SavedAmount, promos.RewardType, promos.Description, promos.DiscountType,
			promos.AdditionalInformation);
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationDelete]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationDelete] 
GO

CREATE PROCEDURE [dbo].[PromotionInformationDelete]
	@OrderFormId INT
AS
BEGIN
	DELETE FROM PromotionInformation
		WHERE PromotionInformation.OrderFormId = @OrderFormId
END
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
		   PromotionInformation.AdditionalInformation AS AdditionalInformation
	   FROM dbo.PromotionInformation
	WHERE PromotionInformation.OrderFormId = @OrderFormId
	
END
GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 1, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
