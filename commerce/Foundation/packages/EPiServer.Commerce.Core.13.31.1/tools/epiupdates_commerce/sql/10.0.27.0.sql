--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 10, @minor int = 0, @patch int = 27    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
PRINT N'Creating [dbo].[ecf_LineItemReportSubscriptionData_Get]...';


GO
CREATE PROCEDURE [dbo].[ecf_LineItemReportSubscriptionData_Get]
	@FromDate DateTime,
	@ToDate DateTime
AS
BEGIN
	SELECT OOP.TotalRevenue, L.LineItemId, L.CatalogEntryId AS LineItemCode, L.DisplayName, L.PlacedPrice, L.Quantity, L.ExtendedPrice, 
		L.LineItemDiscountAmount AS EntryDiscountAmount, L.Epi_SalesTax AS SalesTax, 
		O.BillingCurrency AS Currency, O.OrderGroupId, O.[Status], O.CustomerId, O.CustomerName, O.MarketId, 
		PP.PlanCycleMode, PP.PlanCycleLength , PP.PlanMaxCyclesCount , PP.PlanCompletedCyclesCount, 
		PP.PlanStartDate, PP.PlanEndDate, PP.LastTransactionDate, PP.PlanIsActive
	FROM LineItem L
	INNER JOIN OrderGroup O ON O.OrderGroupId = L.OrderGroupId
	INNER JOIN OrderGroup_PaymentPlan PP ON PP.ObjectId = L.OrderGroupId
	LEFT JOIN (
		SELECT SUM(O.Total) AS TotalRevenue, PO.ParentOrderGroupId FROM OrderGroup_PaymentPlan PP 
		INNER JOIN OrderGroup_PurchaseOrder PO ON PO.ParentOrderGroupId = PP.ObjectId
		INNER JOIN OrderGroup O ON PO.ObjectId = O.OrderGroupId
		WHERE PO.ParentOrderGroupId > 0 AND O.Status = 'Completed'
		GROUP BY ParentOrderGroupId
	) OOP ON OOP.ParentOrderGroupId = L.OrderGroupId
	WHERE PP.Created BETWEEN @FromDate AND @ToDate
	ORDER BY O.OrderGroupId ASC
END
GO
 
GO 


 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(10, 0, 27, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
