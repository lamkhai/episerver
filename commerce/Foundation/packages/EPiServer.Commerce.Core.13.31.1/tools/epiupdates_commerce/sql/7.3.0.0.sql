--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 3, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

CREATE TABLE [dbo].[PromotionRedemption](
	[PromotionId] [int] NOT NULL,
	[CustomerId] [uniqueidentifier] NOT NULL,
	[Count] [int] NOT NULL,
 CONSTRAINT [PK_PromotionRedemption] PRIMARY KEY CLUSTERED 
(
	[PromotionId] ASC,
	[CustomerId] ASC
))

GO

--Drop SP in order to drop the user defined table type.
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave] 
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(		
	[PromotionInformationId][int] NULL,
	[EntryCodes] NVARCHAR(MAX) NOT NULL,
	[PromotionLink] NVARCHAR(100) NOT NULL,
	[OrderFormId] INT NOT NULL,
	[SavedAmount]  DECIMAL(18,3) NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL,
	[VisitorGroup] UNIQUEIDENTIFIER NULL
)

GO

ALTER TABLE [dbo].[PromotionInformation] ADD [VisitorGroup] UNIQUEIDENTIFIER NULL
GO

ALTER TABLE [dbo].[PromotionInformation] ADD [EntryCodes] NVARCHAR(MAX)
GO

UPDATE [dbo].[PromotionInformation] 
SET EntryCodes = '["' + e.Code + '"]'
FROM [dbo].[PromotionInformation] p
INNER JOIN [dbo].[CatalogEntry] e 
ON e.CatalogEntryId = CONVERT(INT, REPLACE(p.ContentLink, '__CatalogContent', ''))
GO

ALTER TABLE [dbo].[PromotionInformation] DROP COLUMN [ContentLink]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionInformationList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationList] 
GO

CREATE PROCEDURE [dbo].[PromotionInformationList]
	@OrderFormId int
AS
BEGIN
	SELECT
		   PromotionInformation.PromotionInformationId as PromotionInformationId,
		   PromotionInformation.EntryCodes AS EntryCodes,
		   PromotionInformation.PromotionLink AS PromotionLink,
		   PromotionInformation.SavedAmount AS SavedAmount,
		   PromotionInformation.Description AS Description,
		   PromotionInformation.RewardType AS RewardType,
		   PromotionInformation.DiscountType AS DiscountType,
		   PromotionInformation.CouponCode AS CouponCode,
		   PromotionInformation.AdditionalInformation AS AdditionalInformation,
		   PromotionInformation.VisitorGroup AS VisitorGroup
	FROM dbo.PromotionInformation
	WHERE PromotionInformation.OrderFormId = @OrderFormId
END
GO

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@OrderFormId INT,
	@PromotionInformation dbo.udttPromotionInformation READONLY
AS
BEGIN

    DELETE FROM dbo.PromotionInformation WHERE OrderFormId = @OrderFormId;

    INSERT INTO dbo.PromotionInformation(OrderFormId, EntryCodes, PromotionLink, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup)
    SELECT @OrderFormId, EntryCodes, PromotionLink, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup
    FROM @PromotionInformation

END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionRedemptionList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionRedemptionList] 
GO

CREATE PROCEDURE [dbo].[PromotionRedemptionList]
	@PromotionIds udttIdTable readonly,
	@CustomerId UNIQUEIDENTIFIER = NULL
AS
BEGIN
	IF @CustomerId IS NULL
		BEGIN

	    SELECT PromotionRedemption.PromotionId,
		0  AS [CustomerTotalCount],
		PromotionTotalCount = SUM([COUNT]) 
		FROM PromotionRedemption WHERE PromotionId IN (SELECT DISTINCT ID FROM @PromotionIds)
		GROUP BY PromotionRedemption.PromotionId;

		END
	ELSE
		BEGIN
		    CREATE TABLE #Totals(PromotionId int, [PromotionTotalCount] int);
			INSERT INTO #Totals 
			SELECT PromotionRedemption.PromotionId, SUM([COUNT]) 
			FROM PromotionRedemption WHERE PromotionId IN (SELECT DISTINCT ID FROM @PromotionIds)
			GROUP BY PromotionRedemption.PromotionId;

			SELECT PromotionLevel.PromotionId AS [PromotionId], 
				   CustomerLevel.[Count] AS [CustomerTotalCount],
				   [PromotionTotalCount] = PromotionLevel.[PromotionTotalCount]
			FROM dbo.PromotionRedemption AS CustomerLevel RIGHT JOIN #Totals AS PromotionLevel	
			ON CustomerLevel.PromotionId = PromotionLevel.PromotionId AND CustomerLevel.CustomerId = @CustomerId;
		
			DROP TABLE #Totals;
		END
END


GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionRedemptionSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionRedemptionSave] 
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionRedemption') DROP TYPE [dbo].[udttPromotionRedemption]
GO

CREATE TYPE [dbo].[udttPromotionRedemption] AS TABLE(		
	[PromotionId] [int] NOT NULL,
	[Count] [int] NOT NULL
)

GO

CREATE PROCEDURE [dbo].[PromotionRedemptionSave]
	@CustomerId UNIQUEIDENTIFIER,
	@RedeemedPromotions udttPromotionRedemption readonly
AS
BEGIN
	MERGE dbo.PromotionRedemption WITH(HOLDLOCK) AS target
	USING @RedeemedPromotions AS source
	ON (target.PromotionId = source.PromotionId AND target.CustomerId = @CustomerId)
	WHEN MATCHED THEN 
		UPDATE SET [Count] = target.[Count] + source.[Count]
	WHEN NOT MATCHED THEN
		INSERT (CustomerId, PromotionId, [Count])
		VALUES(@CustomerId, source.PromotionId, source.[Count]);
END

GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[PromotionRedemptionDelete]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) 
	DROP PROCEDURE [dbo].[PromotionRedemptionDelete] 
GO

CREATE PROCEDURE [dbo].[PromotionRedemptionDelete]
	@PromotionId INT
AS
BEGIN
	DELETE FROM dbo.PromotionRedemption WHERE PromotionId = @PromotionId;
END

GO

--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 3, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
