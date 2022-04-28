--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    DECLARE @major INT = 7, @minor INT = 3, @patch INT = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        SELECT 0,'Already correct database version' 
    ELSE 
        SELECT 1, 'Upgrading database' 
    END 
ELSE 
    SELECT -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
GO 

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttContentGuidList') DROP TYPE [dbo].[udttContentGuidList]
GO

CREATE TYPE [dbo].[udttContentGuidList] AS TABLE(	
	ContentGuid UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TYPE [dbo].[udttContentGuidContentLinkMap] AS TABLE(
	ContentLink VARCHAR(100) NOT NULL,
	ContentGuid UNIQUEIDENTIFIER NOT NULL
)
GO

ALTER TABLE PromotionInformation ADD CustomerId UNIQUEIDENTIFIER NULL;
GO

UPDATE PromotionInformation SET PromotionInformation.CustomerId = OrderGroup.CustomerId
FROM PromotionInformation INNER JOIN OrderForm 
ON PromotionInformation.OrderFormId = OrderForm.OrderFormId INNER JOIN OrderGroup 
ON OrderGroup.OrderGroupId = OrderForm.OrderGroupId;
GO

ALTER TABLE dbo.PromotionInformation DROP CONSTRAINT FK_PromotionInformation_OrderFormId;
GO

EXEC sp_rename @objname = 'PromotionInformation', @newname = 'PromotionInformation_Temp', @objtype = 'OBJECT';
GO

EXEC sp_rename @objname = 'PK_PromotionInformationId', @newname = 'PK_PromotionInformationId_Temp', @objtype = 'OBJECT';
GO

CREATE TABLE [dbo].[PromotionInformation](
	[PromotionInformationId]  INT IDENTITY(1,1) NOT NULL,
	[OrderFormId] INT NOT NULL,
	[EntryCodes] NVARCHAR(MAX) NOT NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
	[SavedAmount]  DECIMAL(18,3) NOT NULL,
	[RewardType] VARCHAR(50) NOT NULL,
	[Description]  NVARCHAR(4000) NULL,
	[DiscountType] VARCHAR(50) NOT NULL,
	[CouponCode] NVARCHAR(100) NULL,
	[AdditionalInformation] NVARCHAR(MAX) NULL,
	[VisitorGroup] UNIQUEIDENTIFIER NULL,
	[CustomerId] UNIQUEIDENTIFIER NOT NULL

 CONSTRAINT [PK_PromotionInformationId] PRIMARY KEY NONCLUSTERED ([PromotionInformationId] ASC),
 CONSTRAINT [FK_PromotionInformation_OrderFormId] FOREIGN KEY([OrderFormId])
	REFERENCES [dbo].[OrderForm] ([OrderFormId]) 
	ON UPDATE CASCADE 
	ON DELETE CASCADE
)
GO

CREATE CLUSTERED INDEX IDX_PromotionInformation_OrderFormId ON [dbo].[PromotionInformation]
(
	[OrderFormId]
)
GO

CREATE NONCLUSTERED INDEX IDX_PromotionInformation_PromotionGuid_CustomermId ON [dbo].[PromotionInformation]
(
	[PromotionGuid],
	[CustomerId]
)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionRedemptionSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionRedemptionSave];
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionRedemptionList]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionRedemptionList];
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionRedemptionDelete]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionRedemptionDelete];
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionRedemption') DROP TYPE [dbo].[udttPromotionRedemption];
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionRedemption]') AND OBJECTPROPERTY(id, N'IsTable') = 1) DROP TABLE [dbo].PromotionRedemption;
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationSave]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationSave];
GO

-- recreate udttPromotionInformation 
IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttPromotionInformation') DROP TYPE [dbo].[udttPromotionInformation]
GO

