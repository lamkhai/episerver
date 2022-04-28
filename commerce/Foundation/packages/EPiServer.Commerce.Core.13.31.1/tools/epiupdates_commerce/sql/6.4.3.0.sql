--beginvalidatingquery 
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SchemaVersion') 
    BEGIN 
    declare @major int = 6, @minor int = 4, @patch int = 3    
    IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE Major = @major AND Minor = @minor AND Patch = @patch) 
        select 0,'Already correct database version' 
    ELSE 
        select 1, 'Upgrading database' 
    END 
ELSE 
    select -1, 'Not an EPiServer Commerce database' 
--endvalidatingquery 
 
GO 

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[ecf_GenerateReportingDates]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1) DROP PROCEDURE [dbo].[ecf_GenerateReportingDates] 

GO

CREATE PROCEDURE ecf_GenerateReportingDates
@EndDate DATE
AS
BEGIN
	DECLARE @StartDate DATE
	SET @StartDate = (SELECT MAX(DateFull) FROM [dbo].[ReportingDates])

	--If there is no reporting date yet, make sure to add the current date.
	IF (@StartDate IS NULL)
		SET @StartDate = GETDATE()
	ELSE
	--We will add the start date as the day after the max date in ReportingDates
		SET @StartDate = DATEADD(day, 1, @StartDate)

	IF (@EndDate > @StartDate)
	BEGIN
		CREATE TABLE #ReportingDates (ReportingDate Datetime2);
		WITH ReportingDates_CTE(Date) AS		
		( 
			SELECT @StartDate 
			UNION ALL
			SELECT DateAdd(day,1,ReportingDates_CTE.Date) FROM ReportingDates_CTE WHERE ReportingDates_CTE.Date <= @EndDate
		)
		
		INSERT INTO #ReportingDates
		SELECT * FROM ReportingDates_CTE OPTION (MAXRECURSION 32767);


		INSERT INTO [dbo].[ReportingDates] 
		(DateKey, DateFull, CharacterDate, FullYear, QuarterNumber, WeekNumber, WeekDayName, MonthDay, MonthName, YearDay, 
		DateDefinition, WeekDay, MonthNumber)

		SELECT cast (REPLACE(convert(varchar, ReportingDate, 102), '.', '') as int), 
				 ReportingDate,
				 convert(varchar, ReportingDate, 101),
				 YEAR(ReportingDate),
				 MONTH(ReportingDate) / 3,
				 DATEPART(wk, ReportingDate),
				 DATENAME(dw, ReportingDate),
				 DAY(ReportingDate),
				 DATENAME(month, ReportingDate),
				 DATEPART(dy, ReportingDate),
				 DATENAME(month, ReportingDate) + CAST(DAY(ReportingDate) AS varchar) + ',   
		           ' + CAST(YEAR(ReportingDate) AS varchar),
				 DATEPART(dw, ReportingDate),
				 MONTH(ReportingDate)
				 FROM #ReportingDates

		DROP TABLE #ReportingDates
	END
END

GO

--Generate reporting dates 10 years from now.
DECLARE @EndDate Date
SET @EndDate = DATEADD(year, 10, GETUTCDATE()) 
EXEC ecf_GenerateReportingDates @EndDate
GO

 
--beginUpdatingDatabaseVersion 
 
INSERT INTO dbo.SchemaVersion(Major, Minor, Patch, InstallDate) VALUES(6, 4, 3, GETUTCDATE()) 
 
GO 

--endUpdatingDatabaseVersion 
