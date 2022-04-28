--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 8, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

-- add IsActive column to PromotionInformation if it does not exist
IF NOT EXISTS(SELECT * FROM sys.columns 
        WHERE [name] = N'IsActive' AND [object_id] = OBJECT_ID(N'PromotionInformation'))
BEGIN
	ALTER TABLE [dbo].[PromotionInformation] ADD [IsActive] bit NOT NULL DEFAULT(0)
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionsInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionsInformationSave] 
GO 

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(
		
	[PromotionInformationId][int] NULL,
	[ContentReference] [nvarchar](100) NOT NULL,
	[SavedAmount] [decimal](18, 3) NOT NULL,
	[Description] [nvarchar](4000) NOT NULL,
	[IsActive][bit] NOT NULL
)
GO

CREATE PROCEDURE [dbo].[PromotionsInformationSave]
	@OrderGroupId int,
	@PromotionsInformation dbo.udttPromotionInformation readonly
AS
BEGIN
	MERGE dbo.PromotionInformation as existingpromos
	USING @PromotionsInformation as promos
	ON promos.PromotionInformationId = existingpromos.PromotionInformationId
	WHEN MATCHED THEN 
		UPDATE SET existingpromos.SavedAmount = promos.SavedAmount, 
		existingpromos.Description = promos.Description, 
		existingpromos.IsActive = promos.IsActive, 
		existingpromos.ContentReference = promos.ContentReference
	WHEN NOT MATCHED THEN 
		INSERT (OrderGroupId, ContentReference, SavedAmount, Description, IsActive)
		VALUES(@OrderGroupId, promos.ContentReference, promos.SavedAmount, promos.Description, promos.IsActive);
END
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionsInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionsInformationList] 
GO 

CREATE PROCEDURE [dbo].[PromotionsInformationList]
	@OrderGroupId int
AS
BEGIN
	SELECT
		   PromotionInformation.PromotionInformationId as PromotionInformationId,
		   PromotionInformation.ContentReference AS ContentReference,
		   PromotionInformation.SavedAmount AS SavedAmount,
		   PromotionInformation.Description AS Description,
		   PromotionInformation.IsActive AS IsActive
	   FROM dbo.PromotionInformation
	WHERE PromotionInformation.OrdergroupId = @OrderGroupId
	
END 

GO 

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 8, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