CREATE TYPE [dbo].[udttPromotionInformation] AS TABLE(		
	[PromotionInformationId] INT NULL,
	[OrderFormId] INT NOT NULL,
	[EntryCodes] NVARCHAR(MAX) NOT NULL,
	[PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
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

CREATE PROCEDURE [dbo].[PromotionInformationSave]
	@PromotionInformation dbo.udttPromotionInformation READONLY
AS
BEGIN

    DELETE FROM dbo.PromotionInformation WHERE OrderFormId IN (SELECT OrderFormId FROM @PromotionInformation);

    INSERT INTO dbo.PromotionInformation(OrderFormId, EntryCodes, PromotionGuid, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId)
    SELECT OrderFormId, EntryCodes, PromotionGuid, SavedAmount, RewardType, Description, DiscountType, CouponCode, AdditionalInformation, VisitorGroup, CustomerId
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

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[PromotionInformationGetRedemptions]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[PromotionInformationGetRedemptions]
GO

CREATE PROCEDURE [dbo].[PromotionInformationGetRedemptions]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@ExcludeOrderFormId INT = NULL
AS
BEGIN

	IF @CustomerId IS NULL
		BEGIN

	    SELECT PromotionInformation.PromotionGuid, COUNT(*) AS TotalRedemptions, 0 AS CustomerRedemptions 
		FROM PromotionInformation 
		WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids)
		GROUP BY PromotionInformation.PromotionGuid;

		END
	ELSE
		BEGIN

		    CREATE TABLE #Totals(PromotionGuid UNIQUEIDENTIFIER, TotalRedemptions INT);

			INSERT INTO #Totals 
			SELECT PromotionInformation.PromotionGuid, COUNT(*) AS TotalRedemptions
			FROM PromotionInformation WHERE PromotionGuid IN (SELECT DISTINCT ContentGuid FROM @PromotionGuids) AND (PromotionInformation.OrderFormId != @ExcludeOrderFormId OR @ExcludeOrderFormId IS NULL)
			GROUP BY PromotionInformation.PromotionGuid;

			SELECT PromotionLevel.PromotionGuid AS PromotionGuid, TotalRedemptions = PromotionLevel.TotalRedemptions, COUNT(CustomerId) AS CustomerRedemptions
			FROM dbo.PromotionInformation AS CustomerLevel 
			RIGHT JOIN #Totals AS PromotionLevel	
			ON CustomerLevel.PromotionGuid = PromotionLevel.PromotionGuid AND CustomerLevel.CustomerId = @CustomerId AND CustomerLevel.OrderFormId != @ExcludeOrderFormId
			GROUP BY PromotionLevel.PromotionGuid, PromotionLevel.TotalRedemptions;

			DROP TABLE #Totals;

		END
END
GO

IF EXISTS (SELECT * FROM sys.types WHERE is_table_type = 1 AND name ='udttContentGuidContentLinkMap') DROP TYPE [dbo].[udttContentGuidContentLinkMap]
GO

CREATE TYPE [dbo].[udttContentGuidContentLinkMap] AS TABLE(
	ContentLink VARCHAR(100) NOT NULL,
	ContentGuid UNIQUEIDENTIFIER NOT NULL
)
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID (N'[dbo].[MigratePromotionInformation]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[MigratePromotionInformation]
GO

CREATE PROCEDURE [dbo].[MigratePromotionInformation]
	@PromotionMap [dbo].[udttContentGuidContentLinkMap] READONLY
AS
BEGIN
	INSERT INTO dbo.PromotionInformation(CustomerId, OrderFormId, 
                    EntryCodes, SavedAmount, RewardType, Description, 
                    DiscountType, CouponCode, AdditionalInformation, 
                    VisitorGroup, PromotionGuid
                ) SELECT 
                    p.CustomerId, 
                    p.OrderFormId, 
                    p.EntryCodes, 
                    p.SavedAmount, 
                    p.RewardType, 
                    p.Description, 
                    p.DiscountType, 
                    p.CouponCode, 
                    p.AdditionalInformation, 
                    p.VisitorGroup,
                    m.ContentGuid  FROM PromotionInformation_temp p
                    INNER JOIN @PromotionMap m on m.ContentLink = p.PromotionLink
END
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[mdpsp_sys_DeleteMetaKeyObjects]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[mdpsp_sys_DeleteMetaKeyObjects] 
GO

CREATE PROCEDURE [dbo].[mdpsp_sys_DeleteMetaKeyObjects]
	@MetaClassId	INT,
	@MetaFieldId	INT	=	-1,
	@MetaObjectId	INT	=	-1,
	@WorkId			INT =	-1
AS
	
	CREATE TABLE #MetaKeysToRemove (MetaKey INT)
	INSERT INTO #MetaKeysToRemove (MetaKey)
		SELECT MK.MetaKey FROM MetaKey MK WHERE
		(@MetaObjectId = MK.MetaObjectId OR @MetaObjectId = -1)  AND
		(@MetaClassId = MK.MetaClassId OR @MetaClassId = -1) AND
		(@MetaFieldId = MK.MetaFieldId  OR @MetaFieldId = -1) AND
		(@WorkId = MK.WorkId OR @WorkId = -1)
	
	IF EXISTS (SELECT 1 FROM #MetaKeysToRemove)
	BEGIN
		-- Delete MetaObjectValue
		DELETE MO FROM MetaObjectValue MO INNER JOIN #MetaKeysToRemove M ON MO.MetaKey = M.MetaKey
		IF @@ERROR <> 0 GOTO ERR
		
		-- Delete MetaStringDictionaryValue
		DELETE MSD FROM MetaStringDictionaryValue MSD INNER JOIN #MetaKeysToRemove M ON MSD.MetaKey = M.MetaKey 
		IF @@ERROR <> 0 GOTO ERR
		
		--Delete MetaMultiValueDictionary
		DELETE MV FROM MetaMultiValueDictionary MV INNER JOIN #MetaKeysToRemove M ON MV.MetaKey = M.MetaKey
		IF @@ERROR <> 0 GOTO ERR
		
		--Delete MetaFileValue
		DELETE MF FROM MetaFileValue MF INNER JOIN #MetaKeysToRemove M ON MF.MetaKey = M.MetaKey
		IF @@ERROR <> 0 GOTO ERR
		
		--Delete MetaKey
		DELETE MK FROM MetaKey MK INNER JOIN #MetaKeysToRemove M ON MK.MetaKey = M.MetaKey
		IF @@ERROR <> 0 GOTO ERR
		
	END
	DROP TABLE #MetaKeysToRemove
ERR:
	IF object_id('tempdb..#MetaKeysToRemove') IS NOT NULL
	BEGIN
	DROP TABLE #MetaKeysToRemove
	END

	RETURN
GO

--beginUpdatingDatabaseVersion 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 3, 1, GETUTCDATE()) 
GO 
--endUpdatingDatabaseVersion 
