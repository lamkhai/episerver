--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 7, @minor int = 9, @patch int = 0    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[PromotionInformationGetOrders]...';


GO
CREATE PROCEDURE [dbo].[PromotionInformationGetOrders]
	@ContentGuidList [dbo].[udttContentGuidList] READONLY
AS
BEGIN
	SELECT P.PromotionGuid, F.OrderGroupId 
	FROM PromotionInformation P
		INNER JOIN OrderForm F ON F.OrderFormId = P.OrderFormId
		INNER JOIN OrderGroup_PurchaseOrder PO ON PO.ObjectId = F.OrderGroupId
		INNER JOIN @ContentGuidList C ON C.ContentGuid = P.PromotionGuid
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(7, 9, 0, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
