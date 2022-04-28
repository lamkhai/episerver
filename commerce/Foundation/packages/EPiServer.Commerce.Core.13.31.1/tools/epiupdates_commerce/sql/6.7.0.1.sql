--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 7, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 
CREATE TABLE [dbo].[PromotionInformation](
	[PromotionInformationId]  INT IDENTITY(1,1) NOT NULL,
	[OrdergroupId] INT NOT NULL,
	[ContentReference] NVARCHAR(100) NOT NULL,
	[SavedAmount]  DECIMAL(18,3) NOT NULL,
	[Description]  NVARCHAR(4000) NOT NULL,
	
 CONSTRAINT [PK_PromotionInformationId] PRIMARY KEY NONCLUSTERED 
(
	[PromotionInformationId] ASC
),
 CONSTRAINT [FK_PromotionInformation_OrderGroup] FOREIGN KEY([OrderGroupId])
	REFERENCES [dbo].[OrderGroup] ([OrderGroupId]) 
	ON UPDATE CASCADE 
	ON DELETE CASCADE
)
GO

CREATE CLUSTERED INDEX IDX_PromotionInformation_OrderGroupId ON [dbo].[PromotionInformation]([OrdergroupId])
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(
	[ContentReference] [NVARCHAR](100) NOT NULL,
	[SavedAmount] [DECIMAL](18,3) NOT NULL,
	[Description] [NVARCHAR](4000) NOT NULL
)
GO

CREATE PROCEDURE [dbo].[PromotionsInformationSave]
	@OrderGroupId int,
	@PromotionsInformation dbo.udttPromotionInformation readonly
AS
BEGIN
	INSERT INTO dbo.PromotionInformation([OrdergroupId],
										 [ContentReference],
										 [SavedAmount],
										 [Description])
									SELECT @OrderGroupId,
										   PI.ContentReference,
										   PI.SavedAmount,
										   PI.Description
										FROM @PromotionsInformation PI
										
END
GO

CREATE PROCEDURE [dbo].[PromotionsInformationList]
	@OrderGroupId int
AS
BEGIN
	SELECT PromotionInformation.ContentReference AS ContentReference,
		   PromotionInformation.SavedAmount AS SavedAmount,
		   PromotionInformation.Description AS Description
	   FROM dbo.PromotionInformation
	WHERE PromotionInformation.OrdergroupId = @OrderGroupId
	
END
GO

CREATE PROCEDURE [dbo].[PromotionsInformationDelete]
	@OrderGroupId INT
AS
BEGIN
	DELETE FROM PromotionInformation
		WHERE PromotionInformation.OrdergroupId = @OrderGroupId
END
GO


--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 7, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
