--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 16    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[OrderPerPromotionReportData]...';


GO
CREATE TABLE [dbo].[OrderPerPromotionReportData] (
    [PromotionGuid] UNIQUEIDENTIFIER NOT NULL,
    [OrderCount]    INT              NOT NULL,
    PRIMARY KEY CLUSTERED ([PromotionGuid] ASC)
);


GO
PRINT N'Altering [dbo].[PromotionInformationGetOrders]...';


GO
ALTER PROCEDURE [dbo].[PromotionInformationGetOrders]
	@ContentGuidList [dbo].[udttContentGuidList] READONLY
AS
BEGIN
	SELECT P.PromotionGuid, COUNT(F.OrderGroupId) AS OrderGroupCount
	FROM PromotionInformation P
		INNER JOIN OrderForm F ON F.OrderFormId = P.OrderFormId 
		INNER JOIN @ContentGuidList C ON C.ContentGuid = P.PromotionGuid
	WHERE P.IsRedeemed = 1 AND P.IsReturnOrderForm = 0
	GROUP BY P.PromotionGuid
	UNION
	SELECT NULL, COUNT(DISTINCT(F.OrderGroupId)) AS OrderGroupCount
	FROM PromotionInformation P
		INNER JOIN OrderForm F ON F.OrderFormId = P.OrderFormId
		INNER JOIN @ContentGuidList C ON C.ContentGuid = P.PromotionGuid
	WHERE P.IsRedeemed = 1 AND P.IsReturnOrderForm = 0
END
GO
PRINT N'Creating [dbo].[OrderPerPromotionReportData_Load]...';


GO
CREATE PROCEDURE [dbo].[OrderPerPromotionReportData_Load]
	@ContentGuidList [dbo].[udttContentGuidList] READONLY
AS
BEGIN
	SELECT P.PromotionGuid, P.OrderCount
	FROM dbo.OrderPerPromotionReportData P
	INNER JOIN @ContentGuidList C on C.ContentGuid = P.PromotionGuid
END
GO
PRINT N'Creating [dbo].[OrderPerPromotionReportData_Upsert]...';


GO
CREATE PROCEDURE [dbo].[OrderPerPromotionReportData_Upsert]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CampaignGuid UNIQUEIDENTIFIER
AS
BEGIN
	;WITH CTE1 AS
		(SELECT P.PromotionGuid AS PromotionGuid, COUNT(DISTINCT(F.OrderGroupId)) AS OrderGroupCount
		FROM PromotionInformation P
			INNER JOIN OrderForm F ON F.OrderFormId = P.OrderFormId 
			INNER JOIN @PromotionGuids C ON C.ContentGuid = P.PromotionGuid
		WHERE P.IsRedeemed = 1 AND P.IsReturnOrderForm = 0
		GROUP BY P.PromotionGuid
		)
	,CTE2 AS
		(SELECT p.ContentGuid as PromotionGuid, COALESCE(CTE1.OrderGroupCount, 0) as OrderGroupCount 
		FROM @PromotionGuids p
		LEFT JOIN CTE1 ON p.ContentGuid = CTE1.PromotionGuid

		UNION

		SELECT @CampaignGuid AS PromotionGuid, COUNT(DISTINCT(F.OrderGroupId)) AS OrderGroupCount
		FROM PromotionInformation P
			INNER JOIN OrderForm F ON F.OrderFormId = P.OrderFormId
			INNER JOIN @PromotionGuids C ON C.ContentGuid = P.PromotionGuid
		WHERE P.IsRedeemed = 1 AND P.IsReturnOrderForm = 0
		)	

	MERGE dbo.OrderPerPromotionReportData t
	USING
		CTE2 s
	ON t.PromotionGuid = s.PromotionGuid
	WHEN MATCHED
    THEN UPDATE SET 
    	t.OrderCount = s.OrderGroupCount
	WHEN NOT MATCHED BY TARGET
    THEN INSERT (PromotionGuid, OrderCount)
        VALUES (s.PromotionGuid, s.OrderGroupCount);
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 16, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
