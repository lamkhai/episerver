--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 20    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Altering [dbo].[PromotionInformationGetRedemptions]...';

GO

ALTER PROCEDURE [dbo].[PromotionInformationGetRedemptions]
	@PromotionGuids [dbo].[udttContentGuidList] READONLY,
	@CustomerId UNIQUEIDENTIFIER = NULL,
	@ExcludeOrderFormId INT = NULL
AS
BEGIN

	IF @CustomerId IS NULL
		BEGIN
			SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions, 0 AS CustomerRedemptions, 0 AS OrderFormId 
			FROM PromotionInformation p
			INNER JOIN @PromotionGuids g ON p.PromotionGuid = g.ContentGuid
			WHERE IsRedeemed = 1 AND IsReturnOrderForm = 0
			GROUP BY p.PromotionGuid;
		END
	ELSE
		BEGIN
			WITH CTE (PromotionGuid, TotalRedemptions)
				AS
				(SELECT p.PromotionGuid, COUNT(*) AS TotalRedemptions
				FROM PromotionInformation p
				INNER JOIN @PromotionGuids g ON p.PromotionGuid = g.ContentGuid
				AND (p.OrderFormId != @ExcludeOrderFormId OR @ExcludeOrderFormId IS NULL) 
				AND IsRedeemed = 1 AND IsReturnOrderForm = 0
				GROUP BY p.PromotionGuid)

			SELECT PromotionLevel.PromotionGuid AS PromotionGuid, TotalRedemptions = PromotionLevel.TotalRedemptions, COUNT(CustomerId) AS CustomerRedemptions, @ExcludeOrderFormId AS OrderFormId
			FROM dbo.PromotionInformation AS CustomerLevel 
			RIGHT JOIN CTE AS PromotionLevel 
			ON CustomerLevel.PromotionGuid = PromotionLevel.PromotionGuid AND CustomerLevel.CustomerId = @CustomerId
			AND IsRedeemed = 1 AND IsReturnOrderForm = 0
			AND CustomerLevel.OrderFormId != @ExcludeOrderFormId
			GROUP BY PromotionLevel.PromotionGuid, PromotionLevel.TotalRedemptions;

		END
END

GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 20, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
