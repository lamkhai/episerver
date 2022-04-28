--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 10, @patch int = 1    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO

ALTER PROCEDURE [dbo].[ecf_reporting_Shipping] 
	@ApplicationID uniqueidentifier,
	@MarketId nvarchar(8),
	@CurrencyCode NVARCHAR(8),
	@interval VARCHAR(20),
	@startdate DATETIME, -- parameter expected in UTC
	@enddate DATETIME, -- parameter expected in UTC
	@offset_st INT,
	@offset_dt INT
AS

BEGIN

	SELECT	x.Period,  
			ISNULL(y.ShippingMethodDisplayName, 'NONE') AS ShippingMethodDisplayName,
			ISNULL(y.NumberofOrders, 0) AS NumberOfOrders,
			ISNULL(y.ShippingTotal, 0) AS TotalShipping,
			ISNULL(y.ShippingDiscount, 0) AS ShippingDiscount,
			ISNULL(y.ShippingCost, 0) AS ShippingCost
			
	FROM 
	(
		SELECT DISTINCT 
			(CASE WHEN @interval = 'Day'
				THEN CONVERT(VARCHAR(10), D.DateFull, 101)
			WHEN @interval = 'Month'
			THEN (DATENAME(MM, D.DateFull) + ', ' + CAST(YEAR(D.DateFull) AS VARCHAR(20))) 
			ElSE CAST(YEAR(D.DateFull) AS VARCHAR(20))  
			End) AS Period 
		FROM ReportingDates D LEFT OUTER JOIN OrderFormEx FEX ON D.DateFull = FEX.Created
		WHERE 
			-- convert back from UTC using offset to generate a list of WEBSERVER datetimes
			D.DateFull BETWEEN 
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@startdate, @offset_st, @offset_dt) as float)) as datetime) AND
				cast(floor(cast(dbo.fn_GetDaylightSavingsTime(@enddate, @offset_st, @offset_dt) as float)) as datetime)
	) AS x

	LEFT JOIN

	(
		SELECT DISTINCT (CASE WHEN @interval = 'Day'
							THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
							WHEN @interval = 'Month'
							THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' 
								+ CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20)) )
							ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
							End) AS Period, 
				COUNT(S.ShipmentId) AS NumberofOrders, 
				SUM(S.ShipmentTotal) AS ShippingTotal,
				SUM(S.ShippingDiscountAmount) AS ShippingDiscount,
				SUM(S.ShipmentTotal - S.ShippingDiscountAmount) AS ShippingCost,
				SM.DisplayName AS ShippingMethodDisplayName
		FROM Shipment AS S INNER JOIN
		ShippingMethod AS SM ON S.ShippingMethodId = SM.ShippingMethodId INNER JOIN
			OrderForm AS F ON S.OrderFormId = F.OrderFormId INNER JOIN
			OrderFormEx AS FEX ON FEX.ObjectId = F.OrderFormId INNER JOIN
			OrderGroup AS OG ON OG.OrderGroupId = F.OrderGroupId
		WHERE (FEX.Created BETWEEN @startdate AND @enddate)
		AND @ApplicationID = (SELECT  ApplicationId FROM OrderGroup  WHERE OrderGroupId = F.OrderGroupId)
		AND OG.BillingCurrency = @CurrencyCode 
		AND (LEN(@MarketId) = 0 OR OG.MarketId = @MarketId)
		AND S.Status <> 'Cancelled'
		GROUP BY (Case WHEN @interval = 'Day'
					THEN CONVERT(VARCHAR(20), dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt), 101)
					WHEN @interval = 'Month'
					THEN (DATENAME(MM, dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) + ', ' + CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))  )
					ElSE CAST(YEAR(dbo.fn_GetDaylightSavingsTime(FEX.Created, @offset_st, @offset_dt)) AS VARCHAR(20))   
				END), SM.DisplayName
	) AS y

	ON x.Period = y.Period
	ORDER BY CONVERT(datetime, x.Period, 101)

END
GO
 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 10, 1, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
